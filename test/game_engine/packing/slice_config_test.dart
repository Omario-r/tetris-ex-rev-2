import 'package:flutter_test/flutter_test.dart';
import 'package:explosive_tetris/game_engine/data/ronin_parts.dart';
import 'package:explosive_tetris/game_engine/models/target_mask.dart';
import 'package:explosive_tetris/game_engine/packing/pack_slicer.dart';
import 'package:explosive_tetris/game_engine/packing/slice_config.dart';

typedef _Cell = ({int x, int y});

/// Связность набора клеток по 4-соседству.
bool _isConnected(Set<_Cell> cells) {
  if (cells.isEmpty) return true;
  final visited = <_Cell>{cells.first};
  final stack = <_Cell>[cells.first];
  while (stack.isNotEmpty) {
    final c = stack.removeLast();
    for (final n in <_Cell>[
      (x: c.x - 1, y: c.y),
      (x: c.x + 1, y: c.y),
      (x: c.x, y: c.y - 1),
      (x: c.x, y: c.y + 1),
    ]) {
      if (cells.contains(n) && visited.add(n)) stack.add(n);
    }
  }
  return visited.length == cells.length;
}

/// Проверка общих инвариантов нарезки: куски нормализованы и связны, укладка по
/// `solution` покрывает силуэт ровно (без дыр, пересечений и выхода за силуэт).
void _expectExactCover(TargetMask silhouette, PackSlice slice) {
  final covered = <_Cell>{};
  var total = 0;
  expect(slice.solution.length, slice.pieces.length);
  for (var i = 0; i < slice.pieces.length; i++) {
    final piece = slice.pieces[i];
    expect(piece.id, i, reason: 'id кусков идут 0..N-1');
    final minX = piece.cells.map((c) => c.x).reduce((a, b) => a < b ? a : b);
    final minY = piece.cells.map((c) => c.y).reduce((a, b) => a < b ? a : b);
    expect(minX, 0, reason: 'кусок $i не нормализован по x');
    expect(minY, 0, reason: 'кусок $i не нормализован по y');
    expect(_isConnected(piece.cells.toSet()), isTrue, reason: 'кусок $i связен');
    final origin = slice.solution[piece.id]!;
    for (final c in piece.cells) {
      final abs = (x: origin.x + c.x, y: origin.y + c.y);
      expect(silhouette.contains(abs.x, abs.y), isTrue,
          reason: 'кусок $i вне силуэта');
      expect(covered.add(abs), isTrue, reason: 'пересечение кусков в $abs');
      total++;
    }
  }
  expect(total, silhouette.cells.length);
  expect(covered.length, silhouette.cells.length);
}

List<int> _sizes(PackSlice slice) => [for (final p in slice.pieces) p.size];

