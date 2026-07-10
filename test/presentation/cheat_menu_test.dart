import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:explosive_tetris/application/progress_service.dart';
import 'package:explosive_tetris/presentation/screens/cheat_menu.dart';
import 'package:explosive_tetris/presentation/screens/game_screen.dart';
import 'package:explosive_tetris/presentation/screens/ship_screen.dart';
import 'package:explosive_tetris/presentation/widgets/hud.dart';
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
    // kShipPartCount+1 кнопок состояния корабля: 0..kShipPartCount
    for (int n = 0; n <= kShipPartCount; n++) {
      expect(find.byKey(Key('cheat_ship_parts_$n')), findsOneWidget);
    }
  });

  testWidgets('Чит «выбор уровня» предлагает ровно kShipPartCount уровней',
      (tester) async {
    await pumpGame(tester);

    await tester.tap(find.byKey(const Key('cheat_button')));
    await _pumpFrames(tester);

    for (int i = 0; i < kShipPartCount; i++) {
      expect(find.byKey(Key('cheat_level_$i')), findsOneWidget,
          reason: 'уровень $i должен быть предложен читом');
    }
    expect(find.byKey(Key('cheat_level_$kShipPartCount')), findsNothing,
        reason: 'уровней ровно kShipPartCount — лишнего быть не должно');
  });

  testWidgets('Чит «состояние корабля»: N=2 → прогресс=2 → корабль 2/7',
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

  testWidgets('Чит «заряды взрыва»: N=5 → заряды в HUD == 5',
      (tester) async {
    await pumpGame(tester);

    await tester.tap(find.byKey(const Key('cheat_button')));
    await _pumpFrames(tester);

    expect(find.byKey(const Key('cheat_charges_5')), findsOneWidget);
    await tester.tap(find.byKey(const Key('cheat_charges_5')));
    await _pumpFrames(tester);

    final hud = tester.widget<GameHud>(find.byType(GameHud));
    expect(hud.state.charges, 5);
  });

  testWidgets(
      'Чит-меню не переполняется на маленьком экране (390×844, iPhone-like) '
      'и все секции доступны через скролл',
      (tester) async {
    // Регрессия: на большом тестовом канвасе (1200×1600, см. pumpGame выше)
    // переполнение не проявлялось — поймано PO на реальном устройстве
    // (iPhone-эмулятор), не тестами. Здесь — реалистичный маленький вьюпорт.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(home: GameScreen(levelIndex: 0)));
    await tester.pump();

    await tester.tap(find.byKey(const Key('cheat_button')));
    await _pumpFrames(tester);

    expect(tester.takeException(), isNull,
        reason: 'чит-меню не должно переполняться (RenderFlex overflow) на '
            'маленьком экране — регрессия к hotfix 2026-07-11');

    // Последняя секция («Заряды взрыва») не помещается без скролла на таком
    // экране — но должна быть достижима и рабочей через scroll внутри sheet.
    await tester.scrollUntilVisible(
      find.byKey(const Key('cheat_charges_5')),
      200.0,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const Key('cheat_charges_5')));
    await _pumpFrames(tester);

    expect(tester.takeException(), isNull);
    final hud = tester.widget<GameHud>(find.byType(GameHud));
    expect(hud.state.charges, 5);
  });

  testWidgets('Чит «мгновенная победа»: прогресс +1 и пост-победный экран',
      (tester) async {
    SharedPreferences.setMockInitialValues({'current_level': 0});
    await pumpGame(tester, level: 0);

    await tester.tap(find.byKey(const Key('cheat_button')));
    await _pumpFrames(tester);

    await tester.tap(find.byKey(const Key('cheat_instant_win')));
    await _pumpFrames(tester);

    // Запустился тот же пост-победный поток, что после обычной победы —
    // авто-показ корабля (Стори 03) с кнопкой перехода.
    expect(find.byType(ShipScreen), findsOneWidget);
    expect(find.byKey(const Key('ship_next_button')), findsOneWidget);
    // Прогресс засчитан: 0 → 1.
    expect(await ProgressService().getCurrentLevel(), 1);
  });
}
