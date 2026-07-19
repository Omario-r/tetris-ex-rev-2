import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:explosive_tetris/presentation/screens/game_screen.dart';
import 'package:explosive_tetris/presentation/widgets/board_painter.dart';

void main() {
  group('GameScreen', () {
    testWidgets('renders_board_painter', (WidgetTester tester) async {
      // Set larger viewport to avoid overflow
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: GameScreen(levelIndex: 0),
        ),
      );

      // Find CustomPaint widgets and check that the board painter is present
      final customPaints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
      final hasBoardPainter = customPaints.any((cp) => cp.painter is BoardPainter);
      expect(hasBoardPainter, isTrue);

      // Reset viewport
      tester.view.resetPhysicalSize();
    });

    testWidgets('renders_without_error', (WidgetTester tester) async {
      // Set larger viewport to avoid overflow
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: GameScreen(levelIndex: 0),
        ),
      );

      // Verify GameScreen renders
      expect(find.byType(GameScreen), findsOneWidget);

      // Reset viewport
      tester.view.resetPhysicalSize();
    });

    testWidgets('boom_button_disabled_when_cannot_arm_or_detonate', (
      WidgetTester tester,
    ) async {
      // Set larger viewport to avoid overflow
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: GameScreen(levelIndex: 0),
        ),
      );

      // Find the combined boom (arm+detonate) button by key.
      final boomButtonFinder = find.byKey(const Key('boom_button'));
      expect(boomButtonFinder, findsOneWidget);

      // Get the GestureDetector wrapping the boom button.
      final gesture = tester.widget<GestureDetector>(boomButtonFinder);

      // Verify it's not tappable when canArm/canDetonate are both false
      // (initial state, before the first tick spawns a falling piece).
      expect(gesture.onTap, isNull);

      // Reset viewport
      tester.view.resetPhysicalSize();
    });

    testWidgets('renders_part_chip_text', (WidgetTester tester) async {
      // Set larger viewport to avoid overflow
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        const MaterialApp(
          home: GameScreen(levelIndex: 0),
        ),
      );

      // Топбар (Стори 02 T3): чип «ДЕТАЛЬ N/7» вместо старого «Level N».
      expect(find.text('ДЕТАЛЬ 1/7'), findsOneWidget);

      // Reset viewport
      tester.view.resetPhysicalSize();
    });

    testWidgets(
      'renders_without_overflow_on_short_screen',
      (WidgetTester tester) async {
        // Стори 02 T4: короткий телефон (например iPhone SE) — 360×640
        // логических px. Топбар(44) + поле(boardHeight*_cellSize) + HUD(150)
        // раньше не влезали (RenderFlex overflow); адаптивный размер клетки
        // должен вписать колонку без переполнения и без падения.
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(
            home: GameScreen(levelIndex: 0),
          ),
        );

        // Никакого FlutterError (в т.ч. "A RenderFlex overflowed").
        expect(tester.takeException(), isNull);
        expect(find.byType(GameScreen), findsOneWidget);
      },
    );
  });
}
