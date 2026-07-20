import 'package:flutter/foundation.dart' show kDebugMode, visibleForTesting;
import 'package:flutter/material.dart';

import '../../game_engine/models/target_mask.dart';
import '../../game_engine/packing/pack_controller.dart';
import '../../game_engine/packing/pack_piece.dart';
import '../../game_engine/packing/pack_slicer.dart';
import '../../game_engine/packing/pack_state.dart';
import '../theme/block_material.dart';
import '../theme/ship_materials.dart';
import '../widgets/packing_painter.dart';

/// Режим подачи кусочков (эпик «Укладка», Стори 01 T3): весь набор сразу, или
/// порционный лоток (3 кусочка одновременно, следующий подаётся, когда один из
/// видимых уложен).
enum FeedMode { fullSet, tray3 }

/// Режим подачи прототипа — module-level, чтобы **переживать перезаход** на
/// экран в рамках сессии (ТЗ T3: тумблер живёт в чит-меню прототипа, персист
/// на диск не требуется). Дефолт — «полный набор».
FeedMode _prototypeFeedMode = FeedMode.fullSet;

/// Сбрасывает режим подачи к дефолту. Только для тестов (module-level
/// переменная переживает `initState`/`dispose` намеренно — см.
/// [_prototypeFeedMode] — обычным виджетам сбрасывать её незачем; тестам
/// нужна изоляция между `testWidgets`, т.к. переменная живёт весь процесс).
@visibleForTesting
void resetPrototypeFeedModeForTest() {
  _prototypeFeedMode = FeedMode.fullSet;
}

/// Прототип-экран укладки (эпик «Укладка», контрольная точка Стори 01):
/// силуэт детали режется генератором ([slicePolyomino]) на кусочки-полиомино,
/// кусочки собираются drag-and-drop из лотка в силуэт (движок `PackController`
/// из T1/T2). Параллельный экран — старое тетрис-ядро (`GameScreen`) не
/// трогает. Доступен из чит-меню (`cheat_menu.dart`).
class PackingPrototypeScreen extends StatefulWidget {
  const PackingPrototypeScreen({super.key});

  @override
  State<PackingPrototypeScreen> createState() =>
      _PackingPrototypeScreenState();
}

class _PackingPrototypeScreenState extends State<PackingPrototypeScreen> {
  /// Силуэт прототипа: крест `defaultTargetMask` (6×6, 20 клеток) — выбор из
  /// ТЗ T3 («крест `defaultTargetMask` для наглядности»): нарезается на 5
  /// кусочков (не 3, как деталь корабля 4×3/12 клеток на этой же нарезке —
  /// проверено на seed 0..29), поэтому тумблер «лоток-3» реально показывает
  /// разницу (3 видимых из 5, не все сразу). Выбор зафиксирован здесь.
  static const TargetMask _silhouette = defaultTargetMask;

  static const double _cellSize = 40.0;

  /// Офсет кусочка над пальцем при drag (риск drag-UX эпика): кусок рисуется
  /// на столько пикселей выше точки касания, чтобы палец его не закрывал.
  static const double _dragLiftPx = 56.0;

  /// Сид нарезки (по умолчанию 0 → детерминированная стартовая нарезка).
  /// «Пересобрать нарезку» инкрементирует и режет заново той же детали —
  /// демонстрация реиграбельности разных нарезок одной детали.
  int _seed = 0;

  late PackController _controller;

  /// Эталонная раскладка последней нарезки — используется дев-кнопкой
  /// «Решить».
  late Map<int, ({int x, int y})> _solution;

  // --- Drag state (ручной GestureDetector, на усмотрение Исполнителя ТЗ T3) ---
  int? _dragPieceId;
  bool _dragFromTray = false;
  Offset? _dragGlobalPos;

  final GlobalKey _stackKey = GlobalKey();
  final GlobalKey _boardKey = GlobalKey();

  @override
  void initState() {
    super.initState();
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
  }

  void _reshuffle() {
    setState(() {
      _seed++;
      _dragPieceId = null;
      _dragGlobalPos = null;
      _rebuild();
    });
  }

  /// Дев-кнопка «Решить» (опционально по ТЗ T3): раскладывает все кусочки по
  /// эталонному `PackSlice.solution`. Заодно — programmatic-хук, которым
  /// виджет-тест доводит укладку до `isComplete` без симуляции drag-жестов.
  void _solveAll() {
    setState(() {
      for (final entry in _solution.entries) {
        _controller.place(entry.key, entry.value.x, entry.value.y);
      }
    });
  }

