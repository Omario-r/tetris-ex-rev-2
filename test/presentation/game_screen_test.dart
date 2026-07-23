import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:explosive_tetris/application/progress_service.dart';
import 'package:explosive_tetris/presentation/screens/game_screen.dart';
import 'package:explosive_tetris/presentation/screens/ship_screen.dart';
import 'package:explosive_tetris/presentation/widgets/packing_painter.dart';

/// Прокачивает кадры без `pumpAndSettle` — `GameScreen` держит пульс-контроллер
/// (`AnimationController.repeat`), который не settle-ится.
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

  group('GameScreen — ядро укладки', () {
    testWidgets('строится без ошибок, рисует укладку (PackingPainter)',
        (tester) async {
      await pumpGame(tester);

      expect(tester.takeException(), isNull);
      expect(find.byType(GameScreen), findsOneWidget);

      final hasPackingPainter = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .any((cp) => cp.painter is PackingPainter);
      expect(hasPackingPainter, isTrue,
          reason: 'поле должно рисоваться PackingPainter (ядро укладки)');
    });

    testWidgets('топбар-чип «ДЕТАЛЬ 1/7» на уровне 0', (tester) async {
      await pumpGame(tester);
      expect(find.text('ДЕТАЛЬ 1/7'), findsOneWidget);
    });

    testWidgets('лоток: подпись «ЛОТОК · ПОЛНЫЙ НАБОР» + кусочки в ряду',
        (tester) async {
      await pumpGame(tester);

      expect(find.text('ЛОТОК · ПОЛНЫЙ НАБОР'), findsOneWidget);

      // Стартовая нарезка кладёт весь набор в лоток — есть tray_piece_* виджеты.
      final trayPieces = find
          .byWidgetPredicate((w) =>
              w.key is ValueKey<String> &&
              (w.key as ValueKey<String>).value.startsWith('tray_piece_'))
          .evaluate()
          .length;
      expect(trayPieces, greaterThan(0),
          reason: 'кусочки нарезки должны лежать в лотке');
    });

    testWidgets('прогресс-бар: подпись «уложено 0 / M кусков» на старте',
        (tester) async {
      await pumpGame(tester);
      // На старте ничего не уложено; M = число кусков нарезки (≥1).
      expect(find.textContaining('уложено 0 / '), findsOneWidget);
    });

    testWidgets(
        'завершение через solve-хук: деталь собрана → баннер → мета-поток '
        '(авто-показ корабля)', (tester) async {
      SharedPreferences.setMockInitialValues({'current_level': 0});
      await pumpGame(tester);

      // Solve-хук из чит-меню раскладывает всю деталь без drag-жестов.
      await tester.tap(find.byKey(const Key('cheat_button')));
      await _pumpFrames(tester);
      await tester.tap(find.byKey(const Key('cheat_solve')));
      await _pumpFrames(tester);

      // Деталь собрана — баннер «ДЕТАЛЬ СОБРАНА».
      expect(find.byKey(const Key('packing_complete')), findsOneWidget);

      // Через ~900 мс запускается прежний мета-поток — авто-показ корабля.
      await tester.pump(const Duration(milliseconds: 1000));
      await _pumpFrames(tester);

      expect(find.byType(ShipScreen), findsOneWidget);
      expect(find.byKey(const Key('ship_next_button')), findsOneWidget);
      // Прогресс засчитан.
      expect(await ProgressService().getCurrentLevel(), 1);
    });

    testWidgets(
        'панель поля больше холста PackingPainter на 16px по каждой оси '
        '(паддинг 8px канона .board — возврат Гейта 3, замечание 3)',
        (tester) async {
      await pumpGame(tester);

      final customPaintFinder = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is PackingPainter,
      );
      expect(customPaintFinder, findsOneWidget);
      final canvasSize = tester.getSize(customPaintFinder);

      // Панель поля — ближайший `DecoratedBox`-предок с заливкой `boardBg`
      // (канон `.board`): паддинг живёт между этим контейнером и `CustomPaint`.
      final panelFinder = find.ancestor(
        of: customPaintFinder,
        matching: find.byWidgetPredicate((w) =>
            w is DecoratedBox &&
            (w.decoration as BoxDecoration?)?.color == PackingPainter.boardBg),
      );
      expect(panelFinder, findsOneWidget);
      final panelSize = tester.getSize(panelFinder);

      expect(panelSize.width - canvasSize.width, closeTo(16.0, 0.01));
      expect(panelSize.height - canvasSize.height, closeTo(16.0, 0.01));
    });

    testWidgets(
      'без overflow на коротком экране (360×640)',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(home: GameScreen(levelIndex: 0)),
        );
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byType(GameScreen), findsOneWidget);
      },
    );
  });
}
