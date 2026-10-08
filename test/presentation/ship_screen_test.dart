import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:explosive_tetris/application/progress_service.dart';
import 'package:explosive_tetris/game_engine/data/ronin_parts.dart';
import 'package:explosive_tetris/presentation/screens/game_screen.dart';
import 'package:explosive_tetris/presentation/screens/ship_screen.dart';
import 'package:explosive_tetris/presentation/ship_render/ship_composite_painter.dart';

/// Достаёт единственный [ShipCompositePainter] из дерева.
ShipCompositePainter _shipPainter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((cp) => cp.painter)
    .whereType<ShipCompositePainter>()
    .first;

/// Прокачивает кадры без `pumpAndSettle` — `GameScreen` держит пульс-контроллер.
Future<void> _pumpFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

/// Экран корабля поверх хост-маршрута (кнопка «open» пушит `ShipScreen()`).
Widget _host() => MaterialApp(
  home: Builder(
    builder: (context) => Scaffold(
      body: Center(
        child: TextButton(
          key: const Key('open'),
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const ShipScreen())),
          child: const Text('open'),
        ),
      ),
    ),
  ),
);

void main() {
  final total = RoninParts.parts.length;

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => SharedPreferences.setMockInitialValues({}));

  group(
    'ShipScreen — число деталей = getCollectedCount (0..15), счётчик «N / 15»',
    () {
      // ProgressService клампит персист к 0..15 на чтении (число собранных,
      // Ронин-1/05 T1; единый источник истины RoninParts.parts.length) —
      // «сырые» значения >15 читаются как 15.
      for (final entry in {
        0: 0,
        1: 1,
        2: 2,
        3: 3,
        5: 5,
        6: 6,
        7: 7,
        12: 12,
        14: 14,
        15: 15,
        30: 15,
      }.entries) {
        final level = entry.key;
        final expected = entry.value;
        testWidgets('current_level=$level → собрано $expected', (tester) async {
          SharedPreferences.setMockInitialValues({'current_level': level});

          await tester.pumpWidget(const MaterialApp(home: ShipScreen()));
          await tester.pumpAndSettle();

          expect(_shipPainter(tester).collectedCount, expected);
          expect(
            tester
                .widget<Text>(find.byKey(const Key('ship_collected_text')))
                .data,
            '$expected / $total',
          );
          expect(find.text('РОНИН · СБОРКА'), findsOneWidget);
        });
      }
    },
  );

  testWidgets('Ручной режим: одна кнопка «Продолжить сборку», без AppBar', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'current_level': 3});
    await tester.pumpWidget(const MaterialApp(home: ShipScreen()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ship_continue_button')), findsOneWidget);
    expect(find.text('Продолжить сборку'), findsOneWidget);
    expect(find.byKey(const Key('ship_back_button')), findsOneWidget);
    expect(find.byKey(const Key('ship_finale_text')), findsNothing);
    expect(find.byType(AppBar), findsNothing);
  });

  testWidgets('«Продолжить сборку» закрывает экран', (tester) async {
    SharedPreferences.setMockInitialValues({'current_level': 3});
    await tester.pumpWidget(_host());
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();
    expect(find.byType(ShipScreen), findsOneWidget);

    await tester.tap(find.byKey(const Key('ship_continue_button')));
    await tester.pumpAndSettle();
    expect(find.byType(ShipScreen), findsNothing);
    expect(find.byKey(const Key('open')), findsOneWidget);
  });

  testWidgets('«Назад» закрывает экран', (tester) async {
    await tester.pumpWidget(_host());
    await tester.tap(find.byKey(const Key('open')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('ship_back_button')));
    await tester.pumpAndSettle();
    expect(find.byType(ShipScreen), findsNothing);
  });

  testWidgets(
    'Сохранение сборки: повторное открытие показывает то же число деталей',
    (tester) async {
      SharedPreferences.setMockInitialValues({'current_level': 2});
      await tester.pumpWidget(const MaterialApp(home: ShipScreen()));
      await tester.pumpAndSettle();
      expect(_shipPainter(tester).collectedCount, 2);

      // «Перезапуск приложения»: тот же persistent-стор, новый экран.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(const MaterialApp(home: ShipScreen()));
      await tester.pumpAndSettle();
      expect(_shipPainter(tester).collectedCount, 2);
    },
  );

  testWidgets('Вход из игры: тап по иконке → экран корабля → «Назад» → игра', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues({'current_level': 1});
    await tester.pumpWidget(const MaterialApp(home: GameScreen(levelIndex: 1)));
    await tester.pump();

    await tester.tap(find.byKey(const Key('ship_button')));
    await _pumpFrames(tester);

    expect(find.byType(ShipScreen), findsOneWidget);
    expect(_shipPainter(tester).collectedCount, 1);

    await tester.tap(find.byKey(const Key('ship_back_button')));
    await _pumpFrames(tester);

    expect(find.byType(GameScreen), findsOneWidget);
    expect(find.byType(ShipScreen), findsNothing);
  });

  // Регресс на возврат Гейта 2: без SafeArea кнопка «Корабль» уходила под
  // системный статус-бар (верхний inset) и не нажималась.
  testWidgets('Кнопка корабля ниже верхнего inset (статус-бар) и нажимается', (
    tester,
  ) async {
    const topInset = 100.0;
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(top: topInset);
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({'current_level': 1});
    await tester.pumpWidget(const MaterialApp(home: GameScreen(levelIndex: 1)));
    await tester.pump();

    final button = find.byKey(const Key('ship_button'));
    expect(tester.getTopLeft(button).dy, greaterThanOrEqualTo(topInset));

    await tester.tap(button);
    await _pumpFrames(tester);
    expect(find.byType(ShipScreen), findsOneWidget);
    // И шапка экрана корабля — тоже ниже статус-бара.
    expect(
      tester.getTopLeft(find.byKey(const Key('ship_back_button'))).dy,
      greaterThanOrEqualTo(topInset),
    );
  });

  group('После сборки (afterWin)', () {
    testWidgets('заработанная деталь въезжает (revealProgress 0→1)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ShipScreen.afterWin(collectedCount: 2, onContinue: () {}),
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

    testWidgets(
      'счётчик «N / 15», «Продолжить сборку» зовёт onContinue, без «Назад»',
      (tester) async {
        var continued = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: ShipScreen.afterWin(
              collectedCount: 4,
              onContinue: () => continued++,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tester
              .widget<Text>(find.byKey(const Key('ship_collected_text')))
              .data,
          '4 / $total',
        );
        expect(_shipPainter(tester).collectedCount, 4);
        expect(find.text('Продолжить сборку'), findsOneWidget);
        expect(find.byKey(const Key('ship_back_button')), findsNothing);
        expect(find.byKey(const Key('ship_finale_text')), findsNothing);

        await tester.tap(find.byKey(const Key('ship_continue_button')));
        expect(continued, 1);
      },
    );
  });

  group('Финал «продолжение следует»', () {
    testWidgets(
      'собрано N: надпись, без «Продолжить сборку» и «Назад»; последняя '
      'деталь въезжает',
      (tester) async {
        await tester.pumpWidget(const MaterialApp(home: ShipScreen.finale()));

        await tester.pump();
        final p0 = _shipPainter(tester);
        expect(p0.collectedCount, total);
        expect(p0.revealPartIndex, total - 1);
        expect(p0.revealProgress, lessThan(1.0));

        await tester.pumpAndSettle();
        expect(_shipPainter(tester).revealProgress, 1.0);
        expect(find.text('$total / $total'), findsOneWidget);
        expect(
          tester.widget<Text>(find.byKey(const Key('ship_finale_text'))).data,
          'ПРОДОЛЖЕНИЕ СЛЕДУЕТ',
        );
        expect(find.byKey(const Key('ship_continue_button')), findsNothing);
        expect(find.byKey(const Key('ship_back_button')), findsNothing);
        expect(find.text('Начать заново'), findsNothing);
      },
    );

    testWidgets('animateLast: false — корабль сразу целиком, без въезда', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: ShipScreen.finale(animateLast: false)),
      );
      await tester.pump();
      final p = _shipPainter(tester);
      expect(p.collectedCount, total);
      expect(p.revealPartIndex, isNull);
      expect(find.byKey(const Key('ship_finale_text')), findsOneWidget);
    });

    testWidgets('dev-сброс: прогресс 0 → игра с уровня 1', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      SharedPreferences.setMockInitialValues({'current_level': total});
      await tester.pumpWidget(
        const MaterialApp(home: ShipScreen.finale(animateLast: false)),
      );
      await tester.pump();

      // В тестах kDebugMode = true — дев-кнопка есть.
      await tester.tap(find.byKey(const Key('ship_dev_reset')));
      await _pumpFrames(tester);

      expect(find.byType(ShipScreen), findsNothing);
      expect(tester.widget<GameScreen>(find.byType(GameScreen)).levelIndex, 0);
      expect(await ProgressService().getCollectedCount(), 0);
    });
  });
}
