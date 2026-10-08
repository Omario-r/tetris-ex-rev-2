import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';

import '../../application/progress_service.dart';
import '../../game_engine/data/level_map.dart';
import '../../game_engine/data/ronin_parts.dart';
import '../../game_engine/models/target_mask.dart';
import '../../game_engine/packing/pack_controller.dart';
import '../../game_engine/packing/pack_piece.dart';
import '../../game_engine/packing/slice_config.dart';
import '../../game_engine/packing/pack_state.dart';
import '../ship_render/ronin_art.dart';
import '../theme/block_material.dart';
import '../widgets/packing_painter.dart';
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
/// таймера, ни проигрыша; уложенный кусок можно переложить. Деталь собрана →
/// прогресс засчитан сразу (`ProgressService.completeLevel`) и **пауза**
/// (Ронин-1/05 T1): над полем «ДЕТАЛЬ СОБРАНА», на месте лотка — кнопки
/// «К кораблю» (`ShipScreen.afterWin`) и «Следующая деталь»; на последней
/// детали — одна «К кораблю» (`ShipScreen.finale`).
class GameScreen extends StatefulWidget {
  /// Индекс уровня (0..`RoninParts.parts.length-1`). Деталь `i` ↔ уровень `i`.
  final int levelIndex;

  /// Creates a [GameScreen] with the given [levelIndex].
  const GameScreen({super.key, this.levelIndex = 0});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  // --- Канон макета (мокап при 812-высоте) ---
  static const double _canonicalCellSize = 34.0;
  static const double _topbarHeight = 44.0;
  static const double _progZoneHeight = 34.0;

  /// Габариты лотка (фиксированные — поле не прыгает, когда лоток пустеет):
  /// внешний контейнер = рамка 1+1, вертикальный паддинг 12+12, ряд кусков
  /// [_trayRowMaxHeight], зазор 6, подпись [_trayLabelHeight].
  static const double _trayBorderWidth = 1.0;
  static const double _trayPaddingV = 12.0;
  static const double _trayLabelGap = 6.0;
  static const double _trayLabelHeight = 14.0;

  /// Высота зоны лотка: 2·1 + 2·12 + 160 + 6 + 14 = 206. Её же вычитает расчёт
  /// клетки поля ([_computeCellSize]).
  static const double _trayZoneHeight =
      2 * _trayBorderWidth +
      2 * _trayPaddingV +
      _trayRowMaxHeight +
      _trayLabelGap +
      _trayLabelHeight;

  /// Зона нажатия «ОЧИСТИТЬ ПОЛЕ» (не меньше 40×32); живёт поверх строки
  /// прогресса и строку не раздвигает.
  static const double _clearHitWidthPad = 8.0;
  static const double _clearHitHeight = 32.0;

  /// Канонический размер клетки кусочка в лотке (`el-piece-tray`, уменьшенный
  /// масштаб) и высота ряда лотка: клетка ужимается, чтобы самый высокий кусок
  /// уровня не превышал [_trayRowMaxHeight] (см. [_trayCellSize]).
  static const double _trayCellCanon = 32.0;
  static const double _trayRowMaxHeight = 160.0;

  /// Зазор между нижним краем поднятого куска и пальцем (`el-piece-drag`,
  /// канон `DESIGN.md`: «офсет ~1 клетка вверх», по центру X; Ронин-1/08 T3).
  /// Подбирается на устройстве. Геометрия — [_dragPieceRect].
  static const double _dragLiftGap = 32.0;

  /// Паддинг панели поля (канон `.board` мокапа, `ukladka-field.html:85-86`):
  /// отступ между рамкой панели и сеткой силуэта на каждую сторону — вокруг
  /// мишени читается подложка `boardBg`, обводка снап-превью на крайних
  /// клетках не срезается клипом панели.
  static const double _boardPadding = 8.0;

  // --- Силуэт уровня и нарезка ---
  late TargetMask _silhouette;

  /// Сдвиг bbox маски детали в поле (`PreparedLevel.targetX/targetY`):
  /// по нему уложенная клетка поля находит свой кусок рисунка.
  late int _targetX, _targetY;
  late int _fragmentIndex;

  /// Клетка лотка (и ширина клетки): `min(32, 160 / h)`, `h` — наибольшая
  /// высота куска уровня в клетках; считается один раз при (пере)сборке уровня.
  late double _trayCellSize;

