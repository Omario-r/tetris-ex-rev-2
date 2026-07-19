import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../../game_engine/game/game_controller.dart';
import '../../game_engine/game/game_state.dart';
import '../../game_engine/models/board.dart';
import '../../game_engine/rules/randomizer.dart';
import '../../game_engine/data/level_map.dart';
import '../../application/progress_service.dart';
import '../theme/block_material.dart';
import '../theme/block_theme.dart';
import '../theme/level_skin.dart';
import '../theme/ship_materials.dart';
import '../widgets/board_painter.dart';
import '../widgets/hud.dart';
import '../widgets/ship.dart';
import 'cheat_menu.dart';
import 'ship_screen.dart';

/// The main game screen widget that displays the Tetris game.
///
/// Uses [TickerProviderStateMixin] to drive the game loop via an
/// [AnimationController] at approximately 60fps.
class GameScreen extends StatefulWidget {
  /// The level index to load (0..15). Defaults to 0.
  final int levelIndex;

  /// Creates a [GameScreen] with the given [levelIndex].
  const GameScreen({super.key, this.levelIndex = 0});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late final AnimationController _animController;
  late final GameController _controller;
  late double _lastTime;
  static const double _cellSize = 28.0;
  bool _winHandled = false;

  @override
  void initState() {
    super.initState();
    _lastTime = 0.0;
    _winHandled = false;

    // Load level from LevelMap
    final level = LevelMap.levelAt(widget.levelIndex);

    // Initialize game state
    final initialState = GameState(
      board: Board(level.boardWidth, level.boardHeight),
      fallingPiece: null,
      phase: GamePhase.spawning,
      generator: SevenBagGenerator(),
      level: level,
    );

    _controller = GameController(
      initialState: initialState,
      gravityInterval: 1,
    );

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    )..repeat();
    _animController.addListener(_onTick);
  }

  @override
  void dispose() {
    _animController.removeListener(_onTick);
    _animController.dispose();
    super.dispose();
  }

  void _onTick() {
    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final dt = _lastTime == 0.0 ? 0.0 : now - _lastTime;
    _lastTime = now;

    if (dt > 0) {
      _controller.tick(dt);
    }

    // Check for win condition
    final state = _controller.state;
    if (state.isWin) {
      _handleWin();
    }

    setState(() {});
  }

  /// Единая точка обработки победы: и по игровому состоянию (тик), и по читу
  /// «мгновенная победа». Идемпотентна (`_winHandled`) — победа обрабатывается один раз.
  void _handleWin() {
    if (_winHandled) return;
    _winHandled = true;
    _onWin();
  }

  Future<void> _onWin() async {
    final completedLevel = widget.levelIndex;
    await ProgressService().advanceOnWin();
    if (!mounted) return;

    // Capture navigator BEFORE pushReplacement while context is still valid
    final navigator = Navigator.of(context);

    // Последний дев-уровень (индекс kShipPartCount-1) → корабль собран (N/N).
    final isLastDevLevel = completedLevel >= kShipPartCount - 1;
    final collected = isLastDevLevel ? kShipPartCount : completedLevel + 1;

    // Авто-показ прироста: победа → экран корабля с новой деталью.
    navigator.pushReplacement(
      MaterialPageRoute(
        builder: (_) => ShipScreen.reveal(
          collectedCount: collected,
          isComplete: isLastDevLevel,
          onNext: () =>
              _afterShipReveal(navigator, completedLevel, isLastDevLevel),
        ),
      ),
    );
  }

  Future<void> _afterShipReveal(
    NavigatorState navigator,
    int completedLevel,
    bool isLastDevLevel,
  ) async {
    if (isLastDevLevel) {
      // Корабль собран → сброс прогресса и новый круг с уровня 1.
      await ProgressService().reset();
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => const GameScreen(levelIndex: 0)),
      );
    } else {
      navigator.pushReplacement(
        MaterialPageRoute(
          builder: (_) => GameScreen(levelIndex: completedLevel + 1),
        ),
      );
    }
  }

  // --- Читы (только dev-сборка, вход под kDebugMode) ---

  void _openCheatMenu() {
    showCheatMenu(
      context,
      onSelectLevel: _cheatSelectLevel,
      onInstantWin: _cheatInstantWin,
      onSetShipParts: _cheatSetShipParts,
      onSetCharges: _cheatSetCharges,
    );
  }

  /// Чит «выбор уровня»: перезапустить игру на уровне `levelIndex`.
  void _cheatSelectLevel(int levelIndex) {
    Navigator.of(context).pop(); // закрыть bottom sheet
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => GameScreen(levelIndex: levelIndex)),
    );
  }

  /// Чит «мгновенная победа»: тот же пост-победный поток, что после обычной победы.
  /// Движок не трогаем — засчитываем победу на мета-уровне (`_handleWin` → `advanceOnWin`).
  void _cheatInstantWin() {
    Navigator.of(context).pop(); // закрыть bottom sheet
    _handleWin();
  }

  /// Чит «установка состояния корабля»: собрано N деталей (N = 0..kShipPartCount).
  /// На мета-уровне — просто сохранённый прогресс (ключ `current_level`).
  Future<void> _cheatSetShipParts(int parts) async {
    Navigator.of(context).pop(); // закрыть bottom sheet
    await ProgressService().setCurrentLevel(parts);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Корабль: собрано $parts'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  /// Чит «заряды взрыва» (эпик «Взрыв»): выставить заряды в текущей партии напрямую.
  void _cheatSetCharges(int charges) {
    Navigator.of(context).pop(); // закрыть bottom sheet
    setState(() => _controller.setCharges(charges));
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    final boardWidth = state.level.boardWidth;
    final boardHeight = state.level.boardHeight;
    final boardPixelWidth = boardWidth * _cellSize;
    final boardPixelHeight = boardHeight * _cellSize;

    return Scaffold(
      // spaceBg token: hsl(220 14% 7%) = #0F1114 — "космос"-фон экрана.
      backgroundColor: const Color(0xFF0F1114),
      // SafeArea: у экрана нет AppBar — без него шапка (в т.ч. кнопка «Корабль»)
      // уходит под системный статус-бар/вырез и не нажимается.
      body: SafeArea(
        child: Column(
          children: [
            // HUD: уровень + вход на экран корабля
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Level ${widget.levelIndex + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Вход в чит-меню — только в дев-сборке.
                      if (kDebugMode)
                        IconButton(
                          key: const Key('cheat_button'),
                          tooltip: 'Читы',
                          icon: const Icon(
                            Icons.bug_report,
                            color: Colors.white,
                          ),
                          onPressed: _openCheatMenu,
                        ),
                      IconButton(
                        key: const Key('ship_button'),
                        tooltip: 'Корабль',
                        icon: const Icon(
                          Icons.rocket_launch,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ShipScreen()),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Game board with overlay, framed as mokap `.board`: 1px gunmetal
            // border, radius 6.
            Container(
              width: boardPixelWidth,
              height: boardPixelHeight,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                border: Border.all(color: BlockMaterial.gunmetal.color),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Stack(
                children: [
                  // Board painter
                  CustomPaint(
                    size: Size(boardPixelWidth, boardPixelHeight),
                    painter: BoardPainter(
                      state: state,
                      cellSize: _cellSize,
                      theme: BlockTheme.defaultTheme,
                      levelMaterial: LevelSkin.materialForLevelIndex(
                        widget.levelIndex,
                      ),
                      shipMaterials: ShipMaterials.defaultMaterials,
                      animValue: _animController.value,
                    ),
                  ),
                  // Win/Lose overlay
                  if (state.isWin || state.isLost)
                    Container(
                      width: boardPixelWidth,
                      height: boardPixelHeight,
                      color: Colors.black54,
                      child: Center(
                        child: Text(
                          state.isWin ? 'YOU WIN 🎉' : 'GAME OVER',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Control panel — фиксированная зона HUD (Стори 02 T2, канон
            // `.hud` height:150; `GameHud` уже сама несёт эту высоту).
            GameHud(
              controller: _controller,
              state: state,
              animValue: _animController.value,
            ),
          ],
        ),
      ),
    );
  }
}
