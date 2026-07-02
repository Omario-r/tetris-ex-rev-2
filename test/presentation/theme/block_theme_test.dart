import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:explosive_tetris/presentation/theme/block_material.dart';
import 'package:explosive_tetris/presentation/theme/block_skin.dart';
import 'package:explosive_tetris/presentation/theme/block_theme.dart';
import 'package:explosive_tetris/presentation/theme/procedural_block_skin.dart';

class CountingSkin implements BlockSkin {
  CountingSkin(this.label);

  final String label;
  int calls = 0;

  @override
  void paint(Canvas canvas, Rect rect, {int? boardX, int? boardY}) {
    calls++;
  }
}

void main() {
  group('BlockTheme', () {
    test('of_returns_registered_skin', () {
      final counting = CountingSkin('grass');
      final theme = BlockTheme.defaultTheme.copyWithMaterial(
        BlockMaterial.grass,
        counting,
      );

      final canvas = Canvas(PictureRecorder());
      theme.of(BlockMaterial.grass).paint(canvas, const Rect.fromLTWH(0, 0, 10, 10));
      expect(counting.calls, 1);
    });

    test('copyWithMaterial_only_replaces_one_entry', () {
      final grassSkin = CountingSkin('grass');
      final cobbleSkin = CountingSkin('cobble');

      final theme = BlockTheme({
        BlockMaterial.grass: grassSkin,
        BlockMaterial.cobble: cobbleSkin,
        BlockMaterial.planks: const ProceduralBlockSkin(BlockMaterial.planks),
        BlockMaterial.bricks: const ProceduralBlockSkin(BlockMaterial.bricks),
        BlockMaterial.sand: const ProceduralBlockSkin(BlockMaterial.sand),
        BlockMaterial.stone: const ProceduralBlockSkin(BlockMaterial.stone),
        BlockMaterial.dirt: const ProceduralBlockSkin(BlockMaterial.dirt),
      });

      final replaced = theme.copyWithMaterial(
        BlockMaterial.grass,
        CountingSkin('new_grass'),
      );

      expect(replaced.of(BlockMaterial.grass), isNot(same(grassSkin)));
      expect(replaced.of(BlockMaterial.cobble), same(cobbleSkin));
    });

    test('defaultTheme_registers_all_materials', () {
      final canvas = Canvas(PictureRecorder());
      for (final material in BlockMaterial.values) {
        expect(
          () => BlockTheme.defaultTheme
              .of(material)
              .paint(canvas, const Rect.fromLTWH(0, 0, 16, 16)),
          returnsNormally,
        );
      }
    });
  });
}
