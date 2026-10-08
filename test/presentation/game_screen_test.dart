import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:explosive_tetris/application/progress_service.dart';
import 'package:explosive_tetris/game_engine/data/ronin_parts.dart';
import 'package:explosive_tetris/game_engine/packing/slice_config.dart';
import 'package:explosive_tetris/presentation/screens/game_screen.dart';
import 'package:explosive_tetris/presentation/screens/ship_screen.dart';
import 'package:explosive_tetris/presentation/theme/block_material.dart';
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

  group('GameScreen — лоток и очистка поля (Ронин-1/08 T2)', () {
    PreparedLevel level0() => prepareLevel(
      RoninParts.parts[0].mask,
      SliceConfig.bigPieces,
      seed: 0,
    );

    Finder trayPieces() => find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key as ValueKey<String>).value.startsWith('tray_piece_'),
    );

    /// Id кусков лотка слева направо (по положению на экране).
    List<int> trayIdsOnScreen(WidgetTester tester) {
      final entries = [
        for (final e in trayPieces().evaluate())
          (
            id: int.parse(
              (e.widget.key as ValueKey<String>).value.substring(
                'tray_piece_'.length,
              ),
            ),
            x: tester.getTopLeft(find.byElementPredicate((x) => x == e)).dx,
          ),
      ]..sort((a, b) => a.x.compareTo(b.x));
      return [for (final e in entries) e.id];
    }

    /// Кладёт кусок жестом в эталонную клетку: тянет вверх, затем ищет точку
    /// пальца, при которой снап-превью показывает ровно эталонные клетки и
    /// валидно (не зависит от величины подъёма куска над пальцем).
    Future<void> dragPieceToSolution(
      WidgetTester tester,
      PreparedLevel level,
      int id,
    ) async {
      final piece = level.slice.pieces.firstWhere((p) => p.id == id);
      final target = level.slice.solution[id]!;
      final want = {
        for (final c in piece.cells) '${target.x + c.x},${target.y + c.y}',
      };
      final boardFinder = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is PackingPainter,
      );
      final boardOrigin = tester.getTopLeft(boardFinder);
      final cell = packingPainter(tester).cellSize;
      var w = 0;
      var h = 0;
      for (final c in piece.cells) {
        if (c.x + 1 > w) w = c.x + 1;
        if (c.y + 1 > h) h = c.y + 1;
      }

      // Скан по полю с зажатым пальцем может подвинуть прокрутку лотка —
      // вернуть её в начало, чтобы кусок лежал под пальцем.
      tester
          .state<ScrollableState>(
            find.descendant(
              of: find.byKey(const Key('packing_tray')),
              matching: find.byType(Scrollable),
            ),
          )
          .position
          .jumpTo(0);
      await tester.pump();
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(Key('tray_piece_$id'))),
      );
      await gesture.moveBy(const Offset(0, -40));
      await tester.pump();

      var found = false;
      for (
        var y = boardOrigin.dy + target.y * cell;
        y <= boardOrigin.dy + (target.y + h) * cell + 100 && !found;
        y += cell / 4
      ) {
        for (
          var x = boardOrigin.dx + target.x * cell;
          x <= boardOrigin.dx + (target.x + w) * cell && !found;
          x += cell / 4
        ) {
          await gesture.moveTo(Offset(x, y));
          await tester.pump();
          final pv = packingPainter(tester).dragPreview;
          if (pv != null &&
              pv.valid &&
              {for (final c in pv.cells) '${c.x},${c.y}'}.containsAll(want) &&
              pv.cells.length == want.length) {
            found = true;
          }
        }
      }
      expect(found, isTrue, reason: 'не нашли точку укладки куска $id');
      await gesture.up();
      await tester.pump();
    }

    testWidgets('лоток на старте идёт в порядке prepared.trayOrder, не по id',
        (tester) async {
      await pumpGame(tester);
      final order = level0().trayOrder;
      final byId = [for (final p in level0().slice.pieces) p.id]..sort();

      expect(order, isNot(byId));
      expect(trayIdsOnScreen(tester), order);
    });

    testWidgets('«Очистить поле»: неактивна на старте, после укладки '
        'активна, нажатие возвращает всё в лоток', (tester) async {
      await pumpGame(tester);
      final level = level0();
      final total = level.slice.pieces.length;
      final orderBefore = trayIdsOnScreen(tester);

      Color labelColor() => tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(const Key('clear_field')),
              matching: find.byType(Text),
            ),
          )
          .style!
          .color!;
      GestureDetector button() =>
          tester.widget<GestureDetector>(find.byKey(const Key('clear_field')));

      expect(find.text('ОЧИСТИТЬ ПОЛЕ'), findsOneWidget);
      expect(button().onTap, isNull);
      expect(labelColor(), const Color(0xFF7C848D));

      await dragPieceToSolution(tester, level, level.trayOrder[0]);
      await dragPieceToSolution(tester, level, level.trayOrder[1]);
      expect(find.text('уложено 2 / $total кусков'), findsOneWidget);
      expect(trayPieces(), findsNWidgets(total - 2));
      expect(button().onTap, isNotNull);
      expect(labelColor(), BlockMaterial.hazardOrange.color);

      await tester.tap(find.byKey(const Key('clear_field')));
      await tester.pump();

      expect(find.text('уложено 0 / $total кусков'), findsOneWidget);
      expect(trayPieces(), findsNWidgets(total));
      expect(trayIdsOnScreen(tester), orderBefore);
      expect(button().onTap, isNull);
    });

    testWidgets('«Очистить поле»: зона нажатия не меньше 40×32 и лежит '
        'внутри строки прогресса высотой 34', (tester) async {
      await pumpGame(tester);
      final button = tester.getRect(find.byKey(const Key('clear_field')));
      expect(button.width, greaterThanOrEqualTo(40.0));
      expect(button.height, greaterThanOrEqualTo(32.0));

      final progressTop = tester.getTopLeft(find.byType(LayoutBuilder).first);
      // Строка прогресса идёт сразу под топбаром (44) и занимает 34.
      expect(button.top, greaterThanOrEqualTo(progressTop.dy + 44.0));
      expect(button.bottom, lessThanOrEqualTo(progressTop.dy + 44.0 + 34.0));
    });

    testWidgets('поле и лоток не прыгают, когда лоток опустел',
        (tester) async {
      await pumpGame(tester);
      final boardFinder = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is PackingPainter,
      );
      final trayFinder = find.byKey(const Key('packing_tray'));
      final boardBefore = tester.getRect(boardFinder);
      final trayBefore = tester.getRect(trayFinder);
      // Лоток 160 (ряд) + рамка/паддинги/подпись = 206.
      expect(trayBefore.height, 206.0);

      await tester.tap(find.byKey(const Key('cheat_button')));
      await _pumpFrames(tester);
      await tester.tap(find.byKey(const Key('cheat_solve')));
      await _pumpFrames(tester);

      expect(trayPieces(), findsNothing, reason: 'лоток должен опустеть');
      expect(tester.getRect(boardFinder), boardBefore);
      expect(tester.getRect(trayFinder), trayBefore);

      // Дать отработать отложенному мета-потоку победы.
      await tester.pump(const Duration(milliseconds: 1000));
      await _pumpFrames(tester);
    });
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

    testWidgets('выбор конфигурации сохраняет seed; «Пересобрать» его меняет', (
      tester,
    ) async {
      await pumpGame(tester);
      List<String> sig(int seed) => [
        for (final p in prepareLevel(
          RoninParts.parts[0].mask,
          SliceConfig.bigPieces,
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
      await pickSliceConfig(tester, SliceConfig.bigPieces);
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
