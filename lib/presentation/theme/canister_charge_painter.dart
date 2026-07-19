import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Icon state of the boom button's canister/core (Стори 02 T1, canon
/// `docs/design/game-field.html` `.can`/`.armedcore`, панель
/// «КНОПКА ВЗРЫВА — СОСТОЯНИЯ»). Own voxel "canister-charge" language —
/// replaces the Minecraft TNT/creeper look.
enum ChargeIconState {
  /// Есть заряды, не взведено — спокойная канистра, hazard-полоса горит.
  ready,

  /// Взведено — горячее ядро с кольцами/искрами/пульсом.
  armed,

  /// 0 зарядов — канистра «мёртвая», hazard-полоса гаснет в серый.
  empty,
}

/// Paints the canister-charge icon for the boom button: canister body
/// ([ChargeIconState.ready]/[ChargeIconState.empty]) or hot core
/// ([ChargeIconState.armed]) — canon `docs/design/game-field.html`
/// `.can`/`.armedcore`. Only the icon itself (no outer button chrome/badge —
/// those are composed by `GameHud`, `presentation/widgets`).
///
/// Design coordinates are authored at the mockup's base size (canister
/// 34×46, core 36×36) and scaled by `size.width / <base width>` — same
/// scaling pattern as `BlockPaintUtils` (`rect.width / baseCellSize`).
class CanisterChargePainter extends CustomPainter {
  /// Creates a canister/core icon painter for [state].
  ///
  /// [pulse] drives the armed glow's alpha boost — same source/period as
  /// `HaloHighlightOverlay`/`armedGlow` (`animValue` propagated from
  /// `GameScreen` through `GameHud`, no own timer).
  const CanisterChargePainter({required this.state, this.pulse = 0.0});

  /// Current icon state (Ready/Armed/Empty).
  final ChargeIconState state;

  /// Pulse phase in `[0, 1]` driving the armed glow's alpha boost.
  final double pulse;

  // Base design sizes (mockup `.can` / `.armedcore`).
  static const double _canisterBaseW = 34.0;
  static const double _coreBaseW = 36.0;

  // Tokens (docs/DESIGN.md + game-field.html), computed to hex where the
  // mockup gives HSL directly (deterministic HSL->RGB, same approach as
  // Стори 01 T4).
  static const Color _graphite = Color(0xFF484E56); // graphite token
  static const Color _graphiteDark = Color(0xFF3C4148); // graphiteDark token
  static const Color _capIndicator = Color(0xFFCFD6DD); // `.can::after`
  static const Color _hazardOrange = Color(0xFFBE642D); // hazardOrange token
  static const Color _stripeDark = Color(0xFF17191D); // stripe dark band
  static const Color _stripeDeadGray = Color(0xFF3A3F46); // dead stripe gray
  static const Color _coreFill = Color(0xFF7E4E30); // hsl(23 45% 34%)
  static const Color _ringColor = Color(0xFFCF6D30); // hsl(23 62% 50%)
  static const Color _armedGlow = Color(0xFFD37C45); // armedGlow/ghostTarget
  static const Color _armedEmber = Color(0xFFFFD9B8); // armedEmber token
  static const Color _armedEmberGlow = Color(0xFFFFB87A); // armedEmberGlow

  @override
  void paint(Canvas canvas, Size size) {
    switch (state) {
      case ChargeIconState.armed:
        _paintCore(canvas, size);
        break;
      case ChargeIconState.ready:
        _paintCanister(canvas, size, dead: false);
        break;
      case ChargeIconState.empty:
        _paintCanister(canvas, size, dead: true);
        break;
    }
  }

  static void _paintCanister(Canvas canvas, Size size, {required bool dead}) {
    final s = size.width / _canisterBaseW;

    // Body: `.can` — 34×46, radius 7, graphite fill + light/dark bevel bands.
    final body = Rect.fromLTWH(0, 0, 34.0 * s, 46.0 * s);
    final bodyRRect = RRect.fromRectAndRadius(body, Radius.circular(7.0 * s));
    canvas.save();
    canvas.clipRRect(bodyRRect);
    canvas.drawRRect(bodyRRect, Paint()..color = _graphite);
    canvas.drawRect(
      Rect.fromLTWH(body.left, body.top, body.width, 2.0 * s),
      Paint()..color = Colors.white.withValues(alpha: 0.10),
    );
    canvas.drawRect(
      Rect.fromLTWH(body.left, body.bottom - 3.0 * s, body.width, 3.0 * s),
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );
    canvas.restore();

    // Cap: `.can::before` — 12×8 above body, top corners rounded, graphiteDark.
    final capRect = Rect.fromLTWH(11.0 * s, -8.0 * s, 12.0 * s, 8.0 * s);
    final capPath = Path()
      ..moveTo(capRect.left, capRect.bottom)
      ..lineTo(capRect.left, capRect.top + 3.0 * s)
      ..arcToPoint(
        Offset(capRect.left + 3.0 * s, capRect.top),
        radius: Radius.circular(3.0 * s),
      )
      ..lineTo(capRect.right - 3.0 * s, capRect.top)
      ..arcToPoint(
        Offset(capRect.right, capRect.top + 3.0 * s),
        radius: Radius.circular(3.0 * s),
      )
      ..lineTo(capRect.right, capRect.bottom)
      ..close();
    canvas.drawPath(capPath, Paint()..color = _graphiteDark);

    // Indicator dot: `.can::after` — Ø4 circle above cap.
    canvas.drawCircle(
      Offset(17.0 * s, -4.0 * s),
      2.0 * s,
      Paint()..color = _capIndicator,
    );

    // Seam: `.can .seam` — vertical 1px line, inset 4px top/bottom.
    canvas.drawLine(
      Offset(17.0 * s, 4.0 * s),
      Offset(17.0 * s, 42.0 * s),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.25)
        ..strokeWidth = 1.0 * s,
    );

