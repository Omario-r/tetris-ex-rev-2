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
}
