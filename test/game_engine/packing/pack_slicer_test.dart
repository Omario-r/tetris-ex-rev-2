import 'package:flutter_test/flutter_test.dart';
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
}
