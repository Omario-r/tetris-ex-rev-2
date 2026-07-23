import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../../application/progress_service.dart';
import '../../game_engine/data/level_map.dart';
import '../../game_engine/models/target_mask.dart';
import '../../game_engine/packing/pack_controller.dart';
import '../../game_engine/packing/pack_piece.dart';
import '../../game_engine/packing/pack_slicer.dart';
import '../../game_engine/packing/pack_state.dart';
import '../theme/block_material.dart';
import '../theme/ship_materials.dart';
import '../widgets/packing_painter.dart';
import '../widgets/ship.dart';
import 'cheat_menu.dart';
import 'ship_screen.dart';

/// Токен `hudIcon` `hsl(215 9% 72%)` — глиф dev-кнопок топбара.
const Color _hudIconColor = Color(0xFFB1B7BE);

/// Режим подачи кусочков (эпик «Укладка»): весь набор сразу (`fullSet`) или
/// порционный лоток (`tray3` — 3 кусочка на виду + индикатор «+N» на остаток).
/// Переключается из чит-меню; хранится в состоянии `GameScreen`.
enum FeedMode { fullSet, tray3 }

/// Основной игровой экран — ядро укладки (эпик «Укладка», Стори 02).
///
/// Игрок перетаскивает кусочки-полиомино из лотка в силуэт детали корабля,
/// пока не заполнит его без дыр (`PackState.isComplete`). Ни гравитации, ни
/// таймера, ни проигрыша; уложенный кусок можно переложить. Победа = деталь
/// собрана → прежний мета-поток (`ProgressService.advanceOnWin` →
/// `ShipScreen.reveal` → следующий уровень / сброс).
class GameScreen extends StatefulWidget {
  /// Индекс уровня (0..`kShipPartCount-1`). Деталь `i` ↔ уровень `i`.
  final int levelIndex;

  /// Creates a [GameScreen] with the given [levelIndex].
  const GameScreen({super.key, this.levelIndex = 0});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  // --- Канон макета (мокап при 812-высоте) ---
  static const double _canonicalCellSize = 40.0;
  static const double _topbarHeight = 44.0;
  static const double _progZoneHeight = 34.0;
  static const double _trayZoneHeight = 132.0;

  /// Размер клетки кусочка в лотке (`el-piece-tray`, уменьшенный масштаб).
  static const double _trayCellSize = 32.0;

  /// Офсет кусочка над пальцем при drag (`el-piece-drag`, риск drag-UX эпика):
  /// кусок рисуется на столько пикселей выше точки касания.
  static const double _dragLiftPx = 56.0;

  // --- Силуэт уровня и нарезка ---
  late TargetMask _silhouette;
  late int _fragmentIndex;
  late BlockMaterial _partMaterial;

  /// Сид нарезки (0 → детерминированная стартовая нарезка); «Пересобрать
  /// нарезку» инкрементирует и режет заново.
  int _seed = 0;
  late PackController _controller;

  /// Эталонная раскладка последней нарезки — solve-хук (дев + тесты).
  late Map<int, ({int x, int y})> _solution;

  /// Режим подачи лотка (тумблер чит-меню). Дефолт — полный набор.
  FeedMode _feedMode = FeedMode.fullSet;

  // --- Победа / завершение ---
  bool _winHandled = false;
  bool _winScheduled = false;
  late final AnimationController _pulseController;

  // --- Drag state (сырые pointer-события, НЕ GestureDetector.onPan* —
  // фикс возврата Гейта 2 Стори 01: лоток-скролл выигрывал арену) ---
  int? _dragPieceId;
  bool _dragFromTray = false;
  Offset? _dragGlobalPos;

  /// Текущий размер клетки поля — обновляется в `build` (адаптивный), нужен
  /// pointer-обработчикам (они работают вне `build`).
  double _cellSize = _canonicalCellSize;

