import 'dart:ui' as ui;

import 'package:explosive_tetris/game_engine/data/ronin_parts.dart';
import 'package:explosive_tetris/presentation/ship_render/ronin_art.dart';
import 'package:explosive_tetris/presentation/ship_render/ship_composite_painter.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = Size(320, 540);

Future<ui.Image> _raster(ShipCompositePainter p) {
  final rec = ui.PictureRecorder();
  p.paint(Canvas(rec, Offset.zero & _size), _size);
  return rec.endRecording().toImage(_size.width.toInt(), _size.height.toInt());
}

void main() {
  final art = RoninArt();

  /// Точка рисунка (клетки) → точка холста [_size] по кадру мокапа.
  Offset onCanvas(double x, double y) {
    final f = ShipCompositePainter.frameOf(art);
    final k = [
      _size.width / f.width,
      _size.height / f.height,
    ].reduce((a, b) => a < b ? a : b);
    final ox = (_size.width - f.width * k) / 2,
        oy = (_size.height - f.height * k) / 2;
    final s = art.toScene(x, y);
    return Offset(ox + (s.dx - f.left) * k, oy + (s.dy - f.top) * k);
  }

  Future<int> alphaAt(ui.Image img, Offset p) async {
    final data = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    return data.getUint8((p.dy.floor() * img.width + p.dx.floor()) * 4 + 3);
  }

  test('кадр мокапа: x 44..W−44, y 26..H−14', () {
    final f = ShipCompositePainter.frameOf(art);
    expect(f, Rect.fromLTRB(44, 26, RoninArt.width - 44, RoninArt.height - 14));
  });

  for (final n in [0, 3, 15]) {
    test('пейнт при $n собранных — без исключений', () async {
      final img = await _raster(
        ShipCompositePainter(art: art, collectedCount: n),
      );
      expect(img.width, 320);
      img.dispose();
    });
  }

  test('собранное — из рисунка, несобранное — пусто (только контур)', () async {
    // Середина носа (prow, order 1) и середина нижнего пояса (fwd2_cr, order 15).
    final nose = onCanvas(7.5, 1.0);
    final belt = onCanvas(8.0, 7.5);

    final none = await _raster(
      ShipCompositePainter(art: art, collectedCount: 0),
    );
    expect(await alphaAt(none, nose), 0);
    expect(await alphaAt(none, belt), 0);

    final three = await _raster(
      ShipCompositePainter(art: art, collectedCount: 3),
    );
    expect(await alphaAt(three, nose), 255);
    expect(await alphaAt(three, belt), 0);

    final all = await _raster(
      ShipCompositePainter(art: art, collectedCount: RoninParts.parts.length),
    );
    expect(await alphaAt(all, nose), 255);
    expect(await alphaAt(all, belt), 255);
    for (final img in [none, three, all]) {
      img.dispose();
    }
  });

  test(
    'reveal: деталь в процессе появления и на старте (progress 0)',
    () async {
      for (final progress in [0.0, 0.5, 1.0]) {
        final img = await _raster(
          ShipCompositePainter(
            art: art,
            collectedCount: 9,
            revealPartIndex: 8,
            revealProgress: progress,
          ),
        );
        img.dispose();
      }
      // progress 0 — сама деталь ещё не видна: её середина пуста.
      final nose = onCanvas(7.5, 1.0);
      final img = await _raster(
        ShipCompositePainter(
          art: art,
          collectedCount: 1,
          revealPartIndex: 0,
          revealProgress: 0,
        ),
      );
      expect(await alphaAt(img, nose), 0);
      img.dispose();
    },
  );

  test('collectedCount клампится 0..15, shouldRepaint по полям', () {
    final a = ShipCompositePainter(art: art, collectedCount: 99);
    expect(a.collectedCount, RoninParts.parts.length);
    expect(
      ShipCompositePainter(art: art, collectedCount: -1).collectedCount,
      0,
    );
    expect(
      a.shouldRepaint(ShipCompositePainter(art: art, collectedCount: 15)),
      isFalse,
    );
    expect(
      a.shouldRepaint(ShipCompositePainter(art: art, collectedCount: 3)),
      isTrue,
    );
  });
}
