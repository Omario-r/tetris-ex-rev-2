import 'package:flutter_test/flutter_test.dart';
import 'package:explosive_tetris/game_engine/data/ship_parts.dart';
import 'package:explosive_tetris/game_engine/packing/pack_controller.dart';
import 'package:explosive_tetris/game_engine/packing/pack_state.dart';
import 'package:explosive_tetris/game_engine/packing/pack_slicer.dart';

/// Доказывает «каждая дев-деталь корабля нарезается и укладывается новым
/// ядром» (критерий приёмки Стори 03): для КАЖДОЙ детали `ShipParts.parts[i]`
/// и сидов 0/1/2 — нарезка не бросает, куски валидны (размер 3..5,
/// суммарная площадь == площадь маски), а эталонное решение (`slice.solution`)
/// укладывается через `PackController.place` до `isComplete`.
void main() {
  for (var i = 0; i < ShipParts.parts.length; i++) {
    final part = ShipParts.parts[i];
    final mask = part.mask;
    final maskArea = mask.cells.length;

    group('деталь $i (${mask.width}x${mask.height})', () {
      for (final seed in [0, 1, 2]) {
        test('seed $seed: нарезка валидна + эталон укладывается до isComplete',
            () {
          final slice = slicePolyomino(mask, seed: seed);

          var totalSize = 0;
          for (final piece in slice.pieces) {
            expect(piece.size, inInclusiveRange(3, 5),
                reason: 'кусок ${piece.id} размера ${piece.size}');
            totalSize += piece.size;
          }
          expect(totalSize, equals(maskArea),
              reason: 'суммарная площадь кусков == площадь маски');

          final controller = PackController(
            PackState(
              silhouette: mask,
              placements: const {},
              pieces: slice.pieces,
              trayOrder: [for (final piece in slice.pieces) piece.id],
            ),
          );

          for (final entry in slice.solution.entries) {
            controller.place(entry.key, entry.value.x, entry.value.y);
          }

          expect(controller.state.isComplete, isTrue,
              reason: 'эталонное решение обязано укладываться без дыр');
        });
      }
    });
  }
}
