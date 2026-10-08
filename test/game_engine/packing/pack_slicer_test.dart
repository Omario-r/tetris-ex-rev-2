import 'package:flutter_test/flutter_test.dart';
import 'package:explosive_tetris/game_engine/data/ronin_parts.dart';
import 'package:explosive_tetris/game_engine/data/ship_parts.dart';
import 'package:explosive_tetris/game_engine/models/target_mask.dart';
import 'package:explosive_tetris/game_engine/packing/pack_piece.dart';
import 'package:explosive_tetris/game_engine/packing/pack_slicer.dart';

/// Обязательный набор масок для проверки нарезки (все 4).
final _masks = <(String, TargetMask)>[
  ('крест 6×6 (defaultTargetMask)', defaultTargetMask),
  ('верхний корпус 4×3 (parts[1])', ShipParts.parts[1].mask),
  ('нос 4×2 (parts[0])', ShipParts.parts[0].mask),
  ('двигатель 4×2 (parts[5])', ShipParts.parts[5].mask),
];

/// Абсолютные клетки куска = нормализованные cells + origin из solution.
Set<({int x, int y})> _absCells(PackPiece piece, ({int x, int y}) origin) => {
  for (final c in piece.cells) (x: origin.x + c.x, y: origin.y + c.y),
};

