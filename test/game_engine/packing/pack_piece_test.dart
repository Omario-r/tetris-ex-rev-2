import 'package:flutter_test/flutter_test.dart';
import 'package:explosive_tetris/game_engine/packing/pack_piece.dart';

void main() {
  group('PackPiece', () {
    test('конструктор сохраняет id и cells', () {
      const piece = PackPiece(
        id: 1,
        cells: [(x: 0, y: 0), (x: 1, y: 0), (x: 0, y: 1)],
      );

      expect(piece.id, 1);
      expect(piece.cells, [(x: 0, y: 0), (x: 1, y: 0), (x: 0, y: 1)]);
    });

    test('size == число клеток', () {
      const piece = PackPiece(
        id: 0,
        cells: [(x: 0, y: 0), (x: 1, y: 0), (x: 2, y: 0), (x: 0, y: 1)],
      );

      expect(piece.size, 4);
    });

    test('нормализованный кусочек имеет min x == 0 и min y == 0', () {
      const piece = PackPiece(
        id: 2,
        cells: [(x: 0, y: 0), (x: 1, y: 0), (x: 1, y: 1)],
      );

      final minX = piece.cells.map((c) => c.x).reduce((a, b) => a < b ? a : b);
      final minY = piece.cells.map((c) => c.y).reduce((a, b) => a < b ? a : b);

      expect(minX, 0);
      expect(minY, 0);
    });
  });
}
