import 'package:flutter_test/flutter_test.dart';

import 'package:explosive_tetris/game_engine/models/level_template.dart';
import 'package:explosive_tetris/game_engine/models/target_mask.dart';
import 'package:explosive_tetris/presentation/theme/block_material.dart';
import 'package:explosive_tetris/presentation/theme/level_skin.dart';

void main() {
  group('LevelSkin', () {
    test('early_fragments_use_graphite', () {
      expect(LevelSkin.materialForLevelIndex(0), BlockMaterial.graphite);
      expect(LevelSkin.materialForLevelIndex(1), BlockMaterial.graphite);
    });

    test('next_fragments_use_graphite_dark', () {
      expect(LevelSkin.materialForLevelIndex(2), BlockMaterial.graphiteDark);
      expect(LevelSkin.materialForLevelIndex(3), BlockMaterial.graphiteDark);
    });

    test('placeholder_objects_use_single_material_each', () {
      for (var i = 4; i < 8; i++) {
        expect(LevelSkin.materialForLevelIndex(i), BlockMaterial.gunmetal);
      }
      for (var i = 8; i < 12; i++) {
        expect(LevelSkin.materialForLevelIndex(i), BlockMaterial.darkNiche);
      }
      for (var i = 12; i < 16; i++) {
        expect(LevelSkin.materialForLevelIndex(i), BlockMaterial.hazardOrange);
      }
    });

    test('materialForLevel_matches_levelIndex_table', () {
      // Чистая функция темы (objectId/fragmentIndex → материал); level template
      // строим напрямую, не завязываясь на реальное число уровней в LevelMap.
      for (var objectId = 0; objectId < 4; objectId++) {
        for (var fragmentIndex = 0; fragmentIndex < 4; fragmentIndex++) {
          final levelIndex = objectId * 4 + fragmentIndex;
          final level = LevelTemplate(
            boardWidth: 10,
            boardHeight: 20,
            targetMask: defaultTargetMask,
            targetX: 2,
            targetY: 14,
            objectId: objectId,
            fragmentIndex: fragmentIndex,
          );
          expect(
            LevelSkin.materialForLevel(level),
            LevelSkin.materialForLevelIndex(levelIndex),
          );
        }
      }
    });

    test('materialForObjectFragment_matches_levelIndex', () {
      for (var objectId = 0; objectId < 4; objectId++) {
        for (var fragmentIndex = 0; fragmentIndex < 4; fragmentIndex++) {
          final levelIndex = objectId * 4 + fragmentIndex;
          expect(
            LevelSkin.materialForObjectFragment(objectId, fragmentIndex),
            LevelSkin.materialForLevelIndex(levelIndex),
          );
        }
      }
    });
  });
}
