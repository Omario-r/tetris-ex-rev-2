import 'block_material.dart';
import 'block_skin.dart';
import 'procedural_block_skin.dart';
import 'overlays.dart';

/// Single wiring point mapping block materials to their skins.
class BlockTheme {
  /// Creates a theme from a material-to-skin map.
  BlockTheme(this._skins);

  final Map<BlockMaterial, BlockSkin> _skins;

  /// Default voxel-space procedural theme (own style, "Ronin" palette).
  static final BlockTheme defaultTheme = BlockTheme({
    BlockMaterial.graphite: const ProceduralBlockSkin(BlockMaterial.graphite),
    BlockMaterial.graphiteDark:
        const ProceduralBlockSkin(BlockMaterial.graphiteDark),
    BlockMaterial.darkNiche:
        const ProceduralBlockSkin(BlockMaterial.darkNiche),
    BlockMaterial.hazardOrange:
        const ProceduralBlockSkin(BlockMaterial.hazardOrange),
    BlockMaterial.rust: const ProceduralBlockSkin(BlockMaterial.rust),
    BlockMaterial.gunmetal: const ProceduralBlockSkin(BlockMaterial.gunmetal),
    BlockMaterial.matteBlack:
        const ProceduralBlockSkin(BlockMaterial.matteBlack),
  });

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
