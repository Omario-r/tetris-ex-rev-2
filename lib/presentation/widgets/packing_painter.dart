import 'package:flutter/material.dart';

import '../../game_engine/data/ronin_parts.dart';
import '../../game_engine/packing/pack_piece.dart';
import '../../game_engine/packing/pack_state.dart';
import '../ship_render/ship_art.dart';
import '../ship_render/ship_cell_sampler.dart';
import '../theme/block_material.dart';
import '../theme/block_paint_utils.dart';
import '../theme/block_theme.dart';

/// Рисует укладку (эпик «Укладка», Стори 01 T3, канон утверждён Стори 02 T1):
/// силуэт (ghost для незаполненных клеток S, канон [BlockTheme.ghostTarget])
/// + уложенные клетки — каждая свой кусок рисунка корабля в масштабе детали
/// (канон `el-cell-filled`, Ронин-1/03: [paintPartCells]): во время сборки —
/// плитка с рельефом, собранная деталь ([assembled]) — рисунок целиком с
/// чёткой кромкой (D-016, Ронин-1/10) + живое снап-превью драга
/// (`el-drop-ok`/`el-drop-bad`, [dragPreview]).
///
/// Только вид — без игровой логики (инвариант модуля `widgets`): не мутирует
/// [state], не знает про drag-жесты (это `presentation/screens`).
class PackingPainter extends CustomPainter {
  /// Создаёт пейнтер укладки для снапшота [state].
  const PackingPainter({
    required this.state,
    required this.cellSize,
    required this.art,
    required this.part,
    required this.targetX,
    required this.targetY,
    this.excludePieceId,
    this.dragPreview,
    this.assembled = false,
    this.cellColors,
  });

  /// Текущий снапшот укладки (силуэт + размещённые кусочки).
  final PackState state;

  /// Пиксельный размер одной клетки силуэта.
  final double cellSize;

  /// Рисунок корабля, из которого сэмплируются уложенные клетки.
  final ShipArt art;

  /// Деталь уровня: её маска лежит в поле со сдвигом [targetX]/[targetY];
  /// масштаб и место клеток на корабле — `cellOnShip`.
  final RoninPartDef part;

  /// Сдвиг bbox маски детали в поле по X (`PreparedLevel.targetX`): клетка
  /// поля (x, y) ↔ клетка маски (x − [targetX], y − [targetY]).
  final int targetX;

  /// Сдвиг bbox маски детали в поле по Y (`PreparedLevel.targetY`).
  final int targetY;

  /// Id уложенного кусочка, который сейчас пропускается при отрисовке (экран
  /// рисует его отдельно как плавающий drag-фидбэк — иначе кусочек рисовался
  /// бы дважды, на старом месте и под пальцем).
  final int? excludePieceId;

  /// Живое снап-превью текущего драга (клетки поля, куда ляжет кусок при
  /// текущем якоре, + валидность). `null` — драга нет, превью не рисуется
  /// (Стори 02 T1).
  final PackDragPreview? dragPreview;

  /// `true` — деталь собрана (пауза «ДЕТАЛЬ СОБРАНА»): рисунок целиком, без
  /// плиток и рельефа, у плиты — чёткая кромка (D-016). `false` — сборка:
  /// каждая уложенная клетка — плитка с рельефом и заклёпками.
  final bool assembled;

  /// Преобладающие цвета клеток детали ([partCellColors]): заливка клетки
  /// предмета и тон заклёпок в сборке. `null` — ещё не посчитаны (предмет —
  /// рисунком под клеткой, заклёпки 45 %).
  final PartCellColors? cellColors;

  /// boardBg token (`docs/DESIGN.md`) — тот же фон, что у игрового поля
  /// (`BoardPainter`).
  static const Color boardBg = Color(0xFF16191D);

  /// dropOk token (`docs/DESIGN.md`): снап-превью «кусок ляжет» — контур.
  static const Color dropOk = Color(0xE6D37C45);

  /// dropOkFill token (`docs/DESIGN.md`): снап-превью «кусок ляжет» — заливка.
  static const Color dropOkFill = Color(0x33BE642D);

  /// dropBad token (`docs/DESIGN.md`): снап-превью «класть нельзя» — контур.
  static const Color dropBad = Color(0x99CC3833);

  /// dropBadFill token (`docs/DESIGN.md`): снап-превью «класть нельзя» —
  /// заливка.
  static const Color dropBadFill = Color(0x2EAB2F2B);

  /// trayBg token (`docs/DESIGN.md`): фон лотка кусочков (полка).
  static const Color trayBg = Color(0xFF14161A);

  /// doneGlow token (`docs/DESIGN.md`): тёплый ободок собранной детали
  /// (пульс, канон `board.complete`).
  static const Color doneGlow = Color(0x8CE09952);

  /// Рисует один кусочек [piece] с левым-верхним углом в пиксельной точке
  /// [originPx] — «сырой» вид кусочка вне поля (лоток и кусок в руке,
  /// `el-piece-tray`/`el-piece-drag`, материал `graphite`). Единая точка
  /// правды — её зовёт `GameScreen`, чтобы вид лотка и драга не разъезжался.
  /// Уложенные клетки так не рисуются — они куски рисунка корабля.
  static void paintPiece(
    Canvas canvas,
    PackPiece piece,
    Offset originPx,
    double cellSize,
    BlockMaterial material,
  ) {
    for (final cell in piece.cells) {
      final rect = Rect.fromLTWH(
        originPx.dx + cell.x * cellSize,
        originPx.dy + cell.y * cellSize,
        cellSize,
        cellSize,
      );
      BlockPaintUtils.paintElBlock(canvas, rect, material.color);
    }
  }

