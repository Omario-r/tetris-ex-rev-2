import 'package:flutter/material.dart';

/// Shared drawing helpers for procedural block skins.
class BlockPaintUtils {
  BlockPaintUtils._();

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
