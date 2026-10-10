import 'dart:ui' as ui;

import 'package:explosive_tetris/game_engine/data/ronin_parts.dart';
import 'package:explosive_tetris/presentation/ship_render/ronin_art.dart';
import 'package:explosive_tetris/presentation/ship_render/ship_art.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

// Эталон: node по ship-render.js (mulberry32(20260712), первые 20 значений).
const _refRnd = <double>[
  0.42405920871533453,
  0.4856667504645884,
  0.1698424646165222,
  0.43967699771746993,
  0.8503685537725687,
  0.5954533459153026,
  0.23462690645828843,
  0.18724020151421428,
  0.3547839354723692,
  0.9650827411096543,
  0.6423449292778969,
  0.7916828063316643,
  0.6603536605834961,
  0.7291205828078091,
  0.49089057208038867,
  0.2222853833809495,
  0.7336347422096878,
  0.8109176058787853,
  0.77409936953336,
  0.8979926959145814,
];

// Эталон: нарезка plates из ship-render.js — (x, y, w, h, kind, i, jl, rv).
const _refPlates = <(int, int, int, int, String, int, double, double)>[
  (5, 0, 3, 2, 'prow', 0, -2.3111027476843446, 0.43967699771746993),
  (8, 0, 2, 2, 'prow', 1, 0.6681734214071184, 0.23462690645828843),
  (4, 2, 3, 2, 'bridge', 0, 3.25557918776758, 0.6423449292778969),
  (7, 2, 4, 2, 'bridge', 1, 1.1224756240844727, 0.7291205828078091),
  (3, 4, 2, 2, 'fwd', 0, 1.6354431954678148, 0.8109176058787853),
  (5, 4, 4, 2, 'fwd', 1, 2.78594887140207, 0.6436525650788099),
  (9, 4, 3, 2, 'fwd', 2, 0.5769713730551302, 0.7551760526839644),
  (3, 6, 2, 2, 'fwd', 0, 2.8954123915173113, 0.7693037015851587),
  (5, 6, 2, 2, 'fwd', 1, -0.11577704828232527, 0.6715390775352716),
  (7, 6, 3, 2, 'fwd', 2, 0.6254598279483616, 0.6490277533885092),
  (10, 6, 2, 2, 'fwd', 3, 3.0277280346490443, 0.9745984557084739),
  (3, 8, 4, 2, 'bandA', 0, 1.0866217487491667, 0.4053178681060672),
  (7, 8, 3, 2, 'bandA', 1, 0.7448608095292002, 0.28078370564617217),
  (10, 8, 2, 2, 'bandA', 2, 0.21274806302972138, 0.04955439758487046),
  (3, 10, 4, 1, 'bandA', 0, -0.6171318588312715, 0.6334119949024171),
  (7, 10, 5, 1, 'bandA', 1, 2.891519207973033, 0.1870826466474682),
  (3, 11, 4, 2, 'bandA', 0, -1.7950487069319934, 0.08404277125373483),
  (7, 11, 3, 2, 'bandA', 1, 1.9016988836228848, 0.47782273893244565),
  (10, 11, 2, 2, 'bandA', 2, -0.7718937294557691, 0.40023059654049575),
  (3, 13, 3, 2, 'mid', 0, 2.955578829161823, 0.2542190938256681),
  (6, 13, 4, 2, 'mid', 1, -3.0491830301471055, 0.8746666873339564),
  (10, 13, 2, 2, 'mid', 2, 2.4169296137988567, 0.03618431370705366),
  (3, 15, 3, 2, 'mid', 0, -0.21934006456285715, 0.738804389256984),
  (6, 15, 4, 2, 'mid', 1, -2.8057167856022716, 0.023823548341169953),
  (10, 15, 2, 2, 'mid', 2, -0.865172330988571, 0.410682565998286),
  (3, 17, 2, 1, 'mid', 0, 1.388129560276866, 0.012702524429187179),
  (5, 17, 3, 1, 'mid', 1, -2.6592916052322835, 0.8199258397798985),
  (8, 17, 4, 1, 'mid', 2, -0.1905081879813224, 0.5331257306970656),
  (3, 18, 3, 2, 'bandB', 0, 1.779716420918703, 0.6394742864649743),
  (6, 18, 6, 2, 'bandB', 1, -2.154364669928327, 0.7735826887656003),
  (3, 20, 4, 1, 'bandB', 0, 1.9733016074169427, 0.5999940352048725),
  (7, 20, 5, 1, 'bandB', 1, -0.7145182464737445, 0.7500222399830818),
  (4, 21, 2, 2, 'eng', 0, 2.199922418454662, 0.367015645140782),
  (6, 21, 5, 2, 'eng', 1, -2.3292647225316614, 0.7016383316367865),
  (4, 23, 2, 2, 'eng', 0, 1.8712800957728177, 0.21072914428077638),
  (6, 23, 2, 2, 'eng', 1, 1.409507793141529, 0.010774780996143818),
  (8, 23, 3, 2, 'eng', 2, 2.7762005743570626, 0.9620606354437768),
  (5, 25, 2, 2, 'skirt', 0, -2.138341448502615, 0.38806168478913605),
  (7, 25, 3, 2, 'skirt', 1, 0.04200753988698125, 0.9139832486398518),
];

