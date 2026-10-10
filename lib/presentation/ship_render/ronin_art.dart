import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../game_engine/data/ronin_parts.dart';
import '../../game_engine/models/target_mask.dart';
import 'ship_art.dart';

/// Параметры формы предмета слоя 1 (канон — поле `object` в
/// `docs/design/ronin-parts.js`; геометрия — `docs/design/ronin-objects.js`).
/// [x], [y] — центр в клетках рисунка (для `rcs`), [flip] — сторона: бокового
/// сопла у `rcs`, половина у `visor` (`half`), сторона люка у `hatch` (`side`);
/// `1` — вправо, `-1` — влево.
class ShipObject {
  final String kind;
  final double x, y;
  final int flip;
  const ShipObject(this.kind, {this.x = 0, this.y = 0, this.flip = 1});
}

/// Предметы «Ронина-1» по id детали (в `RoninPartDef` их параметров нет).
const Map<String, ShipObject> roninObjects = {
  'sensor': ShipObject('sensor'),
  'rcs_fr': ShipObject('rcs', x: 12, y: 4.5, flip: 1),
  'rcs_fl': ShipObject('rcs', x: 3, y: 4.5, flip: -1),
  'visor_l': ShipObject('visor', flip: -1),
  'visor_r': ShipObject('visor', flip: 1),
  'hatch_l': ShipObject('hatch', flip: -1),
  'hatch_r': ShipObject('hatch', flip: 1),
};

const int _m32 = 0xFFFFFFFF;

/// `Math.imul` JS: младшие 32 бита произведения (беззнаково). Делится на
/// 16-битные половины, чтобы не терять точность и на web-таргете.
int _imul(int a, int b) {
  final lo = (a & 0xFFFF) * b;
  final hi = ((a >> 16) * b) & 0xFFFF;
  return ((hi << 16) + lo) & _m32;
}

/// Детерминированный рандом `mulberry32` из `ship-render.js` — точная
/// эмуляция 32-битной арифметики JS (`|0`, `>>>`, `Math.imul`): та же
/// последовательность чисел в `[0, 1)` при том же [seed].
double Function() mulberry32(int seed) {
  var a = seed & _m32;
  return () {
    a = (a + 0x6D2B79F5) & _m32;
    var t = _imul(a ^ (a >> 15), 1 | a);
    t = ((t + _imul(t ^ (t >> 7), 61 | t)) & _m32) ^ t;
    return ((t ^ (t >> 14)) & _m32) / 4294967296;
  };
}

/// Плита обшивки из нарезки эталона: место и размер в клетках рисунка, пояс,
/// номер в ряду, сдвиг светлоты [jl] и случайное [rv] выбора материала.
class RoninPlate {
  final int x, y, w, h;
  final String kind;
  final int i;
  final double jl, rv;
  const RoninPlate(
    this.x,
    this.y,
    this.w,
    this.h,
    this.kind,
    this.i,
    this.jl,
    this.rv,
  );
}

class _Band {
  final int r0, r1;
  final String kind;
  const _Band(this.r0, this.r1, this.kind);
}

/// Материал `[h, s, l]` эталона.
class _Mat {
  final double h, s, l;
  const _Mat(this.h, this.s, this.l);
}

/// Плита «Ронина-1» v3 = плита-деталь `RoninParts` (`partPlates` эталона):
/// материал секции [m], сдвиг светлоты [jl], сторона клетки [cs] (px рисунка),
/// маска (соседство клеток для кромок) и клетки маски `(c, r, x, y)` с
/// левым-верхом в px рисунка.
class _PartPlate {
  final _Mat m;
  final double jl, cs;
  final TargetMask mask;
  final List<(int, int, double, double)> cells;
  const _PartPlate(this.m, this.jl, this.cs, this.mask, this.cells);

  bool on(int c, int r) => mask.contains(c, r);
}

const _graf = _Mat(215, 9, 31);
const _graf2 = _Mat(215, 9, 26);
const _dark = _Mat(216, 11, 17);
const _oran = _Mat(23, 62, 46);
const _rust = _Mat(19, 58, 38);
const _gun = _Mat(220, 10, 22);
const _blackm = _Mat(220, 12, 13);