  /// Сдвиг seed от канонного `RoninPartDef.seed` детали (0 → канонная
  /// нарезка); «Пересобрать нарезку» инкрементирует и режет заново.
  int _seedOffset = 0;
  late PackController _controller;

  /// Эталонная раскладка последней нарезки — solve-хук (дев + тесты).
  late Map<int, ({int x, int y})> _solution;

  /// Режим подачи лотка (тумблер чит-меню). Дефолт — полный набор.
  FeedMode _feedMode = FeedMode.fullSet;

  // --- Деталь собрана: пауза (Ронин-1/05 T1) ---
  /// Пауза «деталь собрана»: поле и лоток касаний не принимают, на месте
  /// лотка — кнопки выбора маршрута. Флаг же — идемпотентность засчитывания.
  bool _done = false;

  /// Запись прогресса (`completeLevel`), начатая в момент сборки; переходы с
  /// паузы дожидаются её, прежде чем уйти с экрана.
  Future<int>? _progressSaved;

  /// Переход с паузы уже начат — повторное нажатие кнопки игнорируется.
  bool _leaving = false;
  late final AnimationController _pulseController;

  // --- Drag state (сырые pointer-события, НЕ GestureDetector.onPan* —
  // фикс возврата Гейта 2 Стори 01: лоток-скролл выигрывал арену) ---
  int? _dragPieceId;
  bool _dragFromTray = false;
  Offset? _dragGlobalPos;

  // --- Кандидат захвата с лотка (Ронин-1/08 T3): касание куска лотка драг
  // не стартует сразу — направление решает, поднять кусок или листать лоток
  // (см. [_onTrayPointerMove]) ---
  int? _candidateId;
  Offset? _candidateDown;

  /// Позиция прокрутки лотка в момент касания кандидата — к ней лоток
  /// возвращается при старте драга (вертикальный жест лоток не листает).
  double? _candidateTrayOffset;

  /// Прокрутка ряда кусков лотка: нужна, чтобы на старте драга с лотка
  /// остановить начатую прокрутку (см. [_freezeTrayScroll]).
  final ScrollController _trayScroll = ScrollController();

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

  /// Запоминает деталь уровня ([LevelMap] — единый источник «уровень i ↔
  /// деталь i»), затем собирает уровень ([_rebuild]).
  void _loadLevel() {
    _fragmentIndex = LevelMap.levelAt(widget.levelIndex).fragmentIndex;
    _rebuild();
  }

  /// Строит уровень через [prepareLevel]: силуэт в поле, масштаб клетки и
  /// нарезка («Крупные куски») с seed детали плюс текущий `_seedOffset`.
  void _rebuild() {
    final part = RoninParts.parts[_fragmentIndex];
    final prepared = prepareLevel(
      part.mask,
      seed: part.seed + _seedOffset,
    );
    _silhouette = prepared.silhouette;
    _targetX = prepared.targetX;
    _targetY = prepared.targetY;
    final slice = prepared.slice;
    var maxHeight = 1;
    for (final p in slice.pieces) {
      for (final c in p.cells) {
        if (c.y + 1 > maxHeight) maxHeight = c.y + 1;
      }
    }
    _trayCellSize = math.min(_trayCellCanon, _trayRowMaxHeight / maxHeight);
    _solution = slice.solution;
    _controller = PackController(
      PackState(
        silhouette: _silhouette,
        placements: const {},
        pieces: slice.pieces,
        trayOrder: prepared.trayOrder,
      ),
    );
    // Пересборка уровня (дев-читы нарезки) снимает паузу: деталь снова не
    // собрана; прогресс уже засчитан, повторное засчитывание идемпотентно.
    _done = false;
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _trayScroll.dispose();
    super.dispose();
  }

  // --- Деталь собрана: пауза и выбор маршрута (Ронин-1/05 T1) ---

  /// Последняя деталь «Ронина-1»: с паузы — только «К кораблю» (финал).
  bool get _isLastPart => widget.levelIndex >= RoninParts.parts.length - 1;

  /// Деталь собрана (`isComplete`) или чит «Победить»: сразу, без задержки,
  /// засчитывает прогресс (`completeLevel`) и ставит паузу. Идемпотентно
  /// (`_done`). Прогресс пишется до выбора кнопки — оба маршрута дают ровно
  /// +1, закрытие игры на паузе деталь не теряет.
  void _markDone() {
    if (_done) return;
    setState(() => _done = true);
    _progressSaved = ProgressService().completeLevel(widget.levelIndex);
  }

