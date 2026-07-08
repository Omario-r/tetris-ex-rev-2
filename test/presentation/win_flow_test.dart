import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:explosive_tetris/application/progress_service.dart';
import 'package:explosive_tetris/presentation/screens/game_screen.dart';
import 'package:explosive_tetris/presentation/screens/ship_screen.dart';

/// Пост-победный поток (Стори 03): победа → авто-показ корабля → следующий уровень;
/// на последнем дев-уровне → 3/3 + «Начать заново» → сброс.
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
      expect(find.text('Собрано 1 из 3'), findsOneWidget);
      expect(find.text('Далее'), findsOneWidget);
      expect(await ProgressService().getCurrentLevel(), 1);

      await t.tap(find.byKey(const Key('ship_next_button')));
      await _pump(t);
      final game = t.widget<GameScreen>(find.byType(GameScreen));
      expect(game.levelIndex, 1);
      expect(find.text('Level 2'), findsOneWidget);
    },
  );

  testWidgets(
    'победа на 3-м уровне → 3/3 + «Начать заново» → сброс к уровню 1',
    (t) async {
      SharedPreferences.setMockInitialValues({'current_level': 2});
      await pumpGame(t, 2);
      await _instantWin(t);

      expect(find.text('Собрано 3 из 3'), findsOneWidget);
      expect(find.text('Начать заново'), findsOneWidget);

      await t.tap(find.byKey(const Key('ship_next_button')));
      await _pump(t);

      final game = t.widget<GameScreen>(find.byType(GameScreen));
      expect(game.levelIndex, 0);
      expect(find.text('Level 1'), findsOneWidget);
      expect(await ProgressService().getCurrentLevel(), 0);
    },
  );
}
