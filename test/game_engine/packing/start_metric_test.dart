import 'package:flutter_test/flutter_test.dart';
import 'package:explosive_tetris/game_engine/data/ronin_parts.dart';
import 'package:explosive_tetris/game_engine/models/target_mask.dart';
import 'package:explosive_tetris/game_engine/packing/pack_piece.dart';
import 'package:explosive_tetris/game_engine/packing/pack_slicer.dart';
import 'package:explosive_tetris/game_engine/packing/slice_config.dart';
import 'package:explosive_tetris/game_engine/packing/start_metric.dart';

void main() {
  group('startMetric', () {
    test('силуэт 3×3, один вертикальный кусок-I 3×1: 3 места', () {
      const silhouette = TargetMask(rows: ['###', '###', '###']);
      final slice = PackSlice(
        pieces: const [
          PackPiece(id: 0, cells: [(x: 0, y: 0), (x: 0, y: 1), (x: 0, y: 2)]),
        ],
        solution: const {0: (x: 0, y: 0)},
      );
      final metric = startMetric(silhouette, slice);
      expect(metric.placesPerPiece, 3);
      expect(metric.minPlaces, 3);
    });

    test('среднее по кускам и минимум: I-кусок (3) и уголок (4 места)', () {
      const silhouette = TargetMask(rows: ['###', '###', '###']);
      final slice = PackSlice(
        pieces: const [
          PackPiece(id: 0, cells: [(x: 0, y: 0), (x: 0, y: 1), (x: 0, y: 2)]),
          PackPiece(id: 1, cells: [(x: 0, y: 0), (x: 1, y: 0), (x: 0, y: 1)]),
        ],
        solution: const {0: (x: 0, y: 0), 1: (x: 1, y: 0)},
      );
      final metric = startMetric(silhouette, slice);
      expect(metric.placesPerPiece, 3.5);
      expect(metric.minPlaces, 3);
    });
  });

  group('рамп сложности старта (разметка v3, канонные seed)', () {
    for (final part in RoninParts.parts) {
      test('${part.id} (seed ${part.seed}) в полосе своей группы', () {
        final level = prepareLevel(part.mask, seed: part.seed);
        final metric = startMetric(level.silhouette, level.slice);
        final reason =
            'places/piece ${metric.placesPerPiece}, min ${metric.minPlaces}';
        if (part.layer == 1) {
          // Предметы.
          expect(metric.placesPerPiece, lessThanOrEqualTo(15), reason: reason);
        } else if (part.module == 'fwd') {
          // Плиты пояса.
          expect(metric.placesPerPiece, inInclusiveRange(22, 40),
              reason: reason);
        } else {
          // Нос и мостик.
          expect(metric.placesPerPiece, lessThanOrEqualTo(15), reason: reason);
          expect(metric.minPlaces, lessThanOrEqualTo(8), reason: reason);
        }
      });
    }
  });
}
