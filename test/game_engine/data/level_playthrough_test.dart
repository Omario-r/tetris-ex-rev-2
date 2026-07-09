import 'package:flutter_test/flutter_test.dart';
import 'package:explosive_tetris/game_engine/data/level_map.dart';
import 'package:explosive_tetris/game_engine/game/game_controller.dart';
import 'package:explosive_tetris/game_engine/game/game_state.dart';
import 'package:explosive_tetris/game_engine/models/board.dart';
import 'package:explosive_tetris/game_engine/models/piece.dart';
import 'package:explosive_tetris/game_engine/rules/randomizer.dart';

/// Сквозной прогон реальным падением фигур (T2, ⚠ хрупкое: проходимость масок).
///
/// В отличие от `golden_scenario_test` (который фабрикует победный `Board`
/// напрямую), здесь фигуры реально спавнятся и падают через `GameController`
/// — доказательство физической проходимости, а не только корректности
/// геометрии `S`/`H`.
void main() {
  group('Реальный дроп фигур до победы', () {
    test('уровень 6 (2×2, ровно один O-тетромино): гравитация без движений',
        () {
      // Мишень 2×2 центрирована (targetX=4) и floor-anchored (targetY=18).
      // O-фигура спавнится на x=3 и занимает столбцы 4..5 (matrix col 1..2) —
      // совпадает с мишенью без единого moveLeft/moveRight.
      final level = LevelMap.levelAt(6);
      expect(level.targetX, 4);
      expect(level.targetY, 18);

      final controller = GameController(
        initialState: GameState(
          board: Board(level.boardWidth, level.boardHeight),
          fallingPiece: null,
          phase: GamePhase.spawning,
          generator: FixedSequenceGenerator([PieceType.O]),
          level: level,
        ),
        gravityInterval: 0.5,
      );

      controller.tick(0.1); // spawn
      for (int i = 0; i < 40; i++) {
        if (controller.state.phase != GamePhase.falling) break;
        controller.tick(0.5); // gravity — свободное падение до дна
      }

      expect(controller.state.phase, GamePhase.won,
          reason: 'O-фигура должна лечь ровно на мишень и дать победу');
      expect(controller.state.dirtyHalo, isEmpty);
    });

    test('уровень 1 (верхний корпус, 4×3 сплошной прямоугольник): 3×I внахлёст',
        () {
      // Мишень — сплошной блок 4×3 (mask 0xFFF, без вырезов), targetX=3
      // совпадает со спавном I-фигуры (columns 3..6) — три I-фигуры подряд
      // без единого движения ложатся друг на друга и точно закрывают S,
      // не задевая H (ширина фигуры == ширине мишени на всех трёх рядах).
      final level = LevelMap.levelAt(1);
      expect(level.targetX, 3);
      expect(level.targetMask.width, 4);
      expect(level.targetMask.height, 3);

      final controller = GameController(
        initialState: GameState(
          board: Board(level.boardWidth, level.boardHeight),
          fallingPiece: null,
          phase: GamePhase.spawning,
          generator: FixedSequenceGenerator([
            PieceType.I,
            PieceType.I,
            PieceType.I,
          ]),
          level: level,
        ),
        gravityInterval: 0.5,
      );

      for (int piece = 0; piece < 3; piece++) {
        controller.tick(0.1); // spawn — I уже на x=3, без movement
        for (int i = 0; i < 40; i++) {
          if (controller.state.phase != GamePhase.falling) break;
          controller.tick(0.5);
        }
        if (piece < 2) {
          expect(controller.state.phase, GamePhase.spawning,
              reason: 'после ${piece + 1}-й фигуры мишень ещё не полна');
        }
      }

      expect(controller.state.phase, GamePhase.won,
          reason: 'три I-фигуры друг на друге должны точно закрыть мишень 1');
      expect(controller.state.dirtyHalo, isEmpty);
    });
  });
}
