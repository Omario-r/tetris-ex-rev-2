import 'dart:math' as math;

import '../models/target_mask.dart';
import 'pack_piece.dart';

/// Результат нарезки силуэта: кусочки (для лотка) + эталонная раскладка.
///
/// [pieces] — кусочки с уникальными id (0..N-1), `cells` НОРМАЛИЗОВАНЫ
/// (`min x == 0`, `min y == 0`). [solution] — `pieceId → origin` в координатах
/// силуэта: положив каждый кусок в его origin, получаем полное покрытие силуэта
/// без дыр и пересечений (решение существует по построению). T3 использует
/// [solution] как «известно решаемое» начальное состояние.
class PackSlice {
  /// Кусочки с уникальными id (0..N-1), cells НОРМАЛИЗОВАНЫ (min x=0, min y=0).
  final List<PackPiece> pieces;

  /// pieceId → origin в координатах силуэта: положив каждый кусок в его origin,
  /// получаем полное покрытие силуэта без дыр/пересечений (решение существует).
  final Map<int, ({int x, int y})> solution;

  const PackSlice({required this.pieces, required this.solution});
}

/// Детерминированно режет силуэт [silhouette] на связные (4-соседство)
/// полиомино-кусочки по 3..5 клеток, покрывающие силуэт полностью и без
/// пересечений.
///
/// Детерминизм: всё случайное (порядок перебора кандидатов) берётся из одного
/// `math.Random(seed)`, протянутого через весь алгоритм. При равном [seed]
/// возвращает побитово идентичный [PackSlice]. `seed == null` → `Random()`
/// (недетерминирован).
///
/// Алгоритм — полный бэктрекинг-DFS (не жадное выращивание):
/// 1. Все клетки покрыты → успех.
/// 2. Якорь = непокрытая клетка с минимальным линейным индексом `y*width + x`
///    (детерминированный выбор) — гарантирует, что якорь всегда покрывается
///    формируемым куском (не остаётся сирота).
/// 3. Перебираются все связные подмножества непокрытых клеток, содержащие якорь,
///    размера 3, 4 и 5 в порядке размеров [4, 5, 3] (антивырождение: размер 3 —
///    крайняя мера). Внутри одного размера кандидаты перемешиваются единым
///    `Random(seed)`.
/// 4. Для каждого кандидата: пометить покрытым, записать кусок, рекурсивно решить
///    остаток; успех — вернуть, неудача — откатить и пробовать следующего.
///
/// Куски нормализуются: `origin = (minX, minY)` абсолютных клеток куска,
/// `PackPiece.cells = абсолютные − origin`, `solution[id] = origin`. id — счётчик
/// 0..N-1 в порядке нахождения кусков (детерминирован при фиксированном seed).
///
/// Предусловия: силуэт непуст (≥ 3 клеток) и связен по 4-соседству — все игровые
/// маски валидны (проверяется `assert`). Если разбиение не найдено (не должно
/// случаться на валидном контенте) — бросает [StateError]: генератор обязан
/// резать валидный силуэт, это НЕ штатный no-op. Поведение на невалидном
/// (пустом/несвязном/слишком мелком) силуэте не гарантируется.
PackSlice slicePolyomino(TargetMask silhouette, {int? seed}) {
  final cells = silhouette.cells;
  assert(
    cells.length >= 3,
    'Силуэт должен содержать ≥ 3 клеток для нарезки на куски 3..5.',
  );
  final width = silhouette.width;
  final height = silhouette.height;
  final all = <int>{for (final c in cells) c.y * width + c.x};
  assert(
    _isConnected(all, width, height),
    'Силуэт должен быть связным по 4-соседству.',
  );

  final rng = seed != null ? math.Random(seed) : math.Random();
  final raw = _Slicer(width, height, all, rng).solve();
  if (raw == null) {
    throw StateError(
      'Не удалось нарезать силуэт на связные куски 3..5 клеток '
      '(${cells.length} клеток, ${width}x$height). Силуэт неразрезаем при '
      'данных ограничениях.',
    );
  }

  final pieces = <PackPiece>[];
  final solution = <int, ({int x, int y})>{};
  for (var id = 0; id < raw.length; id++) {
    pieces.add(PackPiece(id: id, cells: raw[id].cells));
    solution[id] = raw[id].origin;
  }
  return PackSlice(pieces: pieces, solution: solution);
}

/// Кусок в процессе нарезки: нормализованные клетки + origin в силуэте.
class _RawPiece {
  final List<({int x, int y})> cells;
  final ({int x, int y}) origin;
  const _RawPiece(this.cells, this.origin);
}