/// Страж «Крупных кусков» (Ронин-1/04 T3): результат `prepareLevel` на
/// канонном seed каждой из 19 деталей v3, снятый ДО добавления «Колючих кусков»
/// (в Ронин-1/10 T1 снят заново для масок и seed v3, D-016).
/// `id` детали → куски; кусок — отсортированные абсолютные клетки силуэта в поле
/// 10×14 (`y*10 + x`). Менять — только осознанно, вместе с пересмотром seed.
const _bigPiecesReference = <String, List<List<int>>>{
  'prow': [[50, 51, 52, 61, 62, 63, 71, 72], [53, 54, 55, 56, 64, 66, 76, 77], [57, 58, 59, 67, 68, 69, 79, 89], [60, 70, 73, 74, 80, 81, 82, 83, 84], [65, 75, 78, 85, 86, 87, 88]],
  'sensor': [[24, 34, 43, 44, 53, 54, 62, 63], [45, 55, 64, 65, 66, 73, 74, 75], [71, 72, 81, 82, 83, 84, 91, 101], [76, 77, 86, 87, 96, 97, 106, 107], [85, 92, 93, 94, 95, 102, 103, 104, 105]],
  'bridge_c': [[41, 42, 43, 44, 45, 51, 52, 60, 61, 62, 70, 71], [46, 54, 55, 56, 64, 65, 66], [47, 48, 57, 67, 75, 76, 77, 85], [53, 63, 72, 73, 74, 82, 83, 93], [78, 84, 86, 87, 88, 94, 95, 96, 97]],
  'bridge_l': [[41, 42, 43, 44, 45, 52, 53, 54], [46, 55, 56, 64, 65, 73, 74, 83], [51, 61, 62, 63, 71, 72, 81, 91], [75, 85, 86, 87, 95, 96, 97, 98], [82, 84, 92, 93, 94]],
  'bridge_r': [[42, 43, 44, 45, 46, 53, 55, 65], [47, 48, 57, 58, 67, 68, 77, 78, 87, 88, 98], [51, 52, 54, 61, 62, 63, 64, 73], [56, 66, 74, 75, 76, 84, 85, 86, 95, 96, 97], [72, 82, 83, 91, 92, 93, 94]],
  'visor_l': [[50, 51, 52, 53, 54, 61, 62, 64], [55, 56, 57, 58, 65, 66, 76], [59, 67, 68, 69, 77, 78, 79], [60, 63, 70, 71, 72, 73, 74, 75]],
  'visor_r': [[50, 51, 52, 53, 54, 55, 60, 61], [56, 65, 66, 67, 75, 76, 77], [57, 58, 59, 68, 69, 78, 79], [62, 63, 64, 70, 71, 72, 73, 74]],
  'fwd1_cl': [[30, 31, 32, 33, 40, 41, 42, 43], [34, 35, 36, 37, 38, 45, 48, 55], [44, 52, 53, 54, 62, 63, 64, 72], [46, 47, 49, 57, 58, 59, 67, 68], [51, 61, 71, 80, 81, 82, 90, 91, 92], [56, 65, 66, 74, 75, 76, 84, 86], [73, 83, 85, 87, 93, 94, 95, 96, 97], [77, 78, 88, 98, 99, 107, 108, 109]],
  'hatch_l': [[41, 42, 43, 44, 52, 54, 64, 74], [45, 46, 47, 55, 57, 65, 75, 85], [51, 53, 61, 62, 63, 71, 72, 73], [56, 66, 67, 76, 77, 86, 87, 97], [81, 82, 83, 84, 91, 92, 93, 94, 95, 96]],
  'fwd1_cr': [[30, 31, 32, 33, 34, 43, 44, 45], [35, 36, 37, 38, 39, 46, 47, 49], [41, 42, 51, 52, 53, 61, 62, 63], [48, 54, 55, 56, 57, 58, 64, 65], [60, 70, 71, 72, 73, 74, 80, 84], [66, 67, 68, 75, 76, 85, 86, 95], [77, 78, 87, 88, 89, 96, 97, 98, 99], [81, 82, 83, 91, 92, 93, 94]],
  'hatch_r': [[41, 42, 43, 44, 45, 46, 53, 56], [47, 54, 55, 57, 64, 65, 66, 67], [51, 52, 61, 62, 71, 72, 82, 83], [63, 73, 74, 75, 81, 84, 85, 91, 92, 93, 94], [76, 77, 86, 87, 95, 96, 97]],
  'fwd1_r': [[21, 22, 23, 24, 25, 31, 32, 42], [26, 27, 28, 34, 35, 36, 38, 48], [33, 43, 44, 52, 53, 54, 64, 74], [37, 45, 46, 47, 55, 56, 57, 66], [40, 41, 50, 51, 60, 61, 62, 71], [58, 65, 67, 68, 75, 76, 77, 78, 85, 86, 87, 88], [63, 72, 73, 81, 82, 83, 84, 92], [90, 91, 93, 94, 100, 101, 102, 103, 104]],
  'rcs_fr': [[22, 23, 24, 32, 33, 34, 42, 44], [41, 43, 51, 52, 53, 54, 61, 63], [45, 55, 56, 57, 65, 66, 67, 77], [62, 71, 72, 81, 82, 92, 102], [64, 73, 74, 75, 76, 83, 84, 85, 93, 94, 103, 104]],
  'fwd2_r': [[25, 26, 27, 28, 35, 36, 37, 46], [38, 47, 48, 57, 58, 66, 67, 68], [41, 42, 43, 44, 51, 52, 54, 61], [45, 55, 56, 64, 65, 74, 75, 76], [53, 62, 63, 72, 73, 82, 83, 92], [60, 70, 71, 81, 91, 93, 101, 102, 103], [77, 78, 85, 86, 87, 88, 98, 108], [84, 94, 95, 96, 97, 104, 105, 106, 107]],
  'fwd1_l': [[30, 31, 32, 40, 41, 42, 51, 52], [33, 34, 35, 36, 37, 44, 45, 46], [38, 47, 48, 57, 58, 59, 67, 68, 69, 77, 78, 79], [43, 53, 54, 55, 56, 63, 64, 65], [50, 60, 61, 70, 71, 80, 81, 82], [62, 72, 73, 74, 75, 83, 84, 94], [66, 76, 85, 86, 87, 88, 96, 97, 98, 106, 107, 108], [90, 91, 92, 93, 95, 103, 104, 105]],
  'rcs_fl': [[24, 25, 26, 34, 35, 36, 45, 46], [43, 44, 52, 53, 54, 62, 64, 65], [47, 55, 56, 57, 66, 67, 76, 77], [51, 61, 63, 71, 72, 73, 74, 75], [83, 84, 85, 86, 87, 94, 95, 96, 104, 105, 106]],
  'fwd2_l': [[20, 21, 22, 30, 31, 40, 50, 60], [32, 33, 34, 35, 36, 37, 42, 52], [38, 46, 47, 48, 49, 56, 59, 66], [41, 51, 61, 62, 71, 72, 82, 92], [43, 44, 45, 53, 54, 55, 63, 64], [57, 58, 67, 68, 69, 77, 87, 97], [65, 73, 74, 75, 83, 84, 93, 94], [70, 80, 81, 90, 91, 100, 101, 102], [76, 78, 86, 88, 96, 98, 99, 106, 107, 108, 109], [85, 95, 103, 104, 105]],
  'fwd2_cl': [[20, 21, 22, 23, 24, 30, 32, 33], [25, 26, 35, 36, 37, 45, 47, 55], [31, 41, 42, 51, 52, 61, 62, 72], [34, 43, 44, 53, 54, 63, 73, 74], [38, 39, 48, 49, 57, 58, 67, 77], [46, 56, 64, 65, 66, 75, 76, 85], [68, 78, 79, 89, 98, 99, 108], [70, 71, 80, 81, 82, 83, 92, 93], [84, 91, 94, 101, 102, 103, 104, 105], [86, 87, 88, 95, 96, 97, 106, 107]],
  'fwd2_cr': [[21, 22, 23, 31, 32, 33, 42, 43], [24, 25, 26, 27, 34, 35, 44, 45], [28, 36, 37, 38, 46, 47, 56, 57], [41, 50, 51, 52, 60, 61, 62, 71], [48, 49, 58, 59, 67, 68, 77, 78], [53, 63, 73, 83, 93, 103, 104], [54, 55, 64, 65, 74, 75, 84, 94], [66, 76, 85, 86, 87, 95, 105, 106], [72, 81, 82, 91, 92, 100, 101, 102], [88, 89, 96, 97, 98, 99, 107, 108, 109]],
};