/// Связность куска по 4-соседству (по локальным нормализованным клеткам).
bool _isPieceConnected(PackPiece piece) {
  final cells = piece.cells.toSet();
  if (cells.isEmpty) return true;
  final start = piece.cells.first;
  final visited = <({int x, int y})>{start};
  final stack = <({int x, int y})>[start];
  while (stack.isNotEmpty) {
    final c = stack.removeLast();
    for (final n in <({int x, int y})>[
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

/// Проверка равенства двух нарезок (для детерминизма).
bool _sliceEquals(PackSlice a, PackSlice b) {
  if (a.pieces.length != b.pieces.length) return false;
  for (var i = 0; i < a.pieces.length; i++) {
    final pa = a.pieces[i];
    final pb = b.pieces[i];
    if (pa.id != pb.id) return false;
    if (pa.cells.length != pb.cells.length) return false;
    for (var j = 0; j < pa.cells.length; j++) {
      if (pa.cells[j] != pb.cells[j]) return false;
    }
  }
  if (a.solution.length != b.solution.length) return false;
  for (final entry in a.solution.entries) {
    if (b.solution[entry.key] != entry.value) return false;
  }
  return true;
}

/// Страж канонных нарезок 15 деталей «Ронина» v2 (Ронин-1/04 T2): нарезка на
/// канонном seed детали не должна меняться молча при будущих правках
/// генератора. Снимок сделан ПОСЛЕ отсечения тупиковых веток (отсечение
/// изменило нарезку пяти деталей относительно версии без него, решение
/// Постановщика: новые нарезки приняты как канон). `id` детали → куски; кусок —
/// отсортированные абсолютные клетки силуэта в поле 10×14 (`y*10 + x`).
/// Менять эталон — только осознанно, вместе с пересмотром seed и рампа.
const _referenceSlices = <String, List<List<int>>>{
  'prow': [[40, 41, 51, 52], [42, 43, 44, 53], [45, 55, 65, 66], [46, 47, 56, 57], [48, 49, 58, 68], [50, 60, 61, 70], [54, 63, 64, 73], [59, 69, 78, 79], [62, 71, 72, 82], [67, 74, 75, 76, 77], [83, 92, 93]],
  'sensor': [[24, 34, 44, 54], [43, 53, 62, 63], [45, 55, 65, 66], [64, 73, 74, 75], [71, 81, 91, 101], [72, 82, 83, 84], [76, 86, 96, 106], [77, 87, 97, 107], [85, 93, 94, 95], [92, 102, 103, 104, 105]],
  'bridge_c': [[44, 45, 46, 56], [47, 48, 57, 67], [54, 64, 74, 75], [55, 65, 66, 76], [60, 70, 71, 72], [73, 82, 83, 93], [77, 85, 86, 87], [78, 79, 88], [84, 94, 95, 96, 97]],
  'bridge_l': [[41, 42, 52, 53], [43, 44, 45, 54], [46, 55, 56, 65], [51, 61, 62, 63], [64, 73, 74, 83], [71, 72, 81, 91], [75, 85, 86, 87], [82, 84, 92, 93, 94], [95, 96, 97, 98]],
  'bridge_r': [[42, 43, 53, 54], [44, 45, 55, 65], [46, 56, 57, 67], [47, 48, 58, 68], [51, 52, 61, 62], [63, 64, 74, 75], [66, 76, 86, 87], [73, 82, 83, 84], [77, 78, 88, 98], [85, 95, 96, 97], [91, 92, 93, 94]],
  'fwd1_cl': [[30, 31, 40, 41], [32, 33, 42, 43], [34, 35, 45, 55], [36, 37, 38, 48], [44, 53, 54, 64], [46, 47, 57, 67], [49, 58, 59, 68], [51, 61, 71, 81], [52, 62, 63, 72], [56, 66, 76, 86], [65, 74, 75, 84], [73, 83, 93, 94], [77, 78, 88, 98], [80, 82, 90, 91, 92], [85, 87, 95, 96, 97], [99, 107, 108, 109]],
  'fwd1_cr': [[30, 31, 32, 33], [34, 43, 44, 45], [35, 36, 46, 47], [37, 38, 39, 49], [41, 42, 52, 53], [48, 56, 57, 58], [51, 61, 62, 63], [54, 55, 64, 65], [60, 70, 71, 80], [66, 67, 68, 76], [72, 73, 74, 84], [75, 85, 86, 95], [77, 78, 88, 89], [81, 82, 91, 92], [83, 93, 94], [87, 96, 97, 98, 99]],
  'fwd1_r': [[21, 31, 32, 42], [22, 23, 24, 25], [26, 34, 35, 36], [27, 28, 38, 48], [33, 43, 52, 53], [37, 46, 47, 57], [40, 41, 50, 60], [44, 54, 64, 74], [45, 55, 56, 66], [51, 61, 62, 71], [58, 67, 68, 77], [63, 73, 83, 84], [65, 75, 76, 85], [72, 81, 82, 92], [78, 86, 87, 88], [91, 100, 101, 102], [93, 94, 103, 104]],
  'rcs_fr': [[22, 23, 32, 42], [24, 33, 34, 44], [41, 51, 52, 61], [43, 53, 54, 63], [45, 55, 56, 65], [57, 66, 67, 77], [62, 71, 72, 81], [64, 74, 75, 76], [73, 83, 93, 103], [82, 92, 102], [84, 85, 94, 104]],
  'fwd2_r': [[25, 35, 36, 46], [26, 27, 28, 37], [38, 48, 58, 68], [40, 41, 42, 52], [43, 44, 45, 54], [47, 57, 66, 67], [50, 51, 61, 62], [53, 63, 72, 73], [55, 56, 64, 65], [70, 71, 80, 81], [74, 75, 84, 85], [76, 77, 78, 88], [82, 83, 92, 93], [86, 95, 96, 106], [87, 97, 98, 107, 108], [90, 91, 100, 101], [94, 102, 103, 104, 105]],
  'fwd1_l': [[30, 40, 41, 51], [31, 32, 42, 52], [33, 34, 35, 44], [36, 37, 45, 46], [38, 47, 48, 58], [43, 53, 63, 64], [50, 60, 70, 80], [54, 55, 56, 65], [57, 67, 77, 78], [59, 68, 69, 79], [61, 71, 81, 82], [62, 72, 73, 83], [66, 76, 85, 86], [74, 75, 84, 94], [87, 88, 96, 97], [90, 91, 92, 93], [95, 103, 104, 105], [98, 106, 107, 108]],
  'rcs_fl': [[24, 25, 34, 35], [26, 36, 45, 46], [43, 52, 53, 62], [44, 54, 64, 65], [47, 57, 67, 77], [51, 61, 71, 72], [55, 56, 66, 76], [63, 73, 74, 75], [83, 84, 85, 94], [86, 87, 96, 106], [95, 104, 105]],
  'fwd2_l': [[20, 21, 30, 31], [22, 32, 33, 43], [34, 35, 45, 46], [36, 37, 47, 57], [38, 48, 49, 58], [40, 50, 60, 70], [41, 51, 61, 71], [42, 52, 62, 72], [44, 53, 54, 64], [55, 65, 74, 75], [56, 66, 76, 86], [63, 73, 83, 84], [67, 68, 77, 78], [80, 81, 82, 92], [85, 95, 96, 97], [87, 88, 98, 108], [90, 91, 100, 101], [93, 94, 102, 103], [104, 105, 106, 107]],
  'fwd2_cl': [[20, 21, 30, 31], [22, 23, 33, 34], [24, 25, 26, 36], [32, 42, 52, 62], [35, 45, 55, 65], [37, 38, 39, 47], [41, 51, 61, 71], [43, 53, 63, 73], [44, 54, 64, 74], [46, 56, 66, 76], [48, 57, 58, 68], [50, 60, 70, 80], [67, 77, 78, 79], [72, 82, 83, 84], [75, 85, 95, 105], [81, 91, 92, 102], [86, 96, 106, 107], [87, 88, 97, 98, 108], [90, 100, 101], [93, 94, 103, 104]],
  'fwd2_cr': [[21, 31, 32, 33], [22, 23, 24, 25], [26, 35, 36, 45], [27, 37, 47, 57], [28, 29, 38, 48], [34, 43, 44, 53], [40, 50, 60, 61], [41, 42, 51, 52], [46, 56, 66, 67], [54, 64, 73, 74], [55, 65, 75, 85], [58, 68, 69, 78], [62, 63, 71, 72], [76, 77, 86, 96], [80, 81, 91, 92], [82, 83, 93, 103], [84, 94, 95, 104], [87, 88, 98, 108], [90, 100, 101, 102], [97, 105, 106, 107]],
};

void main() {
  for (final (name, mask) in _masks) {
    group('slicePolyomino — $name', () {
      final silhouetteCells = mask.cells.toSet();

      for (var seed = 0; seed <= 9; seed++) {
        test('seed $seed: покрытие/непересечение/размеры/связность/нормализация/id',
            () {
          final slice = slicePolyomino(mask, seed: seed);

          // Покрытие: объединение абсолютных клеток == все клетки силуэта.
          final union = <({int x, int y})>{};
          var totalSize = 0;
          for (final piece in slice.pieces) {
            final origin = slice.solution[piece.id];
            expect(origin, isNotNull, reason: 'у куска ${piece.id} нет origin');
            union.addAll(_absCells(piece, origin!));
            totalSize += piece.size;
          }
          expect(union, equals(silhouetteCells),
              reason: 'полное покрытие без дыр');

          // Непересечение: сумма размеров == число клеток силуэта.
          expect(totalSize, equals(silhouetteCells.length),
              reason: 'непересечение кусков');

          for (final piece in slice.pieces) {
            // Размеры 3..5.
            expect(piece.size, inInclusiveRange(3, 5),
                reason: 'кусок ${piece.id} размера ${piece.size}');
            // Связность.
            expect(_isPieceConnected(piece), isTrue,
                reason: 'кусок ${piece.id} несвязен');
            // Нормализация: min x == 0 && min y == 0.
            final minX = piece.cells.map((c) => c.x).reduce((a, b) => a < b ? a : b);
            final minY = piece.cells.map((c) => c.y).reduce((a, b) => a < b ? a : b);
            expect(minX, 0, reason: 'кусок ${piece.id} не нормализован по x');
            expect(minY, 0, reason: 'кусок ${piece.id} не нормализован по y');
          }

          // id уникальны, 0..N-1.
          final ids = slice.pieces.map((p) => p.id).toList()..sort();
          expect(ids, equals(List.generate(slice.pieces.length, (i) => i)));
        });
      }

      test('детерминизм: seed 3 дважды → идентичный PackSlice', () {
        final a = slicePolyomino(mask, seed: 3);
        final b = slicePolyomino(mask, seed: 3);
        expect(_sliceEquals(a, b), isTrue);
      });
    });
  }

  group('slicePolyomino — антивырождение (крест 6×6)', () {
    for (var seed = 0; seed <= 9; seed++) {
      test('seed $seed: доля кусков размера 3 ≤ 0.5', () {
        final slice = slicePolyomino(defaultTargetMask, seed: seed);
        final size3 = slice.pieces.where((p) => p.size == 3).length;
        final fraction = size3 / slice.pieces.length;
        expect(fraction, lessThanOrEqualTo(0.5),
            reason: 'доля size-3 = $fraction (${slice.pieces.length} кусков)');
      });
    }
  });

  group('slicePolyomino — страж канонных нарезок (разметка v2)', () {
    for (final part in RoninParts.parts) {
      test('${part.id} seed ${part.seed}: нарезка совпадает с эталоном', () {
        final m = part.mask;
        final silhouette = m.padTo(
          width: 10,
          height: 14,
          dx: (10 - m.width) ~/ 2,
          dy: (14 - m.height) ~/ 2,
        );
        final slice = slicePolyomino(silhouette, seed: part.seed);
        final actual = <List<int>>[];
        for (final piece in slice.pieces) {
          final origin = slice.solution[piece.id]!;
          actual.add([
            for (final c in piece.cells) (origin.y + c.y) * 10 + origin.x + c.x,
          ]..sort());
        }
        expect(actual, _referenceSlices[part.id]);
      });
    }
  });
}
