import 'package:flutter_test/flutter_test.dart';
import 'package:explosive_tetris/game_engine/data/level_map.dart';
import 'package:explosive_tetris/game_engine/game/game_controller.dart';
import 'package:explosive_tetris/game_engine/game/game_state.dart';
import 'package:explosive_tetris/game_engine/models/board.dart';
import 'package:explosive_tetris/game_engine/models/piece.dart';
import 'package:explosive_tetris/game_engine/rules/randomizer.dart';

/// Тест «каждый уровень проходим в рамках своего бюджета зарядов» (эпик «Взрыв»,
/// Стори 02, ⚠ хрупкое: расчёт экономики).
///
/// Структурная часть — для всех 7 уровней (бюджет закреплён, неотрицателен).
/// Реальный прогон через `GameController` (аналогично
/// `level_playthrough_test.dart` из «Контента») — для показательных случаев:
/// бюджет 0 (уровни 1, 2, 6 — доказано, что взрыв там не нужен вовсе) и бюджет > 0
/// (уровень 0 — доказано, что ровно 1 взрыв закрывает неизбежный залёт в halo).
/// Остальные уровни (3, 4) той же (ступенчатой) формы, что уже разобранный уровень 0 —
/// полный солвер по всем 7 уровням сознательно не строился (тот же принцип, что и в
/// «Контенте»: см. её «Заметки по выполнению», Стори 02).
void main() {
  group('Структурные проверки: бюджет закреплён и неотрицателен', () {
    const expectedBudgets = [2, 0, 0, 2, 2, 1, 0];

    for (int i = 0; i < expectedBudgets.length; i++) {
      test('уровень $i: chargeBudget == ${expectedBudgets[i]}', () {
        final level = LevelMap.levelAt(i);
        expect(level.chargeBudget, expectedBudgets[i]);
        expect(level.chargeBudget, greaterThanOrEqualTo(0));
      });
    }
  });

  group('Реальный прогон при budget == 0 (взрыв объективно не нужен)', () {
    test('уровень 1 (4×3 прямоугольник): 3×I внахлёст, заряды не расходуются', () {
      final level = LevelMap.levelAt(1);
      expect(level.chargeBudget, 0);

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
        controller.tick(0.1); // spawn — I уже на targetX, без движений
        for (int i = 0; i < 40; i++) {
          if (controller.state.phase != GamePhase.falling) break;
          controller.tick(0.5);
        }
      }

      expect(controller.state.phase, GamePhase.won);
      expect(controller.state.dirtyHalo, isEmpty);
      expect(controller.state.charges, 0,
          reason: 'взрыв ни разу не понадобился — заряды остались на нуле');
    });

    test('уровень 2 (4×3 прямоугольник, та же форма): 3×I внахлёст', () {
      final level = LevelMap.levelAt(2);
      expect(level.chargeBudget, 0);

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
        controller.tick(0.1);
        for (int i = 0; i < 40; i++) {
          if (controller.state.phase != GamePhase.falling) break;
          controller.tick(0.5);
        }
      }

      expect(controller.state.phase, GamePhase.won);
      expect(controller.state.dirtyHalo, isEmpty);
      expect(controller.state.charges, 0);
    });

    test('уровень 6 (2×2 квадрат): 1×O, гравитация без движений', () {
      final level = LevelMap.levelAt(6);
      expect(level.chargeBudget, 0);

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

      controller.tick(0.1);
      for (int i = 0; i < 40; i++) {
        if (controller.state.phase != GamePhase.falling) break;
        controller.tick(0.5);
      }

      expect(controller.state.phase, GamePhase.won);
      expect(controller.state.dirtyHalo, isEmpty);
      expect(controller.state.charges, 0);
    });
  });

  group('Реальный прогон при budget > 0 (взрыв нужен и укладывается в бюджет)', () {
    test(
        'уровень 0 (нос: .##./####, floor-anchored): I + O переполняет halo '
        'на 1 ряд, 1 взрыв чистит его, budget=2 хватает с запасом', () {
      final level = LevelMap.levelAt(0);
      expect(level.chargeBudget, 2);
      // Мишень: mask row1 (нижний, floor) = board-ряд targetY+1, cols targetX..+3
      // (все 4) — совпадает с I-фигурой без единого движения (спавн I тоже на
      // x=targetX). mask row0 (верхний) = cols targetX+1..targetX+2 (только 2 из 4) —
      // O-фигура (2×2, спавн тоже на этих двух колонках) неизбежно займёт СВОЙ
      // верхний ряд на 1 клетку выше мишени (halo) — O всегда 2 ряда высотой,
      // а мишени нужен только 1. Взрыв убирает этот неизбежный залёт.
      expect(level.targetX, 3);
      expect(level.targetY, 18);

      final controller = GameController(
        initialState: GameState(
          board: Board(level.boardWidth, level.boardHeight),
          fallingPiece: null,
          phase: GamePhase.spawning,
          generator: FixedSequenceGenerator([
            PieceType.I, // нижний ряд мишени (floor), cols 3..6
            PieceType.O, // верхний ряд мишени, cols 4..5 + неизбежный залёт в halo рядом выше
            PieceType.O, // взрывной — чистит залёт
          ]),
          level: level,
        ),
        gravityInterval: 0.5,
      );

      // Piece 1: I, свободное падение до пола — cols 3..6, board row 19.
      controller.tick(0.1);
      for (int i = 0; i < 40; i++) {
        if (controller.state.phase != GamePhase.falling) break;
        controller.tick(0.5);
      }
      expect(controller.state.phase, GamePhase.spawning,
          reason: 'мишень ещё не полна — верхний ряд (cols 4..5) пуст');

      // Piece 2: O, свободное падение — ложится на I (cols 4..5), верх на 1 ряд
      // выше мишени → dirtyHalo не пуст.
      controller.tick(0.1);
      for (int i = 0; i < 40; i++) {
        if (controller.state.phase != GamePhase.falling) break;
        controller.tick(0.5);
      }
      expect(controller.state.phase, GamePhase.spawning,
          reason: 'S заполнен полностью, но halo испачкан — победы ещё нет');
      expect(controller.state.dirtyHalo, isNotEmpty);

      // Piece 3: O (уже выровнен на cols 4..5 на спавне, без движений), взводим и
      // спускаем взрывной footprint вниз по одному ряду за тик (canMoveDownExplosive
      // игнорирует блоки), пока нижний ряд footprint не встанет ровно на испачканный
      // ряд halo (board row 17) — тогда детонируем: под footprint попадут только
      // (4,16)/(5,16) (пусто, no-op) и (4,17)/(5,17) (грязный halo, будет расчищен),
      // клетки S (ряды 18-19) footprint не задевает.
      controller.tick(0.1); // spawn — fp.y=0, boardCells rows 0..1
      expect(controller.state.fallingPiece, isNotNull);
      controller.armExplosive();
      expect(controller.state.charges, 1,
          reason: 'списан 1 заряд из бюджета 2');
      for (int i = 0; i < 16; i++) {
        controller.tick(0.5); // explosive: свободно проходит сквозь блоки
      }
      expect(controller.state.fallingPiece!.y, 16,
          reason: 'нижний ряд footprint (y+1=17) — ровно испачканный ряд halo');
      controller.detonate();

      expect(controller.state.dirtyHalo, isEmpty,
          reason: 'взрыв расчистил залёт в halo');
      expect(controller.state.phase, GamePhase.won,
          reason: 'S по-прежнему полностью занят, halo теперь пуст — победа');
      expect(controller.state.charges, 1,
          reason: 'использован ровно 1 заряд из бюджета 2 — с запасом');
    });
  });
}
