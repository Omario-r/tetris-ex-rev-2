import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game_engine/game/game_state.dart';
import '../../game_engine/models/board.dart';
import '../../game_engine/models/falling_piece.dart';
import '../theme/block_material.dart';
import '../theme/block_theme.dart';
import '../theme/scrap_block_skin.dart';
import '../theme/ship_materials.dart';
import '../theme/tnt_skin.dart';

/// Custom painter for the game board with Minecraft-style block skins.
class BoardPainter extends CustomPainter {
  /// Creates a board painter for the given [state] and visual theme.
  const BoardPainter({
    required this.state,
    required this.cellSize,
    required this.theme,
    required this.levelMaterial,
    required this.shipMaterials,
    this.scrapSkin = const ScrapBlockSkin(),
    this.tntSkin = BlockTheme.tnt,
    this.animValue = 0.0,
  });

  /// Current game state snapshot.
  final GameState state;

  /// Pixel size of one board cell.
  final double cellSize;

  /// Block skin registry.
  final BlockTheme theme;

  /// Material used for placed and falling normal pieces on this level.
  final BlockMaterial levelMaterial;

  /// Skin used for armed explosive falling pieces.
  final TntSkin tntSkin;

  /// Animation value for halo pulse (0..1).
  final double animValue;

  /// Ship materials map for material-to-part mapping (T3, per-cell coloring).
  final ShipMaterials shipMaterials;

  /// Skin used for "scrap" cells outside the target mask.
  final ScrapBlockSkin scrapSkin;

  Rect _cellRect(int x, int y) {
    return Rect.fromLTWH(
      x * cellSize,
      y * cellSize,
      cellSize,
      cellSize,
    );
  }

  List<({int x, int y})> _ghostCells(FallingPiece fp, Board board) {
    var ghostY = fp.y;
    while (true) {
      final nextY = ghostY + 1;
      var canMove = true;
      for (final cell in fp.piece.cells) {
        final bx = fp.x + cell.x;
        final by = nextY + cell.y;
        if (by >= board.height || board.isOccupied(bx, by)) {
          canMove = false;
          break;
        }
      }
      if (!canMove) break;
      ghostY = nextY;
    }
    return fp.piece.cells
        .map((cell) => (x: fp.x + cell.x, y: ghostY + cell.y))
        .toList();
  }

  void _paintBlockSkin(
    Canvas canvas,
    Rect rect,
    int boardX,
    int boardY, {
    required bool useTnt,
    double opacity = 1.0,
  }) {
    if (opacity < 1.0) {
      canvas.saveLayer(rect, Paint()..color = Colors.white.withValues(alpha: opacity));
    }

    if (useTnt) {
      tntSkin.paint(canvas, rect, boardX: boardX, boardY: boardY);
    } else {
      theme
          .of(levelMaterial)
          .paint(canvas, rect, boardX: boardX, boardY: boardY);
    }

    if (opacity < 1.0) {
      canvas.restore();
    }
  }

  void _paintPlacedBlock(
    Canvas canvas,
    Rect rect,
    int boardX,
    int boardY,
  ) {
    // Check if cell is inside the target mask (S region)
    final isInTarget = state.level.S.contains((boardX, boardY));

    if (isInTarget) {
      // Cell is on target: paint with material for current level's object fragment
      final partIndex = state.level.fragmentIndex;
      final material = shipMaterials.materialForPart(partIndex);
      theme.of(material).paint(canvas, rect, boardX: boardX, boardY: boardY);
    } else {
      // Cell is outside target: paint with scrap skin
      scrapSkin.paint(canvas, rect, boardX: boardX, boardY: boardY);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final board = state.board;
    final fp = state.fallingPiece;

    // 1. Background
    final bgPaint = Paint()..color = const Color(0xFF2A2A2A);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, board.width * cellSize, board.height * cellSize),
      bgPaint,
    );

    // 2. Ghost target — unfilled S cells
    for (final cell in state.level.S) {
      final x = cell.$1;
      final y = cell.$2;
      if (!board.isOccupied(x, y)) {
        BlockTheme.ghostTarget.paint(canvas, _cellRect(x, y));
      }
    }

    // 3. Placed blocks
    for (var y = 0; y < board.height; y++) {
      for (var x = 0; x < board.width; x++) {
        if (board.isOccupied(x, y)) {
          _paintPlacedBlock(canvas, _cellRect(x, y), x, y);
        }
      }
    }

    // 4. Dirty halo — occupied H cells only
    final pulse = math.sin(animValue * 2 * math.pi).abs() * 0.5;
    for (final cell in state.dirtyHalo) {
      BlockTheme.haloHighlight.paint(
        canvas,
        _cellRect(cell.$1, cell.$2),
        pulse: pulse,
      );
    }

    if (fp != null) {
      // 5. Drop ghost (normal mode only)
      if (fp.mode == PieceMode.normal) {
        for (final cell in _ghostCells(fp, board)) {
          _paintBlockSkin(
            canvas,
            _cellRect(cell.x, cell.y),
            cell.x,
            cell.y,
            useTnt: false,
            opacity: 0.25,
          );
        }
      }

      // 6. Falling piece
      final useTnt = fp.mode == PieceMode.explosive;
      for (final cell in fp.boardCells) {
        _paintBlockSkin(
          canvas,
          _cellRect(cell.x, cell.y),
          cell.x,
          cell.y,
          useTnt: useTnt,
        );
      }
    }
  }

  @override
  bool shouldRepaint(BoardPainter oldDelegate) {
    return state != oldDelegate.state ||
        cellSize != oldDelegate.cellSize ||
        theme != oldDelegate.theme ||
        levelMaterial != oldDelegate.levelMaterial ||
        shipMaterials != oldDelegate.shipMaterials ||
        scrapSkin != oldDelegate.scrapSkin ||
        animValue != oldDelegate.animValue ||
        tntSkin != oldDelegate.tntSkin;
  }
}
