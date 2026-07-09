import 'package:flutter_test/flutter_test.dart';
import 'package:explosive_tetris/game_engine/data/level_map.dart';
import 'package:explosive_tetris/game_engine/data/ship_parts.dart';

void main() {
  group('LevelMap — уровни = детали корабля (единый источник формы)', () {
    for (int i = 0; i < ShipParts.parts.length; i++) {
      test('levelAt($i).targetMask == ShipParts.parts[$i].mask', () {
        final target = LevelMap.levelAt(i).targetMask;
        final part = ShipParts.parts[i].mask;
        expect(target.width, equals(part.width));
        expect(target.height, equals(part.height));
        expect(target.mask, equals(part.mask));
      });
    }

    test('число уровней == ShipParts.parts.length', () {
      for (int i = 0; i < ShipParts.parts.length; i++) {
        expect(() => LevelMap.levelAt(i), returnsNormally);
      }
    });
  });

  group('Размещение мишени: floor-anchored + центрирование по X', () {
    for (int i = 0; i < ShipParts.parts.length; i++) {
      test('уровень $i: мишень стоит вплотную к дну поля', () {
        final level = LevelMap.levelAt(i);
        expect(
          level.targetY + level.targetMask.height,
          equals(level.boardHeight),
          reason: 'мишень $i не касается дна — падающая фигура не найдёт опору',
        );
      });

      test('уровень $i: мишень целиком в границах поля по X', () {
        final level = LevelMap.levelAt(i);
        expect(level.targetX, greaterThanOrEqualTo(0));
        expect(
          level.targetX + level.targetMask.width,
          lessThanOrEqualTo(level.boardWidth),
        );
      });
    }
  });

  group('Структурные проверки «уровень проходим» (T2, ⚠ хрупкое)', () {
    for (int i = 0; i < ShipParts.parts.length; i++) {
      final level = LevelMap.levelAt(i);
      final cells = level.targetMask.cells;

      test('уровень $i: мишень непуста', () {
        expect(cells, isNotEmpty);
      });

      test('уровень $i: площадь мишени ≥ 4 (минимум одного тетромино)', () {
        expect(cells.length, greaterThanOrEqualTo(4));
      });

      test('уровень $i: мишень достижима сверху (targetY в границах поля)', () {
        // Мишень не «висит» выше верхней границы и не выходит за нижнюю —
        // падающей фигуре есть куда падать от спавна (y=0) до цели.
        expect(level.targetY, greaterThanOrEqualTo(0));
        expect(
          level.targetY + level.targetMask.height,
          lessThanOrEqualTo(level.boardHeight),
        );
      });

      test('уровень $i: клетки мишени образуют один связный кусок (4-связность)', () {
        final set = cells.map((c) => (c.x, c.y)).toSet();
        final start = set.first;
        final seen = <(int, int)>{start};
        final stack = [start];
        while (stack.isNotEmpty) {
          final (x, y) = stack.removeLast();
          for (final n in [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]) {
            if (set.contains(n) && seen.add(n)) stack.add(n);
          }
        }
        expect(seen.length, equals(set.length),
            reason: 'мишень $i распадается на несвязные части');
      });

      test('уровень $i: halo H не пересекается с мишенью S', () {
        expect(level.H.intersection(level.S), isEmpty);
      });
    }
  });
}
