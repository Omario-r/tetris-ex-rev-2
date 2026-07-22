import 'package:flutter/material.dart';

/// Ghost overlay for unfilled target cells (blueprint style).
class GhostTargetOverlay {
  /// Shared ghost target overlay instance.
  const GhostTargetOverlay();

  /// Paints a semi-transparent ghost target cell.
  void paint(Canvas canvas, Rect rect) {
    // Mockup game-field.html `.cell.ghost::after`: inset ~3px, rounded corners.
    final inset = rect.deflate(3.0);
    final rrect = RRect.fromRectAndRadius(inset, const Radius.circular(3.0));

    // hazardOrange (ORAN #BE642D) tint at 5% alpha — light target fill.
    final fill = Paint()
      ..color = const Color.fromRGBO(190, 100, 45, 0.05)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, fill);

    // ghostTarget token: hsl(23 62% 55% / 55%) = #D37C45 @ 55% — hazard
    // dashed outline (was a cool graphite dash pre-mockup, Стори 01 T1).
    final dash = Paint()
      ..color = const Color.fromRGBO(211, 124, 69, 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    const dashLen = 3.0;
    const gapLen = 3.0;
    _drawDashedRect(canvas, inset, dash, dashLen, gapLen);
  }

  static void _drawDashedRect(
    Canvas canvas,
    Rect rect,
    Paint paint,
    double dashLen,
    double gapLen,
  ) {
    _drawDashedLine(
      canvas,
      rect.topLeft,
      rect.topRight,
      paint,
      dashLen,
      gapLen,
    );
    _drawDashedLine(
      canvas,
      rect.topRight,
      rect.bottomRight,
      paint,
      dashLen,
      gapLen,
    );
    _drawDashedLine(
      canvas,
      rect.bottomRight,
      rect.bottomLeft,
      paint,
      dashLen,
      gapLen,
    );
    _drawDashedLine(
      canvas,
      rect.bottomLeft,
      rect.topLeft,
      paint,
      dashLen,
      gapLen,
    );
  }

  static void _drawDashedLine(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint paint,
    double dashLen,
    double gapLen,
  ) {
    final total = (end - start).distance;
    if (total == 0) return;
    final direction = (end - start) / total;
    var traveled = 0.0;
    var drawing = true;

    while (traveled < total) {
      final segment = drawing ? dashLen : gapLen;
      final next = (traveled + segment).clamp(0.0, total);
      if (drawing) {
        canvas.drawLine(
          start + direction * traveled,
          start + direction * next,
          paint,
        );
      }
      traveled = next;
      drawing = !drawing;
    }
  }
}
