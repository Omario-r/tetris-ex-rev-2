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

/// Pulse highlight for occupied dirty-halo cells — canonical `el-halo`
/// (`docs/design/game-field.html`, каталог элементов поля, утверждён PO
/// 2026-07-18): рамка `ghostTarget`-тона (hazardOrange @ 55%) + лёгкое
/// свечение, без плоской заливки. Пульс альфы — прежний период (T1).
class HaloHighlightOverlay {
  /// Shared halo highlight overlay instance.
  const HaloHighlightOverlay();

  /// Paints a pulsing border highlight on a dirty halo cell.
  void paint(Canvas canvas, Rect rect, {double pulse = 0.0}) {
    final s = rect.width / BlockPaintUtils.baseCellSize;
    // Inset ~2.5px / radius 3px at base cell 34px (el-halo annotation).
    final inset = rect.deflate(2.5 * s);
    final rrect = RRect.fromRectAndRadius(inset, Radius.circular(3.0 * s));

    // ghostTarget token RGB (211,124,69 = #D37C45) — same hazard hue as the
    // target overlay; alpha pulses on the existing period (T1), unchanged.
    final alphaBoost = pulse * 0.04;

    // Soft outer glow behind the crisp border.
    final glow = Paint()
      ..color = const Color.fromRGBO(211, 124, 69, 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0 * s
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.5 * s);
    canvas.drawRRect(rrect, glow);

    final border = Paint()
      ..color = Color.fromRGBO(211, 124, 69, 0.55 + alphaBoost)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * s;
    canvas.drawRRect(rrect, border);
  }
}
