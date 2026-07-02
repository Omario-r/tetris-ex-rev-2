import 'package:flutter_test/flutter_test.dart';

import 'package:explosive_tetris/game_engine/data/level_map.dart';
import 'package:explosive_tetris/presentation/theme/block_material.dart';
import 'package:explosive_tetris/presentation/theme/level_skin.dart';

void main() {
  group('LevelSkin', () {
    test('house_roof_fragments_use_planks', () {
      expect(LevelSkin.materialForLevelIndex(0), BlockMaterial.planks);
      expect(LevelSkin.materialForLevelIndex(1), BlockMaterial.planks);
    });

    test('house_wall_fragments_use_cobble', () {
      expect(LevelSkin.materialForLevelIndex(2), BlockMaterial.cobble);
      expect(LevelSkin.materialForLevelIndex(3), BlockMaterial.cobble);
    });

    test('placeholder_objects_use_single_material_each', () {
      for (var i = 4; i < 8; i++) {
        expect(LevelSkin.materialForLevelIndex(i), BlockMaterial.sand);
      }
      for (var i = 8; i < 12; i++) {
        expect(LevelSkin.materialForLevelIndex(i), BlockMaterial.stone);
      }
      for (var i = 12; i < 16; i++) {
        expect(LevelSkin.materialForLevelIndex(i), BlockMaterial.bricks);
      }
    });

    test('materialForLevel_matches_levelIndex_table', () {
      for (var i = 0; i < 16; i++) {
        final level = LevelMap.levelAt(i);
        expect(
          LevelSkin.materialForLevel(level),
          LevelSkin.materialForLevelIndex(i),
        );
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
