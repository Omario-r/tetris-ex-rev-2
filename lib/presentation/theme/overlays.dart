import 'package:flutter/material.dart';

import 'block_paint_utils.dart';

/// Ghost overlay for unfilled target cells (blueprint style).
class GhostTargetOverlay {
  /// Shared ghost target overlay instance.
  const GhostTargetOverlay();

  /// Paints a semi-transparent ghost target cell.
  void paint(Canvas canvas, Rect rect) {
    final fill = Paint()
      ..color = const Color.fromRGBO(120, 110, 90, 0.16)
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, fill);

    final dash = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const dashLen = 3.0;
    const gapLen = 3.0;
    _drawDashedRect(canvas, rect, dash, dashLen, gapLen);
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
    final alphaBoost = pulse * 0.04;
    final fill = Paint()
      ..color = Color.fromRGBO(255, 190, 80, 0.12 + alphaBoost)
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, fill);

    final stroke = Paint()
      ..color = Color.fromRGBO(255, 205, 95, 0.6 + alphaBoost)
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
