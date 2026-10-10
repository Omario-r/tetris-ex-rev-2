import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/painting.dart';

import '../../game_engine/data/ronin_parts.dart';
import 'ship_art.dart';

/// Клетка ([c], [r]) маски детали на корабле — прямоугольник в px рисунка
/// (`cellOnShip` → [ShipArt.toScene]); сторона — клетка рисунка / масштаб детали.
Rect shipCellRect(ShipArt art, RoninPartDef part, int c, int r) {
  final cell = part.cellOnShip(c, r);
  final tl = art.toScene(cell.x, cell.y);
  final br = art.toScene(cell.x + cell.size, cell.y + cell.size);
  return Rect.fromPoints(tl, br);
}

// ---------- вид и цвет клеток (D-017, `cellInfo` ronin-draw.js) ----------

/// Вид клетки поля во время сборки (D-017): основа (однотонная, у плиты —
/// с краской корпуса поверх), цветной элемент (клетка целиком его цвета),
/// свет (клетка целиком его цвета с ореолом на соседей).
enum PartCellKind { base, accent, light }

/// Вид и цвет клеток маски детали (bbox маски `width × height`, построчно) —
/// `cellInfo` эталона (D-017). Неизменяемый; строит [partCellColors].
@immutable
class PartCellColors {
  /// Цвета [colors] и виды [kinds] клеток bbox маски [width] × [height]
  /// построчно (`r * width + c`); без [kinds] — все клетки [PartCellKind.base].
  PartCellColors({
    required this.width,
    required this.height,
    required List<Color> colors,
    List<PartCellKind>? kinds,
  }) : _colors = List.unmodifiable(colors),
       _kinds = List.unmodifiable(
         kinds ?? List.filled(width * height, PartCellKind.base),
       ) {
    if (colors.length != width * height) {
      throw ArgumentError.value(colors.length, 'colors', 'не $width × $height');
    }
    if (_kinds.length != width * height) {
      throw ArgumentError.value(_kinds.length, 'kinds', 'не $width × $height');
    }
  }

  /// Ширина bbox маски, клеток.
  final int width;

  /// Высота bbox маски, клеток.
  final int height;

  final List<Color> _colors;
  final List<PartCellKind> _kinds;

  /// Цвет клетки ([c], [r]) маски (непрозрачный): основа — преобладающий цвет
  /// слоя основы, элемент — среднее его пикселей.
  Color colorAt(int c, int r) {
    RangeError.checkValueInInterval(c, 0, width - 1, 'c');
    RangeError.checkValueInInterval(r, 0, height - 1, 'r');
    return _colors[r * width + c];
  }

  /// Вид клетки ([c], [r]) маски.
  PartCellKind kindAt(int c, int r) {
    RangeError.checkValueInInterval(c, 0, width - 1, 'c');
    RangeError.checkValueInInterval(r, 0, height - 1, 'r');
    return _kinds[r * width + c];
  }

  /// Тёмная клетка: яркость `(0.2126R + 0.7152G + 0.0722B) / 255 < 0.2` —
  /// заклёпки на ней чёрные 85 %, иначе 45 % (D-016).
  bool isDark(int c, int r) {
    final k = colorAt(c, r);
    return (0.2126 * k.r + 0.7152 * k.g + 0.0722 * k.b) < 0.2;
  }
}

/// Пикселей растра на клетку маски при подсчёте вида и цвета клетки.
const int _samplePx = 8;

/// Порог «почти чёрного» пикселя основы (яркость 0..1), D-017: обводка и тень
/// предмета ниже него не берутся в цвет основы, если их < 70 % клетки.
const double _nearBlack = 0.05;

/// Цвет клетки без непрозрачных пикселей (`[23, 26, 30]` эталона).
const Color _noPixels = Color(0xFF171A1E);

/// Кеш [partCellColors] по `part.id`: одна деталь — один расчёт за запуск.
final Map<String, PartCellColors> _cellColorsCache = {};

