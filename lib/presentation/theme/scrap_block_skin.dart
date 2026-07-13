import 'dart:ui' as ui;

import 'block_skin.dart';
import 'block_paint_utils.dart';

/// Scrap block skin — "сырой" вид клеток вне мишени.
///
/// Визуально отличается от материалов корабля: более шероховатый, необработанный
/// текстурный шум с резкими переходами и пятнами, имитирующий неотполированный
/// материал. Используется `BoardPainter` для клеток вне целевого окна.
class ScrapBlockSkin implements BlockSkin {
  /// Creates a scrap block skin with optional tint.
  const ScrapBlockSkin({
    this.baseColor = const ui.Color(0xFF3D3D3D),
    this.spotColor = const ui.Color(0xFF2A2A2A),
  });

  /// Base color for the scrap texture.
  final ui.Color baseColor;

  /// Spot/patch color for roughness variation.
  final ui.Color spotColor;

  @override
  void paint(ui.Canvas canvas, ui.Rect rect, {int? boardX, int? boardY}) {
    // Base fill
    final paint = ui.Paint()..color = baseColor;
    canvas.drawRect(rect, paint);

    // Draw rough patches
    if (BlockPaintUtils.noise(boardX ?? 0, boardY ?? 0, 1, 0) > 0.7) {
      final spotPaint = ui.Paint()..color = spotColor.withAlpha(128);
      final spotSize = rect.width * 0.25;
      final offsetX = (rect.left + rect.width * 0.1) +
          (rect.width * 0.8 * BlockPaintUtils.noise(boardX ?? 0, boardY ?? 0, 2, 0));
      final offsetY = (rect.top + rect.height * 0.1) +
          (rect.height * 0.8 * BlockPaintUtils.noise(boardX ?? 0, boardY ?? 0, 3, 0));
      canvas.drawRect(
        ui.Rect.fromLTWH(offsetX, offsetY, spotSize, spotSize),
        spotPaint,
      );
    }

    // Edge bevel for texture
    BlockPaintUtils.drawBevel(canvas, rect);
  }
}
