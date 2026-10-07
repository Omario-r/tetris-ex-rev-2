import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:explosive_tetris/application/progress_service.dart';
import 'package:explosive_tetris/game_engine/data/ronin_parts.dart';
import 'package:explosive_tetris/game_engine/packing/slice_config.dart';
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
  tearDown(() {
    SharedPreferences.setMockInitialValues({});
    GameScreen.sliceConfig = SliceConfig.bigPieces;
  });

  Future<void> pumpGame(WidgetTester tester, {int level = 0}) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(home: GameScreen(levelIndex: level)));
    await tester.pump();
  }

  PackingPainter packingPainter(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .map((cp) => cp.painter)
      .whereType<PackingPainter>()
      .single;

  Future<void> pickSliceConfig(WidgetTester tester, SliceConfig config) async {
    await tester.tap(find.byKey(const Key('cheat_button')));
    await _pumpFrames(tester);
    await tester.tap(find.byKey(Key('slice_config_${config.name}')));
    await _pumpFrames(tester);
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

    testWidgets(
        'топбар: «ДЕТАЛЬ 1 / 13» + название детали на уровне 0',
        (tester) async {
      await pumpGame(tester);
      expect(find.text('ДЕТАЛЬ 1 / 13'), findsOneWidget);
      // Уровень 0 ↔ деталь order 1 (`RoninParts.parts[0]`) — «Нос, левый борт».
      expect(find.text('НОС, ЛЕВЫЙ БОРТ'), findsOneWidget);
    });

    testWidgets(
        'топбар на 360×640: название любой из 13 деталей помещается, '
        'кнопки справа целиком в экране', (tester) async {
      const screen = Rect.fromLTWH(0, 0, 360, 640);
      for (var i = 0; i < RoninParts.parts.length; i++) {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        // key по индексу — иначе State прошлой детали переиспользуется.
        await tester.pumpWidget(MaterialApp(
          home: GameScreen(key: ValueKey(i), levelIndex: i),
        ));
        await tester.pump();

        final title = RoninParts.parts[i].title.toUpperCase();
        expect(tester.takeException(), isNull, reason: 'деталь ${i + 1}');
        expect(find.text(title), findsOneWidget, reason: 'деталь ${i + 1}');
        for (final key in const ['ship_button', 'cheat_button']) {
          final rect = tester.getRect(find.byKey(Key(key)));
          expect(
              screen.contains(rect.topLeft) && screen.contains(rect.bottomRight),
              isTrue,
              reason: '$key вне экрана на детали ${i + 1}: $rect');
        }
        // Название не заезжает на кнопки.
        final nameRect = tester.getRect(find.text(title));
        final cheatRect = tester.getRect(find.byKey(const Key('cheat_button')));
        expect(nameRect.right, lessThanOrEqualTo(cheatRect.left),
            reason: 'название налезает на кнопки, деталь ${i + 1}');
      }
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

  group('GameScreen — конфигурации нарезки (Ронин-1/07)', () {
    testWidgets('по умолчанию bigPieces: поле 10×14, клетка 34, число кусков '
        'из prepareLevel', (tester) async {
      await pumpGame(tester);
      final painter = packingPainter(tester);
      expect(GameScreen.sliceConfig, SliceConfig.bigPieces);
      expect(painter.state.silhouette.width, 10);
      expect(painter.state.silhouette.height, 14);
      expect(painter.cellSize, 34.0);

      final expected = prepareLevel(
        RoninParts.parts[0].mask,
        SliceConfig.bigPieces,
        seed: 0,
      ).slice.pieces.length;
      expect(find.text('уложено 0 / $expected кусков'), findsOneWidget);
    });

    testWidgets('переключение на coarseCell: поле 5×7, клетка 68, ≤ 7 кусков, '
        'конфигурация переживает переход на другой уровень', (tester) async {
      await pumpGame(tester);
      await pickSliceConfig(tester, SliceConfig.coarseCell);

      expect(GameScreen.sliceConfig, SliceConfig.coarseCell);
      var painter = packingPainter(tester);
      expect(painter.state.silhouette.width, 5);
      expect(painter.state.silhouette.height, 7);
      expect(painter.cellSize, 68.0);
      expect(
        tester.getSize(
          find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is PackingPainter,
          ),
        ),
        const Size(5 * 68.0, 7 * 68.0),
      );

      final expected = prepareLevel(
        RoninParts.parts[0].mask,
        SliceConfig.coarseCell,
        seed: 0,
      ).slice.pieces.length;
      expect(expected, lessThanOrEqualTo(7));
      expect(find.text('уложено 0 / $expected кусков'), findsOneWidget);

      // Выбор уровня читом создаёт новый GameScreen — конфигурация та же.
      await tester.tap(find.byKey(const Key('cheat_button')));
      await _pumpFrames(tester);
      await tester.tap(find.byKey(const Key('cheat_level_1')));
      await _pumpFrames(tester);

      expect(find.text('ДЕТАЛЬ 2 / 13'), findsOneWidget);
      painter = packingPainter(tester);
      expect(painter.state.silhouette.width, 5);
      expect(painter.state.silhouette.height, 7);
      expect(painter.cellSize, 68.0);
    });

    testWidgets('выбор конфигурации сохраняет seed; «Пересобрать» его меняет', (
      tester,
    ) async {
      await pumpGame(tester);
      List<String> sig(int seed) => [
        for (final p in prepareLevel(
          RoninParts.parts[0].mask,
          SliceConfig.halfPart,
          seed: seed,
        ).slice.pieces)
          p.cells.map((c) => '${c.x},${c.y}').join(';'),
      ];
      final seed0 = sig(0);
      final seed1 = sig(1);
      expect(seed1, isNot(seed0));

      await tester.tap(find.byKey(const Key('cheat_button')));
      await _pumpFrames(tester);
      await tester.tap(find.byKey(const Key('cheat_reshuffle')));
      await _pumpFrames(tester);
      await pickSliceConfig(tester, SliceConfig.halfPart);
      // seed остался 1 (reshuffle) — выбор конфигурации его не сбросил.
      expect([
        for (final p in packingPainter(tester).state.pieces)
          p.cells.map((c) => '${c.x},${c.y}').join(';'),
      ], seed1);
    });

    testWidgets(
      'лоток не выше 160 px на всех 13 деталях во всех конфигурациях',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        for (final config in SliceConfig.values) {
          GameScreen.sliceConfig = config;
          for (var i = 0; i < RoninParts.parts.length; i++) {
            await tester.pumpWidget(
              MaterialApp(
                home: GameScreen(key: ValueKey('$config$i'), levelIndex: i),
              ),
            );
            await tester.pump();
            final pieces = find.byWidgetPredicate(
              (w) =>
                  w.key is ValueKey<String> &&
                  (w.key as ValueKey<String>).value.startsWith('tray_piece_'),
            );
            expect(pieces, findsWidgets);
            for (final e in pieces.evaluate()) {
              final size = tester.getSize(
                find.byElementPredicate((x) => x == e),
              );
              expect(
                size.height,
                lessThanOrEqualTo(160.0 + 0.001),
                reason: '$config деталь ${i + 1}',
              );
            }
          }
        }
      },
    );
  });
}