/// Вид и цвет каждой клетки маски [part] (`cellInfo` в
/// `docs/design/ronin-draw.js`, D-017) по трём слоям [ShipArt.fieldLayer]:
/// плита — `hullBase` / `hullAccents` / `hullLights`, предмет — `objectsBase` /
/// `objectsAccents` / `objectsLights`.
///
/// Пиксели с альфой < 128 не считаются. Пиксель света — ярче того же пикселя
/// основы на 0,25; пиксель цветного элемента — отличается от основы (сумма
/// |ΔRGB| > 40). Элемент берёт клетку, если занимает ≥ 40 % её, или ≥ 15 % и
/// ≥ 70 % от доли соседа поперёк элемента (`elemCells`); цвет — среднее его
/// пикселей. Свет важнее цветного элемента. Остальное — основа: самая частая
/// корзина цвета слоя основы (4 бита на канал, итог — средний цвет корзины),
/// почти чёрное (яркость < 0,05) не берётся, если его < 70 % клетки.
///
/// Каждый слой растрируется целиком один раз, [_samplePx] px на клетку;
/// результат кешируется по `part.id` (второй вызов отдаёт тот же объект).
Future<PartCellColors> partCellColors(ShipArt art, RoninPartDef part) async {
  final hit = _cellColorsCache[part.id];
  if (hit != null) return hit;
  final colors = await _sampleCellColors(art, part);
  return _cellColorsCache.putIfAbsent(part.id, () => colors);
}

Future<PartCellColors> _sampleCellColors(ShipArt art, RoninPartDef part) async {
  final w = part.mask.width, h = part.mask.height;
  final plate = part.isPlate;
  final base = await _rasterPart(
    art,
    part,
    plate ? ShipFieldLayer.hullBase : ShipFieldLayer.objectsBase,
  );
  final accents = await _rasterPart(
    art,
    part,
    plate ? ShipFieldLayer.hullAccents : ShipFieldLayer.objectsAccents,
  );
  final lights = await _rasterPart(
    art,
    part,
    plate ? ShipFieldLayer.hullLights : ShipFieldLayer.objectsLights,
  );
  final stride = w * _samplePx;
  final light = _elemCells(
    part,
    (c, r) => _elemShare(lights, base, stride, c, r, _isLightPx),
  );
  final accent = _elemCells(
    part,
    (c, r) => _elemShare(accents, base, stride, c, r, _isAccentPx),
  );
  final colors = <Color>[], kinds = <PartCellKind>[];
  for (var r = 0; r < h; r++) {
    for (var c = 0; c < w; c++) {
      final l = light[(x: c, y: r)], a = accent[(x: c, y: r)];
      if (l != null) {
        colors.add(l);
        kinds.add(PartCellKind.light);
      } else if (a != null) {
        colors.add(a);
        kinds.add(PartCellKind.accent);
      } else {
        colors.add(_dominant(base, stride, c * _samplePx, r * _samplePx));
        kinds.add(PartCellKind.base);
      }
    }
  }
  return PartCellColors(width: w, height: h, colors: colors, kinds: kinds);
}

/// Растр слоя [layer] в раскладке маски [part] ([_samplePx] px на клетку,
/// клетка (0, 0) — в (0, 0)), RGBA без premultiply (как `getImageData`
/// эталона; у прозрачного пикселя RGB = 0).
Future<Uint8List> _rasterPart(
  ShipArt art,
  RoninPartDef part,
  ShipFieldLayer layer,
) async {
  final src = shipCellRect(art, part, 0, 0);
  final k = _samplePx / src.width;
  final rec = ui.PictureRecorder();
  Canvas(rec)
    ..scale(k)
    ..translate(-src.left, -src.top)
    ..drawPicture(art.fieldLayer(layer));
  final picture = rec.endRecording();
  final image = await picture.toImage(
    part.mask.width * _samplePx,
    part.mask.height * _samplePx,
  );
  picture.dispose();
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  final px = Uint8List.fromList(
    data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );
  for (var i = 0; i < px.length; i += 4) {
    final a = px[i + 3];
    if (a == 255) continue;
    for (var k = i; k < i + 3; k++) {
      px[k] = a == 0 ? 0 : math.min(255, (px[k] * 255 / a).round());
    }
  }
  return px;
}

