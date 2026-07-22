import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:explosive_tetris/application/progress_service.dart';
import 'package:explosive_tetris/presentation/screens/game_screen.dart';
import 'package:explosive_tetris/presentation/screens/ship_screen.dart';

/// Пост-победный поток на ядре укладки (Стори 02):
/// деталь собрана (`PackState.isComplete`) → авто-показ корабля → следующий
/// уровень; на последнем дев-уровне → N/N + «Начать заново» → сброс.
///
/// Минимальный зелёный прогон укладки: один уровень доводится до `isComplete`
/// solve-хуком (`Key('cheat_solve')`) — без симуляции drag-жестов. Последняя
/// мета-ветка (сброс на 7/7) проверяется читом «мгновенная победа» (тот же
/// `_handleWin`/`_onWin`). **Полный прогон всего контента до собранного корабля
/// (все kShipPartCount уровней реальной укладкой) — Стори 03.**
Future<void> _pump(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 600));
}

/// Довести уровень до победы solve-хуком: деталь раскладывается по эталону,
/// затем ~900 мс пульса — и запускается пост-победный поток.
Future<void> _solveWin(WidgetTester t) async {
  await t.tap(find.byKey(const Key('cheat_button')));
  await _pump(t);
  await t.tap(find.byKey(const Key('cheat_solve')));
  await _pump(t);
  // Пульс-задержка перед мета-переходом (~900 мс).
  await t.pump(const Duration(milliseconds: 1000));
  await _pump(t);
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
    'укладка собрана (solve-хук) → корабль +1 → «Далее» → следующий уровень',
    (t) async {
      SharedPreferences.setMockInitialValues({'current_level': 0});
      await pumpGame(t, 0);
      await _solveWin(t);

      // Авто-показ корабля; деталь +1.
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
}
