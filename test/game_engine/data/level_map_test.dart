import 'package:flutter_test/flutter_test.dart';
import 'package:explosive_tetris/game_engine/data/level_map.dart';
import 'package:explosive_tetris/game_engine/data/ronin_parts.dart';

void main() {
  group('LevelMap — уровни = детали «Ронина» на фиксированном поле 10×14', () {
    test('поле фиксировано 10×14 (LevelMap.fieldWidth/fieldHeight)', () {
      expect(LevelMap.fieldWidth, 10);
      expect(LevelMap.fieldHeight, 14);
    });

    test('число уровней == RoninParts.parts.length', () {
      for (int i = 0; i < RoninParts.parts.length; i++) {
        expect(() => LevelMap.levelAt(i), returnsNormally);
      }
    });

    for (int i = 0; i < RoninParts.parts.length; i++) {
      final part = RoninParts.parts[i];

      test('уровень $i: поле уровня — 10×14, деталь order ${part.order}', () {
        final level = LevelMap.levelAt(i);
        expect(level.boardWidth, LevelMap.fieldWidth);
        expect(level.boardHeight, LevelMap.fieldHeight);
        expect(level.fragmentIndex, i);
      });

      test('уровень $i: мишень отцентрована в поле по обеим осям', () {
        final level = LevelMap.levelAt(i);
        final expectedX = (LevelMap.fieldWidth - part.mask.width) ~/ 2;
        final expectedY = (LevelMap.fieldHeight - part.mask.height) ~/ 2;
        expect(level.targetX, expectedX);
        expect(level.targetY, expectedY);
      });

      test('уровень $i: targetMask — размера поля, деталь вложена по padTo',
          () {
        final level = LevelMap.levelAt(i);
        expect(level.targetMask.width, LevelMap.fieldWidth);
        expect(level.targetMask.height, LevelMap.fieldHeight);

        final expectedMask = part.mask.padTo(
          width: LevelMap.fieldWidth,
          height: LevelMap.fieldHeight,
          dx: level.targetX,
          dy: level.targetY,
        );
        expect(level.targetMask.rows, equals(expectedMask.rows));
      });

      test('уровень $i: число клеток мишени совпадает с part.cells', () {
        final level = LevelMap.levelAt(i);
        expect(level.targetMask.cells.length, part.cells);
      });

      test('уровень $i: мишень целиком внутри поля', () {
        final level = LevelMap.levelAt(i);
        expect(level.targetX, greaterThanOrEqualTo(0));
        expect(level.targetY, greaterThanOrEqualTo(0));
        expect(
          level.targetX + part.mask.width,
          lessThanOrEqualTo(level.boardWidth),
        );
        expect(
          level.targetY + part.mask.height,
          lessThanOrEqualTo(level.boardHeight),
        );
      });
    }
  });
}