List<List<int>> _absPieces(PackSlice slice) => [
  for (final piece in slice.pieces)
    [
      for (final c in piece.cells)
        (slice.solution[piece.id]!.y + c.y) * 10 +
            slice.solution[piece.id]!.x +
            c.x,
    ]..sort(),
];

void main() {
  const seeds = [0, 1, 2, 3, 4];

  group('prepareLevel', () {
    for (final part in RoninParts.parts) {
      for (final seed in {...seeds, part.seed}) {
        test('${part.id} seed $seed', () {
          final level = prepareLevel(part.mask, seed: seed);
          final again = prepareLevel(part.mask, seed: seed);
          final sil = level.silhouette;

          // Поле.
          expect((level.fieldWidth, level.fieldHeight), (10, 14));
          expect(sil.width, level.fieldWidth);
          expect(sil.height, level.fieldHeight);
          expect(sil.isWellFormed, isTrue);

          // Силуэт связен и центрирован по bbox.
          final silCells = {for (final c in sil.cells) c};
          expect(_isConnected(silCells), isTrue);
          final minX = silCells.map((c) => c.x).reduce((a, b) => a < b ? a : b);
          final minY = silCells.map((c) => c.y).reduce((a, b) => a < b ? a : b);
          expect(minX, level.targetX);
          expect(minY, level.targetY);

          // Покрытие кусками ровное.
          _expectExactCover(sil, level.slice);

          final sizes = _sizes(level.slice);
          expect(silCells.length, part.mask.cells.length);
          // Нижняя граница 5 и число кусков — гарантия только для канонного
          // seed детали (то, что видит игрок); на других seed слияние может
          // оставить кусок 3–4 клетки (Ронин-1/04 T1, находка в BACKLOG).
          final isCanonicalSeed = seed == part.seed;
          expect(sizes.every((s) => s <= 12), isTrue,
              reason: 'размеры $sizes');
          if (isCanonicalSeed) {
            expect(sizes.every((s) => s >= 5), isTrue,
                reason: 'размеры $sizes');
            expect(sizes.length, lessThanOrEqualTo(10),
                reason: 'размеры $sizes');
          }

          // Лоток: перестановка id, не порядок решения, детерминирован.
          final n = level.slice.pieces.length;
          final ids = [for (final p in level.slice.pieces) p.id];
          expect([...level.trayOrder]..sort(), ids);
          if (n >= 2) {
            expect(level.trayOrder, isNot([for (var i = 0; i < n; i++) i]),
                reason: 'лоток совпал с порядком решения');
          }
          expect(again.trayOrder, level.trayOrder);

          // Детерминизм.
          expect(again.silhouette.rows, sil.rows);
          expect(again.targetX, level.targetX);
          expect(again.targetY, level.targetY);
          expect(again.slice.solution, level.slice.solution);
          expect([for (final p in again.slice.pieces) p.cells],
              [for (final p in level.slice.pieces) p.cells]);
        });
      }
    }
  });

  group('prepareLevel · бюджет времени', () {
    // Отсечение тупиковых веток (Ронин-1/04 T2): нарезка любой детали на любом
    // seed 0..15 быстрая. Бюджет не ослаблять — выход за него это вопрос к
    // генератору или разметке (эскалация).
    const budget = Duration(milliseconds: 500);
    // Прогрев JIT одним вызовом.
    prepareLevel(RoninParts.parts[0].mask, seed: 0);

    for (final part in RoninParts.parts) {
      test('${part.id} × seed 0..15 ≤ ${budget.inMilliseconds} мс', () {
        for (var seed = 0; seed <= 15; seed++) {
          final sw = Stopwatch()..start();
          prepareLevel(part.mask, seed: seed);
          sw.stop();
          expect(sw.elapsed, lessThan(budget),
              reason: '${part.id} seed $seed: ${sw.elapsedMilliseconds} мс');
        }
      });
    }
  });

  group('«Крупные куски» — канонные нарезки деталей v3 не меняются', () {
    for (final part in RoninParts.parts) {
      test('${part.id} seed ${part.seed}: совпадает с эталоном', () {
        final slice = prepareLevel(part.mask, seed: part.seed).slice;
        expect(_absPieces(slice), _bigPiecesReference[part.id]);
      });
    }
  });

  group('mergeAdjacentPieces', () {
    const rect = TargetMask(rows: ['####', '####', '####']);

    test('прямоугольник 4×3: покрытие ровное, суммы ≤ 12', () {
      for (final seed in seeds) {
        final base = slicePolyomino(rect, seed: seed);
        final merged = mergeAdjacentPieces(rect, base);
        _expectExactCover(rect, merged);
        expect(merged.pieces.every((p) => p.size <= 12), isTrue);
        expect(merged.pieces.length, lessThanOrEqualTo(base.pieces.length));
      }
    });

    test('детерминирован и не меняет исходную нарезку', () {
      final base = slicePolyomino(rect, seed: 1);
      final before = _sizes(base);
      final a = mergeAdjacentPieces(rect, base);
      final b = mergeAdjacentPieces(rect, base);
      expect(_sizes(base), before);
      expect(a.solution, b.solution);
      expect([for (final p in a.pieces) p.cells],
          [for (final p in b.pieces) p.cells]);
    });

    test('куски упорядочены по минимальной клетке (y*width+x)', () {
      const mask = TargetMask(rows: [
        '######',
        '######',
        '######',
        '######',
      ]);
      final merged = mergeAdjacentPieces(mask, slicePolyomino(mask, seed: 2));
      _expectExactCover(mask, merged);
      var prev = -1;
      for (final p in merged.pieces) {
        final o = merged.solution[p.id]!;
        // Минимальная клетка куска: первая строка куска, наименьший x в ней.
        final topX = p.cells.where((c) => c.y == 0).map((c) => c.x).reduce(
              (a, b) => a < b ? a : b,
            );
        final idx = o.y * mask.width + o.x + topX;
        expect(idx, greaterThan(prev));
        prev = idx;
      }
    });
  });
}
