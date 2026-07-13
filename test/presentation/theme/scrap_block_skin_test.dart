import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:explosive_tetris/presentation/theme/block_paint_utils.dart';
import 'package:explosive_tetris/presentation/theme/block_skin.dart';
import 'package:explosive_tetris/presentation/theme/scrap_block_skin.dart';

/// Dummy skin for comparing noise sampling behavior.
class CountingNoiseSkin implements BlockSkin {
  CountingNoiseSkin();

  final List<double> noiseValues = [];

  @override
  void paint(ui.Canvas canvas, ui.Rect rect, {int? boardX, int? boardY}) {
    // Sample noise at same positions as ScrapBlockSkin
    noiseValues.add(BlockPaintUtils.noise(boardX ?? 0, boardY ?? 0, 1, 0));
    noiseValues.add(BlockPaintUtils.noise(boardX ?? 0, boardY ?? 0, 2, 0));
    noiseValues.add(BlockPaintUtils.noise(boardX ?? 0, boardY ?? 0, 3, 0));
  }
}

void main() {
  group('ScrapBlockSkin', () {
    test('paint_without_exception', () {
      final skin = ScrapBlockSkin();

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      expect(
        () => skin.paint(canvas, const Rect.fromLTWH(0, 0, 100, 100)),
        returnsNormally,
      );
    });

    test('deterministic_with_same_coords', () {
      final skin = ScrapBlockSkin();
      final skin2 = ScrapBlockSkin();

      // Two canvases for same coordinates
      final recorder1 = ui.PictureRecorder();
      final canvas1 = Canvas(recorder1);
      skin.paint(canvas1, const Rect.fromLTWH(0, 0, 100, 100), boardX: 5, boardY: 10);

      final recorder2 = ui.PictureRecorder();
      final canvas2 = Canvas(recorder2);
      skin2.paint(canvas2, const Rect.fromLTWH(0, 0, 100, 100), boardX: 5, boardY: 10);

      // Both should produce valid pictures
      expect(() => recorder1.endRecording(), returnsNormally);
      expect(() => recorder2.endRecording(), returnsNormally);
    });

    test('noise_samples_are_deterministic', () {
      final skin1 = CountingNoiseSkin();
      final skin2 = CountingNoiseSkin();

      // Same coordinates should produce same noise values
      final recorder1 = ui.PictureRecorder();
      final canvas1 = Canvas(recorder1);
      skin1.paint(canvas1, const Rect.fromLTWH(0, 0, 100, 100), boardX: 3, boardY: 7);

      final recorder2 = ui.PictureRecorder();
      final canvas2 = Canvas(recorder2);
      skin2.paint(canvas2, const Rect.fromLTWH(0, 0, 100, 100), boardX: 3, boardY: 7);

      expect(skin1.noiseValues, equals(skin2.noiseValues));
    });
  });
}