  List<int> _visibleTray(PackState state) {
    if (_prototypeFeedMode == FeedMode.tray3) {
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

  Size _pieceBoundsPx(PackPiece piece) {
    var maxX = 0;
    var maxY = 0;
    for (final cell in piece.cells) {
      if (cell.x > maxX) maxX = cell.x;
      if (cell.y > maxY) maxY = cell.y;
    }
    return Size((maxX + 1) * _cellSize, (maxY + 1) * _cellSize);
  }

  Offset? _globalToLocal(GlobalKey key, Offset global) {
    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) return null;
    return renderObject.globalToLocal(global);
  }

  void _startDrag(int pieceId, {required bool fromTray, required Offset globalPos}) {
    setState(() {
      _dragPieceId = pieceId;
      _dragFromTray = fromTray;
      _dragGlobalPos = globalPos;
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_dragPieceId == null) return;
    setState(() => _dragGlobalPos = details.globalPosition);
  }

  void _onBoardPanStart(DragStartDetails details) {
    final local = _globalToLocal(_boardKey, details.globalPosition);
    if (local == null) return;
    final x = (local.dx / _cellSize).floor();
    final y = (local.dy / _cellSize).floor();
    final pieceId = _pieceAt(x, y);
    if (pieceId != null) {
      _startDrag(pieceId, fromTray: false, globalPos: details.globalPosition);
    }
  }

  void _endDrag() {
    if (_dragPieceId == null) return;
    final pieceId = _dragPieceId!;
    final fromTray = _dragFromTray;
    final pointer = _dragGlobalPos;

    setState(() {
      final visual = pointer?.translate(0, -_dragLiftPx);
      final local = visual == null ? null : _globalToLocal(_boardKey, visual);
      final boardWpx = _silhouette.width * _cellSize;
      final boardHpx = _silhouette.height * _cellSize;
      final insideBoard = local != null &&
          local.dx >= 0 &&
          local.dx < boardWpx &&
          local.dy >= 0 &&
          local.dy < boardHpx;

      if (insideBoard) {
        final cellX = (local.dx / _cellSize).floor();
        final cellY = (local.dy / _cellSize).floor();
        if (fromTray) {
          _controller.place(pieceId, cellX, cellY);
        } else {
          _controller.move(pieceId, cellX, cellY);
        }
      } else if (!fromTray) {
        // Отпустили уложенный кусочек за пределами силуэта — вернуть в лоток
        // (невалидная позиция отбивается в исходную область — здесь трактуем
        // «вне поля» как явный жест «вытащить обратно», не no-op).
        _controller.remove(pieceId);
      }
      // fromTray && !insideBoard → отпустили над лотком/вне поля: остался в
      // лотке, `place` не звался — состояние не бьётся.

      _dragPieceId = null;
      _dragGlobalPos = null;
      _dragFromTray = false;
    });
  }

  void _openPrototypeCheatMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Прототип укладки: подача (dev)',
                        style: Theme.of(sheetContext).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Подача',
                        style: Theme.of(sheetContext).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          ElevatedButton(
                            key: const Key('feed_full'),
                            onPressed: () {
                              _prototypeFeedMode = FeedMode.fullSet;
                              setSheetState(() {});
                              setState(() {});
                            },
                            child: const Text('Полный набор'),
                          ),
                          ElevatedButton(
                            key: const Key('feed_tray3'),
                            onPressed: () {
                              _prototypeFeedMode = FeedMode.tray3;
                              setSheetState(() {});
                              setState(() {});
                            },
                            child: const Text('Лоток-3'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          _reshuffle();
                        },
                        child: const Text('Пересобрать нарезку'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    final boardWpx = _silhouette.width * _cellSize;
    final boardHpx = _silhouette.height * _cellSize;

    return Scaffold(
      // boardBg token (docs/DESIGN.md, #16191D) — тёмный фон поля (ТЗ T3).
      backgroundColor: PackingPainter.boardBg,
      body: SafeArea(
        child: Stack(
          key: _stackKey,
          children: [
            Column(
              children: [
                _Toolbar(
                  onClose: () => Navigator.of(context).pop(),
                  onReshuffle: _reshuffle,
                  onOpenCheat: kDebugMode
                      ? () => _openPrototypeCheatMenu(context)
                      : null,
                  onSolve: kDebugMode ? _solveAll : null,
                ),
                const SizedBox(height: 12),
                Center(
                  child: GestureDetector(
                    onPanStart: _onBoardPanStart,
                    onPanUpdate: _onDragUpdate,
                    onPanEnd: (_) => _endDrag(),
                    child: Container(
                      width: boardWpx,
                      height: boardHpx,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        border: Border.all(color: BlockMaterial.gunmetal.color),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: CustomPaint(
                        key: _boardKey,
                        size: Size(boardWpx, boardHpx),
                        painter: PackingPainter(
                          state: state,
                          cellSize: _cellSize,
                          shipMaterials: ShipMaterials.defaultMaterials,
                          excludePieceId: _dragFromTray ? null : _dragPieceId,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(child: _buildTray(state)),
              ],
            ),
            if (_dragPieceId != null && _dragGlobalPos != null) _buildFeedback(),
            if (state.isComplete) _buildCompleteBanner(),
          ],
        ),
      ),
    );
  }

  Widget _buildTray(PackState state) {
    final visible = _visibleTray(state);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (final id in visible)
              if (!(id == _dragPieceId && _dragFromTray))
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    key: Key('tray_piece_$id'),
                    onPanStart: (details) => _startDrag(
                      id,
                      fromTray: true,
                      globalPos: details.globalPosition,
                    ),
                    onPanUpdate: _onDragUpdate,
                    onPanEnd: (_) => _endDrag(),
                    child: CustomPaint(
                      size: _pieceBoundsPx(_pieceById(id)),
                      painter: _PieceCellsPainter(
                        piece: _pieceById(id),
                        cellSize: _cellSize,
                        material: PackingPainter.materialForPiece(
                          id,
                          ShipMaterials.defaultMaterials,
                        ),
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedback() {
    final local = _globalToLocal(
      _stackKey,
      _dragGlobalPos!.translate(0, -_dragLiftPx),
    );
    if (local == null) return const SizedBox.shrink();
    final piece = _pieceById(_dragPieceId!);
    final material = PackingPainter.materialForPiece(
      _dragPieceId!,
      ShipMaterials.defaultMaterials,
    );
    return Positioned(
      left: local.dx,
      top: local.dy,
      child: IgnorePointer(
        child: CustomPaint(
          size: _pieceBoundsPx(piece),
          painter: _PieceCellsPainter(
            piece: piece,
            cellSize: _cellSize,
            material: material,
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
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Деталь собрана',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                key: const Key('packing_restart_button'),
                onPressed: _reshuffle,
                child: const Text('Заново'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Верхняя панель прототипа: закрыть, «Пересобрать нарезку», вход в
/// дев-чит-меню прототипа (только `kDebugMode`).
class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.onClose,
    required this.onReshuffle,
    required this.onOpenCheat,
    required this.onSolve,
  });

  final VoidCallback onClose;
  final VoidCallback onReshuffle;
  final VoidCallback? onOpenCheat;
  final VoidCallback? onSolve;

  static const Color _iconColor = Color(0xFFB1B7BE); // hudIcon token

  /// Компактная иконочная кнопка тулбара: телефонная ширина (375, целевая
  /// форма из `PROJECT.md`) не даёт места дефолтным 48×48 `IconButton` на
  /// пять кнопок в ряд — сжимаем до 32×32 (hotfix RenderFlex overflow,
  /// Гейт 2 возврат по T3).
  static Widget _compactIconButton({
    required Key key,
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return IconButton(
      key: key,
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: _iconColor, size: 18.0),
      iconSize: 18.0,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32.0, minHeight: 32.0),
      visualDensity: VisualDensity.compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        children: [
          _compactIconButton(
            key: const Key('packing_close_button'),
            icon: Icons.close,
            tooltip: 'Закрыть',
            onPressed: onClose,
          ),
          const SizedBox(width: 4.0),
          const Expanded(
            child: Text(
              'Прототип укладки',
              style: TextStyle(color: Color(0xFFAEB6BF), fontSize: 14.0),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 4.0),
          // Иконка вместо текста «Пересобрать» — экономит место (ужато под
          // 375-ширину, тот же ключ/действие).
          _compactIconButton(
            key: const Key('packing_reshuffle'),
            icon: Icons.shuffle,
            tooltip: 'Пересобрать нарезку',
            onPressed: onReshuffle,
          ),
          if (onSolve != null)
            _compactIconButton(
              key: const Key('packing_debug_solve'),
              icon: Icons.check_circle_outline,
              tooltip: 'Решить (dev)',
              onPressed: onSolve,
            ),
          if (onOpenCheat != null)
            _compactIconButton(
              key: const Key('packing_cheat_button'),
              icon: Icons.bug_report,
              tooltip: 'Читы прототипа',
              onPressed: onOpenCheat,
            ),
        ],
      ),
    );
  }
}

/// Отрисовка одного кусочка вне поля (лоток/drag-фидбэк) — переиспользует
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
