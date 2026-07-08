import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:explosive_tetris/presentation/screens/game_screen.dart';
import 'package:explosive_tetris/presentation/screens/ship_screen.dart';
import 'package:explosive_tetris/presentation/widgets/ship.dart';

/// Достаёт единственный [ShipPainter] из дерева.
ShipPainter _shipPainter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((cp) => cp.painter)
    .whereType<ShipPainter>()
    .first;

/// Прокачивает кадры без `pumpAndSettle` — игровой цикл `GameScreen` не settle-ится.
Future<void> _pumpFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => SharedPreferences.setMockInitialValues({}));

  group('ShipScreen — число деталей = min(current_level, 7)', () {
    for (final entry in {0: 0, 1: 1, 2: 2, 3: 3, 5: 5, 7: 7, 15: 7}.entries) {
      final level = entry.key;
      final expected = entry.value;
      testWidgets('current_level=$level → собрано $expected', (tester) async {
        SharedPreferences.setMockInitialValues({'current_level': level});

        await tester.pumpWidget(const MaterialApp(home: ShipScreen()));
        await tester.pumpAndSettle();

        expect(_shipPainter(tester).collectedCount, expected);
        expect(find.text('Собрано $expected из 7'), findsOneWidget);
      });
    }
  });

  testWidgets(
    'Сохранение сборки: повторное открытие показывает то же число деталей',
    (tester) async {
      // «Первый запуск»: current_level=2 сохранён.
      SharedPreferences.setMockInitialValues({'current_level': 2});
      await tester.pumpWidget(const MaterialApp(home: ShipScreen()));
      await tester.pumpAndSettle();
      expect(_shipPainter(tester).collectedCount, 2);

      // «Перезапуск приложения»: тот же persistent-стор, новый экран.
      await tester.pumpWidget(const MaterialApp(home: ShipScreen()));
      await tester.pumpAndSettle();
      expect(_shipPainter(tester).collectedCount, 2);
    },
  );

  testWidgets(
    'Вход из игры: тап по иконке → экран корабля → «Назад» → игра',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      SharedPreferences.setMockInitialValues({'current_level': 1});
      await tester.pumpWidget(
        const MaterialApp(home: GameScreen(levelIndex: 1)),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('ship_button')));
      await _pumpFrames(tester);

      expect(find.byType(ShipScreen), findsOneWidget);
      expect(_shipPainter(tester).collectedCount, 1);

      await tester.pageBack();
      await _pumpFrames(tester);

      expect(find.byType(GameScreen), findsOneWidget);
      expect(find.byType(ShipScreen), findsNothing);
    },
  );

  // Регресс на возврат Гейта 2: без SafeArea кнопка «Корабль» уходила под
  // системный статус-бар (верхний inset) и не нажималась.
  testWidgets(
    'Кнопка корабля ниже верхнего inset (статус-бар) и нажимается',
    (tester) async {
      const topInset = 100.0;
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      tester.view.padding = const FakeViewPadding(top: topInset);
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({'current_level': 1});
      await tester.pumpWidget(
        const MaterialApp(home: GameScreen(levelIndex: 1)),
      );
      await tester.pump();

      final button = find.byKey(const Key('ship_button'));
      // Верх кнопки — ниже статус-бара (иначе тап уходит в систему).
      expect(tester.getTopLeft(button).dy, greaterThanOrEqualTo(topInset));

      // И она реально нажимается по своим координатам → открывает экран корабля.
      await tester.tap(button);
      await _pumpFrames(tester);
      expect(find.byType(ShipScreen), findsOneWidget);
    },
  );

  testWidgets('Авто-показ: заработанная деталь въезжает (revealProgress 0→1)',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ShipScreen.reveal(collectedCount: 2, onNext: () {}),
      ),
    );

    // Первый кадр: деталь index 1 ещё не на месте (scale < 1).
    await tester.pump();
    final p0 = _shipPainter(tester);
    expect(p0.revealPartIndex, 1);
    expect(p0.revealProgress, lessThan(1.0));

    // По завершении анимации — деталь на месте (scale == 1).
    await tester.pumpAndSettle();
    expect(_shipPainter(tester).revealProgress, 1.0);
  });
}
