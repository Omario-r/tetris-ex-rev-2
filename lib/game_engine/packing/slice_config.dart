import '../models/target_mask.dart';
import 'pack_piece.dart';
import 'pack_slicer.dart';

/// Конфигурация нарезки детали на кусочки (dev-калибровка Ронин-1/07).
///
/// Порядок значений — порядок кнопок в чит-меню. После КТ-1 лишние
/// конфигурации удаляются.
enum SliceConfig {
  /// «Крупные куски»: деталь целиком, поле 10×14, клетка 34; нарезка 3..5,
  /// затем слияние соседних кусков в 5..12 клеток; ожидаемо 7–10 кусков.
  bigPieces,

  /// «Полдетали»: связная половина детали (`ceil(n/2)` клеток), поле 10×14,
  /// клетка 34; куски 3..5; ожидаемо ~8–10 кусков.
  halfPart,

  /// «Крупная клетка»: деталь, огрублённая 2×2, поле 5×7, клетка 68; куски
  /// 3..5; ожидаемо ~4–6 кусков.
  coarseCell,
}

/// Готовый к игре уровень: поле, силуэт в поле, масштаб клетки, нарезка.
class PreparedLevel {
  /// Размер поля в клетках.
  final int fieldWidth;
  final int fieldHeight;

  /// Силуэт размера поля [fieldWidth]×[fieldHeight].
  final TargetMask silhouette;

  /// Сдвиг bbox силуэта в поле.
  final int targetX;
  final int targetY;

  /// Масштаб клетки: 1 — 34 px, 2 — 68 px.
  final int cellScale;

  /// Нарезка [silhouette] (координаты поля).
  final PackSlice slice;

  const PreparedLevel({
    required this.fieldWidth,
    required this.fieldHeight,
    required this.silhouette,
    required this.targetX,
    required this.targetY,
    required this.cellScale,
    required this.slice,
  });
}

const int _fullFieldWidth = 10;
const int _fullFieldHeight = 14;
const int _coarseFieldWidth = 5;
const int _coarseFieldHeight = 7;

/// Из маски детали [partMask] (bbox-маска `RoninPartDef.mask`), конфигурации
/// [config] и [seed] строит готовый уровень. Детерминирован: одни и те же
/// аргументы дают побитово одинаковый результат.
PreparedLevel prepareLevel(
  TargetMask partMask,
  SliceConfig config, {
  required int seed,
}) {
  final int fieldWidth;
  final int fieldHeight;
  final int cellScale;
  final TargetMask work;
  switch (config) {
    case SliceConfig.bigPieces:
      fieldWidth = _fullFieldWidth;
      fieldHeight = _fullFieldHeight;
      cellScale = 1;
      work = partMask;
    case SliceConfig.halfPart:
      fieldWidth = _fullFieldWidth;
      fieldHeight = _fullFieldHeight;
      cellScale = 1;
      work = _halfOf(partMask);
    case SliceConfig.coarseCell:
      fieldWidth = _coarseFieldWidth;
      fieldHeight = _coarseFieldHeight;
      cellScale = 2;
      work = _coarsen(partMask);
  }

  final targetX = (fieldWidth - work.width) ~/ 2;
  final targetY = (fieldHeight - work.height) ~/ 2;
  final silhouette = work.padTo(
    width: fieldWidth,
    height: fieldHeight,
    dx: targetX,
    dy: targetY,
  );
  var slice = slicePolyomino(silhouette, seed: seed);
  if (config == SliceConfig.bigPieces) {
    slice = mergeAdjacentPieces(silhouette, slice);
  }
  return PreparedLevel(
    fieldWidth: fieldWidth,
    fieldHeight: fieldHeight,
    silhouette: silhouette,
    targetX: targetX,
    targetY: targetY,
    cellScale: cellScale,
    slice: slice,
  );
}