/// Яркость пикселя [i] растра [px] (0..1, `lumAt` эталона).
double _lumAt(List<int> px, int i) =>
    (0.2126 * px[i] + 0.7152 * px[i + 1] + 0.0722 * px[i + 2]) / 255;

/// Пиксель света: ярче основы на 0,25.
bool _isLightPx(List<int> src, List<int> base, int i) =>
    _lumAt(src, i) - _lumAt(base, i) > 0.25;

/// Пиксель цветного элемента: сумма |ΔRGB| против основы > 40.
bool _isAccentPx(List<int> src, List<int> base, int i) =>
    (src[i] - base[i]).abs() +
        (src[i + 1] - base[i + 1]).abs() +
        (src[i + 2] - base[i + 2]).abs() >
    40;

/// Доля пикселей элемента в клетке ([c], [r]) и их средний цвет
/// (`elemShare` эталона): [src] — слой элемента, [base] — слой основы
/// (оба — [_rasterPart]), [isElem] — пиксель элемента.
({double f, Color? col}) _elemShare(
  List<int> src,
  List<int> base,
  int stride,
  int c,
  int r,
  bool Function(List<int> src, List<int> base, int i) isElem,
) {
  var hit = 0, tot = 0, sr = 0, sg = 0, sb = 0;
  for (var y = r * _samplePx; y < (r + 1) * _samplePx; y++) {
    for (var x = c * _samplePx; x < (c + 1) * _samplePx; x++) {
      final i = (y * stride + x) * 4;
      if (src[i + 3] < 128) continue;
      tot++;
      if (!isElem(src, base, i)) continue;
      hit++;
      sr += src[i];
      sg += src[i + 1];
      sb += src[i + 2];
    }
  }
  return (
    f: tot == 0 ? 0 : hit / tot,
    col: hit == 0
        ? null
        : Color.fromARGB(
            255,
            (sr / hit).round(),
            (sg / hit).round(),
            (sb / hit).round(),
          ),
  );
}

/// Клетки элемента детали [part] и их цвет (`elemCells` эталона): клетка
/// берётся, если доля ≥ 0,4, или ≥ 0,15 и ≥ 0,7 от доли соседа поперёк
/// элемента. «Горячие» клетки — доля ≥ 0,15; их размах по колонкам ≥ размаха
/// по строкам — соседи сверху и снизу, иначе — слева и справа.
Map<({int x, int y}), Color> _elemCells(
  RoninPartDef part,
  ({double f, Color? col}) Function(int c, int r) share,
) {
  final f = {for (final cell in part.mask.cells) cell: share(cell.x, cell.y)};
  final hot = [
    for (final e in f.entries)
      if (e.value.f >= 0.15) e.key,
  ];
  if (hot.isEmpty) return const {};
  int span(int Function(({int x, int y})) axis) =>
      hot.map(axis).reduce(math.max) - hot.map(axis).reduce(math.min);
  final across = span((h) => h.x) >= span((h) => h.y)
      ? const [(0, 1), (0, -1)]
      : const [(1, 0), (-1, 0)];
  final out = <({int x, int y}), Color>{};
  for (final cell in hot) {
    final v = f[cell]!;
    var nb = 0.0;
    for (final (dx, dy) in across) {
      nb = math.max(nb, f[(x: cell.x + dx, y: cell.y + dy)]?.f ?? 0);
    }
    if (v.f >= 0.4 || v.f >= 0.7 * nb) out[cell] = v.col!;
  }
  return out;
}

