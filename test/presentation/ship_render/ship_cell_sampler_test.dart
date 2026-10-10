import 'dart:ui' as ui;

import 'package:explosive_tetris/game_engine/data/ronin_parts.dart';
import 'package:explosive_tetris/presentation/ship_render/ronin_art.dart';
import 'package:explosive_tetris/presentation/ship_render/ship_art.dart';
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

/// RGBA пикселя ([x], [y]) растра [img].
Future<List<int>> _rgba(ui.Image img, int x, int y) async {
  final data = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final i = (y * img.width + x) * 4;
  return [for (var k = 0; k < 4; k++) data.getUint8(i + k)];
}

/// `paintPartCells` по [cells] детали [id] против `paintPartCell` по тем же
/// клеткам (холст 1×, клетка 32, origin (0, 0)): в точках `(c + .5) * 32` и
/// `(c + .2) * 32` каналы совпадают с допуском ±2.
Future<void> _expectCellsMatchSingle(
  RoninArt art,
  String id,
  List<({int x, int y})> cells,
) async {
  const cs = 32.0;
  const size = 320;
  final part = RoninParts.byId(id);
  final many = await _raster(
    size,
    size,
    (g) =>
        paintPartCells(g, art, part, cells, origin: Offset.zero, cellSize: cs),
  );
  final single = await _raster(size, size, (g) {
    for (final cell in cells) {
      paintPartCell(
        g,
        art,
        part,
        cell.x,
        cell.y,
        Rect.fromLTWH(cell.x * cs, cell.y * cs, cs, cs),
      );
    }
  });
  for (final cell in cells) {
    for (final f in const [0.5, 0.2]) {
      final x = ((cell.x + f) * cs).floor(), y = ((cell.y + f) * cs).floor();
      final a = await _rgba(many, x, y), b = await _rgba(single, x, y);
      for (var k = 0; k < 4; k++) {
        expect(
          (a[k] - b[k]).abs(),
          lessThanOrEqualTo(2),
          reason:
              '$id клетка (${cell.x}, ${cell.y}) точка ($x, $y) канал $k: '
              '$a против $b',
        );
      }
      expect(a[3], 255, reason: 'клетка залита целиком (подложка + рисунок)');
    }
  }
  many.dispose();
  single.dispose();
}

int _sum(List<int> p) => p[0] + p[1] + p[2];

double _lum(Color k) => 0.2126 * k.r + 0.7152 * k.g + 0.0722 * k.b;

