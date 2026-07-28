import 'package:flutter_test/flutter_test.dart';
import 'package:explosive_tetris/game_engine/models/target_mask.dart';
import 'package:explosive_tetris/game_engine/packing/pack_piece.dart';
import 'package:explosive_tetris/game_engine/packing/pack_state.dart';

// Силуэт 2×2, все клетки заняты (0xF = 0b1111, MSB-first, все биты — 1).
const _fullSquare = TargetMask(rows: ['##', '##']);

const _rowA = PackPiece(id: 0, cells: [(x: 0, y: 0), (x: 1, y: 0)]);
const _rowB = PackPiece(id: 1, cells: [(x: 0, y: 0), (x: 1, y: 0)]);

void main() {
  group('PackState.occupiedCells', () {
    test('пусто без размещений', () {
      final state = PackState(
        silhouette: _fullSquare,
        placements: const {},
        pieces: const [_rowA, _rowB],
        trayOrder: const [0, 1],
      );

      expect(state.occupiedCells, isEmpty);
    });

    test('клетка кусочка + origin', () {
      final state = PackState(
        silhouette: _fullSquare,
        placements: const {0: (x: 0, y: 1)},
        pieces: const [_rowA, _rowB],
        trayOrder: const [1],
      );

      expect(state.occupiedCells, {(x: 0, y: 1), (x: 1, y: 1)});
    });
  });

  group('PackState.isComplete', () {
    test('полное покрытие без дыр и пересечений → true', () {
      final state = PackState(
        silhouette: _fullSquare,
        placements: const {0: (x: 0, y: 0), 1: (x: 0, y: 1)},
        pieces: const [_rowA, _rowB],
        trayOrder: const [],
      );

      expect(state.isComplete, isTrue);
    });

    test('дыра (не все клетки покрыты) → false', () {
      final state = PackState(
        silhouette: _fullSquare,
        placements: const {0: (x: 0, y: 0)},
        pieces: const [_rowA, _rowB],
        trayOrder: const [1],
      );

      expect(state.isComplete, isFalse);
    });

    test('пересечение одной и той же клетки → false', () {
      // Обе строки уложены в одну и ту же origin — покрывают одни и те же
      // клетки дважды, а (0,1)/(1,1) остаются непокрытыми. Такое состояние
      // недостижимо через PackController (валидация в place/move это
      // запрещает), но isComplete должен корректно распознать его как
      // незавершённое, если построено напрямую.
      final state = PackState(
        silhouette: _fullSquare,
        placements: const {0: (x: 0, y: 0), 1: (x: 0, y: 0)},
        pieces: const [_rowA, _rowB],
        trayOrder: const [],
      );

      expect(state.isComplete, isFalse);
    });
  });
}
