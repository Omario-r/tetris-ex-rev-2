import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:explosive_tetris/application/progress_service.dart';
import 'package:explosive_tetris/presentation/screens/cheat_menu.dart';
import 'package:explosive_tetris/presentation/screens/game_screen.dart';
import 'package:explosive_tetris/presentation/screens/ship_screen.dart';
import 'package:explosive_tetris/presentation/widgets/ship.dart';

ShipPainter _shipPainter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((cp) => cp.painter)
    .whereType<ShipPainter>()
    .first;

/// Прокачивает кадры без `pumpAndSettle` — `GameScreen` держит пульс-контроллер.
Future<void> _pumpFrames(WidgetTester tester,
    [Duration d = const Duration(milliseconds: 500)]) async {
  await tester.pump();
  await tester.pump(d);
}

int _trayPieceCount() => find
    .byWidgetPredicate((w) =>
        w.key is ValueKey<String> &&
        (w.key as ValueKey<String>).value.startsWith('tray_piece_'))
    .evaluate()
    .length;

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
    for (int n = 0; n <= kShipPartCount; n++) {
      expect(find.byKey(Key('cheat_ship_parts_$n')), findsOneWidget);
    }
  });

  testWidgets('Чит-меню под новое ядро: нет зарядов взрыва и прототипа',
      (tester) async {
    await pumpGame(tester);

    await tester.tap(find.byKey(const Key('cheat_button')));
    await _pumpFrames(tester);

    // Взрыв выпилен: секции зарядов больше нет.
    expect(find.byKey(const Key('cheat_charges_0')), findsNothing);
    expect(find.byKey(const Key('cheat_charges_5')), findsNothing);
    // Прототип-вход убран (экран замещён основным).
    expect(find.byKey(const Key('cheat_open_prototype')), findsNothing);
  });

  testWidgets('Чит «выбор уровня» предлагает ровно kShipPartCount уровней',
      (tester) async {
    await pumpGame(tester);

    await tester.tap(find.byKey(const Key('cheat_button')));
    await _pumpFrames(tester);

    for (int i = 0; i < kShipPartCount; i++) {
      expect(find.byKey(Key('cheat_level_$i')), findsOneWidget);
    }
    expect(find.byKey(Key('cheat_level_$kShipPartCount')), findsNothing);
  });

  testWidgets('Чит «состояние корабля»: N=2 → прогресс=2 → корабль 2/13',
      (tester) async {
    await pumpGame(tester);

    await tester.tap(find.byKey(const Key('cheat_button')));
    await _pumpFrames(tester);

    await tester.tap(find.byKey(const Key('cheat_ship_parts_2')));
    await _pumpFrames(tester, const Duration(seconds: 2));

    expect(await ProgressService().getCurrentLevel(), 2);

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

    await tester.tap(find.byKey(const Key('cheat_level_2')));
    await _pumpFrames(tester);

    final game = tester.widget<GameScreen>(find.byType(GameScreen));
    expect(game.levelIndex, 2);
    expect(find.text('ДЕТАЛЬ 3 / 13'), findsOneWidget);
  });

  testWidgets(
      'Тумблер подачи: feed_tray3 → в лотке максимум 3 кусочка; feed_full → всё',
      (tester) async {
    // Уровень 1 (12 клеток) режется на 3 куска — есть что показать тумблеру.
    await pumpGame(tester, level: 1);

    expect(_trayPieceCount(), greaterThan(0));

    await tester.tap(find.byKey(const Key('cheat_button')));
    await _pumpFrames(tester);

    expect(find.byKey(const Key('feed_full')), findsOneWidget);
    expect(find.byKey(const Key('feed_tray3')), findsOneWidget);

    await tester.tap(find.byKey(const Key('feed_tray3')));
    await _pumpFrames(tester);
    // Закрыть sheet, чтобы считать только лоток экрана.
    await tester.tapAt(const Offset(20, 20));
    await _pumpFrames(tester);

    expect(_trayPieceCount(), lessThanOrEqualTo(3));
    expect(find.text('ЛОТОК · ПОРЦИЯ-3'), findsOneWidget);
  });

  testWidgets('Чит «Пересобрать нарезку» не роняет экран', (tester) async {
    await pumpGame(tester, level: 1);

    await tester.tap(find.byKey(const Key('cheat_button')));
    await _pumpFrames(tester);

    expect(find.byKey(const Key('cheat_reshuffle')), findsOneWidget);
    await tester.tap(find.byKey(const Key('cheat_reshuffle')));
    await _pumpFrames(tester);

    expect(tester.takeException(), isNull);
    expect(find.byType(GameScreen), findsOneWidget);
  });

  testWidgets(
      'Чит-меню не переполняется на маленьком экране (390×844) и секции '
      'доступны через скролл', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const MaterialApp(home: GameScreen(levelIndex: 0)));
    await tester.pump();

    await tester.tap(find.byKey(const Key('cheat_button')));
    await _pumpFrames(tester);

    expect(tester.takeException(), isNull,
        reason: 'чит-меню не должно переполняться (регрессия hotfix 2026-07-11)');

    await tester.scrollUntilVisible(
      find.byKey(const Key('cheat_solve')),
      200.0,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.byKey(const Key('cheat_solve')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Чит «мгновенная победа»: прогресс +1 и пост-победный экран',
      (tester) async {
    SharedPreferences.setMockInitialValues({'current_level': 0});
    await pumpGame(tester, level: 0);

    await tester.tap(find.byKey(const Key('cheat_button')));
    await _pumpFrames(tester);

    await tester.tap(find.byKey(const Key('cheat_instant_win')));
    await _pumpFrames(tester);

    expect(find.byType(ShipScreen), findsOneWidget);
    expect(find.byKey(const Key('ship_next_button')), findsOneWidget);
    expect(await ProgressService().getCurrentLevel(), 1);
  });
}
