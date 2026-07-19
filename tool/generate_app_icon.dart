// Icon source generator — Стори 03 T2 (canon `docs/design/app-icon.html`,
// вариант «Заряд»). Renders `CanisterChargePainter(state: ChargeIconState.ready)`
// — same source of truth as the boom button icon — into two 1024×1024 PNGs
// consumed by `flutter_launcher_icons`:
//   - `assets/icon/app_icon.png` — matteBlack background + canister (iOS/base).
//   - `assets/icon/app_icon_foreground.png` — transparent background + canister
//     (Android adaptive foreground; safe-zone margin so the mask doesn't clip it).
//
// This is a Flutter *test file* used purely as a one-off script — it lives in
// `tool/`, NOT `test/`, so the default `flutter test` run (which globs
// `test/**_test.dart`) never picks it up. Run explicitly:
//   flutter test tool/generate_app_icon.dart
//
// Deterministic render (no animation/pulse — `ChargeIconState.ready` is static),
// safe to re-run any time the canon painter changes.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:explosive_tetris/presentation/theme/canister_charge_painter.dart';

const int _kIconSize = 1024;
const Color _kMatteBlack = Color(0xFF1D2025);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generate_app_icon_sources', () async {
    await _renderIcon(
      outputPath: 'assets/icon/app_icon.png',
      fillBackground: true,
      canvasWidth: 421.0,
      translateDx: 301.5,
      translateDy: 276.5,
    );
    await _renderIcon(
      outputPath: 'assets/icon/app_icon_foreground.png',
      fillBackground: false,
      canvasWidth: 360.0,
      translateDx: 332.0,
      translateDy: 310.7,
    );
  });
}

/// Renders the canister-charge icon (`ChargeIconState.ready`) into a
/// [_kIconSize]×[_kIconSize] PNG at [outputPath].
///
/// [fillBackground] — paint the matteBlack square first (iOS/base icon) or
/// leave it transparent (Android adaptive foreground layer).
/// [canvasWidth] — the painter's `Size(canvasWidth, canvasWidth)`, i.e. the
/// canister's design-space width fed to `CanisterChargePainter` (which scales
/// internally by `size.width / 34`).
/// [translateDx]/[translateDy] — canvas translate before painting, centering
/// the canister's full bounding box (body + cap extending into negative y)
/// within the 1024² square.
Future<void> _renderIcon({
  required String outputPath,
  required bool fillBackground,
  required double canvasWidth,
  required double translateDx,
  required double translateDy,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  if (fillBackground) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, _kIconSize.toDouble(), _kIconSize.toDouble()),
      Paint()..color = _kMatteBlack,
    );
  }

  canvas.translate(translateDx, translateDy);
  const CanisterChargePainter(state: ChargeIconState.ready)
      .paint(canvas, Size(canvasWidth, canvasWidth));

  final picture = recorder.endRecording();
  final image = await picture.toImage(_kIconSize, _kIconSize);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(outputPath);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(byteData!.buffer.asUint8List());
}
