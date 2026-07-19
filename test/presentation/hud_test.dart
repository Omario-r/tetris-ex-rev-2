import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:explosive_tetris/game_engine/game/game_controller.dart';
import 'package:explosive_tetris/game_engine/game/game_state.dart';
import 'package:explosive_tetris/game_engine/models/board.dart';
import 'package:explosive_tetris/game_engine/rules/randomizer.dart';
import 'package:explosive_tetris/game_engine/data/level_map.dart';
import 'package:explosive_tetris/presentation/widgets/hud.dart';

void main() {
  group('GameHud — boom_button (Стори 02 T1)', () {
    late GameController controller;

    setUp(() {
      final level = LevelMap.levelAt(0);
      controller = GameController(
        initialState: GameState(
          board: Board(level.boardWidth, level.boardHeight),
          fallingPiece: null,
          phase: GamePhase.spawning,
          generator: SevenBagGenerator(seed: 42),
          level: level,
        ),
      );
    });

    Future<void> pumpHud(WidgetTester tester) {
      return tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameHud(
              controller: controller,
              state: controller.state,
            ),
          ),
        ),
      );
    }

    testWidgets('boom_button всегда виден — одна кнопка вместо двух', (
      WidgetTester tester,
    ) async {
      await pumpHud(tester);
      expect(find.byKey(const Key('boom_button')), findsOneWidget);
    });

    testWidgets(
      'Пусто: 0 зарядов → кнопка неактивна, задымлена (opacity ~0.55)',
      (WidgetTester tester) async {
        controller.setCharges(0);
        await pumpHud(tester);

        final gesture = tester.widget<GestureDetector>(
          find.byKey(const Key('boom_button')),
        );
        expect(gesture.onTap, isNull);

        final opacityWidget = tester.widget<Opacity>(
          find.ancestor(
            of: find.byKey(const Key('boom_button')),
            matching: find.byType(Opacity),
          ),
        );
        expect(opacityWidget.opacity, equals(0.55));
      },
    );

    testWidgets(
      'Готов: заряды есть, canArm false (нет падающей фигуры) → неактивна',
      (WidgetTester tester) async {
        // spawning phase, до первого тика: fallingPiece == null → canArm false.
        expect(controller.state.canArm, isFalse);
        expect(controller.state.charges, greaterThan(0));
        await pumpHud(tester);

        final gesture = tester.widget<GestureDetector>(
          find.byKey(const Key('boom_button')),
        );
        expect(gesture.onTap, isNull);
      },
    );

    testWidgets(
      'Готов: canArm true → тап взводит (controller.armExplosive)',
      (WidgetTester tester) async {
        controller.tick(0);
        controller.tick(1);
        if (!controller.state.canArm) return;

        await pumpHud(tester);

        final gesture = tester.widget<GestureDetector>(
          find.byKey(const Key('boom_button')),
        );
        expect(gesture.onTap, isNotNull);

        await tester.tap(find.byKey(const Key('boom_button')));
        await tester.pump();

        expect(controller.state.canDetonate, isTrue);
      },
    );

    testWidgets(
      'Взведён: canDetonate true → тап детонирует (controller.detonate)',
      (WidgetTester tester) async {
        controller.tick(0);
        controller.tick(1);
        if (!controller.state.canArm) return;
        controller.armExplosive();
        expect(controller.state.canDetonate, isTrue);

        await pumpHud(tester);

        final opacityWidget = tester.widget<Opacity>(
          find.ancestor(
            of: find.byKey(const Key('boom_button')),
            matching: find.byType(Opacity),
          ),
        );
        expect(opacityWidget.opacity, equals(1.0));

        await tester.tap(find.byKey(const Key('boom_button')));
        await tester.pump();

        expect(controller.state.canDetonate, isFalse);
      },
    );

    testWidgets('charges_indicator показывает бейдж ×N (state.charges)', (
      WidgetTester tester,
    ) async {
      await pumpHud(tester);

      final text = tester.widget<Text>(
        find.byKey(const Key('charges_indicator')),
      );
      expect(text.data, '×${controller.state.charges}');
    });

    testWidgets('charges_indicator обновляется при setCharges', (
      WidgetTester tester,
    ) async {
      controller.setCharges(0);
      await pumpHud(tester);

      final text = tester.widget<Text>(
        find.byKey(const Key('charges_indicator')),
      );
      expect(text.data, '×0');
    });
  });
}
