import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:explosive_tetris/presentation/screens/cheat_menu.dart';
import 'package:explosive_tetris/presentation/screens/game_screen.dart';
import 'package:explosive_tetris/presentation/screens/packing_prototype_screen.dart';

/// Прокачивает кадры без `pumpAndSettle` — `GameScreen` держит свой игровой
/// цикл (`AnimationController.repeat`), который не settle-ится.
Future<void> _pumpFrames(WidgetTester tester,
    [Duration d = const Duration(milliseconds: 500)]) async {
  await tester.pump();
  await tester.pump(d);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // Изоляция между тестами: `_prototypeFeedMode` — module-level (намеренно,
    // ТЗ T3, «переживает перезаход на экран»), поэтому живёт весь процесс
    // теста, не только один `testWidgets` — сбрасываем явно.
    resetPrototypeFeedModeForTest();
  });
  tearDown(() => SharedPreferences.setMockInitialValues({}));

  group('PackingPrototypeScreen — строится, ключи на месте', () {
    testWidgets('экран строится без исключений, тулбар/чит-кнопки на месте',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: PackingPrototypeScreen()),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('packing_close_button')), findsOneWidget);
      expect(find.byKey(const Key('packing_reshuffle')), findsOneWidget);
      // Тесты идут в debug-режиме (`kDebugMode == true`) — дев-кнопки видны.
      expect(find.byKey(const Key('packing_cheat_button')), findsOneWidget);
      expect(find.byKey(const Key('packing_debug_solve')), findsOneWidget);
      // Не собрано с самого начала.
      expect(find.byKey(const Key('packing_complete')), findsNothing);
    });

    testWidgets('дев-чит прототипа открывает тумблер подачи (feed_full/feed_tray3)',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: PackingPrototypeScreen()),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('packing_cheat_button')));
      await _pumpFrames(tester);

      expect(find.byKey(const Key('feed_full')), findsOneWidget);
      expect(find.byKey(const Key('feed_tray3')), findsOneWidget);

      // Переключение режима не роняет экран.
      await tester.tap(find.byKey(const Key('feed_tray3')));
      await _pumpFrames(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'feed_tray3: в лотке видно максимум 3 кусочка, режим переживает '
        'перезаход на прототип-экран (module-level переменная)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: PackingPrototypeScreen()),
      );
      await tester.pump();

      // По умолчанию (fullSet) весь набор нарезки виден в лотке сразу.
      // Силуэт прототипа — крест `defaultTargetMask` (20 клеток) — режется
      // на 5 кусков (проверено на seed 0..9, `pack_slicer_test.dart`), больше
      // порционного лотка-3 — тумблеру есть что показать.
      final fullSetCount =
          find.byWidgetPredicate((w) => w.key is ValueKey<String> &&
              (w.key as ValueKey<String>).value.startsWith('tray_piece_'))
              .evaluate()
              .length;
      expect(fullSetCount, greaterThan(3),
          reason: 'весь набор нарезки силуэта-прототипа должен быть больше 3 '
              'кусков — иначе тумблер тут нечего проверять');

      await tester.tap(find.byKey(const Key('packing_cheat_button')));
      await _pumpFrames(tester);
      await tester.tap(find.byKey(const Key('feed_tray3')));
      await _pumpFrames(tester);
      // Закрыть bottom sheet, чтобы считать только лоток экрана.
      await tester.tapAt(const Offset(20, 20));
      await _pumpFrames(tester);

      int trayPieceCount() => find
          .byWidgetPredicate((w) =>
              w.key is ValueKey<String> &&
              (w.key as ValueKey<String>).value.startsWith('tray_piece_'))
          .evaluate()
          .length;

      expect(trayPieceCount(), lessThanOrEqualTo(3));

      // «Перезаход»: свежий инстанс экрана (module-level `_prototypeFeedMode`
      // живёт вне State — не сбрасывается новым `initState`).
      await tester.pumpWidget(
        const MaterialApp(home: PackingPrototypeScreen()),
      );
      await tester.pump();

      expect(trayPieceCount(), lessThanOrEqualTo(3),
          reason: 'режим подачи должен пережить перезаход на экран');
    });

    testWidgets(
        'программное размещение всех кусочков по PackSlice.solution → '
        'появляется Key(packing_complete)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: PackingPrototypeScreen()),
      );
      await tester.pump();

      expect(find.byKey(const Key('packing_complete')), findsNothing);

      // Дев-кнопка «Решить» раскладывает все кусочки по эталонному решению
      // нарезки (`PackSlice.solution`) — programmatic-хук для теста, без
      // симуляции drag-жестов.
      await tester.tap(find.byKey(const Key('packing_debug_solve')));
      await _pumpFrames(tester);

      expect(find.byKey(const Key('packing_complete')), findsOneWidget);

      // «Заново» пересобирает нарезку — баннер завершения снова пропадает.
      await tester.tap(find.byKey(const Key('packing_restart_button')));
      await _pumpFrames(tester);
      expect(find.byKey(const Key('packing_complete')), findsNothing);
    });

    testWidgets('«Пересобрать» не роняет экран (новый seed → новая нарезка)',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: PackingPrototypeScreen()),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('packing_reshuffle')));
      await _pumpFrames(tester);

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('packing_complete')), findsNothing);
    });
  });

  group('Вход из основного чит-меню', () {
    Future<void> pumpGame(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(const MaterialApp(home: GameScreen()));
      await tester.pump();
    }

    testWidgets('кнопка «Прототип укладки» есть в чит-меню и открывает экран',
        (tester) async {
      await pumpGame(tester);

      await tester.tap(find.byKey(const Key('cheat_button')));
      await _pumpFrames(tester);

      expect(find.byType(CheatMenu), findsOneWidget);
      expect(find.byKey(const Key('cheat_open_prototype')), findsOneWidget);

      await tester.tap(find.byKey(const Key('cheat_open_prototype')));
      await _pumpFrames(tester);

      expect(find.byType(PackingPrototypeScreen), findsOneWidget);
      // Основной экран остаётся под стеком (Navigator.push, не replace) —
      // найден без `skipOffstage`, т.к. предыдущий route уходит в offstage.
      expect(
        find.byType(GameScreen, skipOffstage: false),
        findsOneWidget,
        reason: 'открытие прототипа не должно ломать/убивать GameScreen под стеком',
      );
    });
  });
}