/// Сцена [picture] в уменьшенном масштабе → растр (рисунок целиком проходит
/// через растеризатор, размер маленький).
Future<ui.Image> _rasterize(ui.Picture picture, Size scene, double k) {
  final rec = ui.PictureRecorder();
  Canvas(rec)
    ..scale(k)
    ..drawPicture(picture);
  return rec.endRecording().toImage(
    (scene.width * k).ceil(),
    (scene.height * k).ceil(),
  );
}

/// Пиксель сцены [picture] в точке [at] (px рисунка) в масштабе 1:1 —
/// `(r, g, b, a)`; сетка пикселей совпадает с сеткой сцены.
Future<(int, int, int, int)> _pixel(ui.Picture picture, Offset at) async {
  final rec = ui.PictureRecorder();
  Canvas(rec)
    ..translate(-at.dx.floorToDouble(), -at.dy.floorToDouble())
    ..drawPicture(picture);
  final img = await rec.endRecording().toImage(1, 1);
  final d = (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  img.dispose();
  return (d.getUint8(0), d.getUint8(1), d.getUint8(2), d.getUint8(3));
}

/// Каналы RGB [a] и [b] различаются не больше чем на [tol].
bool _near((int, int, int, int) a, (int, int, int, int) b, int tol) =>
    (a.$1 - b.$1).abs() <= tol &&
    (a.$2 - b.$2).abs() <= tol &&
    (a.$3 - b.$3).abs() <= tol;

/// Яркость пикселя 0..1 (относительная, как `Color.computeLuminance`).
double _lum((int, int, int, int) p) =>
    Color.fromARGB(255, p.$1, p.$2, p.$3).computeLuminance();

/// Сумма каналов RGB — грубая светлота для сравнения «темнее».
int _sum((int, int, int, int) p) => p.$1 + p.$2 + p.$3;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('mulberry32', () {
    test('seed 20260712 — первые 20 значений совпадают с JS', () {
      final rnd = mulberry32(20260712);
      for (var i = 0; i < _refRnd.length; i++) {
        expect(rnd(), _refRnd[i], reason: 'значение #$i');
      }
    });
  });

  group('plates', () {
    final plates = RoninArt.plates;

    test('число плит совпадает с эталоном', () {
      expect(plates.length, _refPlates.length);
      expect(plates.length, 39);
    });

    test('полный список (x, y, w, h, kind) совпадает с эталоном', () {
      for (var k = 0; k < _refPlates.length; k++) {
        final p = plates[k];
        final (x, y, w, h, kind, _, _, _) = _refPlates[k];
        expect(
          (p.x, p.y, p.w, p.h, p.kind),
          (x, y, w, h, kind),
          reason: 'плита #$k',
        );
      }
    });

    test('номер в ряду, jl и rv — тот же порядок вызовов rnd()', () {
      for (var k = 0; k < _refPlates.length; k++) {
        final p = plates[k];
        final (_, _, _, _, _, i, jl, rv) = _refPlates[k];
        expect((p.i, p.jl, p.rv), (i, jl, rv), reason: 'плита #$k');
      }
    });

    test('первые и последние 5 плит', () {
      String fmt(RoninPlate p) => '${p.x},${p.y},${p.w},${p.h},${p.kind}';
      expect(plates.take(5).map(fmt).toList(), [
        '5,0,3,2,prow',
        '8,0,2,2,prow',
        '4,2,3,2,bridge',
        '7,2,4,2,bridge',
        '3,4,2,2,fwd',
      ]);
      expect(plates.skip(plates.length - 5).map(fmt).toList(), [
        '4,23,2,2,eng',
        '6,23,2,2,eng',
        '8,23,3,2,eng',
        '5,25,2,2,skirt',
        '7,25,3,2,skirt',
      ]);
    });

    test(
      'плиты тилят корпус: каждая клетка силуэта покрыта ровно одной плитой',
      () {
        final cover = <(int, int), int>{};
        for (final p in plates) {
          for (var y = p.y; y < p.y + p.h; y++) {
            for (var x = p.x; x < p.x + p.w; x++) {
              cover[(x, y)] = (cover[(x, y)] ?? 0) + 1;
            }
          }
        }
        var cells = 0;
        for (var y = 0; y < RoninArt.rows; y++) {
          for (var x = RoninArt.span[y][0]; x <= RoninArt.span[y][1]; x++) {
            expect(cover[(x, y)], 1, reason: 'клетка ($x, $y)');
            cells++;
          }
        }
        expect(cover.length, cells);
      },
    );
  });

  group('RoninArt', () {
    final ShipArt art = RoninArt();
    const c = RoninArt.cellPx;

    test('сцена и система координат как в ship-render.js', () {
      expect(art.sceneSize, const Size(23 * c, 38.6 * c));
      expect(art.toScene(0, 0), const Offset(4 * c, 1.9 * c));
      expect(art.toScene(7.5, 2), Offset(4 * c + 7.5 * c, 1.9 * c + 2 * c));
    });

    test(
      'слои записываются и растеризуются без исключений, картинка кешируется',
      () async {
        expect(identical(art.hullPicture, art.hullPicture), isTrue);
        expect(identical(art.objectsPicture, art.objectsPicture), isTrue);
        final hull = await _rasterize(art.hullPicture, art.sceneSize, .1);
        final objects = await _rasterize(art.objectsPicture, art.sceneSize, .1);
        expect(hull.width, greaterThan(0));
        expect(objects.height, greaterThan(0));

        // альфа пикселя сцены (x, y в px рисунка) на растре масштаба .1
        Future<int> alpha(ui.Image img, Offset at) async {
          final data = (await img.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!;
          final i =
              ((at.dy * .1).floor() * img.width + (at.dx * .1).floor()) * 4;
          return data.getUint8(i + 3);
        }

        // корпус непрозрачен внутри силуэта и пуст вне его; предметы — только предметы
        expect(await alpha(hull, art.toScene(7.5, 12)), 255);
        expect(await alpha(hull, const Offset(5, 5)), 0);
        expect(await alpha(objects, art.toScene(7.5, -.25)), greaterThan(0));
        expect(await alpha(objects, art.toScene(7.5, 12)), 0);
        hull.dispose();
        objects.dispose();
      },
    );

    test('outline — корпус px(3)..px(12) с гондолами по бортам', () {
      final b = art.outline.getBounds();
      const bw = 1.06 * c;
      expect(b.left, closeTo(RoninArt.px(3) - bw + 2, 1e-3));
      expect(b.right, closeTo(RoninArt.px(12) - 2 + bw, 1e-3));
      expect(b.top, closeTo(RoninArt.py(0), 1e-3));
      expect(b.bottom, closeTo(RoninArt.py(27), 1e-3));
      // корпус внутри, гондола снаружи корпуса — тоже внутри контура
      expect(art.outline.contains(art.toScene(7.5, 13)), isTrue);
      expect(
        art.outline.contains(Offset(RoninArt.px(3) - bw / 2, RoninArt.py(15))),
        isTrue,
      );
    });

    test(
      'objectShape: RCS вокруг своей точки, датчик над носом, чужой id — ArgumentError',
      () {
        expect(art.objectShape('rcs_fl').contains(art.toScene(3, 4.5)), isTrue);
        expect(
          art.objectShape('rcs_fr').contains(art.toScene(12, 4.5)),
          isTrue,
        );
        expect(
          art.objectShape('rcs_fl').contains(art.toScene(12, 4.5)),
          isFalse,
        );
        // боковое сопло наружу: rcs_fl — влево, rcs_fr — вправо
        expect(
          art.objectShape('rcs_fl').contains(art.toScene(2.55, 4.5)),
          isTrue,
        );
        expect(
          art.objectShape('rcs_fr').contains(art.toScene(12.45, 4.5)),
          isTrue,
        );
        final sensor = art.objectShape('sensor');
        expect(sensor.contains(art.toScene(7.5, -.25)), isTrue);
        expect(sensor.contains(art.toScene(7.5, -1.06)), isTrue);
        expect(sensor.contains(art.toScene(7.5, .5)), isFalse);
        expect(() => art.objectShape('nope'), throwsArgumentError);
      },
    );

    test('objectShape v3: визор половинами и торпедные люки', () {
      final vl = art.objectShape('visor_l'), vr = art.objectShape('visor_r');
      expect(vl.contains(art.toScene(5.5, 2.9)), isTrue);
      expect(vl.contains(art.toScene(8.5, 2.9)), isFalse);
      expect(vr.contains(art.toScene(8.5, 2.9)), isTrue);
      expect(vr.contains(art.toScene(5.5, 2.9)), isFalse);
      final hl = art.objectShape('hatch_l'), hr = art.objectShape('hatch_r');
      expect(hr.contains(art.toScene(8.9, 6.2)), isTrue);
      expect(hr.contains(art.toScene(6.1, 6.2)), isFalse);
      expect(hl.contains(art.toScene(6.1, 6.2)), isTrue);
      expect(hl.contains(art.toScene(8.9, 6.2)), isFalse);
    });

    test(
      'поле: fieldBuildPicture и fieldDonePicture записываются и кешируются',
      () {
        expect(identical(art.fieldBuildPicture, art.fieldBuildPicture), isTrue);
        expect(identical(art.fieldDonePicture, art.fieldDonePicture), isTrue);
        expect(identical(art.fieldBuildPicture, art.hullPicture), isFalse);
      },
    );

    test('roninObjects — семь предметов «Ронина-1» v3', () {
      expect(roninObjects.keys.toSet(), {
        'sensor',
        'rcs_fl',
        'rcs_fr',
        'visor_l',
        'visor_r',
        'hatch_l',
        'hatch_r',
      });
    });
  });

  group('рисунок v3 (D-016)', () {
    final ShipArt art = RoninArt();

    Offset cellCenter(String id, int c, int r) {
      final cell = RoninParts.byId(id).cellOnShip(c, r);
      return art.toScene(cell.x + cell.size / 2, cell.y + cell.size / 2);
    }

    test(
      'плита по детали: клетки (3, 3) и (4, 3) fwd1_cl одного цвета — нет чужого шва',
      () async {
        final a = await _pixel(art.hullPicture, cellCenter('fwd1_cl', 3, 3));
        final b = await _pixel(art.hullPicture, cellCenter('fwd1_cl', 4, 3));
        expect(_near(a, b, 3), isTrue, reason: '$a vs $b');
      },
    );

    test(
      'визор — предмет: в корпусе под ним плита мостика, в слое 1 — непрозрачен',
      () async {
        final at = art.toScene(5.2, 2.9);
        // та же колонка той же плиты bridge_l выше визора v2 — эталон цвета плиты
        final plate = await _pixel(art.hullPicture, art.toScene(5.2, 2.5));
        final hull = await _pixel(art.hullPicture, at);
        expect(_near(hull, plate, 3), isTrue, reason: '$hull vs $plate');
        expect((await _pixel(art.objectsPicture, at)).$4, 255);
      },
    );

    test(
      'торпедный люк — предмет: в корпусе под ним плита пояса, в слое 1 непрозрачен',
      () async {
        final at = art.toScene(5.9, 6.25);
        // та же колонка той же плиты fwd2_cl ниже люка
        final plate = await _pixel(art.hullPicture, art.toScene(5.9, 6.75));
        final hull = await _pixel(art.hullPicture, at);
        expect(_near(hull, plate, 3), isTrue, reason: '$hull vs $plate');
        expect((await _pixel(art.objectsPicture, at)).$4, 255);
      },
    );

    test(
      'щель-огонь: в fieldDonePicture светлая, в fieldBuildPicture — цвет плиты',
      () async {
        final at = art.toScene(4.4, 5.53);
        expect(_lum(await _pixel(art.fieldDonePicture, at)), greaterThan(.6));
        expect(_lum(await _pixel(art.hullPicture, at)), greaterThan(.6));
        // та же колонка той же плиты fwd1_l выше щели
        final plate = await _pixel(
          art.fieldBuildPicture,
          art.toScene(4.4, 5.2),
        );
        final build = await _pixel(art.fieldBuildPicture, at);
        expect(_near(build, plate, 3), isTrue, reason: '$build vs $plate');
      },
    );

    test(
      'кромка детали: граница fwd1_cl | fwd1_cr темнее центра клетки в hullPicture, '
      'в поле — нет',
      () async {
        // ряд 0 пояса: fwd1_cl до колонки секции 17, fwd1_cr с 18 (x = 7.5)
        final center = cellCenter('fwd1_cl', 8, 0);
        final edge = Offset(art.toScene(7.5, 0).dx - .5, center.dy);
        for (final (name, pic, hasEdge) in [
          ('hull', art.hullPicture, true),
          ('fieldBuild', art.fieldBuildPicture, false),
          ('fieldDone', art.fieldDonePicture, false),
        ]) {
          final e = await _pixel(pic, edge), m = await _pixel(pic, center);
          if (hasEdge) {
            expect(_sum(e), lessThan(_sum(m) - 24), reason: '$name: $e vs $m');
          } else {
            expect(_near(e, m, 4), isTrue, reason: '$name: $e vs $m');
          }
        }
      },
    );

    test(
      'слой 1 без повтора контура корпуса (предметы лежат поверх него)',
      () async {
        expect((await _pixel(art.objectsPicture, art.toScene(3, 12))).$4, 0);
        expect((await _pixel(art.hullPicture, art.toScene(3, 12))).$4, 255);
      },
    );
  });

  group('слои рисунка поля (D-017)', () {
    final ShipArt art = RoninArt();
    const c = RoninArt.cellPx;

    // оранжевый почти непрозрачный (краска и полоса — альфа .95 и .85):
    // R заметно больше G, G больше B
    bool orange((int, int, int, int) p) =>
        p.$4 > 200 && p.$1 > 150 && p.$1 > p.$2 + 40 && p.$2 > p.$3;

    test('fieldLayer кешируется по слою, слои различаются', () {
      for (final l in ShipFieldLayer.values) {
        expect(
          identical(art.fieldLayer(l), art.fieldLayer(l)),
          isTrue,
          reason: '$l',
        );
      }
      expect(
        identical(
          art.fieldLayer(ShipFieldLayer.hullBase),
          art.fieldLayer(ShipFieldLayer.hullLights),
        ),
        isFalse,
      );
    });

    test(
      'щель-огонь: светлая только в hullLights, в hullBase и hullAccents — цвет плиты',
      () async {
        final at = art.toScene(4.4, 5.53);
        final plate = await _pixel(
          art.fieldLayer(ShipFieldLayer.hullBase),
          art.toScene(4.4, 5.2),
        );
        expect(
          _lum(await _pixel(art.fieldLayer(ShipFieldLayer.hullLights), at)),
          greaterThan(.6),
        );
        for (final l in [ShipFieldLayer.hullBase, ShipFieldLayer.hullAccents]) {
          final p = await _pixel(art.fieldLayer(l), at);
          expect(_near(p, plate, 3), isTrue, reason: '$l: $p vs $plate');
        }
      },
    );

    test(
      'шеврон: в paint оранжевый, в hullBase — плита носа; вне краски paint прозрачен',
      () async {
        final at = art.toScene(7.5, 1.5);
        expect(
          orange(await _pixel(art.fieldLayer(ShipFieldLayer.paint), at)),
          isTrue,
        );
        final base = await _pixel(art.fieldLayer(ShipFieldLayer.hullBase), at);
        final plate = await _pixel(
          art.fieldLayer(ShipFieldLayer.hullBase),
          art.toScene(7.5, 1.1),
        );
        expect(_near(base, plate, 3), isTrue, reason: '$base vs $plate');
        expect(orange(base), isFalse);
        expect(
          (await _pixel(
            art.fieldLayer(ShipFieldLayer.paint),
            art.toScene(5.5, 3.5),
          )).$4,
          0,
        );
      },
    );

    test('полоса люка: оранжевая только в objectsAccents', () async {
      final at = Offset(RoninArt.cx - 1.45 * c, RoninArt.py(5.95) - 1.6);
      expect(
        orange(await _pixel(art.fieldLayer(ShipFieldLayer.objectsAccents), at)),
        isTrue,
      );
      for (final l in [
        ShipFieldLayer.objectsBase,
        ShipFieldLayer.objectsLights,
      ]) {
        final p = await _pixel(art.fieldLayer(l), at);
        expect(orange(p), isFalse, reason: '$l: $p');
      }
    });

    test(
      'стекло визора: светлое только в objectsLights, в objectsBase — тёмная рама',
      () async {
        final at = art.toScene(5.5, 2.9);
        expect(
          _lum(await _pixel(art.fieldLayer(ShipFieldLayer.objectsLights), at)),
          greaterThan(.6),
        );
        final base = await _pixel(
          art.fieldLayer(ShipFieldLayer.objectsBase),
          at,
        );
        expect(base.$4, 255);
        expect(_lum(base), lessThan(.1), reason: '$base');
        final accents = await _pixel(
          art.fieldLayer(ShipFieldLayer.objectsAccents),
          at,
        );
        expect(_near(accents, base, 3), isTrue, reason: '$accents vs $base');
      },
    );

    test(
      'огонёк датчика: яркий в objectsLights, в objectsBase — нет',
      () async {
        final at = art.toScene(7.5, -1.06);
        expect(
          _lum(await _pixel(art.fieldLayer(ShipFieldLayer.objectsLights), at)),
          greaterThan(.8),
        );
        final base = await _pixel(
          art.fieldLayer(ShipFieldLayer.objectsBase),
          at,
        );
        expect(_lum(base), lessThan(.5), reason: '$base');
      },
    );

    test(
      'hullPicture и objectsPicture — рисунок целиком (краска, цвет, свет на месте)',
      () async {
        expect(
          orange(await _pixel(art.hullPicture, art.toScene(7.5, 1.5))),
          isTrue,
        );
        expect(
          _lum(await _pixel(art.hullPicture, art.toScene(4.4, 5.53))),
          greaterThan(.6),
        );
        expect(
          orange(
            await _pixel(
              art.objectsPicture,
              Offset(RoninArt.cx - 1.45 * c, RoninArt.py(5.95) - 1.6),
            ),
          ),
          isTrue,
        );
        expect(
          _lum(await _pixel(art.objectsPicture, art.toScene(5.5, 2.9))),
          greaterThan(.6),
        );
        expect(
          _lum(await _pixel(art.objectsPicture, art.toScene(7.5, -1.06))),
          greaterThan(.8),
        );
      },
    );
  });
}
