import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'block_material.dart';

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
    // Extension hooks for `el-piece-armed` (Стори 01 T6) reuse — no-op for
    // every existing caller (`el-block`/`el-scrap`/`el-piece`, T1/T5).
    void Function(Canvas canvas, Rect blockRect, double scale)?
        onFillPainted,
    Color? topBandOverlayColor,
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

    onFillPainted?.call(canvas, blockRect, s);

    final band = bandSize * s;
    if (topAlpha > 0) {
      canvas.drawRect(
        Rect.fromLTWH(blockRect.left, blockRect.top, blockRect.width, band),
        Paint()..color = Colors.white.withValues(alpha: topAlpha),
      );
    }
    if (topBandOverlayColor != null) {
      canvas.drawRect(
        Rect.fromLTWH(blockRect.left, blockRect.top, blockRect.width, band),
        Paint()..color = topBandOverlayColor,
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

  /// Canonical `el-piece-armed` render (Стори 01 T6, `docs/design/game-field.html`
  /// `#el-piece-armed`): падающая фигура в режиме `armed`. Poклеточный —
  /// вызывается для каждой клетки фигуры, риски продолжаются от [rect] клетки
  /// (не от board-координат — параметра `boardX/boardY` тут нет), что даёт
  /// одинаковую фазу хэтча на каждой клетке фигуры (визуально тайлится).
  ///
  /// Слои: база `el-piece` (графит, свет сверху 12%, риветы, мягкое белое
  /// свечение 6%) → диагональный hazard-хэтч 45° (`armedHatch`, полоса 6/34,
  /// зазор 8/34) поверх заливки, под фаской/риветами → hazard-подкрас верхней
  /// фаски (`hsl(23 62% 70% / 20%)`) → горячее внешнее свечение `armedGlow`
  /// (blur ~20/34) с пульсом альфы от [pulse] (тот же источник/период, что у
  /// `el-halo` — `HaloHighlightOverlay`, `animValue` в `BoardPainter`) →
  /// ембер-ядро в центре клетки (Ø 13/34, `armedEmber` заливка,
  /// `armedEmberGlow` свечение).
  static void paintElPieceArmed(
    Canvas canvas,
    Rect rect, {
    required double pulse,
  }) {
    final s = rect.width / baseCellSize;

    paintElBlock(
      canvas,
      rect,
      BlockMaterial.graphite.color,
      topAlpha: 0.12,
      leftAlpha: 0.0,
      rightAlpha: 0.0,
      glowAlpha: 0.06,
      onFillPainted: (canvas, blockRect, scale) {
        _drawDiagonalHatch(
          canvas,
          blockRect,
          stripeWidth: 6.0 * scale,
          period: 14.0 * scale,
          color: const Color.fromRGBO(190, 100, 45, 0.55), // armedHatch
        );
      },
      topBandOverlayColor: const Color.fromRGBO(226, 167, 131, 0.20),
    );

    // Hot outer glow (armedGlow token) — alpha pulses on the halo's period.
    final blockRect = rect.deflate(1.0 * s);
    final rrect = RRect.fromRectAndRadius(blockRect, Radius.circular(3.0 * s));
    final alphaBoost = pulse * 0.04;
    final hotGlow = Paint()
      ..color = Color.fromRGBO(
        211,
        124,
        69,
        (0.55 + alphaBoost).clamp(0.0, 1.0),
      )
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 20.0 * s);
    canvas.drawRRect(rrect, hotGlow);

    // Ember core: 13/34 circle, armedEmber fill + armedEmberGlow blur.
    final center = rect.center;
    final emberGlow = Paint()
      ..color = const Color(0xFFFFB87A) // armedEmberGlow
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 9.0 * s);
    canvas.drawCircle(center, 6.5 * s, emberGlow);
    final ember = Paint()..color = const Color(0xFFFFD9B8); // armedEmber
    canvas.drawCircle(center, 6.5 * s, ember);
  }

  static void _drawDiagonalHatch(
    Canvas canvas,
    Rect blockRect, {
    required double stripeWidth,
    required double period,
    required Color color,
  }) {
    final paint = Paint()..color = color;
    final diag = blockRect.width + blockRect.height;
    canvas.save();
    canvas.translate(blockRect.center.dx, blockRect.center.dy);
    canvas.rotate(math.pi / 4);
    for (var x = -diag; x < diag; x += period) {
      canvas.drawRect(
        Rect.fromLTWH(x, -diag, stripeWidth, diag * 2),
        paint,
      );
    }
    canvas.restore();
  }

  /// Canonical `el-drop-armed` render (Стори 01 T6, `docs/design/game-field.html`
  /// `#el-drop-armed`): drop-ghost of the armed piece — same geometry as
  /// [paintElDrop] (inset 2px, radius 3px at [baseCellSize]) but **solid**
  /// (not dashed — a target overlay is dashed, this must read as distinct),
  /// coloured with `armedEmberGlow`: solid 1px contour + 10% warm fill +
  /// soft ember glow inside/outside.
  static void paintElDropArmed(Canvas canvas, Rect rect) {
    final s = rect.width / baseCellSize;
    final inset = rect.deflate(2.0 * s);
    final rrect = RRect.fromRectAndRadius(inset, Radius.circular(3.0 * s));
    const emberGlowColor = Color(0xFFFFB87A); // armedEmberGlow

    // Soft ember glow, inside and outside the contour.
    final glow = Paint()
      ..color = emberGlowColor.withValues(alpha: 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0 * s
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4.0 * s);
    canvas.drawRRect(rrect, glow);

    // Warm fill, armedEmberGlow @ 10%.
    canvas.drawRRect(
      rrect,
      Paint()..color = emberGlowColor.withValues(alpha: 0.10),
    );

    // Solid contour, armedEmberGlow @ 100%.
    final outline = Paint()
      ..color = emberGlowColor
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

}