/// Состояние бэктрекинг-DFS. Клетки — линейные индексы `y*width + x`.
class _Slicer {
  final int width;
  final int height;
  final Set<int> all;
  final math.Random rng;
  final Set<int> covered = <int>{};
  final List<_RawPiece> result = <_RawPiece>[];

  /// Порядок перебора размеров куска: 4 и 5 предпочтительнее, 3 — крайняя мера
  /// (антивырождение против россыпи мелочи).
  static const List<int> _sizeOrder = [4, 5, 3];

  _Slicer(this.width, this.height, this.all, this.rng);

  List<_RawPiece>? solve() => _run() ? result : null;

  bool _run() {
    if (covered.length == all.length) return true;

    final anchor = _minUncovered();
    final uncovered = <int>{
      for (final i in all)
        if (!covered.contains(i)) i,
    };

    final candidates = <List<int>>[];
    for (final size in _sizeOrder) {
      if (uncovered.length < size) continue;
      final subs = _connectedSubsets(anchor, size, uncovered);
      // Каноничный порядок до перемешивания — для воспроизводимости при seed.
      subs.sort(_compareCells);
      subs.shuffle(rng);
      candidates.addAll(subs);
    }

    for (final cand in candidates) {
      for (final c in cand) {
        covered.add(c);
      }
      result.add(_normalize(cand));
      if (_run()) return true;
      result.removeLast();
      for (final c in cand) {
        covered.remove(c);
      }
    }
    return false;
  }

  /// Непокрытая клетка с минимальным линейным индексом.
  int _minUncovered() {
    int? best;
    for (final i in all) {
      if (!covered.contains(i) && (best == null || i < best)) best = i;
    }
    return best!;
  }

  /// Все связные (4-соседство) подмножества [uncovered] размера [size],
  /// содержащие [anchor]. Без дубликатов.
  List<List<int>> _connectedSubsets(int anchor, int size, Set<int> uncovered) {
    final results = <List<int>>[];
    final seen = <String>{};
    final current = <int>[anchor];
    final currentSet = <int>{anchor};

    void grow() {
      if (current.length == size) {
        final sorted = [...current]..sort();
        if (seen.add(sorted.join(','))) results.add(sorted);
        return;
      }
      final frontier = <int>{};
      for (final c in currentSet) {
        for (final n in _neighbors(c)) {
          if (uncovered.contains(n) && !currentSet.contains(n)) frontier.add(n);
        }
      }
      for (final f in frontier) {
        currentSet.add(f);
        current.add(f);
        grow();
        current.removeLast();
        currentSet.remove(f);
      }
    }

    grow();
    return results;
  }

  /// Индексы соседей клетки [idx] по 4-соседству в пределах окна.
  List<int> _neighbors(int idx) {
    final x = idx % width;
    final y = idx ~/ width;
    return <int>[
      if (x > 0) idx - 1,
      if (x < width - 1) idx + 1,
      if (y > 0) idx - width,
      if (y < height - 1) idx + width,
    ];
  }

  /// Нормализует абсолютные клетки [cand] к origin (minX, minY).
  _RawPiece _normalize(List<int> cand) {
    var minX = width;
    var minY = height;
    for (final i in cand) {
      final x = i % width;
      final y = i ~/ width;
      if (x < minX) minX = x;
      if (y < minY) minY = y;
    }
    final cells = <({int x, int y})>[
      for (final i in cand) (x: i % width - minX, y: i ~/ width - minY),
    ];
    return _RawPiece(cells, (x: minX, y: minY));
  }

  /// Лексикографическое сравнение двух отсортированных списков индексов.
  static int _compareCells(List<int> a, List<int> b) {
    for (var i = 0; i < a.length && i < b.length; i++) {
      final d = a[i] - b[i];
      if (d != 0) return d;
    }
    return a.length - b.length;
  }
}

/// true, если множество [cells] (линейные индексы) связно по 4-соседству.
bool _isConnected(Set<int> cells, int width, int height) {
  if (cells.isEmpty) return true;
  final start = cells.first;
  final visited = <int>{start};
  final stack = <int>[start];
  while (stack.isNotEmpty) {
    final c = stack.removeLast();
    final x = c % width;
    final y = c ~/ width;
    for (final n in <int>[
      if (x > 0) c - 1,
      if (x < width - 1) c + 1,
      if (y > 0) c - width,
      if (y < height - 1) c + width,
    ]) {
      if (cells.contains(n) && visited.add(n)) stack.add(n);
    }
  }
  return visited.length == cells.length;
}