/// Преобладающий цвет квадрата [_samplePx]² с левым-верхом ([x0], [y0]) в
/// растре [px] (RGBA без premultiply, ширина [stride]) — `domColor(…,
/// skipDark)` эталона: почти чёрные пиксели (яркость < [_nearBlack]) — в своих
/// корзинах и не берутся, если их < 70 % непрозрачных пикселей.
Color _dominant(List<int> px, int stride, int x0, int y0) {
  final bins = <int, List<int>>{};
  var dark = 0, tot = 0;
  for (var y = y0; y < y0 + _samplePx; y++) {
    for (var x = x0; x < x0 + _samplePx; x++) {
      final i = (y * stride + x) * 4;
      if (px[i + 3] < 128) continue;
      tot++;
      final r = px[i], g = px[i + 1], b = px[i + 2];
      final isDark = _lumAt(px, i) < _nearBlack;
      if (isDark) dark++;
      final key =
          (isDark ? 1 << 12 : 0) | (r >> 4) << 8 | (g >> 4) << 4 | (b >> 4);
      final bin = bins.putIfAbsent(key, () => [0, 0, 0, 0, isDark ? 1 : 0]);
      bin[0] += r;
      bin[1] += g;
      bin[2] += b;
      bin[3]++;
    }
  }
  final skip = tot > 0 && dark / tot < 0.7;
  List<int>? best;
  for (final bin in bins.values) {
    if (skip && bin[4] == 1) continue;
    if (best == null || bin[3] > best[3]) best = bin;
  }
  if (best == null) return _noPixels;
  final n = best[3];
  return Color.fromARGB(255, best[0] ~/ n, best[1] ~/ n, best[2] ~/ n);
}

// ---------- клетка поля: сборка и готово (D-016, `drawCell` ronin-draw.js) ----------

/// Сила рельефа плитки (вариант Б, D-016).
const double _reliefK = 1.4;

/// Одна клетка ([c], [r]) маски [part] в квадрат [dst] — тот же вид, что
/// [paintPartCells] для одной этой клетки (в обеих фазах; кромка собранной
/// плиты — по сторонам, где у клетки нет соседа в маске).
void paintPartCell(
  Canvas canvas,
  ShipArt art,
  RoninPartDef part,
  int c,
  int r,
  Rect dst, {
  bool assembled = false,
  PartCellColors? colors,
}) {
  final u = dst.width;
  paintPartCells(
    canvas,
    art,
    part,
    [(x: c, y: r)],
    origin: Offset(dst.left - c * u, dst.top - r * u),
    cellSize: u,
    assembled: assembled,
    colors: colors,
  );
}

