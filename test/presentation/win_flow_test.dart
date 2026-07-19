import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:explosive_tetris/application/progress_service.dart';
import 'package:explosive_tetris/presentation/screens/game_screen.dart';
import 'package:explosive_tetris/presentation/screens/ship_screen.dart';
import 'package:explosive_tetris/presentation/widgets/ship.dart';

/// Пост-победный поток (Стори 03): победа → авто-показ корабля → следующий уровень;
/// на последнем дев-уровне → N/N + «Начать заново» → сброс.
///
/// Победу инициируем читом «мгновенная победа» — это тот же `_handleWin`/`_onWin`,
/// что и по игровому состоянию (без манипуляций движком в тесте).
Future<void> _pump(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 600));
}

Future<void> _instantWin(WidgetTester t) async {
  await t.tap(find.byKey(const Key('cheat_button')));
  await _pump(t);
  await t.tap(find.byKey(const Key('cheat_instant_win')));
  await _pump(t);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpGame(WidgetTester t, int level) async {
    t.view.physicalSize = const Size(1200, 1600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(MaterialApp(home: GameScreen(levelIndex: level)));
    await t.pump();
  }

  testWidgets(
    'победа (не последний уровень) → корабль +1 → «Далее» → следующий',
    (t) async {
      SharedPreferences.setMockInitialValues({'current_level': 0});
      await pumpGame(t, 0);
      await _instantWin(t);

      // Авто-показ корабля, а не старые экраны; деталь +1.
      expect(find.byType(ShipScreen), findsOneWidget);
      expect(find.text('Собрано 1 из 7'), findsOneWidget);
      expect(find.text('Далее'), findsOneWidget);
      expect(await ProgressService().getCurrentLevel(), 1);

      await t.tap(find.byKey(const Key('ship_next_button')));
      await _pump(t);
      final game = t.widget<GameScreen>(find.byType(GameScreen));
      expect(game.levelIndex, 1);
      expect(find.text('ДЕТАЛЬ 2/7'), findsOneWidget);
    },
  );

  testWidgets(
    'победа на последнем (7-м) уровне → 7/7 + «Начать заново» → сброс к уровню 1',
    (t) async {
      SharedPreferences.setMockInitialValues({'current_level': 6});
      await pumpGame(t, 6);
      await _instantWin(t);

      expect(find.text('Собрано 7 из 7'), findsOneWidget);
      expect(find.text('Начать заново'), findsOneWidget);

      await t.tap(find.byKey(const Key('ship_next_button')));
      await _pump(t);

      final game = t.widget<GameScreen>(find.byType(GameScreen));
      expect(game.levelIndex, 0);
      expect(find.text('ДЕТАЛЬ 1/7'), findsOneWidget);
      expect(await ProgressService().getCurrentLevel(), 0);
    },
  );

  testWidgets(
    'полный прогон (Стори 03, смоук): все kShipPartCount уровней подряд → '
    'сборка N/N → «Начать заново» → уровень 0',
    (t) async {
      SharedPreferences.setMockInitialValues({'current_level': 0});
      await pumpGame(t, 0);

      for (int level = 0; level < kShipPartCount; level++) {
        await _instantWin(t);
        final collected = level + 1;
        final isLast = level == kShipPartCount - 1;

        expect(find.text('Собрано $collected из $kShipPartCount'), findsOneWidget,
            reason: 'после уровня $level должно быть собрано $collected деталей');
        expect(find.text(isLast ? 'Начать заново' : 'Далее'), findsOneWidget);

        await t.tap(find.byKey(const Key('ship_next_button')));
        await _pump(t);

        final game = t.widget<GameScreen>(find.byType(GameScreen));
        expect(game.levelIndex, isLast ? 0 : level + 1);
      }

      // Полный круг завершён: прогресс сброшен, снова уровень 0.
      expect(await ProgressService().getCurrentLevel(), 0);
      expect(find.text('ДЕТАЛЬ 1/7'), findsOneWidget);
    },
  );
}
