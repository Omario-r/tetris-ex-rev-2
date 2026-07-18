import 'package:flutter/material.dart';

/// Shared drawing helpers for procedural block skins.
class BlockPaintUtils {
  BlockPaintUtils._();

  /// Base cell size (px) the element catalog annotations are defined at
  /// (`docs/design/game-field.html`, panel "Каталог элементов поля"). All
  /// element size annotations scale proportionally to the actual cell size
  /// from this base.
  static const double baseCellSize = 34.0;

  /// Canonical `el-block` render: flat material fill + inset bevel bands +
  /// optional corner rivets + optional soft outer glow. One render for
  /// every [BlockMaterial] — only [fillColor] and the bevel/glow parameters
  /// vary between `el-block` (mishень) and `el-piece` (falling piece).
  ///
  /// Sizes (gap 1px, radius 3px, bevel band 3px, rivet Ø 3px @ 4px offset)
  /// are annotated at [baseCellSize] and scaled by `rect.width / baseCellSize`.
  static void paintElBlock(
    Canvas canvas,
    Rect rect,
    Color fillColor, {
    double topAlpha = 0.09,
    double bottomAlpha = 0.35,
    double leftAlpha = 0.04,
    double rightAlpha = 0.18,
    double bandSize = 3.0,
    bool rivets = true,
    double glowAlpha = 0.0,
  }) {
    final s = rect.width / baseCellSize;
    final blockRect = rect.deflate(1.0 * s);
    final rrect =
        RRect.fromRectAndRadius(blockRect, Radius.circular(3.0 * s));

    if (glowAlpha > 0) {
      final glow = Paint()
        ..color = Colors.white.withValues(alpha: glowAlpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4.0 * s);
      canvas.drawRRect(rrect, glow);
    }

    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRRect(rrect, Paint()..color = fillColor);

    final band = bandSize * s;
    if (topAlpha > 0) {
      canvas.drawRect(
        Rect.fromLTWH(blockRect.left, blockRect.top, blockRect.width, band),
        Paint()..color = Colors.white.withValues(alpha: topAlpha),
      );
    }
    if (bottomAlpha > 0) {
      canvas.drawRect(
        Rect.fromLTWH(
          blockRect.left,
          blockRect.bottom - band,
          blockRect.width,
          band,
        ),
        Paint()..color = Colors.black.withValues(alpha: bottomAlpha),
      );
    }
    if (leftAlpha > 0) {
      canvas.drawRect(
        Rect.fromLTWH(blockRect.left, blockRect.top, band, blockRect.height),
        Paint()..color = Colors.white.withValues(alpha: leftAlpha),
      );
    }
    if (rightAlpha > 0) {
      canvas.drawRect(
        Rect.fromLTWH(
          blockRect.right - band,
          blockRect.top,
          band,
          blockRect.height,
        ),
        Paint()..color = Colors.black.withValues(alpha: rightAlpha),
      );
    }
    canvas.restore();

    if (rivets) {
      final dotRadius = 1.5 * s;
      final dotOffset = 4.0 * s;
      final dotPaint = Paint()..color = Colors.black.withValues(alpha: 0.45);
      for (final corner in [
        Offset(blockRect.left + dotOffset, blockRect.top + dotOffset),
        Offset(blockRect.right - dotOffset, blockRect.top + dotOffset),
        Offset(blockRect.left + dotOffset, blockRect.bottom - dotOffset),
        Offset(blockRect.right - dotOffset, blockRect.bottom - dotOffset),
      ]) {
        canvas.drawCircle(corner, dotRadius, dotPaint);
      }
    }
  }

  /// Canonical `el-drop` render: 1px white 16% stroke outline, no fill.
  /// Inset 2px, radius 3px at [baseCellSize], scaled to `rect`.
  static void paintElDrop(Canvas canvas, Rect rect) {
    final s = rect.width / baseCellSize;
    final inset = rect.deflate(2.0 * s);
    final rrect = RRect.fromRectAndRadius(inset, Radius.circular(3.0 * s));
    final outline = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 * s;
    canvas.drawRRect(rrect, outline);
  }

  /// Deterministic noise value in [0, 1) from board and local texture coords.
  static double noise(int boardX, int boardY, int localX, int localY) {
    var n = boardX * 374761393 +
        boardY * 668265263 +
        localX * 1274126177 +
        localY * 1975733711;
    n = (n ^ (n >> 13)) * 1274126177;
    n = n ^ (n >> 16);
    return (n & 0x7fffffff) / 0x7fffffff;
  }

  /// Picks a color from [stops] using threshold stops and matching [colors].
  static Color pick(double v, List<double> stops, List<Color> colors) {
    for (var i = stops.length - 1; i >= 0; i--) {
      if (v >= stops[i]) {
        return colors[i.clamp(0, colors.length - 1)];
      }
    }
    return colors.first;
  }

  /// Draws a 16×16 logical texture scaled into [rect].
  static void drawTexturedRect(
    Canvas canvas,
    Rect rect,
    int boardX,
    int boardY,
    Color Function(int localX, int localY) colorAt,
  ) {
    const logicalSize = 16;
    final cellW = rect.width / logicalSize;
    final cellH = rect.height / logicalSize;
    final paint = Paint()..style = PaintingStyle.fill;

    for (var ly = 0; ly < logicalSize; ly++) {
      for (var lx = 0; lx < logicalSize; lx++) {
        paint.color = colorAt(lx, ly);
        canvas.drawRect(
          Rect.fromLTWH(
            rect.left + lx * cellW,
            rect.top + ly * cellH,
            cellW + 0.5,
            cellH + 0.5,
          ),
          paint,
        );
      }
    }
  }

  /// Draws a light top/left and dark bottom/right bevel (~10%).
  static void drawBevel(Canvas canvas, Rect rect) {
    final light = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (rect.width * 0.10).clamp(1.0, 3.0);
    final dark = Paint()
      ..color = Colors.black.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (rect.width * 0.10).clamp(1.0, 3.0);

    canvas.drawLine(rect.topLeft, rect.topRight, light);
    canvas.drawLine(rect.topLeft, rect.bottomLeft, light);
    canvas.drawLine(rect.bottomLeft, rect.bottomRight, dark);
    canvas.drawLine(rect.topRight, rect.bottomRight, dark);
  }

  /// Draws a 1px dark outline around the block perimeter.
  static void drawBlockOutline(Canvas canvas, Rect rect) {
    final outline = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRect(rect, outline);
  }

  /// Full block finish: texture + bevel + outline.
  static void paintBlock(
    Canvas canvas,
    Rect rect,
    int boardX,
    int boardY,
    Color Function(int localX, int localY) colorAt,
  ) {
    drawTexturedRect(canvas, rect, boardX, boardY, colorAt);
    drawBevel(canvas, rect);
    drawBlockOutline(canvas, rect);
  }
}