/// Сливает соседние куски [base] (нарезка [silhouette]) в более крупные:
/// проход 1 — пары нетронутых соседей с суммой ≤ 10; проход 2 — оставшиеся
/// нетронутые вливаются в любого соседа с суммой ≤ 12. Покрытие силуэта
/// сохраняется по построению. Детерминирован (без случайности).
///
/// Выбор партнёра: наименьший по размеру, при равенстве — наименьший id.
/// Участвовавшими считаются обе стороны слияния (в обоих проходах). Результат:
/// id 0..N-1 в порядке возрастания минимального линейного индекса клетки
/// (`y*width + x`) группы; `cells` нормализованы, `solution[id] = (minX, minY)`.
PackSlice mergeAdjacentPieces(TargetMask silhouette, PackSlice base) {
  final width = silhouette.width;

  // Группа = множество абсолютных клеток (линейные индексы).
  final groups = <int, Set<int>>{};
  for (final piece in base.pieces) {
    final origin = base.solution[piece.id]!;
    groups[piece.id] = {
      for (final c in piece.cells) (origin.y + c.y) * width + origin.x + c.x,
    };
  }

  bool adjacent(Set<int> a, Set<int> b) {
    for (final i in a) {
      final x = i % width;
      final neighbors = <int>[
        if (x > 0) i - 1,
        if (x < width - 1) i + 1,
        i - width,
        i + width,
      ];
      if (neighbors.any(b.contains)) return true;
    }
    return false;
  }

  /// Партнёр для [id] среди живых групп: подходит [accept], сумма размеров ≤
  /// [limit]; наименьший по размеру, при равенстве — наименьший id.
  int? pickPartner(int id, int limit, bool Function(int other) accept) {
    int? best;
    for (final other in groups.keys) {
      if (other == id || !accept(other)) continue;
      if (groups[id]!.length + groups[other]!.length > limit) continue;
      if (!adjacent(groups[id]!, groups[other]!)) continue;
      if (best == null ||
          groups[other]!.length < groups[best]!.length ||
          (groups[other]!.length == groups[best]!.length && other < best)) {
        best = other;
      }
    }
    return best;
  }

  final participated = <int>{};

  void absorb(int into, int gone) {
    groups[into]!.addAll(groups[gone]!);
    groups.remove(gone);
    participated
      ..add(into)
      ..add(gone);
  }

  final ids = [for (final p in base.pieces) p.id]..sort();

  // Проход 1.
  for (final id in ids) {
    if (!groups.containsKey(id) || participated.contains(id)) continue;
    final partner = pickPartner(
      id,
      10,
      (other) => !participated.contains(other),
    );
    if (partner != null) absorb(id, partner);
  }

  // Проход 2.
  for (final id in ids) {
    if (!groups.containsKey(id) || participated.contains(id)) continue;
    final partner = pickPartner(id, 12, (_) => true);
    if (partner != null) absorb(partner, id);
  }

  final ordered = groups.values.toList()
    ..sort((a, b) => _minOf(a).compareTo(_minOf(b)));
  final pieces = <PackPiece>[];
  final solution = <int, ({int x, int y})>{};
  for (var id = 0; id < ordered.length; id++) {
    final cells = ordered[id].toList()..sort();
    var minX = width;
    var minY = silhouette.height;
    for (final i in cells) {
      final x = i % width;
      final y = i ~/ width;
      if (x < minX) minX = x;
      if (y < minY) minY = y;
    }
    pieces.add(
      PackPiece(
        id: id,
        cells: [
          for (final i in cells) (x: i % width - minX, y: i ~/ width - minY),
        ],
      ),
    );
    solution[id] = (x: minX, y: minY);
  }
  return PackSlice(pieces: pieces, solution: solution);
}

int _minOf(Set<int> s) => s.reduce((a, b) => a < b ? a : b);

/// Связная половина детали: первые `ceil(n/2)` клеток BFS (4-соседство, порядок
/// соседей — вверх, влево, вправо, вниз) от клетки с минимальным `(y, x)`.
TargetMask _halfOf(TargetMask part) {
  final all = part.cells; // порядок: сверху вниз, слева направо
  final take = (all.length + 1) ~/ 2;
  final start = all.first;
  final visited = <({int x, int y})>{start};
  final order = <({int x, int y})>[start];
  for (var head = 0; head < order.length && order.length < take; head++) {
    final c = order[head];
    for (final n in <({int x, int y})>[
      (x: c.x, y: c.y - 1),
      (x: c.x - 1, y: c.y),
      (x: c.x + 1, y: c.y),
      (x: c.x, y: c.y + 1),
    ]) {
      if (order.length >= take) break;
      if (part.contains(n.x, n.y) && visited.add(n)) order.add(n);
    }
  }
  return _maskOf(order);
}

/// Огрубление 2×2: клетка блока есть, если в блоке ≥ 2 клеток детали; затем
/// наибольшая 4-связная компонента (при равенстве — с минимальной клеткой по
/// `(y, x)`), обрезка по bbox.
TargetMask _coarsen(TargetMask part) {
  final cw = (part.width + 1) ~/ 2;
  final ch = (part.height + 1) ~/ 2;
  final present = <({int x, int y})>{};
  for (var cy = 0; cy < ch; cy++) {
    for (var cx = 0; cx < cw; cx++) {
      var count = 0;
      for (final dy in const [0, 1]) {
        for (final dx in const [0, 1]) {
          if (part.contains(2 * cx + dx, 2 * cy + dy)) count++;
        }
      }
      if (count >= 2) present.add((x: cx, y: cy));
    }
  }

  // Компоненты в порядке минимальной клетки (y, x): обход сверху вниз.
  final seen = <({int x, int y})>{};
  var best = <({int x, int y})>[];
  for (var cy = 0; cy < ch; cy++) {
    for (var cx = 0; cx < cw; cx++) {
      final start = (x: cx, y: cy);
      if (!present.contains(start) || seen.contains(start)) continue;
      final comp = <({int x, int y})>[start];
      seen.add(start);
      for (var head = 0; head < comp.length; head++) {
        final c = comp[head];
        for (final n in <({int x, int y})>[
          (x: c.x, y: c.y - 1),
          (x: c.x - 1, y: c.y),
          (x: c.x + 1, y: c.y),
          (x: c.x, y: c.y + 1),
        ]) {
          if (present.contains(n) && seen.add(n)) comp.add(n);
        }
      }
      // Строго больше: при равенстве остаётся ранее найденная (мин. клетка).
      if (comp.length > best.length) best = comp;
    }
  }
  return _maskOf(best);
}

/// Маска по bbox заданных клеток.
TargetMask _maskOf(List<({int x, int y})> cells) {
  var minX = cells.first.x;
  var maxX = minX;
  var minY = cells.first.y;
  var maxY = minY;
  for (final c in cells) {
    if (c.x < minX) minX = c.x;
    if (c.x > maxX) maxX = c.x;
    if (c.y < minY) minY = c.y;
    if (c.y > maxY) maxY = c.y;
  }
  final set = cells.toSet();
  return TargetMask(
    rows: [
      for (var y = minY; y <= maxY; y++)
        [
          for (var x = minX; x <= maxX; x++)
            set.contains((x: x, y: y)) ? '#' : '.',
        ].join(),
    ],
  );
}
