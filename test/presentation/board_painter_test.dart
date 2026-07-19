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
import 'package:explosive_tetris/presentation/theme/scrap_block_skin.dart';
import 'package:explosive_tetris/presentation/theme/ship_materials.dart';
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

class ScrapCountingSkin extends ScrapBlockSkin {
  ScrapCountingSkin();

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
          BlockMaterial.graphite: levelSkin,
          BlockMaterial.graphiteDark: levelSkin,
          BlockMaterial.darkNiche: levelSkin,
          BlockMaterial.hazardOrange: levelSkin,
          BlockMaterial.rust: levelSkin,
          BlockMaterial.gunmetal: levelSkin,
          BlockMaterial.matteBlack: levelSkin,
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

/// Creates a [GameState] with an occupied board cell inside the target mask S.
GameState createStateWithPlacedBlockInTarget(int x, int y) {
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
  BlockMaterial levelMaterial = BlockMaterial.graphite,
  CountingSkin? levelSkinCounter,
  ShipMaterials? shipMaterials,
  ScrapBlockSkin? scrapSkin,
}) {
  final levelSkin = levelSkinCounter ?? CountingSkin('level');
  final themeToUse = theme ??
      TestBlockTheme(levelSkin: levelSkin);
  final materials = shipMaterials ?? ShipMaterials.defaultMaterials;
  final scrap = scrapSkin ?? const ScrapBlockSkin();

  return BoardPainter(
    state: state,
    cellSize: 30.0,
    theme: themeToUse,
    levelMaterial: levelMaterial,
    shipMaterials: materials,
    scrapSkin: scrap,
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
        levelMaterial: BlockMaterial.graphite,
        shipMaterials: ShipMaterials.defaultMaterials,
      );
      final painter2 = BoardPainter(
        state: state,
        cellSize: 30.0,
        theme: theme,
        levelMaterial: BlockMaterial.graphite,
        shipMaterials: ShipMaterials.defaultMaterials,
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
      // Cell (4, 15) is inside the target mask S for defaultLevel
      // defaultLevel: targetX=2, targetY=14, targetMask is 6x6 cross
      // Cell (4,15) = (2+2, 14+1) is in S (local coords 2,1 is in cross)
      final state = createStateWithPlacedBlockInTarget(4, 15);
      final painter = createPainter(
        state,
        levelSkinCounter: levelSkin,
        levelMaterial: BlockMaterial.graphite,
      );

      final recorder = ui.PictureRecorder();
      painter.paint(Canvas(recorder), const Size(300, 600));

      expect(levelSkin.calls, greaterThan(0));
    });

    test(
      'armed_ghost_cells_pinned_to_bottom_row_ignoring_occupied_cells',
      () {
        final board = Board(defaultLevel.boardWidth, defaultLevel.boardHeight);
        // Occupied cells in and around the footprint must not affect the
        // computed landing row — explosive collision only checks the floor
        // (`CollisionDetector.canMoveDownExplosive`), the bomb passes
        // through placed blocks.
        board.setCell(3, 10, const Cell.occupied());
        board.setCell(4, 19, const Cell.occupied());

        // I-piece: local cells at (0,1)..(3,1) — a single row.
        final piece = PieceFactory.create(PieceType.I);
        final fallingPiece = FallingPiece(
          piece: piece,
          x: 3,
          y: 0,
          mode: PieceMode.explosive,
        );
        final state = GameState(
          board: board,
          fallingPiece: fallingPiece,
          phase: GamePhase.falling,
          generator: SevenBagGenerator(seed: 42),
          level: defaultLevel,
        );
        final painter = createPainter(state);

        final cells = painter.armedGhostCells(fallingPiece, board);

        // Lowest local cell y=1 → footprint row = board.height - 1 = 19,
        // regardless of the occupied cells placed above/within it.
        expect(
          cells.toSet(),
          equals({(x: 3, y: 19), (x: 4, y: 19), (x: 5, y: 19), (x: 6, y: 19)}),
        );
      },
    );

    test(
      'armed_ghost_cells_footprint_independent_of_current_fall_progress',
      () {
        final board = Board(defaultLevel.boardWidth, defaultLevel.boardHeight);
        // T-piece: local cells (0,0),(1,0),(2,0),(1,1) — two rows, lowest
        // local y = 1.
        final piece = PieceFactory.create(PieceType.T);

        final atSpawn = FallingPiece(
          piece: piece,
          x: 0,
          y: 0,
          mode: PieceMode.explosive,
        );
        final midFall = FallingPiece(
          piece: piece,
          x: 0,
          y: 5,
          mode: PieceMode.explosive,
        );

        final painter = createPainter(createStateWithExplosivePiece(0, 0));

        final spawnCells = painter.armedGhostCells(atSpawn, board);
        final midFallCells = painter.armedGhostCells(midFall, board);

        // Same footprint whether the piece just spawned or already fell
        // partway — it's the resting position, not the current position.
        expect(spawnCells, equals(midFallCells));
        // The lowest local cell (1,1) of the T-piece touches the bottom row.
        expect(
          spawnCells.map((c) => c.y).reduce((a, b) => a > b ? a : b),
          equals(board.height - 1),
        );
      },
    );

    test('placed_cells_outside_target_use_scrap_skin', () {
      final scrapSkin = ScrapCountingSkin();
      // Cell (0, 0) is outside the target mask S for defaultLevel
      // defaultLevel: targetX=2, targetY=14, targetMask is 6x6 cross starting at (2,14)
      // Cell (0,0) is far from S, should use scrap skin
      final state = createStateWithPlacedBlock(0, 0);
      final painter = createPainter(
        state,
        scrapSkin: scrapSkin,
      );

      final recorder = ui.PictureRecorder();
      painter.paint(Canvas(recorder), const Size(300, 600));

      expect(scrapSkin.calls, equals(1));
      expect(scrapSkin.coords, equals([(0, 0)]));
    });
  });
}
