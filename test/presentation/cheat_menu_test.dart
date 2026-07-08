import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:explosive_tetris/application/progress_service.dart';
import 'package:explosive_tetris/presentation/screens/cheat_menu.dart';
import 'package:explosive_tetris/presentation/screens/game_screen.dart';
import 'package:explosive_tetris/presentation/screens/level_complete_screen.dart';
import 'package:explosive_tetris/presentation/screens/ship_screen.dart';
import 'package:explosive_tetris/presentation/widgets/ship.dart';

ShipPainter _shipPainter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((cp) => cp.painter)
    .whereType<ShipPainter>()
    .first;

/// Прокачивает кадры без `pumpAndSettle` — игровой цикл `GameScreen` не settle-ится.
Future<void> _pumpFrames(WidgetTester tester,
    [Duration d = const Duration(milliseconds: 500)]) async {
  await tester.pump();
  await tester.pump(d);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpGame(WidgetTester tester, {int level = 0}) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(home: GameScreen(levelIndex: level)));
    await tester.pump();
  }

  testWidgets('В dev-сборке кнопка читов есть и открывает меню', (tester) async {
    await pumpGame(tester);

    expect(find.byKey(const Key('cheat_button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('cheat_button')));
    await _pumpFrames(tester);

    expect(find.byType(CheatMenu), findsOneWidget);
    // 4 кнопки состояния корабля: 0..3
    for (int n = 0; n <= kShipPartCount; n++) {
      expect(find.byKey(Key('cheat_ship_parts_$n')), findsOneWidget);
    }
  });

  testWidgets('Чит «состояние корабля»: N=2 → прогресс=2 → корабль 2/3',
      (tester) async {
    await pumpGame(tester);

    await tester.tap(find.byKey(const Key('cheat_button')));
    await _pumpFrames(tester);

    await tester.tap(find.byKey(const Key('cheat_ship_parts_2')));
    // Закрыть sheet + дать SnackBar-таймеру (1с) отработать, чтобы не висел.
    await _pumpFrames(tester, const Duration(seconds: 2));

    expect(await ProgressService().getCurrentLevel(), 2);

    // Открываем экран корабля — показывает 2 детали.
    await tester.tap(find.byKey(const Key('ship_button')));
    await _pumpFrames(tester);
    expect(find.byType(ShipScreen), findsOneWidget);
    expect(_shipPainter(tester).collectedCount, 2);
  });

  testWidgets('Чит «выбор уровня»: тап уровня 3 → GameScreen(levelIndex=2)',
      (tester) async {
    await pumpGame(tester, level: 0);

    await tester.tap(find.byKey(const Key('cheat_button')));
    await _pumpFrames(tester);

    // cheat_level_2 → индекс 2 (подпись «3»).
    await tester.tap(find.byKey(const Key('cheat_level_2')));
    await _pumpFrames(tester);

    final game = tester.widget<GameScreen>(find.byType(GameScreen));
    expect(game.levelIndex, 2);
    expect(find.text('Level 3'), findsOneWidget);
  });

  testWidgets('Чит «мгновенная победа»: прогресс +1 и пост-победный экран',
      (tester) async {
    SharedPreferences.setMockInitialValues({'current_level': 0});
    await pumpGame(tester, level: 0);

    await tester.tap(find.byKey(const Key('cheat_button')));
    await _pumpFrames(tester);

    await tester.tap(find.byKey(const Key('cheat_instant_win')));
    await _pumpFrames(tester);

    // Запустился тот же пост-победный поток, что после обычной победы.
    expect(find.byType(LevelCompleteScreen), findsOneWidget);
    // Прогресс засчитан: 0 → 1.
    expect(await ProgressService().getCurrentLevel(), 1);
  });
}
