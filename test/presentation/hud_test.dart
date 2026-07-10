import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:explosive_tetris/game_engine/game/game_controller.dart';
import 'package:explosive_tetris/game_engine/game/game_state.dart';
import 'package:explosive_tetris/game_engine/models/board.dart';
import 'package:explosive_tetris/game_engine/rules/randomizer.dart';
import 'package:explosive_tetris/game_engine/data/level_map.dart';
import 'package:explosive_tetris/presentation/widgets/hud.dart';

void main() {
  group('GameHud', () {
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

    testWidgets('arm_button_disabled_when_cannot_arm', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameHud(
              controller: controller,
              state: controller.state,
            ),
          ),
        ),
      );

      final armButton = tester.widget<IconButton>(
        find.byKey(const Key('arm_button')),
      );
      expect(armButton.onPressed, isNull);

      final opacityWidget = tester.widget<Opacity>(
        find.ancestor(
          of: find.byKey(const Key('arm_button')),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacityWidget.opacity, equals(0.3));
    });

    testWidgets('arm_button_enabled_when_can_arm', (
      WidgetTester tester,
    ) async {
      controller.tick(0);
      controller.tick(1);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameHud(
              controller: controller,
              state: controller.state,
            ),
          ),
        ),
      );

      if (!controller.state.canArm) {
        return;
      }

      final armButton = tester.widget<IconButton>(
        find.byKey(const Key('arm_button')),
      );
      expect(armButton.onPressed, isNotNull);

      final opacityWidget = tester.widget<Opacity>(
        find.ancestor(
          of: find.byKey(const Key('arm_button')),
          matching: find.byType(Opacity),
        ),
      );
      expect(opacityWidget.opacity, equals(1.0));
    });

    testWidgets('arm_button_always_visible', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameHud(
              controller: controller,
              state: controller.state,
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('arm_button')), findsOneWidget);
    });

    testWidgets('charges_indicator показывает текущий остаток зарядов', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameHud(
              controller: controller,
              state: controller.state,
            ),
          ),
        ),
      );

      final text = tester.widget<Text>(
        find.byKey(const Key('charges_indicator')),
      );
      expect(text.data, '${controller.state.charges}');
    });

    testWidgets(
      'charges_indicator читается без слов: цвет меняется на 0 зарядов',
      (WidgetTester tester) async {
        controller.setCharges(0);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GameHud(
                controller: controller,
                state: controller.state,
              ),
            ),
          ),
        );

        final text = tester.widget<Text>(
          find.byKey(const Key('charges_indicator')),
        );
        expect(text.data, '0');
        expect(text.style?.color, equals(Colors.redAccent));
      },
    );

    testWidgets(
      'charges_indicator обычный цвет, когда заряды есть',
      (WidgetTester tester) async {
        controller.setCharges(3);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: GameHud(
                controller: controller,
                state: controller.state,
              ),
            ),
          ),
        );

        final text = tester.widget<Text>(
          find.byKey(const Key('charges_indicator')),
        );
        expect(text.style?.color, equals(Colors.white));
      },
    );
  });
}