  /// «Следующая деталь» → следующий уровень.
  Future<void> _onDoneNext() async {
    if (_leaving) return;
    _leaving = true;
    // Захватить navigator ДО await/pushReplacement, пока context валиден.
    final navigator = Navigator.of(context);
    await _progressSaved;
    final next = widget.levelIndex + 1;
    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => GameScreen(levelIndex: next)),
    );
  }

  /// «К кораблю» → корабль с приросшей деталью («Продолжить сборку» →
  /// следующий уровень); на последней детали — финал.
  Future<void> _onDoneToShip() async {
    if (_leaving) return;
    _leaving = true;
    final navigator = Navigator.of(context);
    await _progressSaved;
    if (_isLastPart) {
      navigator.pushReplacement(
        MaterialPageRoute(builder: (_) => const ShipScreen.finale()),
      );
      return;
    }
    final next = widget.levelIndex + 1;
    navigator.pushReplacement(
      MaterialPageRoute(
        builder: (_) => ShipScreen.afterWin(
          collectedCount: next,
          onContinue: () => navigator.pushReplacement(
            MaterialPageRoute(builder: (_) => GameScreen(levelIndex: next)),
          ),
        ),
      ),
    );
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

  /// Чит «мгновенная победа»: та же пауза «деталь собрана», движок не трогаем.
  void _cheatInstantWin() {
    Navigator.of(context).pop();
    _markDone();
  }

  /// Чит «Состояние корабля → n»: собрано n деталей (0..N; «15» — 15 / 15).
  Future<void> _cheatSetShipParts(int parts) async {
    Navigator.of(context).pop();
    await ProgressService().setCollectedCount(parts);
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

  /// Дев-чит «Пересобрать нарезку»: новый сдвиг seed → новая нарезка той же детали.
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
    _seedOffset++;
    _restartLevel();
  }

  /// Пересобирает текущий уровень с текущим `_seedOffset` и сбрасывает драг.
  void _restartLevel() {
    setState(() {
      _dragPieceId = null;
      _dragGlobalPos = null;
      _dragFromTray = false;
      _resetCandidate();
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
    if (_controller.state.isComplete) _markDone();
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

  // --- Захват с лотка по направлению (Ронин-1/08 T3) ---
  //
  // `Listener` в арене жестов не участвует, поэтому горизонтальный
  // drag-recognizer прокрутки лотка (`SingleChildScrollView`) выигрывает арену
  // по умолчанию сразу на касании и листает лоток. Касание куска лишь
  // запоминает кандидата; движение дальше `kTouchSlop` решает: вверх/вниз
  // (|dy| ≥ |dx|) — драг куска, вбок — кандидат сброшен, жест остаётся
  // прокрутке.

  void _onTrayPointerDown(int id, PointerDownEvent event) {
    if (_done || _dragPieceId != null) return;
    _candidateId = id;
    _candidateDown = event.position;
    _candidateTrayOffset =
        _trayScroll.hasClients ? _trayScroll.position.pixels : null;
  }

  void _onTrayPointerMove(PointerMoveEvent event) {
    if (_dragPieceId != null) {
      _onDragUpdate(event.position);
      return;
    }
    final id = _candidateId;
    final down = _candidateDown;
    if (id == null || down == null) return;
    final d = event.position - down;
    if (d.distance <= kTouchSlop) return;
    if (d.dy.abs() >= d.dx.abs()) {
      _freezeTrayScroll();
      _resetCandidate();
      _startDrag(id, fromTray: true, globalPos: event.position);
    } else {
      // Горизонталь — жест прокрутки лотка; в этом касании драг не стартует.
      _resetCandidate();
    }
  }

  void _onTrayPointerUp(PointerUpEvent event) {
    if (_dragPieceId != null) {
      _endDrag();
    } else {
      _resetCandidate();
    }
  }

  void _onTrayPointerCancel(PointerCancelEvent event) {
    _resetCandidate();
    _cancelDrag();
  }

  void _resetCandidate() {
    _candidateId = null;
    _candidateDown = null;
    _candidateTrayOffset = null;
  }

  /// Старт драга с лотка: лоток после этого не листается. Прокрутка уже
  /// захватила это касание (выиграла арену на касании); `jumpTo` начинает у
  /// позиции новую активность — текущий drag прокрутки утилизируется, и
  /// дальнейшие движения/отпускание этого пальца лоток не двигают (и не
  /// бросают инерцией). Позиция — та, что была на касании: сдвиг лотка в
  /// пределах slop откатывается. `Listener` куска события не теряет — путь
  /// hit-test закреплён на касании.
  void _freezeTrayScroll() {
    if (!_trayScroll.hasClients) return;
    final position = _trayScroll.position;
    final target = (_candidateTrayOffset ?? position.pixels)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    position.jumpTo(target);
  }

  void _onBoardPointerDown(PointerDownEvent event) {
    // Пауза «деталь собрана»: собранную деталь не разобрать.
    if (_done) return;
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
    if (_controller.state.isComplete) _markDone();
  }

  /// Прямоугольник поднятого куска (глобальные координаты) при пальце в
  /// [pointer]: размер — клетка поля × габарит куска в клетках, по центру X
  /// относительно пальца, нижний край выше пальца на [_dragLiftGap]. Единый
  /// расчёт для отрисовки ([_buildFeedback]) и якоря укладки/превью
  /// ([_anchorAt]) — они не расходятся.
  Rect _dragPieceRect(Offset pointer, PackPiece piece) {
    final size = _pieceBoundsPx(piece, _cellSize);
    return Rect.fromLTWH(
      pointer.dx - size.width / 2,
      pointer.dy - _dragLiftGap - size.height,
      size.width,
      size.height,
    );
  }

  /// Якорь укладки тащимого куска: клетка поля, ближайшая к левому верхнему
  /// углу [_dragPieceRect] (округление), либо `null`, если эта клетка вне
  /// поля. Им пользуются и снап-превью, и `_endDrag`.
  ({int x, int y})? _anchorAt(Offset? pointer) {
    final pieceId = _dragPieceId;
    if (pointer == null || pieceId == null) return null;
    final topLeft = _dragPieceRect(pointer, _pieceById(pieceId)).topLeft;
    final local = _globalToLocal(_boardKey, topLeft);
    if (local == null) return null;
    final x = (local.dx / _cellSize).round();
    final y = (local.dy / _cellSize).round();
    if (x < 0 || x >= _silhouette.width || y < 0 || y >= _silhouette.height) {
      return null;
    }
    return (x: x, y: y);
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
        _trayZoneHeight -
        2 * _boardPadding;
    final availableWidth = constraints.maxWidth - 2 * _boardPadding;
    final fitByHeight = availableHeight / boardHeight;
    final fitByWidth = availableWidth / boardWidth;
    final size = math.min(
      _canonicalCellSize,
      math.min(fitByHeight, fitByWidth),
    );
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
                    // Пауза «деталь собрана» — кнопки на месте лотка, та же
                    // высота зоны: поле не прыгает.
                    _done ? _buildDoneButtons() : _buildTray(state),
                  ],
                ),
                if (_dragPieceId != null && _dragGlobalPos != null)
                  _buildFeedback(cellSize),
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
            // `.title { flex:1; min-width:0 }`: заголовок берёт остаток строки и
            // ужимается, кнопки справа — натуральным размером (зазор 8).
            Expanded(child: _PartTitle(fragmentIndex: _fragmentIndex)),
            const SizedBox(width: 8.0),
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
    final content = Column(
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
          // Пауза — надпись «ДЕТАЛЬ СОБРАНА» (`.proglbl.done`, по центру, как
          // в мокапе) вместо счётчика кусков.
          // Высота строки — остаток бюджета зоны (34 − 8 − 6 − 4 = 16): строка
          // 12 px выше 10.5 px подписи и иначе переполнила бы зону на 1 px.
          child: _done
              ? const SizedBox(
                  height: 16.0,
                  child: Center(
                    child: Text(
                      'ДЕТАЛЬ СОБРАНА',
                      key: Key('packing_complete'),
                      style: _doneLabelStyle,
                    ),
                  ),
                )
              : Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'уложено ${state.placements.length} / ${state.pieces.length} кусков',
                    style: _progressLabelStyle,
                  ),
                ),
        ),
      ],
    );

    // На паузе «Очистить поле» нет: собранную деталь не разобрать.
    if (_done) return SizedBox(height: _progZoneHeight, child: content);

    final canClear = state.placements.isNotEmpty;
    // Строка прогресса держит бюджетную высоту [_progZoneHeight] (её же
    // вычитает расчёт клетки поля); кнопка «Очистить поле» — оверлей с зоной
    // нажатия 32 px высотой и не раздвигает строку.
    return SizedBox(
      height: _progZoneHeight,
      child: Stack(
        children: [
          content,
          Positioned(
            right: 14.0 - _clearHitWidthPad,
            top: _progZoneHeight - _clearHitHeight,
            height: _clearHitHeight,
            child: GestureDetector(
              key: const Key('clear_field'),
              behavior: HitTestBehavior.opaque,
              onTap: canClear ? _onClearField : null,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  _clearHitWidthPad,
                  0.0,
                  _clearHitWidthPad,
                  3.0,
                ),
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    'ОЧИСТИТЬ ПОЛЕ',
                    style: canClear
                        ? _progressLabelStyle.copyWith(
                            color: BlockMaterial.hazardOrange.color,
                          )
                        : _progressLabelStyle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// «Очистить поле»: отменяет идущий драг и возвращает все куски в лоток
  /// (`PackController.clear`).
  void _onClearField() {
    _cancelDrag();
    setState(() => _controller.clear());
  }

  static const TextStyle _progressLabelStyle = TextStyle(
    color: Color(0xFF7C848D),
    fontSize: 10.5,
    letterSpacing: 0.63, // .06em @ 10.5px
  );

  /// `.proglbl.done`: `hazardOrange`, 12 px, разрядка .24em, свечение
  /// `doneGlow` blur 12.
  static const TextStyle _doneLabelStyle = TextStyle(
    color: Color(0xFFBE642D), // hazardOrange
    fontSize: 12.0,
    letterSpacing: 2.88, // .24em @ 12px
    shadows: [Shadow(color: PackingPainter.doneGlow, blurRadius: 12.0)],
  );

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
        // Ободок `doneGlow` — на паузе (в т.ч. по читу «Победить»).
        final complete = _done;
        // `SizedBox` фиксирует внешний габарит панели (сетка + 2×паддинг);
        // `DecoratedBox` (в отличие от `Container`) красит фон/рамку БЕЗ
        // автоматической вставки внутреннего отступа под рамку — иначе
        // Container сам добавил бы к паддингу ещё толщину рамки и сжал бы
        // холст `CustomPaint` на её толщину (сетка перестала бы совпадать
        // с `boardPixelWidth`/`Height`, на которых держится драг-математика).
        return SizedBox(
          width: boardPixelWidth + 2 * _boardPadding,
          height: boardPixelHeight + 2 * _boardPadding,
          child: DecoratedBox(
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10.0),
              child: Padding(
                padding: const EdgeInsets.all(_boardPadding),
                child: child,
              ),
            ),
          ),
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
            art: RoninArt.shared,
            part: RoninParts.parts[_fragmentIndex],
            targetX: _targetX,
            targetY: _targetY,
            excludePieceId: _dragFromTray ? null : _dragPieceId,
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

    // Контейнер лотка фиксирован по размеру ([_trayZoneHeight], во всю ширину):
    // по мере опустения лоток не сжимается, поле над ним не прыгает.
    return Container(
      key: const Key('packing_tray'),
      width: double.infinity,
      height: _trayZoneHeight,
      margin: const EdgeInsets.symmetric(horizontal: 12.0),
      padding: const EdgeInsets.symmetric(
        vertical: _trayPaddingV,
        horizontal: 6.0,
      ),
      decoration: BoxDecoration(
        color: PackingPainter.trayBg,
        border: Border.all(
          color: BlockMaterial.gunmetal.color,
          width: _trayBorderWidth,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14.0)),
      ),
      child: Column(
        children: [
          SizedBox(
            height: _trayRowMaxHeight,
            child: SingleChildScrollView(
              controller: _trayScroll,
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
                          onPointerDown: (event) =>
                              _onTrayPointerDown(id, event),
                          onPointerMove: _onTrayPointerMove,
                          onPointerUp: _onTrayPointerUp,
                          onPointerCancel: _onTrayPointerCancel,
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
          ),
          const SizedBox(height: _trayLabelGap),
          SizedBox(
            height: _trayLabelHeight,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF6C747D),
                fontSize: 10.0,
                letterSpacing: 1.0, // .1em @ 10px
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedback(double cellSize) {
    final piece = _pieceById(_dragPieceId!);
    final local = _globalToLocal(
      _stackKey,
      _dragPieceRect(_dragGlobalPos!, piece).topLeft,
    );
    if (local == null) return const SizedBox.shrink();
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

  /// Пауза «деталь собрана» на месте лотка (канон `.donebtns` мокапа
  /// `ukladka-field.html`): та же высота [_trayZoneHeight] (поле не прыгает),
  /// ряд кнопок сверху (отступы 14/10/10, зазор 10), подпись лотка скрыта —
  /// её место остаётся пустым. Слева «К кораблю», справа основная «Следующая
  /// деталь»; на последней детали — одна «К кораблю» в основном стиле.
  Widget _buildDoneButtons() {
    return SizedBox(
      key: const Key('done_buttons'),
      width: double.infinity,
      height: _trayZoneHeight,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10.0, 14.0, 10.0, 10.0),
          child: Row(
            children: _isLastPart
                ? [
                    Expanded(
                      child: _DoneButton(
                        key: const Key('done_to_ship_button'),
                        label: 'К кораблю',
                        primary: true,
                        onTap: _onDoneToShip,
                      ),
                    ),
                  ]
                : [
                    Expanded(
                      child: _DoneButton(
                        key: const Key('done_to_ship_button'),
                        label: 'К кораблю',
                        onTap: _onDoneToShip,
                      ),
                    ),
                    const SizedBox(width: 10.0),
                    Expanded(
                      child: _DoneButton(
                        key: const Key('done_next_button'),
                        label: 'Следующая деталь',
                        primary: true,
                        onTap: _onDoneNext,
                      ),
                    ),
                  ],
          ),
        ),
      ),
    );
  }
}

/// Кнопка паузы «деталь собрана» — канон `.donebtns .btn` мокапа
/// `ukladka-field.html`: высота 44 (паддинг 13 + строка), скругление 10, текст
/// 12 px `.05em`. Обычная — рамка 1 `gunmetal`, фон `matteBlack`, текст
/// `#cbd2d9`; основная ([primary]) — рамка 1 + внутренняя обводка 1
/// `hazardOrange` (= 2 px), текст `#f0d6c2`.
class _DoneButton extends StatelessWidget {
  const _DoneButton({
    super.key,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool primary;

  static const Color _text = Color(0xFFCBD2D9); // `.donebtns .btn`
  static const Color _primaryText = Color(0xFFF0D6C2); // `.btn.primary`

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 44.0,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6.0),
          decoration: BoxDecoration(
            color: BlockMaterial.matteBlack.color,
            border: Border.all(
              color: primary
                  ? BlockMaterial.hazardOrange.color
                  : BlockMaterial.gunmetal.color,
              width: primary ? 2.0 : 1.0,
            ),
            borderRadius: BorderRadius.circular(10.0),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: primary ? _primaryText : _text,
              fontSize: 12.0,
              letterSpacing: 0.6, // .05em @ 12px
            ),
          ),
        ),
      ),
    );
  }
}

