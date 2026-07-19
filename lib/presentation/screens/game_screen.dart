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

/// Токен `hudIcon` `hsl(215 9% 72%)`, пересчитан детерминированно
/// (`colorsys.hls_to_rgb`), как в Стори 02 T2 (`hud.dart` `_CtlButton`).
const Color _hudIconColor = Color(0xFFB1B7BE);

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
            // Топбар (Стори 02 T3, канон `docs/design/game-field.html`
            // `.topbar`/`.chip`/`.chip .sw`/`.pausebtn`): чип «ДЕТАЛЬ N/7» со
            // свотчем материала слева, dev-входы (читы + корабль) справа.
            SizedBox(
              height: 44.0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _PartChip(
                      fragmentIndex: state.level.fragmentIndex,
                      material: ShipMaterials.defaultMaterials
                          .materialForPart(state.level.fragmentIndex),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Вход в чит-меню — только в дев-сборке.
                        if (kDebugMode)
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: _DevButton(
                              key: const Key('cheat_button'),
                              icon: Icons.bug_report,
                              tooltip: 'Читы',
                              onTap: _openCheatMenu,
                            ),
                          ),
                        _DevButton(
                          key: const Key('ship_button'),
                          icon: Icons.rocket_launch,
                          tooltip: 'Корабль',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ShipScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
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

/// Чип детали в топбаре — канон `.chip`/`.chip .sw` (Стори 02 T3):
/// matteBlack fill, gunmetal 1px border, radius 8, свотч материала +
/// текст «ДЕТАЛЬ N/7» разрядкой.
class _PartChip extends StatelessWidget {
  const _PartChip({required this.fragmentIndex, required this.material});

  /// Индекс текущей детали (0-based); в тексте отображается `fragmentIndex+1`.
  final int fragmentIndex;

  /// Материал текущей детали (заливка свотча).
  final BlockMaterial material;

  static const Color _matteBlack = Color(0xFF1D2025); // matteBlack token
  static const Color _gunmetal = Color(0xFF32363E); // gunmetal token
  static const Color _textColor = Color(0xFFAEB6BF); // chip text color

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7.0, horizontal: 11.0),
      decoration: BoxDecoration(
        color: _matteBlack,
        border: Border.all(color: _gunmetal, width: 1.0),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Swatch(color: material.color),
          const SizedBox(width: 8.0),
          Text(
            'ДЕТАЛЬ ${fragmentIndex + 1}/$kShipPartCount',
            style: const TextStyle(
              color: _textColor,
              fontSize: 12.0,
              letterSpacing: 0.72, // .06em @ 12px
            ),
          ),
        ],
      ),
    );
  }
}

/// Свотч материала детали — канон `.chip .sw` (Стори 02 T3): 14×14, radius 3,
/// лёгкий bevel (inset top-light/bottom-dark, приближено полосами — та же
/// техника, что `_CtlButton`/`_BoomButton` в `hud.dart`).
class _Swatch extends StatelessWidget {
  const _Swatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3.0),
      child: SizedBox(
        width: 14.0,
        height: 14.0,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: color),
            Column(
              children: [
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.10),
                ),
                const Expanded(child: SizedBox.shrink()),
                Container(
                  height: 1,
                  color: Colors.black.withValues(alpha: 0.35),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Dev-кнопка топбара (читы/корабль) — канон `.pausebtn` (Стори 02 T3):
/// 40×40, radius 10, matteBlack fill, gunmetal 1px border, глиф `hudIcon`.
class _DevButton extends StatelessWidget {
  const _DevButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  static const Color _matteBlack = Color(0xFF1D2025); // matteBlack token
  static const Color _gunmetal = Color(0xFF32363E); // gunmetal token

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40.0,
          height: 40.0,
          decoration: BoxDecoration(
            color: _matteBlack,
            border: Border.all(color: _gunmetal, width: 1.0),
            borderRadius: BorderRadius.circular(10.0),
          ),
          child: Icon(icon, color: _hudIconColor, size: 20.0),
        ),
      ),
    );
  }
}