/// Клетки [cells] маски [part] (координаты маски) на поле укладки; клетка
/// (c, r) ложится в
/// `Rect.fromLTWH(origin.dx + c * cellSize, origin.dy + r * cellSize, cellSize, cellSize)`,
/// рисунок — в масштабе детали (клетка маски (0, 0) = [shipCellRect] →
/// [origin]). Пустой [cells] — ничего не рисует.
///
/// [assembled] `false` — сборка (`drawField(…, 'build')`, D-017): каждая
/// клетка — плитка (клип `RRect` с отступом `s = cellSize / 34` и радиусом
/// `3s`, группа клеток одним клипом), залитая [PartCellColors.colorAt]; у плиты
/// поверх клеток вида [PartCellKind.base] — краска корпуса (replay
/// `fieldLayer(paint)` под клипом этих плиток); поверх — рельеф ×1,4
/// (`tileRelief`), после клипа — 4 заклёпки (`rivets`): чёрные 85 % на тёмной
/// клетке ([PartCellColors.isDark]), иначе 45 %. Клетки [PartCellKind.light] —
/// последними: сначала ореол каждой (`halo`, без клипа, ложится на соседей),
/// затем их плитки. Нет [colors] (ещё не посчитаны) — под плитками рисунок как
/// есть: плита — [ShipArt.fieldBuildPicture], предмет — [ShipArt.backdrop] +
/// [ShipArt.objectsPicture].
///
/// [assembled] `true` — деталь собрана: без плиток и рельефа, один клип
/// (объединение клеток) и один replay — плита [ShipArt.fieldDonePicture],
/// предмет [ShipArt.objectsPicture] (фон под ним не заливается); у плиты затем
/// чёткая кромка по внешнему контуру маски в px поля (`crispEdge`).
void paintPartCells(
  Canvas canvas,
  ShipArt art,
  RoninPartDef part,
  Iterable<({int x, int y})> cells, {
  required Offset origin,
  required double cellSize,
  bool assembled = false,
  PartCellColors? colors,
}) {
  final list = cells.toList(growable: false);
  if (list.isEmpty) return;

  final src = shipCellRect(art, part, 0, 0);
  final k = cellSize / src.width;
  Rect cellAt(({int x, int y}) f) => Rect.fromLTWH(
    origin.dx + f.x * cellSize,
    origin.dy + f.y * cellSize,
    cellSize,
    cellSize,
  );
  void replay(ui.Picture picture) => canvas
    ..save()
    ..translate(origin.dx, origin.dy)
    ..scale(k)
    ..translate(-src.left, -src.top)
    ..drawPicture(picture)
    ..restore();

  if (assembled) {
    final clip = Path();
    for (final f in list) {
      clip.addRect(cellAt(f));
    }
    canvas
      ..save()
      ..clipPath(clip);
    replay(part.isPlate ? art.fieldDonePicture : art.objectsPicture);
    canvas.restore();
    if (part.isPlate) _crispEdge(canvas, part, list, origin, cellSize);
    return;
  }

  final s = cellSize / 34;
  Path tiles(Iterable<({int x, int y})> group) {
    final clip = Path();
    for (final f in group) {
      clip.addRRect(
        RRect.fromRectAndRadius(cellAt(f).deflate(s), Radius.circular(3 * s)),
      );
    }
    return clip;
  }

  /// Плитки [group]: один клип, заливка ([fill]), рельеф, после клипа —
  /// заклёпки.
  void paintTiles(List<({int x, int y})> group, void Function() fill) {
    if (group.isEmpty) return;
    canvas
      ..save()
      ..clipPath(tiles(group));
    fill();
    for (final f in group) {
      _tileRelief(canvas, cellAt(f).deflate(s), s, _reliefK);
    }
    canvas.restore();
    for (final f in group) {
      final dark = colors?.isDark(f.x, f.y) ?? false;
      _rivets(canvas, cellAt(f).deflate(s), s, dark);
    }
  }

  if (colors == null) {
    // Вид клеток ещё не посчитан: рисунок под плитками как есть.
    paintTiles(list, () {
      if (part.isPlate) {
        replay(art.fieldBuildPicture);
      } else {
        canvas.drawPaint(Paint()..color = art.backdrop);
        replay(art.objectsPicture);
      }
    });
    return;
  }

  // D-017 (`drawField(…, 'build')`): сначала основа и цветные элементы, затем
  // ореолы световых клеток (ложатся на соседей), затем сами световые плитки.
  final lit = [
    for (final f in list)
      if (colors.kindAt(f.x, f.y) == PartCellKind.light) f,
  ];
  final rest = [
    for (final f in list)
      if (colors.kindAt(f.x, f.y) != PartCellKind.light) f,
  ];
  void flat(List<({int x, int y})> group) {
    for (final f in group) {
      canvas.drawRect(cellAt(f), Paint()..color = colors.colorAt(f.x, f.y));
    }
  }

  paintTiles(rest, () {
    flat(rest);
    final based = [
      for (final f in rest)
        if (colors.kindAt(f.x, f.y) == PartCellKind.base) f,
    ];
    if (part.isPlate && based.isNotEmpty) {
      canvas
        ..save()
        ..clipPath(tiles(based));
      replay(art.fieldLayer(ShipFieldLayer.paint));
      canvas.restore();
    }
  });
  for (final f in lit) {
    _halo(canvas, colors.colorAt(f.x, f.y), cellAt(f), cellSize);
  }
  paintTiles(lit, () => flat(lit));
}

/// Ореол световой клетки (`halo` эталона) — на соседей, без клипа: `RRect`
/// клетки [cell] с отступом 2 px и радиусом 3, цвет [color] 90 %, размытие
/// σ = 0,35·[u] (`shadowBlur = .7u`).
void _halo(Canvas g, Color color, Rect cell, double u) {
  g.drawRRect(
    RRect.fromRectAndRadius(cell.deflate(2), const Radius.circular(3)),
    Paint()
      ..color = color.withValues(alpha: .9)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, .35 * u),
  );
}

