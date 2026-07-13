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
      final counting = CountingSkin('graphite');
      final theme = BlockTheme.defaultTheme.copyWithMaterial(
        BlockMaterial.graphite,
        counting,
      );

      final canvas = Canvas(PictureRecorder());
      theme
          .of(BlockMaterial.graphite)
          .paint(canvas, const Rect.fromLTWH(0, 0, 10, 10));
      expect(counting.calls, 1);
    });

    test('copyWithMaterial_only_replaces_one_entry', () {
      final graphiteSkin = CountingSkin('graphite');
      final graphiteDarkSkin = CountingSkin('graphiteDark');

      final theme = BlockTheme({
        BlockMaterial.graphite: graphiteSkin,
        BlockMaterial.graphiteDark: graphiteDarkSkin,
        BlockMaterial.darkNiche:
            const ProceduralBlockSkin(BlockMaterial.darkNiche),
        BlockMaterial.hazardOrange:
            const ProceduralBlockSkin(BlockMaterial.hazardOrange),
        BlockMaterial.rust: const ProceduralBlockSkin(BlockMaterial.rust),
        BlockMaterial.gunmetal:
            const ProceduralBlockSkin(BlockMaterial.gunmetal),
        BlockMaterial.matteBlack:
            const ProceduralBlockSkin(BlockMaterial.matteBlack),
      });

      final replaced = theme.copyWithMaterial(
        BlockMaterial.graphite,
        CountingSkin('new_graphite'),
      );

      expect(replaced.of(BlockMaterial.graphite), isNot(same(graphiteSkin)));
      expect(replaced.of(BlockMaterial.graphiteDark), same(graphiteDarkSkin));
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
