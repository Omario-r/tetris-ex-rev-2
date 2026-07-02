import 'package:flutter/material.dart';

import 'block_paint_utils.dart';
import 'block_skin.dart';

/// TNT block skin with fuse spark for armed explosive pieces.
class TntSkin implements BlockSkin {
  /// Shared TNT skin instance.
  const TntSkin();

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    int? boardX,
    int? boardY,
  }) {
    final bx = boardX ?? 0;
    final by = boardY ?? 0;

    BlockPaintUtils.drawTexturedRect(
      canvas,
      rect,
      bx,
      by,
      (lx, ly) => _tntColor(bx, by, lx, ly),
    );

    _drawTntLabel(canvas, rect);
    _drawFuseSpark(canvas, rect);

    BlockPaintUtils.drawBevel(canvas, rect);
    BlockPaintUtils.drawBlockOutline(canvas, rect);
  }

  static Color _tntColor(int bx, int by, int lx, int ly) {
    if (ly < 2 || ly > 13) {
      return const Color(0xFF7A4A3A);
    }
    if (ly >= 6 && ly <= 9) {
      return const Color(0xFFE9E4DA);
    }
    final v = BlockPaintUtils.noise(bx, by, lx, ly);
    return BlockPaintUtils.pick(
      v,
      [0.0, 0.33, 0.66],
      [
        const Color(0xFFA83226),
        const Color(0xFFC0392B),
        const Color(0xFFD1483A),
      ],
    );
  }

  static void _drawTntLabel(Canvas canvas, Rect rect) {
    final labelRect = Rect.fromLTWH(
      rect.left,
      rect.top + rect.height * 0.375,
      rect.width,
      rect.height * 0.25,
    );
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'TNT',
        style: TextStyle(
          color: const Color(0xFF1A1A1A),
          fontSize: (rect.height * 0.18).clamp(6.0, 14.0),
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: labelRect.width);

    final offset = Offset(
      labelRect.left + (labelRect.width - textPainter.width) / 2,
      labelRect.top + (labelRect.height - textPainter.height) / 2,
    );
    textPainter.paint(canvas, offset);
  }

  static void _drawFuseSpark(Canvas canvas, Rect rect) {
    final sparkCenter = Offset(
      rect.left + rect.width * 0.5,
      rect.top + rect.height * 0.08,
    );
    final sparkRadius = rect.width * 0.12;

    final outer = Paint()..color = const Color(0xFFFFD24A);
    canvas.drawCircle(sparkCenter, sparkRadius, outer);

    final inner = Paint()..color = const Color(0xFFFFFFFF);
    canvas.drawCircle(sparkCenter, sparkRadius * 0.45, inner);
  }
}
