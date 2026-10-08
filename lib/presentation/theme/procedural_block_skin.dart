import 'dart:ui';

import 'block_material.dart';
import 'block_paint_utils.dart';
import 'block_skin.dart';

/// Canonical `el-block` skin (`docs/design/game-field.html`, каталог
/// элементов поля) — one render for every [BlockMaterial]: flat material
/// fill + inset bevel + corner rivets. Used for blocks painted with a single
/// material chosen by the caller.
///
/// Возврат Гейта 2 2026-07-18: прежние пер-материальные процедурные текстуры
/// (инсет-грид/hazard-полосы/питтинг) отменены — канон один для всех
/// материалов (`docs/DESIGN.md`).
class ProceduralBlockSkin implements BlockSkin {
  /// Creates a procedural skin for the given [material].
  const ProceduralBlockSkin(this.material);

  /// The block material this skin renders.
  final BlockMaterial material;

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    int? boardX,
    int? boardY,
  }) {
    BlockPaintUtils.paintElBlock(canvas, rect, material.color);
  }
}
