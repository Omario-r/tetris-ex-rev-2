import 'dart:math' as math;

import '../models/target_mask.dart';
import 'pack_piece.dart';
import 'pack_slicer.dart';

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

  /// Нарезка [silhouette] (координаты поля).
  final PackSlice slice;

  /// Порядок кусков в лотке: перестановка id кусков [slice] от seed уровня.
  ///
  /// Зачем (D-007): id кусков растут по минимальной клетке, то есть порядок id
  /// совпадает с порядком решения; лоток «по id» подсказывал бы, куда класть
  /// следующий кусок. Перемешивание детерминировано (один seed — один порядок)
  /// и никогда не равно порядку по возрастанию id (при `N >= 2`).
  final List<int> trayOrder;

  const PreparedLevel({
    required this.fieldWidth,
    required this.fieldHeight,
    required this.silhouette,
    required this.targetX,
    required this.targetY,
    required this.slice,
    required this.trayOrder,
  });
}

const int _fullFieldWidth = 10;
const int _fullFieldHeight = 14;

/// Из маски детали [partMask] (bbox-маска `RoninPartDef.mask`) и [seed] строит
/// готовый уровень: нарезка 3..5, затем слияние соседних кусков в 5..12 клеток
/// («Крупные куски», D-006; поле 10×14, клетка 34; ожидаемо 7–10 кусков).
/// Детерминирован: одни и те же аргументы дают побитово одинаковый результат.
PreparedLevel prepareLevel(TargetMask partMask, {required int seed}) {
  const fieldWidth = _fullFieldWidth;
  const fieldHeight = _fullFieldHeight;

  final targetX = (fieldWidth - partMask.width) ~/ 2;
  final targetY = (fieldHeight - partMask.height) ~/ 2;
  final silhouette = partMask.padTo(
    width: fieldWidth,
    height: fieldHeight,
    dx: targetX,
    dy: targetY,
  );
  final slice = mergeAdjacentPieces(
    silhouette,
    slicePolyomino(silhouette, seed: seed),
  );
  return PreparedLevel(
    fieldWidth: fieldWidth,
    fieldHeight: fieldHeight,
    silhouette: silhouette,
    targetX: targetX,
    targetY: targetY,
    slice: slice,
    trayOrder: _shuffledTrayOrder(slice, seed),
  );
}

/// Перемешанный порядок id кусков [slice] для лотка (см. [PreparedLevel.trayOrder]).
/// ГСЧ лотка отличается от ГСЧ нарезки (`Random(seed)`) произвольными константами.
List<int> _shuffledTrayOrder(PackSlice slice, int seed) {
  final ids = [for (final p in slice.pieces) p.id]..sort();
  final order = List<int>.of(ids)..shuffle(math.Random(seed * 7919 + 17));
  var sorted = true;
  for (var i = 0; i < order.length; i++) {
    if (order[i] != ids[i]) {
      sorted = false;
      break;
    }
  }
  if (sorted && order.length >= 2) {
    order.add(order.removeAt(0));
  }
  return order;
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
      if (best == null) {
        best = other;
        continue;
      }
      if (groups[other]!.length < groups[best]!.length ||
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