/// Заголовок топбара — канон `.title`/`.kick`/`.name` мокапа
/// (`docs/design/ukladka-field.html`, Ронин-1/01 T4): «ДЕТАЛЬ N / число деталей» +
/// название детали заглавными (`RoninParts.parts[fragmentIndex].title`).
/// Заменяет прежний чип со свотчем материала (Стори 02 T3) — свотча в
/// топбаре больше нет.
class _PartTitle extends StatelessWidget {
  const _PartTitle({required this.fragmentIndex});

  /// Индекс текущей детали (0-based); в тексте отображается `fragmentIndex+1`.
  final int fragmentIndex;

  static const Color _kickColor = Color(0xFF7C848D); // `.title .kick`
  static const Color _nameColor = Color(0xFFD7DDE3); // `.title .name`

  @override
  Widget build(BuildContext context) {
    final title = RoninParts.parts[fragmentIndex].title.toUpperCase();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ДЕТАЛЬ ${fragmentIndex + 1} / ${RoninParts.parts.length}',
          style: const TextStyle(
            color: _kickColor,
            fontSize: 10.0,
            letterSpacing: 1.4, // .14em @ 10px
          ),
        ),
        const SizedBox(height: 1.0),
        // Название не переносится и не обрезается: на узком экране ужимается
        // целиком (`scaleDown` шрифт 13 не увеличивает).
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            title,
            maxLines: 1,
            softWrap: false,
            style: const TextStyle(
              color: _nameColor,
              fontSize: 13.0,
              letterSpacing: 0.78, // .06em @ 13px
            ),
          ),
        ),
      ],
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
