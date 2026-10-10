import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:explosive_tetris/application/progress_service.dart';
import 'package:explosive_tetris/game_engine/data/ronin_parts.dart';
import 'package:explosive_tetris/main.dart';
import 'package:explosive_tetris/presentation/screens/game_screen.dart';
import 'package:explosive_tetris/presentation/screens/ship_screen.dart';

/// Поток «деталь собрана» на ядре укладки (Ронин-1/05 T1): деталь собрана
/// (`PackState.isComplete`) → прогресс засчитан сразу → **пауза** («ДЕТАЛЬ
/// СОБРАНА», кнопки на месте лотка) → выбор маршрута: «Следующая деталь» или
/// «К кораблю» → «Продолжить сборку». После последней детали — финал
/// «продолжение следует» без сброса прогресса.
///
/// Полный прогон всего контента: каждый уровень доводится до `isComplete`
/// solve-хуком (`Key('cheat_finish_level')`) — без симуляции drag-жестов.
Future<void> _pump(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 600));
}

/// Довести текущий уровень до сборки solve-хуком: деталь раскладывается по
/// эталону (`PackSlice.solution`) — сразу пауза.
Future<void> _solve(WidgetTester t) async {
  await t.tap(find.byKey(const Key('cheat_button')));
  await _pump(t);
  await t.tap(find.byKey(const Key('cheat_finish_level')));
  await _pump(t);
}

void main() {
  final total = RoninParts.parts.length;

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => SharedPreferences.setMockInitialValues({}));

  void bigView(WidgetTester t) {
    t.view.physicalSize = const Size(1200, 1600);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
  }

  testWidgets(
    'полный прогон: все уровни укладкой (solve-хук) → пауза → чётные через '
    '«Следующая деталь», нечётные через «К кораблю» + «Продолжить сборку» → '
    'финал N/N «продолжение следует», прогресс остаётся N',
    (t) async {
      bigView(t);
      SharedPreferences.setMockInitialValues({'current_level': 0});
      await t.pumpWidget(const MaterialApp(home: GameScreen(levelIndex: 0)));
      await t.pump();

      for (var level = 0; level < total; level++) {
        final game = t.widget<GameScreen>(find.byType(GameScreen));
        expect(game.levelIndex, level);
        expect(find.text('ДЕТАЛЬ ${level + 1} / $total'), findsOneWidget);

        await _solve(t);

        // Пауза: надпись над полем, лотка нет, прогресс уже +1.
        expect(find.byType(ShipScreen), findsNothing);
        expect(
          t.widget<Text>(find.byKey(const Key('packing_complete'))).data,
          'ДЕТАЛЬ СОБРАНА',
        );
        expect(find.byKey(const Key('packing_tray')), findsNothing);
        expect(await ProgressService().getCollectedCount(), level + 1);

        final isLast = level == total - 1;
        if (isLast) {
          // Последняя деталь: только «К кораблю» → финал.
          expect(find.byKey(const Key('done_next_button')), findsNothing);
          await t.tap(find.byKey(const Key('done_to_ship_button')));
          await _pump(t);
        } else if (level.isEven) {
          await t.tap(find.byKey(const Key('done_next_button')));
          await _pump(t);
        } else {
          await t.tap(find.byKey(const Key('done_to_ship_button')));
          await _pump(t);
          expect(find.byType(ShipScreen), findsOneWidget);
          expect(find.text('${level + 1} / $total'), findsOneWidget);
          expect(await ProgressService().getCollectedCount(), level + 1);
          await t.tap(find.byKey(const Key('ship_continue_button')));
          await _pump(t);
        }
        // Переход по кнопке прогресс не меняет.
        expect(await ProgressService().getCollectedCount(), level + 1);
      }

      // Финал: экран корабля N/N, «продолжение следует», без кнопок и сброса.
      expect(find.byType(ShipScreen), findsOneWidget);
      expect(find.byType(GameScreen), findsNothing);
      expect(find.text('$total / $total'), findsOneWidget);
      expect(find.byKey(const Key('ship_finale_text')), findsOneWidget);
      expect(find.text('Начать заново'), findsNothing);
      expect(find.byKey(const Key('ship_continue_button')), findsNothing);
      expect(await ProgressService().getCollectedCount(), total);

      // «Перезапуск игры» после финала: тот же экран финала.
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(const AppRoot());
      await _pump(t);
      expect(find.byType(ShipScreen), findsOneWidget);
      expect(find.byType(GameScreen), findsNothing);
      expect(find.byKey(const Key('ship_finale_text')), findsOneWidget);
      expect(find.text('$total / $total'), findsOneWidget);
      expect(await ProgressService().getCollectedCount(), total);
    },
  );
}