/// `hsl(m, dl, da)` эталона: светлота клампится в `[3, 92]`.
Color _hsl(_Mat m, [double dl = 0, double da = 1]) => HSLColor.fromAHSL(
  da,
  m.h,
  m.s / 100,
  (m.l + dl).clamp(3, 92) / 100,
).toColor();

Color _rgba(int r, int g, int b, double a) => Color.fromRGBO(r, g, b, a);

/// canvas `shadowBlur` не зависит от трансформа: эталон
/// (`ship_ronin_v4.html`) рисует offscreen в 2x, поэтому в px рисунка
/// σ = blur / 2 / 2.
double _sigma(double blur) => blur / 4;

/// Середина em-квадрата над алфавитной базовой линией (canvas
/// `textBaseline = 'middle'`) для `Arial Narrow Bold`, доля кегля
/// (нормированные OS/2 typo-метрики 1491/431, как в Chromium).
const double _middleAboveBaseline = 0.2757;

/// «Ронин» — порт `docs/design/ship-render.js` v3 (D-016) 1:1 по константам и
/// формулам в объёме эпика «Ронин-1»: корпус (строки 0..7 — плиты по деталям
/// `RoninParts`, строки 8+ — генератор плит; сетка, швы, светотень, графика
/// носа, щели-огни, контур) — слой 0; датчик-блок, визор, торпедные люки и
/// RCS-квады — слой 1.
class RoninArt implements ShipArt {
  RoninArt();

  /// Общий экземпляр на запуск: картинки слоёв записываются один раз (экран
  /// корабля и поле укладки рисуют из него).
  static final RoninArt shared = RoninArt();

  /// Клетка рисунка, px (`C`).
  static const double cellPx = 24;
  static const int gw = 15, gh = 30;
  static const double ox = 4 * cellPx, oy = 1.9 * cellPx;
  static const double width = (gw + 8) * cellPx, height = (gh + 8.6) * cellPx;

  /// Воксельные строки корпуса 0..rows-1.
  static const int rows = 27;

  /// Строки рисунка, размеченные деталями «Ронина-1» (`RONIN1_ROWS`): там
  /// плиты = плиты `RoninParts`, без сетки и потёков (v3, D-016).
  static const int ronin1Rows = 8;

  static double px(double x) => ox + x * cellPx;
  static double py(double y) => oy + y * cellPx;
  static final double cx = px(7.5);

  /// Силуэт: `[x0, x1]` колонок корпуса на строку 0..26.
  static final List<List<int>> span = List.unmodifiable([
    for (var y = 0; y < rows; y++)
      y <= 1
          ? const [5, 9]
          : y <= 3
          ? const [4, 10]
          : y <= 20
          ? const [3, 11]
          : y <= 24
          ? const [4, 10]
          : const [5, 9],
  ]);

  static const List<_Band> _bands = [
    _Band(0, 1, 'prow'),
    _Band(2, 3, 'bridge'),
    _Band(4, 7, 'fwd'),
    _Band(8, 12, 'bandA'),
    _Band(13, 17, 'mid'),
    _Band(18, 20, 'bandB'),
    _Band(21, 24, 'eng'),
    _Band(25, 26, 'skirt'),
  ];

  /// Нарезка корпуса на плиты — тем же циклом и порядком `rnd()`, что и в
  /// эталоне (`mulberry32(20260712)`).
  static final List<RoninPlate> plates = List.unmodifiable(_cutPlates());

  static List<RoninPlate> _cutPlates() {
    final rnd = mulberry32(20260712);
    final out = <RoninPlate>[];
    for (final b in _bands) {
      var y = b.r0;
      while (y <= b.r1) {
        final canPair =
            y + 1 <= b.r1 &&
            span[y][0] == span[y + 1][0] &&
            span[y][1] == span[y + 1][1];
        final ph = (canPair && rnd() < .8) ? 2 : 1;
        final x0 = span[y][0], x1 = span[y][1];
        final wide = b.kind == 'bandA' || b.kind == 'bandB';
        var x = x0, i = 0;
        while (x <= x1) {
          var pw = wide ? 3 + (rnd() * 3).floor() : 2 + (rnd() * 3).floor();
          if (x1 - x + 1 - pw == 1) pw++;
          pw = math.min(pw, x1 - x + 1);
          final jl = rnd() * 7 - 3.5;
          final rv = rnd();
          out.add(RoninPlate(x, y, pw, ph, b.kind, i++, jl, rv));
          x += pw;
        }
        y += ph;
      }
    }
    return out;
  }