/// Рисунок [pic] в раскладке поля детали [part]: клетка маски (0, 0) → (0, 0),
/// клетка [u] px — эталон «под клеткой» без плиток и кромок.
Future<ui.Image> _fieldRef(
  RoninArt art,
  RoninPartDef part,
  ui.Picture pic,
  double u,
) {
  final src = shipCellRect(art, part, 0, 0);
  return _raster(
    (part.mask.width * u).ceil(),
    (part.mask.height * u).ceil(),
    (g) => g
      ..scale(u / src.width)
      ..translate(-src.left, -src.top)
      ..drawPicture(pic),
  );
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

  group('paintPartCells (поле укладки, Ронин-1/03)', () {
    test(
      'плита bridge_c: растр клеток = paintPartCell в тех же клетках',
      () async {
        await _expectCellsMatchSingle(art, 'bridge_c', const [
          (x: 4, y: 0),
          (x: 5, y: 0),
          (x: 0, y: 2),
        ]);
      },
    );

    test(
      'предмет sensor: растр клеток = paintPartCell в тех же клетках',
      () async {
        await _expectCellsMatchSingle(art, 'sensor', const [
          (x: 3, y: 0),
          (x: 3, y: 1),
          (x: 0, y: 5),
        ]);
      },
    );

    test('вне переданных клеток — прозрачно', () async {
      final part = RoninParts.byId('bridge_c');
      final img = await _raster(
        320,
        320,
        (g) => paintPartCells(
          g,
          art,
          part,
          const [(x: 4, y: 0), (x: 5, y: 0)],
          origin: Offset.zero,
          cellSize: 32,
        ),
      );
      expect(await _alpha(img, 4 * 32 + 16, 16), 255);
      expect(await _alpha(img, 6 * 32 + 16, 16), 0); // соседняя клетка маски
      expect(await _alpha(img, 3 * 32 + 16, 16), 0);
      expect(await _alpha(img, 4 * 32 + 16, 32 + 16), 0);
      img.dispose();
    });

    test('origin сдвигает клетки: (0, 0) маски ложится в origin', () async {
      final part = RoninParts.byId('bridge_c');
      final img = await _raster(
        320,
        320,
        (g) => paintPartCells(
          g,
          art,
          part,
          const [(x: 0, y: 2)],
          origin: const Offset(64, 32),
          cellSize: 32,
        ),
      );
      expect(await _alpha(img, 64 + 16, 32 + 2 * 32 + 16), 255);
      expect(await _alpha(img, 16, 2 * 32 + 16), 0); // без сдвига было бы тут
      img.dispose();
    });

    test('пустой список — пустой растр', () async {
      final part = RoninParts.byId('sensor');
      final img = await _raster(
        64,
        64,
        (g) => paintPartCells(
          g,
          art,
          part,
          const <({int x, int y})>[],
          origin: Offset.zero,
          cellSize: 32,
        ),
      );
      final data = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
      expect(data.buffer.asUint8List().every((b) => b == 0), isTrue);
      img.dispose();
    });
  });

  group('partCellColors — вид и цвет клетки (D-017)', () {
    testWidgets('плита prow: основа без краски — шеврон (7, 2) того же цвета '
        'плиты, что (0, 3), обе тёмные; кеш — тот же объект', (tester) async {
      final prow = RoninParts.byId('prow');
      await tester.runAsync(() async {
        final colors = await partCellColors(art, prow);
        expect(colors.width, prow.mask.width);
        expect(colors.height, prow.mask.height);

        // (0, 3) — левый-нижний угол носа, краски нет.
        final plain = colors.colorAt(0, 3);
        final ref = await _fieldRef(
          art,
          prow,
          art.fieldLayer(ShipFieldLayer.hullBase),
          8,
        );
        final p = await _rgba(ref, 4, 3 * 8 + 4);
        ref.dispose();
        for (final (got, want) in [
          (plain.r, p[0]),
          (plain.g, p[1]),
          (plain.b, p[2]),
        ]) {
          expect((got * 255 - want).abs(), lessThanOrEqualTo(4));
        }
        // (7, 2) — шеврон: краска рисуется поверх, в основе её нет.
        final chevron = colors.colorAt(7, 2);
        expect(colors.kindAt(7, 2), PartCellKind.base);
        expect((_lum(chevron) - _lum(plain)).abs(), lessThan(.03));
        expect(colors.isDark(0, 3), isTrue, reason: 'нос — DARK: $plain');
        expect(colors.isDark(7, 2), isTrue, reason: '$chevron');

        expect(identical(await partCellColors(art, prow), colors), isTrue);
      });
    });

    /// Клетки детали [id] вида [kind] — множество `(c, r)`.
    Future<Set<(int, int)>> cellsOf(String id, PartCellKind kind) async {
      final part = RoninParts.byId(id);
      final colors = await partCellColors(art, part);
      return {
        for (final f in part.mask.cells)
          if (colors.kindAt(f.x, f.y) == kind) (f.x, f.y),
      };
    }

    testWidgets('световые клетки — ровно как в критерии; цвет светлый, у щелей '
        'голубой', (tester) async {
      await tester.runAsync(() async {
        const want = {
          'fwd1_l': {(4, 6), (5, 6), (6, 6)},
          'fwd1_r': {(2, 6), (3, 6), (4, 6)},
          'sensor': {(3, 0), (3, 1), (2, 3), (3, 3), (4, 3)},
          'visor_l': {
            (1, 1), (2, 1), (3, 1), (4, 1), //
            (6, 1), (7, 1), (8, 1), (9, 1),
          },
          'visor_r': {
            (1, 1), (2, 1), (3, 1), (4, 1), //
            (6, 1), (7, 1), (8, 1),
          },
        };
        for (final part in RoninParts.parts) {
          final got = await cellsOf(part.id, PartCellKind.light);
          expect(got, want[part.id] ?? const <(int, int)>{}, reason: part.id);
          final colors = await partCellColors(art, part);
          for (final (c, r) in got) {
            final k = colors.colorAt(c, r);
            expect(_lum(k), greaterThan(.6), reason: '${part.id} ($c, $r) $k');
            if (part.id.startsWith('fwd1_')) {
              expect(k.b, greaterThan(k.r), reason: 'щель ${part.id} ($c, $r)');
            }
          }
        }
      });
    });

    testWidgets('цветные клетки: hatch_l, hatch_r — ряд 0 целиком, оранжевые; '
        'у остальных деталей нет', (tester) async {
      await tester.runAsync(() async {
        final row0 = {for (var c = 0; c < 7; c++) (c, 0)};
        for (final part in RoninParts.parts) {
          final got = await cellsOf(part.id, PartCellKind.accent);
          final hatch = part.id == 'hatch_l' || part.id == 'hatch_r';
          expect(got, hatch ? row0 : const <(int, int)>{}, reason: part.id);
          final colors = await partCellColors(art, part);
          for (final (c, r) in got) {
            final k = colors.colorAt(c, r);
            expect(k.r > k.g && k.g > k.b, isTrue, reason: '${part.id} $k');
          }
        }
      });
    });

    testWidgets('prow, bridge_c, fwd1_cl, fwd2_l — только основа', (
      tester,
    ) async {
      await tester.runAsync(() async {
        for (final id in const ['prow', 'bridge_c', 'fwd1_cl', 'fwd2_l']) {
          final part = RoninParts.byId(id);
          expect(await cellsOf(id, PartCellKind.base), {
            for (final f in part.mask.cells) (f.x, f.y),
          }, reason: id);
        }
      });
    });

    testWidgets('основа sensor (1, 4), (5, 4) и hatch_l (6, 1), (6, 5) — не '
        'почти чёрная (яркость > 0,05; обводка и тень не берутся)', (
      tester,
    ) async {
      await tester.runAsync(() async {
        for (final (id, c, r) in const [
          ('sensor', 1, 4),
          ('sensor', 5, 4),
          ('hatch_l', 6, 1),
          ('hatch_l', 6, 5),
        ]) {
          final colors = await partCellColors(art, RoninParts.byId(id));
          final k = colors.colorAt(c, r);
          expect(_lum(k), greaterThan(.05), reason: '$id ($c, $r) $k');
        }
      });
    });

    testWidgets('предмет visor_l: стекло среднего ряда светлое, рама тёмная', (
      tester,
    ) async {
      final visor = RoninParts.byId('visor_l');
      await tester.runAsync(() async {
        final colors = await partCellColors(art, visor);
        expect(_lum(colors.colorAt(2, 1)), greaterThan(.5));
        expect(colors.isDark(2, 0), isTrue, reason: '${colors.colorAt(2, 0)}');
      });
    });
  });

  group('paintPartCells — клетка по D-017 (с colors)', () {
    const u = 34.0;

    testWidgets('краска поверх основы: prow (3, 2) — центр оранжевый, '
        'colorAt — тёмная основа носа', (tester) async {
      final prow = RoninParts.byId('prow');
      await tester.runAsync(() async {
        final colors = await partCellColors(art, prow);
        final img = await _raster(
          (prow.mask.width * u).ceil(),
          (prow.mask.height * u).ceil(),
          (g) => paintPartCells(
            g,
            art,
            prow,
            prow.mask.cells,
            origin: Offset.zero,
            cellSize: u,
            colors: colors,
          ),
        );
        final center = await _rgba(img, (3.5 * u).floor(), (2.5 * u).floor());
        img.dispose();
        expect(center[0], greaterThan(center[1] + 40), reason: '$center');
        expect(center[1], greaterThan(center[2]), reason: '$center');
        expect(colors.kindAt(3, 2), PartCellKind.base);
        expect(colors.isDark(3, 2), isTrue, reason: '${colors.colorAt(3, 2)}');
      });
    });

    testWidgets('ореол: низ соседа (4, 5) световой клетки fwd1_l (4, 6) '
        'светлее, чем без световых клеток', (tester) async {
      final part = RoninParts.byId('fwd1_l');
      await tester.runAsync(() async {
        final colors = await partCellColors(art, part);
        final w = (part.mask.width * u).ceil();
        final h = (part.mask.height * u).ceil();
        Future<ui.Image> field(Iterable<({int x, int y})> cells) => _raster(
          w,
          h,
          (g) => paintPartCells(
            g,
            art,
            part,
            cells,
            origin: Offset.zero,
            cellSize: u,
            colors: colors,
          ),
        );
        final all = await field(part.mask.cells);
        final dark = await field([
          for (final f in part.mask.cells)
            if (colors.kindAt(f.x, f.y) != PartCellKind.light) f,
        ]);
        final x = (4.5 * u).floor(), y = (6 * u).floor() - 3;
        final lit = await _rgba(all, x, y), plain = await _rgba(dark, x, y);
        all.dispose();
        dark.dispose();
        expect(_sum(lit), greaterThan(_sum(plain) + 30), reason: '$lit $plain');
      });
    });

    testWidgets('paintPartCell световой клетки — ореол до неё, за пределами '
        'клетки', (tester) async {
      final part = RoninParts.byId('fwd1_l');
      await tester.runAsync(() async {
        final colors = await partCellColors(art, part);
        final img = await _raster(
          (part.mask.width * u).ceil(),
          (part.mask.height * u).ceil(),
          (g) => paintPartCell(
            g,
            art,
            part,
            4,
            6,
            const Rect.fromLTWH(4 * u, 6 * u, u, u),
            colors: colors,
          ),
        );
        final above = await _rgba(img, (4.5 * u).floor(), (6 * u).floor() - 3);
        final center = await _rgba(img, (4.5 * u).floor(), (6.5 * u).floor());
        img.dispose();
        expect(above[3], greaterThan(0), reason: 'ореол над клеткой: $above');
        expect(_lum(colors.colorAt(4, 6)), greaterThan(.6));
        expect(center[2], greaterThan(center[0]), reason: 'щель: $center');
      });
    });
  });

  group('paintPartCells — плитка в сборке и деталь целиком (D-016)', () {
    const u = 34.0;
    final part = RoninParts.byId('fwd1_cl');
    final w = part.mask.width * 34, h = part.mask.height * 34;

    Future<ui.Image> field({required bool assembled}) => _raster(
      w,
      h,
      (g) => paintPartCells(
        g,
        art,
        part,
        part.mask.cells,
        origin: Offset.zero,
        cellSize: u,
        assembled: assembled,
      ),
    );

    test('сборка: центр клетки = fieldBuildPicture, угол прозрачен, '
        'заклёпка темнее центра', () async {
      final img = await field(assembled: false);
      final ref = await _fieldRef(art, part, art.fieldBuildPicture, u);
      // клетка (3, 3): x, y 102..136
      final center = await _rgba(img, 119, 119);
      final want = await _rgba(ref, 119, 119);
      for (var k = 0; k < 4; k++) {
        expect((center[k] - want[k]).abs(), lessThanOrEqualTo(2));
      }
      expect(await _alpha(img, 102, 102), 0, reason: 'угол вне скругления');
      // заклёпка: внутренний прямоугольник с 103, центр в 103 + 4
      final rivet = await _rgba(img, 106, 106);
      expect(_sum(rivet), lessThan(_sum(center) - 20));
      img.dispose();
      ref.dispose();
    });

    test('собрано: центр = fieldDonePicture, граница клеток внутри детали не '
        'темнее центра, внешний край темнее', () async {
      final img = await field(assembled: true);
      final ref = await _fieldRef(art, part, art.fieldDonePicture, u);
      final center = await _rgba(img, 119, 119);
      final want = await _rgba(ref, 119, 119);
      for (var k = 0; k < 4; k++) {
        expect((center[k] - want[k]).abs(), lessThanOrEqualTo(2));
      }
      // граница (3, 3) | (4, 3): столбец 136
      for (final x in const [135, 136]) {
        final border = await _rgba(img, x, 119);
        expect(_sum(border), greaterThanOrEqualTo(_sum(center) - 6));
        expect(border[3], 255);
      }
      // (4, 0): сверху соседа в маске нет — кромка
      final edge = await _rgba(img, 153, 0);
      final mid = await _rgba(img, 153, 17);
      expect(_sum(edge), lessThan(_sum(mid) - 30));
      img.dispose();
      ref.dispose();
    });

    test(
      'paintPartCell в обеих фазах = paintPartCells для одной клетки',
      () async {
        for (final assembled in const [false, true]) {
          final one = await _raster(
            w,
            h,
            (g) => paintPartCells(
              g,
              art,
              part,
              const [(x: 4, y: 0)],
              origin: Offset.zero,
              cellSize: u,
              assembled: assembled,
            ),
          );
          final single = await _raster(
            w,
            h,
            (g) => paintPartCell(
              g,
              art,
              part,
              4,
              0,
              const Rect.fromLTWH(4 * u, 0, u, u),
              assembled: assembled,
            ),
          );
          for (final (x, y) in const [
            (153, 0),
            (153, 17),
            (137, 1),
            (168, 33),
          ]) {
            final a = await _rgba(one, x, y), b = await _rgba(single, x, y);
            for (var k = 0; k < 4; k++) {
              expect(
                (a[k] - b[k]).abs(),
                lessThanOrEqualTo(2),
                reason: '$assembled ($x, $y)',
              );
            }
          }
          one.dispose();
          single.dispose();
        }
      },
    );
  });
}