  final GlobalKey _stackKey = GlobalKey();
  final GlobalKey _boardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadLevel();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  /// Загружает силуэт уровня и материал детали из [LevelMap] (единый источник
  /// «уровень i ↔ деталь i»), затем режет силуэт на кусочки.
  void _loadLevel() {
    final level = LevelMap.levelAt(widget.levelIndex);
    _silhouette = level.targetMask;
    _fragmentIndex = level.fragmentIndex;
    _partMaterial =
        ShipMaterials.defaultMaterials.materialForPart(_fragmentIndex);
    _rebuild();
  }

  void _rebuild() {
    final slice = slicePolyomino(_silhouette, seed: _seed);
    _solution = slice.solution;
    _controller = PackController(
      PackState(
        silhouette: _silhouette,
        placements: const {},
        pieces: slice.pieces,
        trayOrder: [for (final p in slice.pieces) p.id],
      ),
    );
    _winHandled = false;
    _winScheduled = false;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // --- Победа ---

  /// Планирует пост-победный поток, когда деталь собрана (`isComplete`): даёт
  /// ~900 мс на пульс-ободок «готово», затем идемпотентно запускает `_onWin`.
  void _onPackingComplete() {
    if (_winScheduled || _winHandled) return;
    _winScheduled = true;
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      _handleWin();
    });
  }

  /// Единая точка обработки победы (укладка-завершение и чит «мгновенная
  /// победа»). Идемпотентна (`_winHandled`).
  void _handleWin() {
    if (_winHandled) return;
    _winHandled = true;
    _onWin();
  }

  Future<void> _onWin() async {
    final completedLevel = widget.levelIndex;
    await ProgressService().advanceOnWin();
    if (!mounted) return;

    // Захватить navigator ДО pushReplacement, пока context валиден.
    final navigator = Navigator.of(context);

    final isLastDevLevel = completedLevel >= kShipPartCount - 1;
    final collected = isLastDevLevel ? kShipPartCount : completedLevel + 1;

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
      feedMode: _feedMode,
      onSetFeedMode: _cheatSetFeedMode,
      onReshuffle: _cheatReshuffle,
      onSolve: _cheatSolve,
    );
  }

  void _cheatSelectLevel(int levelIndex) {
    Navigator.of(context).pop();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => GameScreen(levelIndex: levelIndex)),
    );
  }

  /// Чит «мгновенная победа»: тот же пост-победный поток, движок не трогаем.
  void _cheatInstantWin() {
    Navigator.of(context).pop();
    _handleWin();
  }

  Future<void> _cheatSetShipParts(int parts) async {
    Navigator.of(context).pop();
    await ProgressService().setCurrentLevel(parts);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Корабль: собрано $parts'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  /// Чит «тумблер подачи»: переключает `fullSet` / `tray3`. Sheet не
  /// закрываем — PO может переключать без перезахода.
  void _cheatSetFeedMode(FeedMode mode) {
    setState(() => _feedMode = mode);
  }

  /// Дев-чит «Пересобрать нарезку»: новый `seed` → новая нарезка той же детали.
  void _cheatReshuffle() {
    Navigator.of(context).pop();
    _reshuffle();
  }

  /// Дев-чит «Решить»: solve-хук (см. [_solveAll]).
  void _cheatSolve() {
    Navigator.of(context).pop();
    _solveAll();
  }

  void _reshuffle() {
    setState(() {
      _seed++;
      _dragPieceId = null;
      _dragGlobalPos = null;
      _dragFromTray = false;
      _rebuild();
    });
  }

  /// Solve-хук: раскладывает все кусочки по эталонному `PackSlice.solution` —
  /// и дев-инструмент (`Key('cheat_solve')`), и programmatic-хук для тестов,
  /// доводящий укладку до `isComplete` без симуляции drag-жестов.
  void _solveAll() {
    setState(() {
      for (final entry in _solution.entries) {
        _controller.place(entry.key, entry.value.x, entry.value.y);
      }
    });
    if (_controller.state.isComplete) _onPackingComplete();
  }

  // --- Drag-and-drop (перенос эталонной логики прототипа) ---

  List<int> _visibleTray(PackState state) {
    if (_feedMode == FeedMode.tray3) {
      return state.trayOrder.take(3).toList();
    }
    return state.trayOrder;
  }

  PackPiece _pieceById(int id) {
    return _controller.state.pieces.firstWhere((p) => p.id == id);
  }

  int? _pieceAt(int x, int y) {
    for (final entry in _controller.state.placements.entries) {
      final piece = _pieceById(entry.key);
      final origin = entry.value;
      for (final cell in piece.cells) {
        if (origin.x + cell.x == x && origin.y + cell.y == y) {
          return entry.key;
        }
      }
    }
    return null;
  }

  Size _pieceBoundsPx(PackPiece piece, double cell) {
    var maxX = 0;
    var maxY = 0;
    for (final c in piece.cells) {
      if (c.x > maxX) maxX = c.x;
      if (c.y > maxY) maxY = c.y;
    }
    return Size((maxX + 1) * cell, (maxY + 1) * cell);
  }

  Offset? _globalToLocal(GlobalKey key, Offset global) {
    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) return null;
    return renderObject.globalToLocal(global);
  }

  void _startDrag(int pieceId,
      {required bool fromTray, required Offset globalPos}) {
    setState(() {
      _dragPieceId = pieceId;
      _dragFromTray = fromTray;
      _dragGlobalPos = globalPos;
    });
  }

  void _onDragUpdate(Offset globalPos) {
    if (_dragPieceId == null) return;
    setState(() => _dragGlobalPos = globalPos);
  }

  void _onBoardPointerDown(PointerDownEvent event) {
    final local = _globalToLocal(_boardKey, event.position);
    if (local == null) return;
    final x = (local.dx / _cellSize).floor();
    final y = (local.dy / _cellSize).floor();
    final pieceId = _pieceAt(x, y);
    if (pieceId != null) {
      _startDrag(pieceId, fromTray: false, globalPos: event.position);
    }
  }

  /// `onPointerCancel`: сбрасываем драг БЕЗ попытки уложить — состояние не
  /// бьётся (raw pointer в арене не участвует, но забрать жест система может).
  void _cancelDrag() {
    if (_dragPieceId == null) return;
    setState(() {
      _dragPieceId = null;
      _dragGlobalPos = null;
      _dragFromTray = false;
    });
  }

  void _endDrag() {
    if (_dragPieceId == null) return;
    final pieceId = _dragPieceId!;
    final fromTray = _dragFromTray;
    final pointer = _dragGlobalPos;

    setState(() {
      final anchor = _anchorAt(pointer);
      if (anchor != null) {
        if (fromTray) {
          _controller.place(pieceId, anchor.x, anchor.y);
        } else {
          _controller.move(pieceId, anchor.x, anchor.y);
        }
      } else if (!fromTray) {
        // Отпустили уложенный кусок вне поля — вернуть в лоток.
        _controller.remove(pieceId);
      }

      _dragPieceId = null;
      _dragGlobalPos = null;
      _dragFromTray = false;
    });
    if (_controller.state.isComplete) _onPackingComplete();
  }

  /// Клетка поля под верх-левым углом всплывшего куска (`pointer` минус
  /// офсет подъёма), либо `null`, если точка вне поля.
  ({int x, int y})? _anchorAt(Offset? pointer) {
    final visual = pointer?.translate(0, -_dragLiftPx);
    final local = visual == null ? null : _globalToLocal(_boardKey, visual);
    if (local == null) return null;
    final boardWpx = _silhouette.width * _cellSize;
    final boardHpx = _silhouette.height * _cellSize;
    if (local.dx < 0 ||
        local.dx >= boardWpx ||
        local.dy < 0 ||
        local.dy >= boardHpx) {
      return null;
    }
    return (x: (local.dx / _cellSize).floor(), y: (local.dy / _cellSize).floor());
  }

  /// Живое снап-превью: клетки поля под текущим якорем + валидность
  /// (`el-drop-ok` / `el-drop-bad`). `null` — драга нет или курсор вне поля.
  PackDragPreview? _computePreview(PackState state) {
    if (_dragPieceId == null || _dragGlobalPos == null) return null;
    final anchor = _anchorAt(_dragGlobalPos);
    if (anchor == null) return null;
    final piece = _pieceById(_dragPieceId!);
    final cells = <({int x, int y})>[
      for (final c in piece.cells) (x: anchor.x + c.x, y: anchor.y + c.y),
    ];
    final valid = PackController.canPlace(
      state,
      _dragPieceId!,
      anchor.x,
      anchor.y,
      ignoreId: _dragFromTray ? null : _dragPieceId,
    );
    return PackDragPreview(cells: cells, valid: valid);
  }

  double _computeCellSize(
    BoxConstraints constraints,
    int boardWidth,
    int boardHeight,
  ) {
    final availableHeight = constraints.maxHeight -
        _topbarHeight -
        _progZoneHeight -
        _trayZoneHeight;
    final fitByHeight = availableHeight / boardHeight;
    final fitByWidth = constraints.maxWidth / boardWidth;
    final size = math.min(_canonicalCellSize, math.min(fitByHeight, fitByWidth));
    return math.max(size, 8.0);
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    final boardWidth = _silhouette.width;
    final boardHeight = _silhouette.height;

    return Scaffold(
      // spaceBg token: hsl(220 14% 7%) = #0F1114.
      backgroundColor: const Color(0xFF0F1114),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            _cellSize = _computeCellSize(constraints, boardWidth, boardHeight);
            final cellSize = _cellSize;
            final boardPixelWidth = boardWidth * cellSize;
            final boardPixelHeight = boardHeight * cellSize;
            final preview = _computePreview(state);

            return Stack(
              key: _stackKey,
              children: [
                Column(
                  children: [
                    _buildTopbar(context),
                    _buildProgress(state),
                    Expanded(
                      child: Center(
                        child: _buildBoard(
                          state,
                          boardPixelWidth,
                          boardPixelHeight,
                          cellSize,
                          preview,
                        ),
                      ),
                    ),
                    _buildTray(state),
                  ],
                ),
                if (_dragPieceId != null && _dragGlobalPos != null)
                  _buildFeedback(cellSize),
                if (state.isComplete) _buildCompleteBanner(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopbar(BuildContext context) {
    return SizedBox(
      height: _topbarHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _PartChip(
              fragmentIndex: _fragmentIndex,
              material: _partMaterial,
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                    MaterialPageRoute(builder: (_) => const ShipScreen()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress(PackState state) {
    final total = state.silhouette.cells.length;
    final filled = state.occupiedCells.length;
    final ratio = total == 0 ? 0.0 : (filled / total).clamp(0.0, 1.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14.0, 8.0, 14.0, 0.0),
          child: Container(
            width: double.infinity,
            height: 6.0,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: BlockMaterial.matteBlack.color,
              border: Border.all(color: BlockMaterial.gunmetal.color, width: 1.0),
              borderRadius: BorderRadius.circular(3.0),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: ratio,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      BlockMaterial.rust.color,
                      BlockMaterial.hazardOrange.color,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(3.0),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14.0, 4.0, 14.0, 0.0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'уложено ${state.placements.length} / ${state.pieces.length} кусков',
              style: const TextStyle(
                color: Color(0xFF7C848D),
                fontSize: 10.5,
                letterSpacing: 0.63, // .06em @ 10.5px
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBoard(
    PackState state,
    double boardPixelWidth,
    double boardPixelHeight,
    double cellSize,
    PackDragPreview? preview,
  ) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final complete = state.isComplete;
        return Container(
          width: boardPixelWidth,
          height: boardPixelHeight,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: PackingPainter.boardBg,
            border: Border.all(color: BlockMaterial.gunmetal.color),
            borderRadius: BorderRadius.circular(10.0),
            boxShadow: complete
                ? [
                    BoxShadow(
                      color: PackingPainter.doneGlow,
                      blurRadius: 18.0 + 16.0 * _pulseController.value,
                      spreadRadius: 2.0,
                    ),
                  ]
                : null,
          ),
          child: child,
        );
      },
      child: Listener(
        onPointerDown: _onBoardPointerDown,
        onPointerMove: (event) => _onDragUpdate(event.position),
        onPointerUp: (_) => _endDrag(),
        onPointerCancel: (_) => _cancelDrag(),
        child: CustomPaint(
          key: _boardKey,
          size: Size(boardPixelWidth, boardPixelHeight),
          painter: PackingPainter(
            state: state,
            cellSize: cellSize,
            shipMaterials: ShipMaterials.defaultMaterials,
            excludePieceId: _dragFromTray ? null : _dragPieceId,
            partMaterial: _partMaterial,
            dragPreview: preview,
          ),
        ),
      ),
    );
  }

  Widget _buildTray(PackState state) {
    final visible = _visibleTray(state);
    final rest = _feedMode == FeedMode.tray3
        ? state.trayOrder.length - visible.length
        : 0;
    final label = _feedMode == FeedMode.tray3
        ? 'ЛОТОК · ПОРЦИЯ-3'
        : 'ЛОТОК · ПОЛНЫЙ НАБОР';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12.0),
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 6.0),
      decoration: BoxDecoration(
        color: PackingPainter.trayBg,
        border: Border.all(color: BlockMaterial.gunmetal.color, width: 1.0),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14.0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (final id in visible)
                  if (!(id == _dragPieceId && _dragFromTray))
                    Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: Listener(
                        key: Key('tray_piece_$id'),
                        onPointerDown: (event) => _startDrag(
                          id,
                          fromTray: true,
                          globalPos: event.position,
                        ),
                        onPointerMove: (event) => _onDragUpdate(event.position),
                        onPointerUp: (_) => _endDrag(),
                        onPointerCancel: (_) => _cancelDrag(),
                        child: CustomPaint(
                          size: _pieceBoundsPx(_pieceById(id), _trayCellSize),
                          painter: _PieceCellsPainter(
                            piece: _pieceById(id),
                            cellSize: _trayCellSize,
                            material: BlockMaterial.graphite,
                          ),
                        ),
                      ),
                    ),
                if (rest > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 4.0),
                    child: Text(
                      '+$rest',
                      style: const TextStyle(
                        color: Color(0xFF8B949E),
                        fontSize: 11.0,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6.0),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6C747D),
              fontSize: 10.0,
              letterSpacing: 1.0, // .1em @ 10px
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedback(double cellSize) {
    final local = _globalToLocal(
      _stackKey,
      _dragGlobalPos!.translate(0, -_dragLiftPx),
    );
    if (local == null) return const SizedBox.shrink();
    final piece = _pieceById(_dragPieceId!);
    return Positioned(
      left: local.dx,
      top: local.dy,
      child: IgnorePointer(
        child: CustomPaint(
          key: const Key('packing_drag_feedback'),
          size: _pieceBoundsPx(piece, cellSize),
          painter: _PieceCellsPainter(
            piece: piece,
            cellSize: cellSize,
            material: BlockMaterial.graphite,
          ),
        ),
      ),
    );
  }

  Widget _buildCompleteBanner() {
    return Positioned.fill(
      child: Container(
        key: const Key('packing_complete'),
        color: Colors.black54,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ДЕТАЛЬ СОБРАНА',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Чип детали в топбаре — канон `.chip`/`.chip .sw` (Стори 02 T3):
/// matteBlack fill, gunmetal 1px border, radius 8, свотч материала детали +
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
/// лёгкий bevel (inset top-light/bottom-dark, приближено полосами).
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

/// Отрисовка одного кусочка вне поля (лоток / drag-фидбэк) — переиспользует
/// [PackingPainter.paintPiece], единую точку правды «как выглядит кусочек».
class _PieceCellsPainter extends CustomPainter {
  const _PieceCellsPainter({
    required this.piece,
    required this.cellSize,
    required this.material,
  });

  final PackPiece piece;
  final double cellSize;
  final BlockMaterial material;

  @override
  void paint(Canvas canvas, Size size) {
    PackingPainter.paintPiece(canvas, piece, Offset.zero, cellSize, material);
  }

  @override
  bool shouldRepaint(covariant _PieceCellsPainter oldDelegate) {
    return piece != oldDelegate.piece ||
        cellSize != oldDelegate.cellSize ||
        material != oldDelegate.material;
  }
}
