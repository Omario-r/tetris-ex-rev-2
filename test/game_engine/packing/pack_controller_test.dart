import 'package:flutter_test/flutter_test.dart';
import 'package:explosive_tetris/game_engine/models/target_mask.dart';
import 'package:explosive_tetris/game_engine/packing/pack_controller.dart';
import 'package:explosive_tetris/game_engine/packing/pack_piece.dart';
import 'package:explosive_tetris/game_engine/packing/pack_state.dart';

// Силуэт 2×2, все клетки заняты; два кусочка по 2 клетки (верхняя и
// нижняя строка квадрата) — минимальная фикстура для полной укладки.
const _fullSquare = TargetMask(width: 2, height: 2, mask: 0xF);

const _rowA = PackPiece(id: 0, cells: [(x: 0, y: 0), (x: 1, y: 0)]);
const _rowB = PackPiece(id: 1, cells: [(x: 0, y: 0), (x: 1, y: 0)]);

PackController _freshController() {
  return PackController(
    PackState(
      silhouette: _fullSquare,
      placements: const {},
      pieces: const [_rowA, _rowB],
      trayOrder: const [0, 1],
    ),
  );
}

void main() {
  group('PackController.place', () {
    test('валидное размещение кладёт кусочек и убирает из лотка', () {
      final controller = _freshController();

      controller.place(0, 0, 0);

      expect(controller.state.placements, {0: (x: 0, y: 0)});
      expect(controller.state.trayOrder, [1]);
    });

    test('невалидное — вне силуэта — no-op', () {
      final controller = _freshController();

      // origin x=-1: одна клетка кусочка (x=-1) выходит за силуэт.
      controller.place(0, -1, 0);

      expect(controller.state.placements, isEmpty);
      expect(controller.state.trayOrder, [0, 1]);
    });

    test('невалидное — пересечение с уже уложенным — no-op', () {
      final controller = _freshController();
      controller.place(0, 0, 0);

      controller.place(1, 0, 0);

      expect(controller.state.placements, {0: (x: 0, y: 0)});
      expect(controller.state.trayOrder, [1]);
    });

    test('пустышка — id не в лотке (уже уложен) — no-op', () {
      final controller = _freshController();
      controller.place(0, 0, 0);

      controller.place(0, 0, 1);

      expect(controller.state.placements, {0: (x: 0, y: 0)});
    });
  });

  group('PackController.move', () {
    test('перекладывает уложенный кусочек в новую валидную позицию', () {
      final controller = _freshController();
      controller.place(0, 0, 0);

      controller.move(0, 0, 1);

      expect(controller.state.placements, {0: (x: 0, y: 1)});
    });

    test('невалидная позиция — no-op, кусочек остаётся на месте', () {
      final controller = _freshController();
      controller.place(0, 0, 0);

      controller.move(0, -1, 0);

      expect(controller.state.placements, {0: (x: 0, y: 0)});
    });

    test('не уложенный кусочек — no-op', () {
      final controller = _freshController();

      controller.move(0, 0, 0);

      expect(controller.state.placements, isEmpty);
      expect(controller.state.trayOrder, [0, 1]);
    });
  });

  group('PackController.remove', () {
    test('возвращает уложенный кусочек в конец лотка', () {
      final controller = _freshController();
      controller.place(0, 0, 0);
      controller.place(1, 0, 1);

      controller.remove(0);

      expect(controller.state.placements, {1: (x: 0, y: 1)});
      expect(controller.state.trayOrder, [0]);
    });

    test('не уложенный кусочек — no-op', () {
      final controller = _freshController();

      controller.remove(0);

      expect(controller.state.placements, isEmpty);
      expect(controller.state.trayOrder, [0, 1]);
    });
  });

  group('Полное заполнение фикстуры', () {
    test('оба кусочка уложены → isComplete == true', () {
      final controller = _freshController();

      controller.place(0, 0, 0);
      controller.place(1, 0, 1);

      expect(controller.state.isComplete, isTrue);
      expect(controller.state.trayOrder, isEmpty);
    });
  });
}
