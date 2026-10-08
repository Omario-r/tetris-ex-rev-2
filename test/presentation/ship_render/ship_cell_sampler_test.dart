import 'dart:ui' as ui;

import 'package:explosive_tetris/game_engine/data/ronin_parts.dart';
import 'package:explosive_tetris/presentation/ship_render/ronin_art.dart';
import 'package:explosive_tetris/presentation/ship_render/ship_cell_sampler.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// Рисует [draw] на холст [w]×[h] и отдаёт растр.
Future<ui.Image> _raster(int w, int h, void Function(Canvas) draw) {
  final rec = ui.PictureRecorder();
  draw(Canvas(rec, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble())));
  return rec.endRecording().toImage(w, h);
}

Future<int> _alpha(ui.Image img, int x, int y) async {
  final data = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  return data.getUint8((y * img.width + x) * 4 + 3);
}

void main() {
  final art = RoninArt();
  const c = RoninArt.cellPx;

  test('клетка (0, 0) плиты prow: источник — toScene(5, 0), сторона C / 2', () {
    final prow = RoninParts.byId('prow');
    final src = shipCellRect(art, prow, 0, 0);
    final tl = art.toScene(5, 0);
    expect(src.left, closeTo(tl.dx, 1e-9));
    expect(src.top, closeTo(tl.dy, 1e-9));
    expect(src.width, closeTo(c / 2, 1e-9));
    expect(src.height, closeTo(c / 2, 1e-9));
  });

  test('клетка предмета — в его масштабе (rcs_fl, s = 8)', () {
    final rcs = RoninParts.byId('rcs_fl');
    final src = shipCellRect(art, rcs, 3, 4);
    final tl = art.toScene(2.438 + 3 / 8, 3.944 + 4 / 8);
    expect(src.topLeft.dx, closeTo(tl.dx, 1e-9));
    expect(src.topLeft.dy, closeTo(tl.dy, 1e-9));
    expect(src.width, closeTo(c / 8, 1e-9));
  });

  test('paintPartCell — все клетки всех деталей рисуются без исключений', () {
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    for (final part in RoninParts.parts) {
      for (final cell in part.mask.cells) {
        paintPartCell(
          canvas,
          art,
          part,
          cell.x,
          cell.y,
          Rect.fromLTWH(cell.x * 34.0, cell.y * 34.0, 34, 34),
        );
      }
    }
    rec.endRecording().dispose();
  });

  test('клетка (0, 0) плиты prow заполняет dst и не выходит за него', () async {
    final prow = RoninParts.byId('prow');
    const dst = Rect.fromLTWH(10, 10, 34, 34);
    final img = await _raster(
      60,
      60,
      (g) => paintPartCell(g, art, prow, 0, 0, dst),
    );
    expect(await _alpha(img, 27, 27), 255); // середина клетки — корпус
    expect(await _alpha(img, 12, 12), 255);
    expect(await _alpha(img, 5, 27), 0); // вне dst — пусто
    expect(await _alpha(img, 50, 27), 0);
    img.dispose();
  });
}
