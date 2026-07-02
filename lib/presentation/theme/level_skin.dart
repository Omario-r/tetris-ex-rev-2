import '../../game_engine/models/level_template.dart';
import 'block_material.dart';

/// Maps levels to block materials ("one level — one block type").
class LevelSkin {
  LevelSkin._();

  static const Map<int, BlockMaterial> _byLevelIndex = {
    0: BlockMaterial.planks,
    1: BlockMaterial.planks,
    2: BlockMaterial.cobble,
    3: BlockMaterial.cobble,
    4: BlockMaterial.sand,
    5: BlockMaterial.sand,
    6: BlockMaterial.sand,
    7: BlockMaterial.sand,
    8: BlockMaterial.stone,
    9: BlockMaterial.stone,
    10: BlockMaterial.stone,
    11: BlockMaterial.stone,
    12: BlockMaterial.bricks,
    13: BlockMaterial.bricks,
    14: BlockMaterial.bricks,
    15: BlockMaterial.bricks,
  };

  /// Returns the block material for [levelIndex] (0..15).
  static BlockMaterial materialForLevelIndex(int levelIndex) {
    assert(levelIndex >= 0 && levelIndex < 16);
    return _byLevelIndex[levelIndex]!;
  }

  /// Returns the block material for a [level] template.
  static BlockMaterial materialForLevel(LevelTemplate level) {
    return materialForObjectFragment(level.objectId, level.fragmentIndex);
  }

  /// Returns the block material for an object fragment pair.
  static BlockMaterial materialForObjectFragment(
    int objectId,
    int fragmentIndex,
  ) {
    final levelIndex = objectId * 4 + fragmentIndex;
    return materialForLevelIndex(levelIndex);
  }
}
