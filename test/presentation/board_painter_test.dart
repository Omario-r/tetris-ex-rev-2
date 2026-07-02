import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:explosive_tetris/game_engine/game/game_state.dart';
import 'package:explosive_tetris/game_engine/models/board.dart';
import 'package:explosive_tetris/game_engine/models/falling_piece.dart';
import 'package:explosive_tetris/game_engine/models/level_template.dart';
import 'package:explosive_tetris/game_engine/models/piece.dart';
import 'package:explosive_tetris/game_engine/rules/randomizer.dart';
import 'package:explosive_tetris/presentation/theme/block_material.dart';
import 'package:explosive_tetris/presentation/theme/block_skin.dart';
import 'package:explosive_tetris/presentation/theme/block_theme.dart';
import 'package:explosive_tetris/presentation/theme/tnt_skin.dart';
import 'package:explosive_tetris/presentation/widgets/board_painter.dart';

class CountingSkin implements BlockSkin {
  CountingSkin(this.name);

  final String name;
  int calls = 0;
  final List<(int?, int?)> coords = [];

  @override
  void paint(Canvas canvas, Rect rect, {int? boardX, int? boardY}) {
    calls++;
    coords.add((boardX, boardY));
  }
}

class TestBlockTheme extends BlockTheme {
  TestBlockTheme({required this.levelSkin})
      : super({
          BlockMaterial.grass: levelSkin,
          BlockMaterial.cobble: levelSkin,
          BlockMaterial.planks: levelSkin,
          BlockMaterial.bricks: levelSkin,
          BlockMaterial.sand: levelSkin,
          BlockMaterial.stone: levelSkin,
          BlockMaterial.dirt: levelSkin,
        });

  final CountingSkin levelSkin;
}

/// Creates a [GameState] with an empty board and no falling piece.
GameState createEmptyState() {
  return GameState(
    board: Board(defaultLevel.boardWidth, defaultLevel.boardHeight),
    fallingPiece: null,
    phase: GamePhase.spawning,
    generator: SevenBagGenerator(seed: 42),
    level: defaultLevel,
  );
}

/// Creates a [GameState] with a block placed in the Halo region.
GameState createStateWithHaloBlock() {
  final board = Board(defaultLevel.boardWidth, defaultLevel.boardHeight);
  final haloCell = defaultLevel.H.first;
  board.setCell(haloCell.$1, haloCell.$2, const Cell.occupied());
  return GameState(
    board: board,
    fallingPiece: null,
    phase: GamePhase.spawning,
    generator: SevenBagGenerator(seed: 42),
    level: defaultLevel,
  );
}

/// Creates a [GameState] with an occupied board cell.
GameState createStateWithPlacedBlock(int x, int y) {
  final board = Board(defaultLevel.boardWidth, defaultLevel.boardHeight);
  board.setCell(x, y, const Cell.occupied());
  return GameState(
    board: board,
    fallingPiece: null,
    phase: GamePhase.spawning,
    generator: SevenBagGenerator(seed: 42),
    level: defaultLevel,
  );
}

/// Creates a [GameState] with an explosive I-piece at the specified position.
GameState createStateWithExplosivePiece(int x, int y) {
  final board = Board(defaultLevel.boardWidth, defaultLevel.boardHeight);
  final piece = PieceFactory.create(PieceType.I);
  final fallingPiece = FallingPiece(
    piece: piece,
    x: x,
    y: y,
    mode: PieceMode.explosive,
  );
  return GameState(
    board: board,
    fallingPiece: fallingPiece,
    phase: GamePhase.falling,
    generator: SevenBagGenerator(seed: 42),
    level: defaultLevel,
  );
}

BoardPainter createPainter(
  GameState state, {
  BlockTheme? theme,
  BlockMaterial levelMaterial = BlockMaterial.planks,
  CountingSkin? levelSkinCounter,
}) {
  final levelSkin = levelSkinCounter ?? CountingSkin('level');
  final themeToUse = theme ??
      TestBlockTheme(levelSkin: levelSkin);

  return BoardPainter(
    state: state,
    cellSize: 30.0,
    theme: themeToUse,
    levelMaterial: levelMaterial,
  );
}

void main() {
  group('BoardPainter', () {
    testWidgets('paints_without_exception', (WidgetTester tester) async {
      final state = createEmptyState();
      final painter = createPainter(state);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      expect(
        () => painter.paint(canvas, const Size(300.0, 600.0)),
        returnsNormally,
      );
    });

    test('shouldRepaint_false_same_state', () {
      final state = createEmptyState();
      final levelSkin = CountingSkin('level');
      final theme = TestBlockTheme(levelSkin: levelSkin);
      final painter1 = BoardPainter(
        state: state,
        cellSize: 30.0,
        theme: theme,
        levelMaterial: BlockMaterial.planks,
      );
      final painter2 = BoardPainter(
        state: state,
        cellSize: 30.0,
        theme: theme,
        levelMaterial: BlockMaterial.planks,
      );

      expect(painter1.shouldRepaint(painter2), isFalse);
    });

    test('shouldRepaint_true_different_state', () {
      final emptyState = createEmptyState();
      final stateWithBlock = createStateWithHaloBlock();

      final painter1 = createPainter(emptyState);
      final painter2 = createPainter(stateWithBlock);

      expect(painter1.shouldRepaint(painter2), isTrue);
    });

    testWidgets('explosive_piece_does_not_throw', (WidgetTester tester) async {
      final state = createStateWithExplosivePiece(3, 0);
      final painter = createPainter(state);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      expect(
        () => painter.paint(canvas, const Size(300.0, 600.0)),
        returnsNormally,
      );
    });

    testWidgets('dirty_halo_does_not_throw', (WidgetTester tester) async {
      final state = createStateWithHaloBlock();
      final painter = createPainter(state);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      expect(
        () => painter.paint(canvas, const Size(300.0, 600.0)),
        returnsNormally,
      );
    });

    test('placed_cells_use_level_material_skin', () {
      final levelSkin = CountingSkin('level');
      final state = createStateWithPlacedBlock(3, 5);
      final painter = createPainter(
        state,
        levelSkinCounter: levelSkin,
        levelMaterial: BlockMaterial.planks,
      );

      final recorder = ui.PictureRecorder();
      painter.paint(Canvas(recorder), const Size(300, 600));

      expect(levelSkin.calls, greaterThan(0));
    });

    test('explosive_piece_uses_tnt_skin', () {
      final levelSkin = CountingSkin('level');
      final tntSkin = _TntCountingSkin();
      final state = createStateWithExplosivePiece(3, 0);
      final painter = BoardPainter(
        state: state,
        cellSize: 30.0,
        theme: TestBlockTheme(levelSkin: levelSkin),
        levelMaterial: BlockMaterial.planks,
        tntSkin: tntSkin,
      );

      final recorder = ui.PictureRecorder();
      painter.paint(Canvas(recorder), const Size(300, 600));

      expect(tntSkin.calls, greaterThan(0));
    });
  });
}

class _TntCountingSkin extends TntSkin {
  int calls = 0;

  @override
  void paint(Canvas canvas, Rect rect, {int? boardX, int? boardY}) {
    calls++;
  }
}
