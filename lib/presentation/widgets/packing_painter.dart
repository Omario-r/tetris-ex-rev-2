import 'package:flutter/material.dart';

import '../../game_engine/packing/pack_piece.dart';
import '../../game_engine/packing/pack_state.dart';
import '../theme/block_material.dart';
import '../theme/block_paint_utils.dart';
import '../theme/block_theme.dart';
import '../theme/ship_materials.dart';
import 'ship.dart' show kShipPartCount;

/// Рисует укладку (эпик «Укладка», Стори 01 T3, канон утверждён Стори 02 T1):
/// силуэт (ghost для незаполненных клеток S, канон [BlockTheme.ghostTarget])
/// + уложенные кусочки (залитые `el-block`, [BlockPaintUtils.paintElBlock]) +
/// живое снап-превью драга (`el-drop-ok`/`el-drop-bad`, [dragPreview]).
/// Уложенные клетки красятся единым [partMaterial] детали, если задан
/// (канон `el-cell-filled`), иначе — прежней циклической [materialForPiece]
/// (обратная совместимость прототипа). Реиспользует существующие токены/
/// пейнтеры `presentation/theme` — новой палитры не заводит (Дизайн-референс
/// Стори 02 T1).
///
/// Только вид — без игровой логики (инвариант модуля `widgets`): не мутирует
/// [state], не знает про drag-жесты (это `presentation/screens`).
class PackingPainter extends CustomPainter {
  /// Создаёт пейнтер укладки для снапшота [state].
  const PackingPainter({
    required this.state,
    required this.cellSize,
    required this.shipMaterials,
    this.excludePieceId,
    this.partMaterial,
    this.dragPreview,
  });

  /// Текущий снапшот укладки (силуэт + размещённые кусочки).
  final PackState state;

  /// Пиксельный размер одной клетки силуэта.
  final double cellSize;

  /// Материалы, которыми красятся кусочки (циклически по `pieceId`, см.
  /// [materialForPiece]) — та же палитра, что у корабля/поля (эпик #4).
  /// Используется, только если [partMaterial] не задан.
  final ShipMaterials shipMaterials;

  /// Id уложенного кусочка, который сейчас пропускается при отрисовке (экран
  /// рисует его отдельно как плавающий drag-фидбэк — иначе кусочек рисовался
  /// бы дважды, на старом месте и под пальцем).
  final int? excludePieceId;

  /// Материал собранной детали (единый цвет). Если задан — ВСЕ уложенные
  /// клетки красятся им (канон `el-cell-filled`, Стори 02 T1). Если `null` —
  /// прежнее поведение: циклическая [materialForPiece] (обратная
  /// совместимость с прототипом Стори 01 T3).
  final BlockMaterial? partMaterial;

  /// Живое снап-превью текущего драга (клетки поля, куда ляжет кусок при
  /// текущем якоре, + валидность). `null` — драга нет, превью не рисуется
  /// (Стори 02 T1).
  final PackDragPreview? dragPreview;

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

  /// Материал кусочка по его `pieceId`: циклический выбор из
  /// [ShipMaterials.defaultMaterials] (7 материалов эпика #4) — различает
  /// соседние кусочки на существующих токенах, новой палитры не заводит
  /// (Дизайн-референс T3).
  static BlockMaterial materialForPiece(int pieceId, ShipMaterials materials) {
    return materials.materialForPart(pieceId % kShipPartCount);
  }

  /// Рисует один кусочек [piece] с левым-верхним углом в пиксельной точке
  /// [originPx]. Единая точка правды «как выглядит кусочек» — переиспользуется
  /// и здесь (уложенные кусочки), и в `packing_prototype_screen` (лоток +
  /// drag-фидбэк), чтобы вид не разъезжался.
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

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = boardBg);

    // Ghost — незаполненные клетки силуэта.
    final occupied = state.occupiedCells;
    for (final cell in state.silhouette.cells) {
      if (!occupied.contains(cell)) {
        BlockTheme.ghostTarget.paint(canvas, _cellRect(cell.x, cell.y));
      }
    }

    // Уложенные кусочки.
    for (final entry in state.placements.entries) {
      if (entry.key == excludePieceId) continue;
      final piece = state.pieces.firstWhere((p) => p.id == entry.key);
      final origin = entry.value;
      final material =
          partMaterial ?? materialForPiece(entry.key, shipMaterials);
      paintPiece(
        canvas,
        piece,
        Offset(origin.x * cellSize, origin.y * cellSize),
        cellSize,
        material,
      );
    }

    // Снап-превью драга (el-drop-ok / el-drop-bad) — поверх ghost и уложенных
    // клеток, только клетки в границах поля.
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
        final rect = _cellRect(cell.x, cell.y);
        canvas.drawRect(rect, fillPaint);
        canvas.drawRect(rect.deflate(1.0), strokePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PackingPainter oldDelegate) {
    return state != oldDelegate.state ||
        cellSize != oldDelegate.cellSize ||
        shipMaterials != oldDelegate.shipMaterials ||
        excludePieceId != oldDelegate.excludePieceId ||
        partMaterial != oldDelegate.partMaterial ||
        dragPreview != oldDelegate.dragPreview;
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

  static bool _listEquals(
    List<({int x, int y})> a,
    List<({int x, int y})> b,
  ) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