  /// Материал плиты-детали по секции (`PLATE_MAT`).
  static const Map<String, _Mat> _partPlateMat = {
    'prow': _dark,
    'bridge': _graf2,
    'fwd': _graf,
  };

  /// Сдвиг светлоты плиты-детали по её индексу в списке плит (`PLATE_JL`).
  static const List<double> _partPlateJl = [
    -2,
    1.5,
    -1,
    2.5,
    0,
    -2.5,
    1,
    -1.5,
    3,
    -3,
    2,
    -.5,
  ];

  /// Плиты-детали (layer 0) в порядке `RoninParts.parts` (`partPlates`).
  static final List<_PartPlate> _partPlates = List.unmodifiable(
    _buildPartPlates(),
  );

  static List<_PartPlate> _buildPartPlates() {
    final out = <_PartPlate>[];
    for (final p in RoninParts.parts.where((p) => p.isPlate)) {
      final i = out.length;
      final cs = cellPx / p.scale;
      final x0 = px(p.shipX), y0 = py(p.shipY);
      out.add(
        _PartPlate(
          _partPlateMat[p.sectionId]!,
          _partPlateJl[i % _partPlateJl.length],
          cs,
          p.mask,
          [
            for (final q in p.mask.cells)
              (q.x, q.y, x0 + q.x * cs, y0 + q.y * cs),
          ],
        ),
      );
    }
    return out;
  }

  static _Mat _plateMat(RoninPlate p) {
    final inInset = p.x >= 6 && p.x + p.w <= 9 && p.y >= 9 && p.y + p.h <= 12;
    final inName = p.x <= 5 && p.y >= 8 && p.y < 13;
    switch (p.kind) {
      case 'prow':
        return _dark;
      case 'bridge':
        return _graf2;
      case 'fwd':
        return p.rv < .15 ? _dark : _graf;
      case 'bandA':
        return inInset
            ? _dark
            : (inName ? _oran : (p.rv < .16 ? _rust : _oran));
      case 'mid':
        return p.rv < .06
            ? _dark
            : (p.rv > .94 ? _oran : (p.rv < .72 ? _graf : _graf2));
      case 'bandB':
        return p.rv < .46 ? _oran : (p.rv < .56 ? _dark : _graf2);
      case 'eng':
        return p.rv < .3 ? _blackm : _gun;
      default: // skirt
        return _blackm;
    }
  }

  /// Контур корпуса — ступенчатый полигон (`hullPath`).
  static Path _hullPath() {
    final p = Path()..moveTo(px(span[0][0].toDouble()), py(0));
    for (var y = 0; y < rows; y++) {
      p
        ..lineTo(px(span[y][0].toDouble()), py(y.toDouble()))
        ..lineTo(px(span[y][0].toDouble()), py(y + 1.0));
    }
    p.lineTo(px(span[rows - 1][1] + 1.0), py(rows.toDouble()));
    for (var y = rows - 1; y >= 0; y--) {
      p
        ..lineTo(px(span[y][1] + 1.0), py(y + 1.0))
        ..lineTo(px(span[y][1] + 1.0), py(y.toDouble()));
    }
    return p..close();
  }

  // ---------- интерфейс ShipArt ----------

  @override
  Size get sceneSize => const Size(width, height);

  /// Середина градиента фона `ship-render.js` (`#05070d → #080b13`), без звёзд.
  @override
  Color get backdrop => const Color(0xFF070A11);

  @override
  Offset toScene(double x, double y) => Offset(px(x), py(y));

  @override
  late final ui.Picture hullPicture = _record(_drawHull);

  @override
  late final ui.Picture fieldBuildPicture = _record(
    (g) => _drawHull(g, edges: false, lights: false),
  );

  @override
  late final ui.Picture fieldDonePicture = _record(
    (g) => _drawHull(g, edges: false),
  );

  @override
  late final ui.Picture objectsPicture = _record(_drawObjects);

  final Map<ShipFieldLayer, ui.Picture> _fieldLayers = {};

