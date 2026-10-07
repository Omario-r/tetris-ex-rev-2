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

void main() {
  const seeds = [0, 1, 2, 3, 4];

  for (final config in SliceConfig.values) {
    group('prepareLevel · ${config.name}', () {
      for (final part in RoninParts.parts) {
        for (final seed in seeds) {
          test('${part.id} seed $seed', () {
            final level = prepareLevel(part.mask, config, seed: seed);
            final sil = level.silhouette;

            // Поле и масштаб.
            switch (config) {
              case SliceConfig.bigPieces:
              case SliceConfig.halfPart:
                expect((level.fieldWidth, level.fieldHeight), (10, 14));
                expect(level.cellScale, 1);
              case SliceConfig.coarseCell:
                expect((level.fieldWidth, level.fieldHeight), (5, 7));
                expect(level.cellScale, 2);
            }
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
            switch (config) {
              case SliceConfig.bigPieces:
                expect(silCells.length, part.mask.cells.length);
                expect(sizes.every((s) => s >= 5 && s <= 12), isTrue,
                    reason: 'размеры $sizes');
                expect(sizes.length, lessThanOrEqualTo(10),
                    reason: 'размеры $sizes');
              case SliceConfig.halfPart:
                expect(silCells.length, (part.mask.cells.length + 1) ~/ 2);
                expect(sizes.every((s) => s >= 3 && s <= 5), isTrue,
                    reason: 'размеры $sizes');
                expect(sizes.length, lessThanOrEqualTo(11),
                    reason: 'размеры $sizes');
              case SliceConfig.coarseCell:
                expect(sizes.every((s) => s >= 3 && s <= 5), isTrue,
                    reason: 'размеры $sizes');
                expect(sizes.length, lessThanOrEqualTo(7),
                    reason: 'размеры $sizes');
            }

            // Детерминизм.
            final again = prepareLevel(part.mask, config, seed: seed);
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
  }

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
