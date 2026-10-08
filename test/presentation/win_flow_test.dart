import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:explosive_tetris/application/progress_service.dart';
import 'package:explosive_tetris/game_engine/packing/slice_config.dart';
import 'package:explosive_tetris/presentation/screens/game_screen.dart';
import 'package:explosive_tetris/presentation/screens/ship_screen.dart';
import 'package:explosive_tetris/presentation/widgets/ship.dart';

/// Пост-победный поток на ядре укладки (Стори 02/03):
/// деталь собрана (`PackState.isComplete`) → авто-показ корабля → следующий
/// уровень; на последнем дев-уровне → N/N + «Начать заново» → сброс.
///
/// Полный прогон всего контента (Стори 03): каждый из `kShipPartCount`
/// уровней доводится до `isComplete` тем же solve-хуком (`Key('cheat_solve')`)
/// — без симуляции drag-жестов — и проходится «Далее» до последнего уровня,
/// затем «Начать заново» и сброс к уровню 1.
Future<void> _pump(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 600));
}

/// Довести текущий уровень до победы solve-хуком: деталь раскладывается по
/// эталону (`PackSlice.solution`), затем ~900 мс пульса — и запускается
/// пост-победный поток.
Future<void> _solveWin(WidgetTester t) async {
  await t.tap(find.byKey(const Key('cheat_button')));
  await _pump(t);
  await t.tap(find.byKey(const Key('cheat_solve')));
  await _pump(t);
  // Пульс-задержка перед мета-переходом (~900 мс).
  await t.pump(const Duration(milliseconds: 1000));
  await _pump(t);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() {
    SharedPreferences.setMockInitialValues({});
    GameScreen.sliceConfig = SliceConfig.bigPieces;
  });

  Future<void> pumpGame(WidgetTester t, int level) async {
    t.view.physicalSize = const Size(1200, 1600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(MaterialApp(home: GameScreen(levelIndex: level)));
    await t.pump();
  }

  testWidgets(
    'полный прогон: все kShipPartCount уровней укладкой (solve-хук) → '
    '«Далее» → … → последний уровень → «Начать заново» → сброс к уровню 1',
    (t) async {
      SharedPreferences.setMockInitialValues({'current_level': 0});
      await pumpGame(t, 0);

      for (var level = 0; level < kShipPartCount; level++) {
        final game = t.widget<GameScreen>(find.byType(GameScreen));
        expect(game.levelIndex, level);
        expect(
          find.text('ДЕТАЛЬ ${level + 1} / $kShipPartCount'),
          findsOneWidget,
        );

        await _solveWin(t);

        final isLastDevLevel = level == kShipPartCount - 1;

        // Авто-показ корабля; деталь +1.
        expect(find.byType(ShipScreen), findsOneWidget);
        expect(
          find.text('Собрано ${level + 1} из $kShipPartCount'),
          findsOneWidget,
        );
        expect(
          find.text(isLastDevLevel ? 'Начать заново' : 'Далее'),
          findsOneWidget,
        );
        if (!isLastDevLevel) {
          expect(await ProgressService().getCurrentLevel(), level + 1);
        }

        await t.tap(find.byKey(const Key('ship_next_button')));
        await _pump(t);
      }

      // Сброс после последнего уровня: назад к уровню 1.
      final game = t.widget<GameScreen>(find.byType(GameScreen));
      expect(game.levelIndex, 0);
      expect(find.text('ДЕТАЛЬ 1 / $kShipPartCount'), findsOneWidget);
      expect(await ProgressService().getCurrentLevel(), 0);
    },
  );
}
