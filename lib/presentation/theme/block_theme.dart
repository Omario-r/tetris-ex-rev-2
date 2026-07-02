import 'block_material.dart';
import 'block_skin.dart';
import 'procedural_block_skin.dart';
import 'tnt_skin.dart';
import 'overlays.dart';

/// Single wiring point mapping block materials to their skins.
class BlockTheme {
  /// Creates a theme from a material-to-skin map.
  BlockTheme(this._skins);

  final Map<BlockMaterial, BlockSkin> _skins;

  /// Default Minecraft-style procedural theme.
  static final BlockTheme defaultTheme = BlockTheme({
    BlockMaterial.grass: const ProceduralBlockSkin(BlockMaterial.grass),
    BlockMaterial.cobble: const ProceduralBlockSkin(BlockMaterial.cobble),
    BlockMaterial.planks: const ProceduralBlockSkin(BlockMaterial.planks),
    BlockMaterial.bricks: const ProceduralBlockSkin(BlockMaterial.bricks),
    BlockMaterial.sand: const ProceduralBlockSkin(BlockMaterial.sand),
    BlockMaterial.stone: const ProceduralBlockSkin(BlockMaterial.stone),
    BlockMaterial.dirt: const ProceduralBlockSkin(BlockMaterial.dirt),
  });

  /// TNT skin for armed explosive pieces.
  static const TntSkin tnt = TntSkin();

  /// Ghost overlay for unfilled target cells.
  static const GhostTargetOverlay ghostTarget = GhostTargetOverlay();

  /// Warm overlay for occupied halo cells.
  static const HaloHighlightOverlay haloHighlight = HaloHighlightOverlay();

  /// Returns the skin for [material].
  BlockSkin of(BlockMaterial material) => _skins[material]!;

  /// Returns a copy with one material skin replaced (for testing).
  BlockTheme copyWithMaterial(BlockMaterial material, BlockSkin skin) {
    return BlockTheme({..._skins, material: skin});
  }
}