    // Hazard stripe: `.can .stripe` — 45° repeating bands, height 10, radius 2,
    // overhangs body by 3px each side. Dead → gray bands (`.can.dead .stripe`).
    final stripeRect = Rect.fromLTWH(-3.0 * s, 17.0 * s, 40.0 * s, 10.0 * s);
    final stripeRRect =
        RRect.fromRectAndRadius(stripeRect, Radius.circular(2.0 * s));
    _drawDiagonalStripes(
      canvas,
      stripeRRect,
      base: _stripeDark,
      stripe: dead ? _stripeDeadGray : _hazardOrange,
      stripeWidth: 7.0 * s,
      period: 14.0 * s,
    );
  }

  void _paintCore(Canvas canvas, Size size) {
    final s = size.width / _coreBaseW;
    final coreRect = Rect.fromLTWH(0, 0, 36.0 * s, 36.0 * s);
    final rrect = RRect.fromRectAndRadius(coreRect, Radius.circular(10.0 * s));

    // Outer blurred glow (box-shadow `0 0 18px armedGlow/55%`), alpha pulses
    // on the halo's period — same formula as `paintElPieceArmed`'s hot glow.
    final alphaBoost = pulse * 0.04;
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = _armedGlow.withValues(alpha: (0.55 + alphaBoost).clamp(0.0, 1.0))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 18.0 * s),
    );

    // Rings (box-shadow spread 18px @ 8% then 9px @ 16%), painted back to front.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        coreRect.inflate(18.0 * s),
        Radius.circular(28.0 * s),
      ),
      Paint()..color = _ringColor.withValues(alpha: 0.08),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        coreRect.inflate(9.0 * s),
        Radius.circular(19.0 * s),
      ),
      Paint()..color = _ringColor.withValues(alpha: 0.16),
    );

    // Sparks at the four corners, outside the core — `.spark` (7×7, radius 2,
    // hazardOrange, rotate 12°).
    for (final corner in [
      coreRect.topLeft,
      coreRect.topRight,
      coreRect.bottomLeft,
      coreRect.bottomRight,
    ]) {
      final dx = corner.dx < coreRect.center.dx ? -6.0 * s : 6.0 * s;
      final dy = corner.dy < coreRect.center.dy ? -6.0 * s : 6.0 * s;
      _drawSpark(canvas, corner + Offset(dx, dy), 7.0 * s);
    }

    // Core body fill: `.armedcore` — hsl(23 45% 34%).
    canvas.drawRRect(rrect, Paint()..color = _coreFill);

    // Ember core: `.armedcore::before` — 15×15 radius 4, armedEmber fill +
    // armedEmberGlow blur (box-shadow `0 0 8px armedEmberGlow`).
    final emberRect = Rect.fromCenter(
      center: coreRect.center,
      width: 15.0 * s,
      height: 15.0 * s,
    );
    final emberRRect =
        RRect.fromRectAndRadius(emberRect, Radius.circular(4.0 * s));
    canvas.drawRRect(
      emberRRect,
      Paint()
        ..color = _armedEmberGlow
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8.0 * s),
    );
    canvas.drawRRect(emberRRect, Paint()..color = _armedEmber);
  }

  static void _drawSpark(Canvas canvas, Offset center, double size) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(12.0 * math.pi / 180.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: size, height: size),
        Radius.circular(size * 2.0 / 7.0),
      ),
      Paint()..color = _hazardOrange,
    );
    canvas.restore();
  }

  static void _drawDiagonalStripes(
    Canvas canvas,
    RRect rrect, {
    required Color base,
    required Color stripe,
    required double stripeWidth,
    required double period,
  }) {
    canvas.save();
    canvas.clipRRect(rrect);
    final rect = rrect.outerRect;
    canvas.drawRect(rect, Paint()..color = base);

    final diag = rect.width + rect.height;
    canvas.translate(rect.center.dx, rect.center.dy);
    canvas.rotate(math.pi / 4);
    final paint = Paint()..color = stripe;
    for (var x = -diag; x < diag; x += period) {
      canvas.drawRect(Rect.fromLTWH(x, -diag, stripeWidth, diag * 2), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CanisterChargePainter oldDelegate) =>
      oldDelegate.state != state || oldDelegate.pulse != pulse;
}