  @override
  ui.Picture fieldLayer(ShipFieldLayer layer) => _fieldLayers.putIfAbsent(
    layer,
    () => _record(switch (layer) {
      ShipFieldLayer.hullBase => (g) => _drawHull(
        g,
        edges: false,
        lights: false,
        paint: false,
        accents: false,
      ),
      ShipFieldLayer.hullAccents => (g) => _drawHull(
        g,
        edges: false,
        lights: false,
        paint: false,
      ),
      ShipFieldLayer.hullLights => (g) => _drawHull(
        g,
        edges: false,
        paint: false,
        accents: false,
      ),
      ShipFieldLayer.objectsBase => (g) => _drawObjects(
        g,
        lights: false,
        paint: false,
        accents: false,
      ),
      ShipFieldLayer.objectsAccents => (g) => _drawObjects(
        g,
        lights: false,
        paint: false,
      ),
      ShipFieldLayer.objectsLights => (g) => _drawObjects(
        g,
        paint: false,
        accents: false,
      ),
      ShipFieldLayer.paint => _drawPaint,
    }),
  );

  @override
  late final Path outline = _buildOutline();

  @override
  Path objectShape(String partId) {
    final o = roninObjects[partId];
    if (o == null) {
      throw ArgumentError.value(partId, 'partId', 'не предмет «Ронина»');
    }
    final parts = switch (o.kind) {
      'sensor' => _sensorShape(),
      'rcs' => _rcsShape(px(o.x), py(o.y), o.flip),
      'visor' => _visorShape(o.flip),
      'hatch' => _hatchShape(o.flip),
      _ => throw ArgumentError.value(
        o.kind,
        'kind',
        'неизвестный вид предмета',
      ),
    };
    return parts.reduce((a, b) => Path.combine(PathOperation.union, a, b));
  }

  ui.Picture _record(void Function(Canvas) draw) {
    final rec = ui.PictureRecorder();
    draw(Canvas(rec, Offset.zero & sceneSize));
    return rec.endRecording();
  }

  /// Контур борта + две гондолы (как `shipOutlinePath` в `ronin-draw.js`).
  static Path _buildOutline() {
    final p = _hullPath();
    const bw = 1.06 * cellPx, bh = 2.9 * cellPx;
    final byt = py(13.55);
    for (final bx in [px(3) - bw + 2, px(12) - 2]) {
      p.addRRect(_rr(bx, byt, bw, bh, 5));
    }
    return p;
  }

  // ---------- формы предметов (ronin-objects.js) ----------

  static List<Path> _sensorShape() => [
    Path()..addRect(
      Rect.fromLTWH(cx - .5 * cellPx, py(-.55), 1 * cellPx, .6 * cellPx),
    ),
    Path()..addRect(
      Rect.fromLTWH(cx - .26 * cellPx, py(-.95), .52 * cellPx, .42 * cellPx),
    ),
    Path()
      ..addOval(Rect.fromCircle(center: Offset(cx, py(-1.06)), radius: 2.2)),
  ];

  static List<Path> _rcsShape(double x, double y, int flip) {
    const up = [
      [-5.2, -.56 * cellPx],
      [5.2, -.56 * cellPx],
      [3.4, -.3 * cellPx],
      [-3.4, -.3 * cellPx],
    ];
    Path rot(double a) {
      final ca = math.cos(a), sa = math.sin(a);
      final pts = [
        for (final q in up)
          Offset(x + q[0] * ca - q[1] * sa, y + q[0] * sa + q[1] * ca),
      ];
      return Path()..addPolygon(pts, true);
    }

    return [
      Path()..addRRect(
        _rr(x - .3 * cellPx, y - .3 * cellPx, .6 * cellPx, .6 * cellPx, 3),
      ),
      rot(0),
      rot(flip * math.pi / 2),
      rot(math.pi),
    ];
  }

  /// Визор мостика половиной (`visor` в `ronin-objects.js`): [half] `-1` —
  /// левая, `1` — правая.
  static List<Path> _visorShape(int half) {
    final vx = px(4.65), vy = py(2.48), vw = 5.7 * cellPx, vh = .86 * cellPx;
    return [
      Path()..addRRect(_rr(half < 0 ? vx : vx + vw / 2, vy, vw / 2, vh, 4)),
    ];
  }

