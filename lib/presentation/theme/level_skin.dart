import '../../game_engine/models/level_template.dart';
import 'block_material.dart';

/// Maps levels to block materials ("one level — one block type").
class LevelSkin {
  LevelSkin._();

  static const Map<int, BlockMaterial> _byLevelIndex = {
    0: BlockMaterial.graphite,
    1: BlockMaterial.graphite,
    2: BlockMaterial.graphiteDark,
    3: BlockMaterial.graphiteDark,
    4: BlockMaterial.gunmetal,
    5: BlockMaterial.gunmetal,
    6: BlockMaterial.gunmetal,
    7: BlockMaterial.gunmetal,
    8: BlockMaterial.darkNiche,
    9: BlockMaterial.darkNiche,
    10: BlockMaterial.darkNiche,
    11: BlockMaterial.darkNiche,
    12: BlockMaterial.hazardOrange,
    13: BlockMaterial.hazardOrange,
    14: BlockMaterial.hazardOrange,
    15: BlockMaterial.hazardOrange,
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
