import 'package:flutter/material.dart';

import '../../game_engine/packing/pack_piece.dart';
import '../../game_engine/packing/pack_state.dart';
import '../theme/block_material.dart';
import '../theme/block_paint_utils.dart';
import '../theme/block_theme.dart';
import '../theme/ship_materials.dart';
import 'ship.dart' show kShipPartCount;

/// Рисует укладку прототипа (эпик «Укладка», Стори 01 T3): силуэт (ghost для
/// незаполненных клеток S, канон [BlockTheme.ghostTarget]) + уложенные
/// кусочки (залитые `el-block`, [BlockPaintUtils.paintElBlock]). Реиспользует
/// существующие токены/пейнтеры `presentation/theme` — новой палитры не
/// заводит (Дизайн-референс T3).
///
/// Только вид — без игровой логики (инвариант модуля `widgets`): не мутирует
/// [state], не знает про drag-жесты (это `packing_prototype_screen`).
class PackingPainter extends CustomPainter {
  /// Создаёт пейнтер укладки для снапшота [state].
  const PackingPainter({
    required this.state,
    required this.cellSize,
    required this.shipMaterials,
    this.excludePieceId,
  });

  /// Текущий снапшот укладки (силуэт + размещённые кусочки).
  final PackState state;

  /// Пиксельный размер одной клетки силуэта.
  final double cellSize;

  /// Материалы, которыми красятся кусочки (циклически по `pieceId`, см.
  /// [materialForPiece]) — та же палитра, что у корабля/поля (эпик #4).
  final ShipMaterials shipMaterials;

  /// Id уложенного кусочка, который сейчас пропускается при отрисовке (экран
  /// рисует его отдельно как плавающий drag-фидбэк — иначе кусочек рисовался
  /// бы дважды, на старом месте и под пальцем).
  final int? excludePieceId;

  /// boardBg token (`docs/DESIGN.md`) — тот же фон, что у игрового поля
  /// (`BoardPainter`).
  static const Color boardBg = Color(0xFF16191D);

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
      final material = materialForPiece(entry.key, shipMaterials);
      paintPiece(
        canvas,
        piece,
        Offset(origin.x * cellSize, origin.y * cellSize),
        cellSize,
        material,
      );
    }
  }

  @override
  bool shouldRepaint(covariant PackingPainter oldDelegate) {
    return state != oldDelegate.state ||
        cellSize != oldDelegate.cellSize ||
        shipMaterials != oldDelegate.shipMaterials ||
        excludePieceId != oldDelegate.excludePieceId;
  }
}