  /// Торпедный люк с оранжевой полоской над ним (`hatch` в `ronin-objects.js`):
  /// [side] `-1` — левый, `1` — правый.
  static List<Path> _hatchShape(int side) {
    final tx = cx + side * 1.45 * cellPx - .42 * cellPx, ty = py(5.95);
    return [
      Path()..addRRect(_rr(tx, ty - 2.6, .84 * cellPx, .66 * cellPx + 2.6, 3)),
    ];
  }

  // ---------- вспомогательные ----------

  /// `rr()` эталона — скруглённый прямоугольник.
  static RRect _rr(double x, double y, double w, double h, double r) =>
      RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r));

  static Paint _fill(Color c) => Paint()..color = c;

  static Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeMiterLimit = 10;

  static Path _line(List<Offset> pts) => Path()..addPolygon(pts, false);

  /// Заливка с canvas-тенью (offset 0): размытая копия формы цветом тени под ней.
  static void _shadowed(
    Canvas g,
    Path path,
    Paint fill,
    Color shadow,
    double blur,
  ) {
    g.drawPath(
      path,
      Paint()
        ..color = shadow
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, _sigma(blur)),
    );
    g.drawPath(path, fill);
  }

  static void _glowDot(Canvas g, double x, double y, double r, Color col) {
    final c = Offset(x, y);
    g.drawCircle(
      c,
      r * 4,
      Paint()
        ..shader = ui.Gradient.radial(c, r * 4, [col, const Color(0x00000000)]),
    );
    g.drawCircle(c, r, _fill(col));
  }

  /// `fillText` с `textAlign = center`, `textBaseline = middle`. Гарнитура —
  /// системная sans-serif (жирная), ширина строки подгоняется горизонтальным
  /// масштабом под [targetWidth] — ширину строки в `Arial Narrow Bold` эталона.
  static void _text(
    Canvas g,
    String s,
    double fontSize,
    double targetWidth,
    Color color,
    double x,
    double y,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final baseline = tp.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    final sx = tp.width > 0 ? targetWidth / tp.width : 1.0;
    g
      ..save()
      ..translate(x, y + _middleAboveBaseline * fontSize)
      ..scale(sx, 1);
    tp.paint(g, Offset(-tp.width / 2, -baseline));
    g.restore();
    tp.dispose();
  }

  // ---------- слой 0: корпус ----------

  /// Корпус (блок `if(HULL)` эталона). [edges] — кромки плит-деталей и контур
  /// корпуса, [lights] — щели-огни, [paint] — краска корпуса (`_drawPaint`),
  /// [accents] — цветные элементы (на корпусе сейчас нет, пробрасывается на
  /// будущее) (`render({edges, lights, paint, accents})`, D-017).
  static void _drawHull(
    Canvas g, {
    bool edges = true,
    bool lights = true,
    bool paint = true,
    bool accents = true,
  }) {
    const c = cellPx;
    final hull = _hullPath();

    // строки 0..7 — плиты по логическим деталям (v3). Клетки плиты (расширены
    // на .3 px, как в эталоне) — один путь на плиту: при replay в масштабе ≠ 1
    // внутри плиты нет щелей сглаживания между клетками (при 1:1 = эталон).
    for (final pl in _partPlates) {
      final fill = Path();
      for (final (_, _, x, y) in pl.cells) {
        fill.addRect(Rect.fromLTWH(x - .3, y - .3, pl.cs + .6, pl.cs + .6));
      }
      g.drawPath(fill, _fill(_hsl(pl.m, pl.jl)));
    }
    if (edges) {
      for (final pl in _partPlates) {
        final lt = _stroke(_hsl(pl.m, pl.jl + 6, .55), 1);
        final dk = _stroke(_hsl(pl.m, pl.jl - 6, .6), 1);
        final sm = _stroke(_rgba(0, 0, 0, .32), .8);
        final cs = pl.cs;
        void seg(double x1, double y1, double x2, double y2, Paint paint) =>
            g.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
        for (final (cc, r, x, y) in pl.cells) {
          if (!pl.on(cc, r - 1)) {
            seg(x, y + 1, x + cs, y + 1, lt);
            seg(x, y + .3, x + cs, y + .3, sm);
          }
          if (!pl.on(cc - 1, r)) {
            seg(x + 1, y, x + 1, y + cs, lt);
            seg(x + .3, y, x + .3, y + cs, sm);
          }
          if (!pl.on(cc, r + 1)) {
            seg(x, y + cs - 1, x + cs, y + cs - 1, dk);
            seg(x, y + cs - .3, x + cs, y + cs - .3, sm);
          }
          if (!pl.on(cc + 1, r)) {
            seg(x + cs - 1, y, x + cs - 1, y + cs, dk);
            seg(x + cs - .3, y, x + cs - .3, y + cs, sm);
          }
        }
      }
    }

    // строки 8+ — прежний генератор (плиты строк 0..7 сгенерированы, но не рисуются)
    for (final p in plates) {
      if (p.y < ronin1Rows) continue;
      final m = _plateMat(p);
      final x = px(p.x.toDouble()),
          y = py(p.y.toDouble()),
          wd = p.w * c,
          hd = p.h * c;
      g.drawRect(Rect.fromLTWH(x, y, wd, hd), _fill(_hsl(m, p.jl)));
      g.drawPath(
        _line([
          Offset(x + 1.2, y + hd - 1.2),
          Offset(x + 1.2, y + 1.2),
          Offset(x + wd - 1.2, y + 1.2),
        ]),
        _stroke(_hsl(m, p.jl + 12, .8), 2),
      );
      g.drawPath(
        _line([
          Offset(x + wd - 1.2, y + 1.2),
          Offset(x + wd - 1.2, y + hd - 1.2),
          Offset(x + 1.2, y + hd - 1.2),
        ]),
        _stroke(_hsl(m, p.jl - 12, .85), 2),
      );
      g.drawRect(
        Rect.fromLTWH(x + .75, y + .75, wd - 1.5, hd - 1.5),
        _stroke(_rgba(0, 0, 0, .4), 1.5),
      );
    }

    // лёгкая воксельная сетка — только строки 8+ (в «Ронине-1» её нет, D-016)
    g
      ..save()
      ..clipPath(hull)
      ..clipRect(Rect.fromLTWH(0, py(ronin1Rows.toDouble()), width, height));
    final grid = _stroke(_rgba(255, 255, 255, .045), 1);
    for (var x = 0; x <= gw; x++) {
      g.drawLine(
        Offset(px(x.toDouble()), py(0)),
        Offset(px(x.toDouble()), py(rows.toDouble())),
        grid,
      );
    }
    for (var y = 0; y <= rows; y++) {
      g.drawLine(
        Offset(px(0), py(y.toDouble())),
        Offset(px(gw.toDouble()), py(y.toDouble())),
        grid,
      );
    }
    g.restore();

    // швы между поясами (швы 2 и 4 — кромки деталей, v3)
    for (final yb in const [8, 13, 18, 21, 25]) {
      final s0 = math.max(span[yb][0], span[yb - 1][0]).toDouble();
      final s1 = math.min(span[yb][1], span[yb - 1][1]).toDouble();
      final y = py(yb.toDouble());
      g.drawLine(
        Offset(px(s0), y),
        Offset(px(s1 + 1), y),
        _stroke(_rgba(0, 0, 0, .6), 2.5),
      );
      g.drawLine(
        Offset(px(s0), y - 2),
        Offset(px(s1 + 1), y - 2),
        _stroke(_rgba(255, 255, 255, .12), 1),
      );
    }

    // крупная светотень
    g
      ..save()
      ..clipPath(hull);
    g.drawRect(
      Rect.fromLTWH(px(-1), py(-1), 17 * c, 29 * c),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(px(0), 0),
          Offset(px(15), 0),
          [
            _rgba(255, 255, 255, .12),
            _rgba(255, 255, 255, 0),
            _rgba(0, 0, 0, 0),
            _rgba(0, 0, 0, .20),
          ],
          const [0, .4, .62, 1],
        ),
    );
    g.drawRect(
      Rect.fromLTWH(px(-1), py(18), 17 * c, 10 * c),
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, py(18)), Offset(0, py(27)), [
          _rgba(0, 0, 0, 0),
          _rgba(0, 0, 0, .16),
        ]),
    );
    g.drawRect(
      Rect.fromLTWH(px(-1), py(10), 17 * c, 18 * c),
      Paint()
        ..shader = ui.Gradient.radial(Offset(px(13.5), py(28)), 13 * c, [
          _rgba(255, 130, 50, .14),
          _rgba(255, 130, 50, 0),
        ]),
    );
    // потёки — только строки 8+, ГСЧ расходуется как раньше
    final wr = mulberry32(9);
    for (var i = 0; i < 9; i++) {
      final wx = px(3 + wr() * 9),
          wy = py(4 + wr() * 20),
          wl = (.5 + wr() * 1.4) * c;
      final a = .05 + wr() * .04;
      if (wy < py(ronin1Rows.toDouble())) continue;
      g.drawRect(Rect.fromLTWH(wx, wy, 2, wl), _fill(_rgba(0, 0, 0, a)));
    }
    for (var i = 0; i < 5; i++) {
      final wx = px(3 + wr() * 9), wy = py(4 + wr() * 20);
      if (wy < py(ronin1Rows.toDouble())) continue;
      g.drawRect(
        Rect.fromLTWH(wx, wy, 3.5, .35 * c),
        _fill(_rgba(255, 255, 255, .04)),
      );
    }
    g.restore();

    // краска корпуса: шеврон, номер борта, трафарет
    if (paint) _drawPaint(g);

    // бортовые огни-иллюминаторы (щели)
    if (lights) _lights(g);

    // контур корпуса
    if (edges) g.drawPath(hull, _stroke(const Color(0xFF07090C), 2.4));
  }

  /// Краска корпуса (`drawPaint` эталона, D-017): шеврон носа (клип по носу),
  /// «V V - 7 7», «7 7». «РОНИН» (строки 8+) не портирован — Ронин-2.
  static void _drawPaint(Canvas g) {
    const c = cellPx;

    // нос: шеврон
    g
      ..save()
      ..clipRect(
        Rect.fromLTWH(
          px(span[0][0].toDouble()),
          py(0),
          (span[0][1] - span[0][0] + 1) * c,
          2 * c,
        ),
      );
    g.drawPath(
      Path()..addPolygon([
        Offset(cx, py(1.95)),
        Offset(cx - 2.1 * c, py(.9)),
        Offset(cx - 2.1 * c, py(.38)),
        Offset(cx, py(1.38)),
        Offset(cx + 2.1 * c, py(.38)),
        Offset(cx + 2.1 * c, py(.9)),
      ], true),
      _fill(_hsl(_oran, 0, .95)),
    );
    g.drawPath(
      _line([
        Offset(cx - 2.1 * c, py(.24)),
        Offset(cx, py(1.22)),
        Offset(cx + 2.1 * c, py(.24)),
      ]),
      _stroke(_rgba(255, 255, 255, .5), 2),
    );
    g.restore();

    // номер борта
    _text(g, 'V V - 7 7', 12, 38.291, _rgba(223, 230, 236, .85), cx, py(4.62));

    // трафарет «7 7»
    _text(g, '7 7', 26, 29.644, _rgba(228, 234, 240, .78), px(4.85), py(7.28));
  }

  /// Бортовые огни-иллюминаторы — щели с подсветкой (только при `lights`).
  static void _lights(Canvas g) {
    const c = cellPx;
    for (final (x, y, warm) in const [
      (4.0, 5.45, false),
      (10.2, 5.45, false),
      (3.6, 10.42, true),
      (9.9, 9.42, true),
      (3.7, 13.42, false),
      (10.5, 13.42, false),
      (3.6, 19.42, true),
      (9.9, 19.42, true),
    ]) {
      _shadowed(
        g,
        Path()..addRRect(_rr(px(x), py(y), .8 * c, .16 * c, 2)),
        _fill(warm ? const Color(0xFFFFD9A0) : const Color(0xFFCFEAFF)),
        warm ? _rgba(255, 205, 140, .85) : _rgba(160, 215, 255, .85),
        7,
      );
    }
  }

  // ---------- слой 1: предметы ----------

  /// Предметы слоя 1. [lights] — строб и огонёк датчика, стёкла визора;
  /// [accents] — оранжевая полоса люков; [paint] — краски на предметах нет
  /// (параметр симметричен корпусу, `render({lights, paint, accents})`, D-017).
  /// Рама визора, корпус датчика, крышки люков и RCS — всегда.
  static void _drawObjects(
    Canvas g, {
    bool lights = true,
    bool paint = true,
    bool accents = true,
  }) {
    const c = cellPx;

    // датчик-блок на носу + строб
    final body = Rect.fromLTWH(cx - .5 * c, py(-.55), 1 * c, .6 * c);
    final head = Rect.fromLTWH(cx - .26 * c, py(-.95), .52 * c, .42 * c);
    g.drawRect(body, _fill(_hsl(_dark, -2)));
    g.drawRect(head, _fill(_hsl(_gun, 6)));
    final edge = _stroke(_rgba(0, 0, 0, .6), 1.5);
    g.drawRect(body, edge);
    g.drawRect(head, edge);
    if (lights) {
      g.drawRect(
        Rect.fromLTWH(cx - .18 * c, py(-.78), .36 * c, 2.2),
        _fill(_rgba(180, 220, 255, .9)),
      );
      _glowDot(g, cx, py(-1.06), 2.2, _rgba(255, 255, 255, .95));
    }

    // мостик: визор со щелями (v3: выше v2 — три ряда клеток, средний стекло)
    final vx = px(4.65), vy = py(2.48), vw = 5.7 * c, vh = .86 * c;
    final visor = _rr(vx, vy, vw, vh, 4);
    g.drawRRect(visor, _fill(const Color(0xFF101318)));
    g.drawRRect(visor, _stroke(_rgba(255, 255, 255, .18), 1.5));
    if (lights) {
      for (final sl in const [
        [5.0, 1.0],
        [6.4, 1.0],
        [7.8, 1.0],
        [9.2, .85],
      ]) {
        final sx = sl[0], sw = sl[1];
        _shadowed(
          g,
          Path()..addRRect(_rr(px(sx), vy + .28 * c, sw * c, .30 * c, 2.5)),
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(px(sx), 0),
              Offset(px(sx + sw), 0),
              const [Color(0xFF8FC6EE), Color(0xFFE8F6FF), Color(0xFF79B6E2)],
              const [0, .5, 1],
            ),
          _rgba(150, 210, 255, .9),
          9,
        );
      }
    }

    // торпедные люки на носовой секции
    for (final s in const [-1, 1]) {
      final tx = cx + s * 1.45 * c - .42 * c, ty = py(5.95);
      final hatch = _rr(tx, ty, .84 * c, .66 * c, 3);
      _shadowed(
        g,
        Path()..addRRect(hatch),
        _fill(_hsl(_dark, -1)),
        _rgba(0, 0, 0, .5),
        5,
      );
      g.drawRRect(hatch, _stroke(_rgba(0, 0, 0, .65), 1.6));
      g.drawLine(
        Offset(tx + .42 * c, ty + 3),
        Offset(tx + .42 * c, ty + .66 * c - 3),
        _stroke(_rgba(255, 255, 255, .14), 1),
      );
      if (accents) {
        g.drawRect(
          Rect.fromLTWH(tx + 2, ty - 2.6, .84 * c - 4, 2),
          _fill(_rgba(224, 131, 55, .85)),
        );
      }
    }

    // RCS-квады — все четыре
    _rcs(g, px(3), py(4.5), -1);
    _rcs(g, px(12), py(4.5), 1);
    _rcs(g, px(3), py(20.5), -1);
    _rcs(g, px(12), py(20.5), 1);
  }

  static void _rcs(Canvas g, double x, double y, int flip) {
    const c = cellPx;
    final block = _rr(x - .3 * c, y - .3 * c, .6 * c, .6 * c, 3);
    g.drawRRect(block, _fill(_hsl(_gun, 10)));
    g.drawRRect(block, _stroke(_rgba(0, 0, 0, .6), 1.5));
    final nozzle = Path()
      ..addPolygon(const [
        Offset(-3.4, -.3 * c),
        Offset(3.4, -.3 * c),
        Offset(5.2, -.56 * c),
        Offset(-5.2, -.56 * c),
      ], true);
    for (final a in [0.0, flip * math.pi / 2, math.pi]) {
      g
        ..save()
        ..translate(x, y)
        ..rotate(a);
      g.drawPath(nozzle, _fill(const Color(0xFF101215)));
      g.drawPath(nozzle, _stroke(_rgba(255, 255, 255, .18), 1));
      g.restore();
    }
  }
}