/// Рельеф плитки (`tileRelief`, как `el-block`): полосы `3s` — сверху белая
/// 9 %·[k], снизу чёрная 35 %·[k], слева белая 4 %·[k], справа чёрная 18 %·[k].
void _tileRelief(Canvas g, Rect t, double s, double k) {
  final b = 3 * s;
  g
    ..drawRect(
      Rect.fromLTWH(t.left, t.top, t.width, b),
      Paint()..color = Color.fromRGBO(255, 255, 255, .09 * k),
    )
    ..drawRect(
      Rect.fromLTWH(t.left, t.bottom - b, t.width, b),
      Paint()..color = Color.fromRGBO(0, 0, 0, .35 * k),
    )
    ..drawRect(
      Rect.fromLTWH(t.left, t.top, b, t.height),
      Paint()..color = Color.fromRGBO(255, 255, 255, .04 * k),
    )
    ..drawRect(
      Rect.fromLTWH(t.right - b, t.top, b, t.height),
      Paint()..color = Color.fromRGBO(0, 0, 0, .18 * k),
    );
}

/// Заклёпки плитки (`rivets`): радиус `1.5s` в `4s` от углов [t]; чёрные 85 %
/// на тёмной клетке, иначе 45 %.
void _rivets(Canvas g, Rect t, double s, bool dark) {
  final paint = Paint()..color = Color.fromRGBO(0, 0, 0, dark ? .85 : .45);
  for (final p in [
    Offset(t.left + 4 * s, t.top + 4 * s),
    Offset(t.right - 4 * s, t.top + 4 * s),
    Offset(t.left + 4 * s, t.bottom - 4 * s),
    Offset(t.right - 4 * s, t.bottom - 4 * s),
  ]) {
    g.drawCircle(p, 1.5 * s, paint);
  }
}

/// Чёткая кромка собранной плиты (`crispEdge`) — в px поля, по сторонам
/// клеток [cells], где соседа нет в маске [part]: сверху белая 2 px 14 % на
/// 1,5 px внутрь, слева белая 7 %, снизу тёмная 35 %, справа тёмная 22 %; по
/// самому краю каждой стороны — тёмная 1 px 55 %.
void _crispEdge(
  Canvas g,
  RoninPartDef part,
  List<({int x, int y})> cells,
  Offset origin,
  double u,
) {
  final m = part.mask;
  void seg(double x1, double y1, double x2, double y2, Color color, double w) =>
      g.drawLine(
        Offset(x1, y1),
        Offset(x2, y2),
        Paint()
          ..color = color
          ..strokeWidth = w,
      );
  const edge = Color.fromRGBO(0, 0, 0, .55);
  for (final f in cells) {
    final x = origin.dx + f.x * u, y = origin.dy + f.y * u;
    if (!m.contains(f.x, f.y - 1)) {
      seg(
        x,
        y + 1.5,
        x + u,
        y + 1.5,
        const Color.fromRGBO(255, 255, 255, .14),
        2,
      );
      seg(x, y + .5, x + u, y + .5, edge, 1);
    }
    if (!m.contains(f.x - 1, f.y)) {
      seg(
        x + 1.5,
        y,
        x + 1.5,
        y + u,
        const Color.fromRGBO(255, 255, 255, .07),
        2,
      );
      seg(x + .5, y, x + .5, y + u, edge, 1);
    }
    if (!m.contains(f.x, f.y + 1)) {
      seg(
        x,
        y + u - 1.5,
        x + u,
        y + u - 1.5,
        const Color.fromRGBO(0, 0, 0, .35),
        2,
      );
      seg(x, y + u - .5, x + u, y + u - .5, edge, 1);
    }
    if (!m.contains(f.x + 1, f.y)) {
      seg(
        x + u - 1.5,
        y,
        x + u - 1.5,
        y + u,
        const Color.fromRGBO(0, 0, 0, .22),
        2,
      );
      seg(x + u - .5, y, x + u - .5, y + u, edge, 1);
    }
  }
}
