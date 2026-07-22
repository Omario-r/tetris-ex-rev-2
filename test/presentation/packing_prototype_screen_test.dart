import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:explosive_tetris/game_engine/models/target_mask.dart';
import 'package:explosive_tetris/game_engine/packing/pack_slicer.dart';
import 'package:explosive_tetris/presentation/screens/cheat_menu.dart';
import 'package:explosive_tetris/presentation/screens/game_screen.dart';
import 'package:explosive_tetris/presentation/screens/packing_prototype_screen.dart';
import 'package:explosive_tetris/presentation/widgets/packing_painter.dart';

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

  group('Регрессия: нет RenderFlex overflow на телефонной ширине (Гейт 2 '
      'возврат по T3, 375×812 не settle-ился на дефолтном тестовом вьюпорте '
      '800×600, где overflow не проявлялся)', () {
    /// Пампит экран на геометрии телефона и убеждается, что раскладка не даёт
    /// overflow (в debug-режиме overflow бросает `FlutterError`, тест ловит
    /// его через `tester.takeException()`). Целевая форма — `PROJECT.md`
    /// (телефон, портрет); ширины подобраны от iPhone SE (320) до iPhone
    /// 12/13 (390) — самый узкий реалистичный случай.
    Future<void> pumpOnPhone(
      WidgetTester tester, {
      double width = 375.0,
      double height = 812.0,
      double dpr = 3.0,
    }) async {
      tester.view.physicalSize = Size(width * dpr, height * dpr);
      tester.view.devicePixelRatio = dpr;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(const MaterialApp(home: PackingPrototypeScreen()));
      await tester.pump();
    }

    testWidgets('320×568 (iPhone SE, самый узкий случай) — стартовая нарезка '
        'без overflow', (tester) async {
      await pumpOnPhone(tester, width: 320.0, height: 568.0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('375×812 — стартовая нарезка + лоток без overflow',
        (tester) async {
      await pumpOnPhone(tester);
      expect(tester.takeException(), isNull);
      // Тулбар (закрыть/заголовок/пересобрать/dev-кнопки) и лоток кусочков —
      // оба Row из отчёта Гейта 2 — построены без overflow.
      expect(find.byKey(const Key('packing_close_button')), findsOneWidget);
      expect(find.byKey(const Key('packing_reshuffle')), findsOneWidget);
      expect(find.byKey(const Key('packing_cheat_button')), findsOneWidget);
    });

    testWidgets('375×812 — dev-чит-меню (тумблер подачи) открывается без '
        'overflow, packing_cheat_button нажимаема', (tester) async {
      await pumpOnPhone(tester);

      // Критично: если бы dev-кнопка уезжала за край (регрессия отчёта Гейта
      // 2), `tester.tap` всё равно нашёл бы виджет по ключу и «нажал» — но
      // overflow-исключение должно было бы уже случиться на этапе layout,
      // до тапа.
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('packing_cheat_button')));
      await _pumpFrames(tester);

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('feed_full')), findsOneWidget);
      expect(find.byKey(const Key('feed_tray3')), findsOneWidget);
    });

    testWidgets('375×812 — переключение feed_tray3, «Решить», «Заново», '
        '«Пересобрать» без overflow ни на одном состоянии', (tester) async {
      await pumpOnPhone(tester);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const Key('packing_cheat_button')));
      await _pumpFrames(tester);
      await tester.tap(find.byKey(const Key('feed_tray3')));
      await _pumpFrames(tester);
      expect(tester.takeException(), isNull, reason: 'feed_tray3');

      // Закрыть sheet.
      await tester.tapAt(const Offset(20, 20));
      await _pumpFrames(tester);
      expect(tester.takeException(), isNull, reason: 'закрытие sheet');

      await tester.tap(find.byKey(const Key('packing_debug_solve')));
      await _pumpFrames(tester);
      expect(tester.takeException(), isNull, reason: 'после «Решить»');
      expect(find.byKey(const Key('packing_complete')), findsOneWidget);

      await tester.tap(find.byKey(const Key('packing_restart_button')));
      await _pumpFrames(tester);
      expect(tester.takeException(), isNull, reason: 'после «Заново»');

      await tester.tap(find.byKey(const Key('packing_reshuffle')));
      await _pumpFrames(tester);
      expect(tester.takeException(), isNull, reason: 'после «Пересобрать»');
    });
  });

  group('Регрессия: непрерывный drag укладывает кусок ОДНИМ жестом (Гейт 2 '
      'возврат — GestureDetector.onPan* терял pan лотка в gesture arena '
      'против горизонтального SingleChildScrollView; починено переходом на '
      'сырые pointer-события Listener)', () {
    Finder boardPaintFinder() => find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is PackingPainter);

    testWidgets(
        'тащим кусочек из лотка на силуэт одним непрерывным жестом (startGesture '
        '→ несколько moveTo → up, БЕЗ отдельного второго тапа) — кусок ложится',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: PackingPrototypeScreen()),
      );
      await tester.pump();

      // Та же нарезка, что и у экрана по умолчанию (`_seed == 0`,
      // `defaultTargetMask`) — знаем эталонную позицию (`solution`), чтобы
      // отпустить кусок ТОЧНО в валидной клетке (кусок должен реально
      // улечься, не просто «куда-то за пределы»).
      final slice = slicePolyomino(defaultTargetMask, seed: 0);
      final pieceId = slice.pieces.first.id;
      final origin = slice.solution[pieceId]!;

      final trayFinder = find.byKey(Key('tray_piece_$pieceId'));
      expect(trayFinder, findsOneWidget);
      final startCenter = tester.getCenter(trayFinder);

      final boardRect = tester.getRect(boardPaintFinder());
      final cellSize = boardRect.width / defaultTargetMask.width;
      final visualTarget = boardRect.topLeft +
          Offset(
            (origin.x + 0.5) * cellSize,
            (origin.y + 0.5) * cellSize,
          );
      // Финальная позиция ПАЛЬЦА = визуальная точка (куда должен «прицелиться»
      // игрок) + офсет вниз — реверс `_dragLiftPx` (56px, кусок рисуется НАД
      // пальцем при драге).
      const dragLiftPx = 56.0;
      final pointerTarget = visualTarget.translate(0, dragLiftPx);

      final gesture = await tester.startGesture(startCenter);
      // Драг-фидбэк появляется сразу на pointer down.
      await tester.pump();
      expect(find.byKey(const Key('packing_drag_feedback')), findsOneWidget,
          reason: 'кусок должен «приподняться» сразу на нажатие');
      final feedbackAtStart =
          tester.getTopLeft(find.byKey(const Key('packing_drag_feedback')));

      // Несколько промежуточных перемещений ОДНОГО и того же жеста — именно
      // это раньше отменялось лотком-скроллвью в gesture arena.
      const steps = 6;
      for (var i = 1; i <= steps; i++) {
        final p = Offset.lerp(startCenter, pointerTarget, i / steps)!;
        await gesture.moveTo(p);
        await tester.pump();
      }

      // Drag-follow: фидбэк реально сдвинулся вслед за пальцем (не завис на
      // стартовой позиции — именно так проявлялся баг: «приподнимается, но
      // не идёт за курсором»).
      final feedbackMid =
          tester.getTopLeft(find.byKey(const Key('packing_drag_feedback')));
      expect(feedbackMid, isNot(equals(feedbackAtStart)),
          reason: 'фигура должна следовать за указателем во время движения');

      await gesture.up();
      await tester.pump();

      // Один непрерывный жест — БЕЗ второго тапа по мишени — уложил кусок:
      // он пропал из лотка (уложенные кусочки не рендерятся в лотке).
      expect(find.byKey(Key('tray_piece_$pieceId')), findsNothing,
          reason: 'кусок должен улечься одним жестом, без второго тапа');
      expect(find.byKey(const Key('packing_drag_feedback')), findsNothing,
          reason: 'после отпускания плавающий фидбэк исчезает');
    });

    testWidgets(
        'перекладка уже уложенного кусочка на board — тоже одним непрерывным '
        'жестом', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: PackingPrototypeScreen()),
      );
      await tester.pump();

      final slice = slicePolyomino(defaultTargetMask, seed: 0);
      // Кладём ПЕРВЫЙ кусок программно (дев-кнопка «Решить» кладёт ВСЕ —
      // нам нужен только один, поэтому кладём вручную тем же непрерывным
      // жестом, что и в первом тесте, затем перекладываем).
      final pieceId = slice.pieces.first.id;
      final origin = slice.solution[pieceId]!;

      final boardRect = tester.getRect(boardPaintFinder());
      final cellSize = boardRect.width / defaultTargetMask.width;
      const dragLiftPx = 56.0;

      Offset cellPointerTarget(({int x, int y}) cell) {
        final visual = boardRect.topLeft +
            Offset((cell.x + 0.5) * cellSize, (cell.y + 0.5) * cellSize);
        return visual.translate(0, dragLiftPx);
      }

      // Шаг 1: уложить кусок (одним жестом, как в предыдущем тесте).
      final trayFinder = find.byKey(Key('tray_piece_$pieceId'));
      final startCenter = tester.getCenter(trayFinder);
      final placeGesture = await tester.startGesture(startCenter);
      await tester.pump();
      final placeTarget = cellPointerTarget(origin);
      for (var i = 1; i <= 4; i++) {
        await placeGesture.moveTo(Offset.lerp(startCenter, placeTarget, i / 4)!);
        await tester.pump();
      }
      await placeGesture.up();
      await tester.pump();
      expect(find.byKey(Key('tray_piece_$pieceId')), findsNothing);

      // Шаг 2: перетащить уложенный кусок на новую (тоже валидную по
      // solution — точно свободную и внутри силуэта) позицию — другой кусок
      // из той же нарезки ещё не уложен, поэтому origin второго куска
      // гарантированно свободен.
      final secondPieceId = slice.pieces[1].id;
      final newOrigin = slice.solution[secondPieceId]!;
      final boardStartPointer = cellPointerTarget(origin);
      final boardTargetPointer = cellPointerTarget(newOrigin);

      final moveGesture = await tester.startGesture(boardStartPointer);
      await tester.pump();
      expect(find.byKey(const Key('packing_drag_feedback')), findsOneWidget,
          reason: 'захват уложенного куска с поля должен поднять фидбэк');

      for (var i = 1; i <= 4; i++) {
        await moveGesture.moveTo(
          Offset.lerp(boardStartPointer, boardTargetPointer, i / 4)!,
        );
        await tester.pump();
      }
      await moveGesture.up();
      await tester.pump();

      expect(tester.takeException(), isNull);
      // Перекладываемый кусок остался «на поле» (не улетел в лоток) — жест
      // захвата+переноса+отпускания прошёл без падений в невалидное no-op
      // (если бы `move` не отработал, кусок остался бы на прежнем месте —
      // тест не отличит «не сдвинулся» от «сдвинулся туда же», но потери
      // куска в лоток/исключений быть не должно).
      expect(find.byKey(Key('tray_piece_$pieceId')), findsNothing,
          reason: 'переложенный кусок должен остаться уложенным (не в лотке)');
      // Второй кусок мы не трогали — как был в лотке, так и остался.
      expect(find.byKey(Key('tray_piece_$secondPieceId')), findsOneWidget,
          reason: 'нетронутый второй кусок остаётся в лотке');
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