  Rect _cellRect(int x, int y) {
    return Rect.fromLTWH(x * cellSize, y * cellSize, cellSize, cellSize);
  }

  /// Клетки всех размещённых кусочков [state], КРОМЕ кусочка
  /// [excludePieceId] (мокап `ukladka-field.html`, `liftPlaced`: кусок,
  /// взятый в руку, немедленно снимается с поля — под ним сразу читается
  /// ghost мишени). Если [excludePieceId] — `null` или не встречается в
  /// `state.placements` (кусок ещё в лотке, драг из лотка), результат
  /// эквивалентен `state.occupiedCells`.
  static Set<({int x, int y})> occupiedCellsExcluding(
    PackState state,
    int? excludePieceId,
  ) {
    if (excludePieceId == null ||
        !state.placements.containsKey(excludePieceId)) {
      return state.occupiedCells;
    }
    final result = <({int x, int y})>{};
    for (final entry in state.placements.entries) {
      if (entry.key == excludePieceId) continue;
      final piece = state.pieces.firstWhere((p) => p.id == entry.key);
      final origin = entry.value;
      for (final cell in piece.cells) {
        result.add((x: origin.x + cell.x, y: origin.y + cell.y));
      }
    }
    return result;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = boardBg);

    // Ghost — незаполненные клетки силуэта (кусок в руке — excludePieceId —
    // снят из occupied, возврат Стори 04 T5: ghost под ним читается сразу).
    final occupied = occupiedCellsExcluding(state, excludePieceId);
    for (final cell in state.silhouette.cells) {
      if (!occupied.contains(cell)) {
        BlockTheme.ghostTarget.paint(canvas, _cellRect(cell.x, cell.y));
      }
    }

    // Уложенные клетки — куски рисунка детали (канон `el-cell-filled`): одним
    // вызовом, один клип и один replay на слой. Клетка поля (x, y) ↔ клетка
    // маски (x − targetX, y − targetY); маска (0, 0) ложится в клетку поля
    // (targetX, targetY), поэтому кусок попадает ровно в свой прямоугольник.
    // Швов `seam` нет (D-016): в сборке клетки делит рельеф плитки.
    paintPartCells(
      canvas,
      art,
      part,
      [for (final f in occupied) (x: f.x - targetX, y: f.y - targetY)],
      origin: Offset(targetX * cellSize, targetY * cellSize),
      cellSize: cellSize,
      assembled: assembled,
      colors: cellColors,
    );

    // Снап-превью драга (el-drop-ok / el-drop-bad) — поверх ghost и уложенных
    // клеток, только клетки в границах поля. Канон мокапа (`.gcell.ok/.bad
    // ::after`, возврат Стори 04 T4): каждая клетка — ОТДЕЛЬНАЯ скруглённая
    // плашка (инсет 3px от границ клетки, радиус 4), а не сплошной блок —
    // между соседними клетками превью читается зазор.
    final preview = dragPreview;
    if (preview != null) {
      final strokeColor = preview.valid ? dropOk : dropBad;
      final fillColor = preview.valid ? dropOkFill : dropBadFill;
      final fillPaint = Paint()..color = fillColor;
      final strokePaint = Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      for (final cell in preview.cells) {
        if (cell.x < 0 ||
            cell.y < 0 ||
            cell.x >= state.silhouette.width ||
            cell.y >= state.silhouette.height) {
          continue;
        }
        final chip = RRect.fromRectAndRadius(
          _cellRect(cell.x, cell.y).deflate(3.0),
          const Radius.circular(4.0),
        );
        canvas.drawRRect(chip, fillPaint);
        canvas.drawRRect(chip, strokePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PackingPainter oldDelegate) {
    return state != oldDelegate.state ||
        cellSize != oldDelegate.cellSize ||
        art != oldDelegate.art ||
        part != oldDelegate.part ||
        targetX != oldDelegate.targetX ||
        targetY != oldDelegate.targetY ||
        excludePieceId != oldDelegate.excludePieceId ||
        dragPreview != oldDelegate.dragPreview ||
        assembled != oldDelegate.assembled ||
        cellColors != oldDelegate.cellColors;
  }
}

/// Снап-превью текущего драга: [cells] — АБСОЛЮТНЫЕ клетки силуэта, куда
/// ляжет кусок при текущем якоре, [valid] — можно ли класть (влияет на цвет:
/// [PackingPainter.dropOk]/[PackingPainter.dropBad], канон
/// `el-drop-ok`/`el-drop-bad`). Immutable — сравнение по значению в
/// [PackingPainter.shouldRepaint] опирается на `==`.
class PackDragPreview {
  const PackDragPreview({required this.cells, required this.valid});

  /// Абсолютные клетки силуэта, куда ляжет кусок при текущем якоре драга.
  final List<({int x, int y})> cells;

  /// true — кусок можно положить сюда (канон `el-drop-ok`), false — нельзя
  /// (канон `el-drop-bad`).
  final bool valid;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PackDragPreview &&
        valid == other.valid &&
        _listEquals(cells, other.cells);
  }

  @override
  int get hashCode => Object.hash(valid, Object.hashAll(cells));

  static bool _listEquals(List<({int x, int y})> a, List<({int x, int y})> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
