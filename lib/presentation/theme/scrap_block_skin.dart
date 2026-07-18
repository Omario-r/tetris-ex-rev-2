import 'dart:ui' as ui;

import 'block_material.dart';
import 'block_paint_utils.dart';
import 'block_skin.dart';

/// Canonical `el-scrap` skin (`docs/design/game-field.html`, каталог
/// элементов поля) — "сырой" вид клеток вне мишени: заливка `graphiteDark`,
/// слабая фаска (без боковых граней), без риветов, питтинг ржавчины вместо
/// них. Используется `BoardPainter` для клеток вне целевого окна.
class ScrapBlockSkin implements BlockSkin {
  /// Creates a scrap block skin.
  const ScrapBlockSkin();

  /// Rust-tone pit colors (hsl(19,58%,30%) / hsl(19,58%,26%)) — darker
  /// lightness variants of the `rust` token hue, same family already used
  /// by the pre-canon rust texture.
  static const _rustSpot1 = ui.Color(0xFF793C20);
  static const _rustSpot2 = ui.Color(0xFF69341C);

  @override
  void paint(ui.Canvas canvas, ui.Rect rect, {int? boardX, int? boardY}) {
    final bx = boardX ?? 0;
    final by = boardY ?? 0;
    final s = rect.width / BlockPaintUtils.baseCellSize;

    BlockPaintUtils.paintElBlock(
      canvas,
      rect,
      BlockMaterial.graphiteDark.color,
      topAlpha: 0.05,
      bottomAlpha: 0.30,
      leftAlpha: 0.0,
      rightAlpha: 0.0,
      bandSize: 2.0,
      rivets: false,
    );

    // Pitting: 2 rust-tone spots + 1 dark spot, positions deterministic
    // from cell coords (boardX, boardY) — stable between frames.
    final blockRect = rect.deflate(1.0 * s);
    final rrect =
        ui.RRect.fromRectAndRadius(blockRect, ui.Radius.circular(3.0 * s));
    canvas.save();
    canvas.clipRRect(rrect);
    _drawSpot(
      canvas,
      _spotCenter(blockRect, bx, by, 4),
      1.0 * s,
      _rustSpot1.withValues(alpha: 0.55),
    );
    _drawSpot(
      canvas,
      _spotCenter(blockRect, bx, by, 5),
      1.0 * s,
      _rustSpot2.withValues(alpha: 0.5),
    );
    _drawSpot(
      canvas,
      _spotCenter(blockRect, bx, by, 6),
      0.75 * s,
      const ui.Color(0xFF000000).withValues(alpha: 0.4),
    );
    canvas.restore();
  }

  static ui.Offset _spotCenter(ui.Rect blockRect, int bx, int by, int seed) {
    final nx = BlockPaintUtils.noise(bx, by, seed, 0);
    final ny = BlockPaintUtils.noise(bx, by, seed, 1);
    return ui.Offset(
      blockRect.left + blockRect.width * (0.15 + nx * 0.7),
      blockRect.top + blockRect.height * (0.15 + ny * 0.7),
    );
  }

  static void _drawSpot(
    ui.Canvas canvas,
    ui.Offset center,
    double radius,
    ui.Color color,
  ) {
    final paint = ui.Paint()
      ..shader = ui.Gradient.radial(
        center,
        radius * 1.6,
        [color, color.withValues(alpha: 0.0)],
        [radius / (radius * 1.6), 1.0],
      );
    canvas.drawCircle(center, radius * 1.6, paint);
  }
}
