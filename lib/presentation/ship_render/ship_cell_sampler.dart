import 'dart:math' as math;
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

// ---------- преобладающий цвет клеток (D-016, `domColor` ronin-draw.js) ----------

/// Преобладающие цвета клеток маски детали (bbox маски `width × height`,
/// построчно): у плиты — по [ShipArt.fieldBuildPicture], у предмета — по
/// [ShipArt.objectsPicture]. Неизменяемый; строит [partCellColors].
@immutable
class PartCellColors {
  /// Цвета [colors] клеток bbox маски [width] × [height] построчно
  /// (`r * width + c`).
  PartCellColors({
    required this.width,
    required this.height,
    required List<Color> colors,
  }) : _colors = List.unmodifiable(colors) {
    if (colors.length != width * height) {
      throw ArgumentError.value(colors.length, 'colors', 'не $width × $height');
    }
  }

  /// Ширина bbox маски, клеток.
  final int width;

  /// Высота bbox маски, клеток.
  final int height;

  final List<Color> _colors;

  /// Преобладающий цвет клетки ([c], [r]) маски (непрозрачный).
  Color colorAt(int c, int r) {
    RangeError.checkValueInInterval(c, 0, width - 1, 'c');
    RangeError.checkValueInInterval(r, 0, height - 1, 'r');
    return _colors[r * width + c];
  }

  /// Тёмная клетка: яркость `(0.2126R + 0.7152G + 0.0722B) / 255 < 0.2` —
  /// заклёпки на ней чёрные 85 %, иначе 45 % (D-016).
  bool isDark(int c, int r) {
    final k = colorAt(c, r);
    return (0.2126 * k.r + 0.7152 * k.g + 0.0722 * k.b) < 0.2;
  }
}

/// Пикселей растра на клетку маски при подсчёте преобладающего цвета.
const int _samplePx = 8;

/// Цвет клетки без непрозрачных пикселей (`[23, 26, 30]` эталона).
const Color _noPixels = Color(0xFF171A1E);

/// Кеш [partCellColors] по `part.id`: одна деталь — один расчёт за запуск.
final Map<String, PartCellColors> _cellColorsCache = {};

/// Преобладающий цвет каждой клетки маски [part] (`domColor` в
/// `docs/design/ronin-draw.js`): самая частая корзина цвета (4 бита на канал),
/// пиксели с альфой < 128 не считаются, итог — средний цвет победившей
/// корзины. Источник: плита — [ShipArt.fieldBuildPicture], предмет —
/// [ShipArt.objectsPicture]. Деталь растрируется целиком один раз,
/// [_samplePx] px на клетку; результат кешируется по `part.id` (второй вызов
/// отдаёт тот же объект).
Future<PartCellColors> partCellColors(ShipArt art, RoninPartDef part) async {
  final hit = _cellColorsCache[part.id];
  if (hit != null) return hit;
  final colors = await _sampleCellColors(art, part);
  return _cellColorsCache.putIfAbsent(part.id, () => colors);
}

Future<PartCellColors> _sampleCellColors(ShipArt art, RoninPartDef part) async {
  final w = part.mask.width, h = part.mask.height;
  final src = shipCellRect(art, part, 0, 0);
  final k = _samplePx / src.width;
  final rec = ui.PictureRecorder();
  Canvas(rec)
    ..scale(k)
    ..translate(-src.left, -src.top)
    ..drawPicture(part.isPlate ? art.fieldBuildPicture : art.objectsPicture);
  final picture = rec.endRecording();
  final image = await picture.toImage(w * _samplePx, h * _samplePx);
  picture.dispose();
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final stride = image.width;
  image.dispose();
  final bytes = data!.buffer.asUint8List(
    data.offsetInBytes,
    data.lengthInBytes,
  );
  return PartCellColors(
    width: w,
    height: h,
    colors: [
      for (var r = 0; r < h; r++)
        for (var c = 0; c < w; c++)
          _dominant(bytes, stride, c * _samplePx, r * _samplePx),
    ],
  );
}

/// Преобладающий цвет квадрата [_samplePx]² с левым-верхом ([x0], [y0]) в
/// растре [px] (premultiplied RGBA, ширина [stride]).
Color _dominant(List<int> px, int stride, int x0, int y0) {
  final bins = <int, List<int>>{};
  for (var y = y0; y < y0 + _samplePx; y++) {
    for (var x = x0; x < x0 + _samplePx; x++) {
      final i = (y * stride + x) * 4, a = px[i + 3];
      if (a < 128) continue;
      // Растр premultiplied, эталон (`getImageData`) — нет.
      int straight(int v) =>
          a == 255 ? v : math.min(255, (v * 255 / a).round());
      final r = straight(px[i]),
          g = straight(px[i + 1]),
          b = straight(px[i + 2]);
      final key = (r >> 4) << 8 | (g >> 4) << 4 | (b >> 4);
      final bin = bins.putIfAbsent(key, () => [0, 0, 0, 0]);
      bin[0] += r;
      bin[1] += g;
      bin[2] += b;
      bin[3]++;
    }
  }
  List<int>? best;
  for (final bin in bins.values) {
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
/// [assembled] `false` — сборка (`drawCell(…, 'build')`): каждая клетка —
/// плитка (клип `RRect` с отступом `s = cellSize / 34` и радиусом `3s`, все
/// клетки одним клипом); плита — [ShipArt.fieldBuildPicture] (один replay),
/// предмет — плоский преобладающий цвет клетки из [colors] (нет [colors] —
/// [ShipArt.backdrop] + [ShipArt.objectsPicture]); поверх — рельеф ×1,4
/// (`tileRelief`), после клипа — 4 заклёпки (`rivets`): чёрные 85 % на тёмной
/// клетке ([PartCellColors.isDark]), иначе 45 %.
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
  final clip = Path();
  for (final f in list) {
    clip.addRRect(
      RRect.fromRectAndRadius(cellAt(f).deflate(s), Radius.circular(3 * s)),
    );
  }
  canvas
    ..save()
    ..clipPath(clip);
  if (part.isPlate) {
    replay(art.fieldBuildPicture);
  } else if (colors == null) {
    canvas.drawPaint(Paint()..color = art.backdrop);
    replay(art.objectsPicture);
  } else {
    for (final f in list) {
      canvas.drawRect(cellAt(f), Paint()..color = colors.colorAt(f.x, f.y));
    }
  }
  for (final f in list) {
    _tileRelief(canvas, cellAt(f).deflate(s), s, _reliefK);
  }
  canvas.restore();
  for (final f in list) {
    _rivets(canvas, cellAt(f).deflate(s), s, colors?.isDark(f.x, f.y) ?? false);
  }
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
