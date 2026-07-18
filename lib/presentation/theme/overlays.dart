import 'package:flutter/material.dart';

import 'block_paint_utils.dart';

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

/// Warm overlay for occupied halo cells.
class HaloHighlightOverlay {
  /// Shared halo highlight overlay instance.
  const HaloHighlightOverlay();

  /// Paints a warm highlight on a dirty halo cell.
  void paint(Canvas canvas, Rect rect, {double pulse = 0.0}) {
    // Hazard-orange hue family (ORAN) — same warning language as block
    // materials, kept warm to preserve the overlay's original function.
    final alphaBoost = pulse * 0.04;
    final fill = Paint()
      ..color = Color.fromRGBO(190, 100, 45, 0.14 + alphaBoost)
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, fill);

    final stroke = Paint()
      ..color = Color.fromRGBO(208, 115, 57, 0.6 + alphaBoost)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRect(rect, stroke);
  }
}

/// Creeper face icon for the Arm button.
class CreeperFacePainter extends CustomPainter {
  /// Creates a creeper face painter.
  const CreeperFacePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    BlockPaintUtils.paintBlock(
      canvas,
      rect,
      0,
      0,
      (lx, ly) {
        final v = BlockPaintUtils.noise(0, 0, lx, ly);
        return BlockPaintUtils.pick(
          v,
          [0.0, 0.33, 0.66],
          [
            const Color(0xFF438C33),
            const Color(0xFF4FA03A),
            const Color(0xFF5CB347),
          ],
        );
      },
    );

    final faceColor = Paint()..color = const Color(0xFF111111);
    final unit = size.width / 16;

    void eye(int col, int row) {
      canvas.drawRect(
        Rect.fromLTWH(col * unit, row * unit, unit * 2, unit * 2),
        faceColor,
      );
    }

    eye(3, 4);
    eye(11, 4);

    for (var col = 5; col <= 10; col++) {
      canvas.drawRect(
        Rect.fromLTWH(col * unit, 8 * unit, unit, unit),
        faceColor,
      );
    }
    for (var row = 9; row <= 11; row++) {
      for (var col in [4, 5, 10, 11]) {
        canvas.drawRect(
          Rect.fromLTWH(col * unit, row * unit, unit, unit),
          faceColor,
        );
      }
    }
  }

  @override
  bool shouldRepaint(CreeperFacePainter oldDelegate) => false;
}
