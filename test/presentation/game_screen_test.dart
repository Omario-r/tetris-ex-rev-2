import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:explosive_tetris/application/build_info.dart';
import 'package:explosive_tetris/application/progress_service.dart';
import 'package:explosive_tetris/game_engine/data/ronin_parts.dart';
import 'package:explosive_tetris/game_engine/packing/slice_config.dart';
import 'package:explosive_tetris/presentation/screens/game_screen.dart';
import 'package:explosive_tetris/presentation/screens/ship_screen.dart';
import 'package:explosive_tetris/presentation/ship_render/ronin_art.dart';
import 'package:explosive_tetris/presentation/ship_render/ship_cell_sampler.dart';
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
  tearDown(() => SharedPreferences.setMockInitialValues({}));

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
        'топбар: «ДЕТАЛЬ 1 / N» + название детали на уровне 0',
        (tester) async {
      await pumpGame(tester);
      expect(find.text('ДЕТАЛЬ 1 / ${RoninParts.parts.length}'), findsOneWidget);
      // Уровень 0 ↔ деталь order 1 (`RoninParts.parts[0]`) — «Нос».
      expect(find.text('НОС'), findsOneWidget);
    });

    testWidgets(
        'топбар на 360×640: название любой детали помещается, '
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

    testWidgets('лоток: подписи нет, кусочки в ряду, высота зоны прежняя',
        (tester) async {
      await pumpGame(tester);

      expect(find.textContaining('ЛОТОК'), findsNothing);
      // Зона лотка 2·1 + 2·12 + 160 + 20 = 206: поле не сдвинулось.
      expect(tester.getSize(find.byKey(const Key('packing_tray'))).height, 206.0);

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

    testWidgets('поле: в укладке плитки (assembled: false), на паузе — '
        'собранная деталь (assembled: true)', (tester) async {
      await pumpGame(tester);
      expect(packingPainter(tester).assembled, isFalse);
      final trayHeight =
          tester.getSize(find.byKey(const Key('packing_tray'))).height;

      await tester.tap(find.byKey(const Key('cheat_button')));
      await _pumpFrames(tester);
      await tester.tap(find.byKey(const Key('cheat_finish_level')));
      await _pumpFrames(tester);

      expect(find.byKey(const Key('packing_complete')), findsOneWidget);
      expect(packingPainter(tester).assembled, isTrue);
      // Кнопки паузы занимают ту же высоту, что и лоток.
      expect(
        tester.getSize(find.byKey(const Key('done_buttons'))).height,
        trayHeight,
      );
    });

    testWidgets('цвета клеток детали приходят в painter после загрузки',
        (tester) async {
      // Растр цветов — настоящий async (Picture.toImage): считаем вне
      // fake-async, экран берёт готовое из кеша ship_render.
      final part = RoninParts.parts[0];
      final colors = await tester
          .runAsync(() => partCellColors(RoninArt.shared, part));
      expect(colors, isNotNull);

      await pumpGame(tester);
      await tester.pump();

      expect(packingPainter(tester).cellColors, same(colors));
    });

    testWidgets('прогресс-бар: подпись «уложено 0 / M кусков» на старте',
        (tester) async {
      await pumpGame(tester);
      // На старте ничего не уложено; M = число кусков нарезки (≥1).
      expect(find.textContaining('уложено 0 / '), findsOneWidget);
    });

    Future<void> solve(WidgetTester tester) async {
      // Чит «Закончить уровень» раскладывает всю деталь без drag-жестов.
      await tester.tap(find.byKey(const Key('cheat_button')));
      await _pumpFrames(tester);
      await tester.tap(find.byKey(const Key('cheat_finish_level')));
      await _pumpFrames(tester);
    }

    testWidgets(
        'завершение через solve-хук: пауза «деталь собрана» — надпись над '
        'полем, кнопки на месте лотка, прогресс засчитан сразу', (tester) async {
      SharedPreferences.setMockInitialValues({'current_level': 0});
      await pumpGame(tester);

      await solve(tester);

      // Надпись «ДЕТАЛЬ СОБРАНА» вместо «уложено N / M кусков».
      expect(
        tester.widget<Text>(find.byKey(const Key('packing_complete'))).data,
        'ДЕТАЛЬ СОБРАНА',
      );
      expect(find.textContaining('уложено'), findsNothing);
      // Лотка нет — на его месте две кнопки; «Очистить поле» скрыта.
      expect(find.byKey(const Key('packing_tray')), findsNothing);
      expect(find.byKey(const Key('done_to_ship_button')), findsOneWidget);
      expect(find.byKey(const Key('done_next_button')), findsOneWidget);
      expect(find.byKey(const Key('clear_field')), findsNothing);
      // «К кораблю» слева, «Следующая деталь» справа.
      expect(
        tester.getCenter(find.byKey(const Key('done_to_ship_button'))).dx,
        lessThan(
          tester.getCenter(find.byKey(const Key('done_next_button'))).dx,
        ),
      );
      // Прогресс засчитан в момент сборки, до выбора кнопки.
      expect(await ProgressService().getCollectedCount(), 1);

      // Автоперехода нет: пауза держится.
      await tester.pump(const Duration(seconds: 3));
      expect(find.byType(GameScreen), findsOneWidget);
      expect(find.byType(ShipScreen), findsNothing);
    });

    testWidgets('пауза: касание поля ничего не меняет', (tester) async {
      await pumpGame(tester);
      await solve(tester);

      final painter = packingPainter(tester);
      final before = painter.state;
      final board = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is PackingPainter,
      );
      // Клетка, занятая уложенным куском.
      final cell = before.occupiedCells.first;
      final at = tester.getTopLeft(board) +
          Offset(
            (cell.x + 0.5) * painter.cellSize,
            (cell.y + 0.5) * painter.cellSize,
          );
      // Тянем уложенный кусок с поля далеко вниз — без паузы он ушёл бы в лоток.
      final gesture = await tester.startGesture(at);
      await tester.pump();
      await gesture.moveBy(const Offset(0, 600));
      await tester.pump();
      expect(find.byKey(const Key('packing_drag_feedback')), findsNothing);
      await gesture.up();
      await _pumpFrames(tester);

      final after = packingPainter(tester).state;
      expect(after.placements, before.placements);
      expect(after.isComplete, isTrue);
      expect(find.byKey(const Key('packing_complete')), findsOneWidget);
    });

    testWidgets('«Следующая деталь» → следующий уровень, прогресс +1 один раз',
        (tester) async {
      SharedPreferences.setMockInitialValues({'current_level': 0});
      await pumpGame(tester);
      await solve(tester);

      await tester.tap(find.byKey(const Key('done_next_button')));
      await _pumpFrames(tester);

      expect(tester.widget<GameScreen>(find.byType(GameScreen)).levelIndex, 1);
      expect(find.byType(ShipScreen), findsNothing);
      expect(await ProgressService().getCollectedCount(), 1);
    });

    testWidgets(
        '«К кораблю» → корабль с приросшей деталью → «Продолжить сборку» → '
        'следующий уровень, прогресс +1 один раз', (tester) async {
      SharedPreferences.setMockInitialValues({'current_level': 0});
      await pumpGame(tester);
      await solve(tester);

      await tester.tap(find.byKey(const Key('done_to_ship_button')));
      await _pumpFrames(tester);

      expect(find.byType(ShipScreen), findsOneWidget);
      expect(find.text('1 / ${RoninParts.parts.length}'), findsOneWidget);
      expect(find.byKey(const Key('ship_back_button')), findsNothing);

      await tester.tap(find.byKey(const Key('ship_continue_button')));
      await _pumpFrames(tester);

      expect(tester.widget<GameScreen>(find.byType(GameScreen)).levelIndex, 1);
      expect(await ProgressService().getCollectedCount(), 1);
    });

    testWidgets('последняя деталь: одна кнопка «К кораблю» → финал',
        (tester) async {
      final last = RoninParts.parts.length - 1;
      SharedPreferences.setMockInitialValues({'current_level': last});
      await pumpGame(tester, level: last);
      await solve(tester);

      expect(find.byKey(const Key('done_next_button')), findsNothing);
      final toShip = find.byKey(const Key('done_to_ship_button'));
      expect(toShip, findsOneWidget);
      expect(await ProgressService().getCollectedCount(), last + 1);

      await tester.tap(toShip);
      await _pumpFrames(tester);

      expect(find.byKey(const Key('ship_finale_text')), findsOneWidget);
      expect(find.byKey(const Key('ship_continue_button')), findsNothing);
      expect(await ProgressService().getCollectedCount(), last + 1);
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
      seed: RoninParts.parts[0].seed,
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

      // Прокрутку лотка не сбрасываем: после старта драга лоток не листается
      // (Ронин-1/08 T3), скан по полю с зажатым пальцем её не двигает.
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

    testWidgets(
        'поле не прыгает, когда лоток опустел: кнопки паузы занимают ту же '
        'зону', (tester) async {
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
      await tester.tap(find.byKey(const Key('cheat_finish_level')));
      await _pumpFrames(tester);

      expect(trayPieces(), findsNothing, reason: 'лоток должен опустеть');
      expect(tester.getRect(boardFinder), boardBefore);
      // На паузе лоток сменился кнопками — зона той же высоты и на том же месте
      // по вертикали.
      final doneZone = tester.getRect(find.byKey(const Key('done_buttons')));
      expect(doneZone.height, trayBefore.height);
      expect(doneZone.top, trayBefore.top);
      expect(doneZone.bottom, trayBefore.bottom);
    });
  });

  group('GameScreen — захват с лотка и кусок над пальцем (Ронин-1/08 T3)', () {
    /// Зазор между нижним краем поднятого куска и пальцем — `_dragLiftGap`.
    const liftGap = 32.0;

    PreparedLevel level0() => prepareLevel(
      RoninParts.parts[0].mask,
      seed: RoninParts.parts[0].seed,
    );

    /// Узкий экран: ряд лотка не помещается и листается; клетка поля — 34.
    Future<void> pumpNarrow(WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: GameScreen()));
      await tester.pump();
    }

    ScrollPosition trayScroll(WidgetTester tester) => tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byKey(const Key('packing_tray')),
            matching: find.byType(Scrollable),
          ),
        )
        .position;

    Finder feedback() => find.byKey(const Key('packing_drag_feedback'));

    Offset boardOrigin(WidgetTester tester) => tester.getTopLeft(
      find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is PackingPainter,
      ),
    );

    ({int w, int h}) dims(PreparedLevel level, int id) {
      final piece = level.slice.pieces.firstWhere((p) => p.id == id);
      var w = 0;
      var h = 0;
      for (final c in piece.cells) {
        if (c.x + 1 > w) w = c.x + 1;
        if (c.y + 1 > h) h = c.y + 1;
      }
      return (w: w, h: h);
    }

    Set<String> cellsAt(PreparedLevel level, int id, ({int x, int y}) at) => {
      for (final c in level.slice.pieces.firstWhere((p) => p.id == id).cells)
        '${at.x + c.x},${at.y + c.y}',
    };

    /// Точка пальца, при которой левый верхний угол поднятого куска (центр X
    /// по пальцу, низ выше пальца на [liftGap]) лежит у клетки [at] со
    /// сдвигом 0.3 клетки — округление якоря должно вернуть ровно [at].
    Offset pointerFor(
      WidgetTester tester,
      PreparedLevel level,
      int id,
      ({int x, int y}) at,
    ) {
      final origin = boardOrigin(tester);
      final cell = packingPainter(tester).cellSize;
      final d = dims(level, id);
      final left = origin.dx + at.x * cell + 0.3 * cell;
      final top = origin.dy + at.y * cell - 0.3 * cell;
      return Offset(left + d.w * cell / 2, top + d.h * cell + liftGap);
    }

    void expectAboveFinger(WidgetTester tester, Offset finger, String why) {
      final rect = tester.getRect(feedback());
      expect(rect.center.dx, closeTo(finger.dx, 0.01), reason: why);
      expect(rect.bottom, closeTo(finger.dy - liftGap, 0.01), reason: why);
      expect(rect.contains(finger), isFalse, reason: why);
    }

    testWidgets('горизонтальный свайп с куска листает лоток и кусок не '
        'поднимает; вверх в том же касании — тоже нет', (tester) async {
      await pumpNarrow(tester);
      final level = level0();
      final scroll = trayScroll(tester);
      expect(scroll.maxScrollExtent, greaterThan(0.0),
          reason: 'ряд лотка должен листаться на узком экране');
      expect(scroll.pixels, 0.0);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(Key('tray_piece_${level.trayOrder[0]}'))),
      );
      for (var i = 0; i < 12; i++) {
        await gesture.moveBy(const Offset(-10, 0));
        await tester.pump();
        expect(feedback(), findsNothing, reason: 'шаг $i');
      }
      expect(scroll.pixels, greaterThan(0.0), reason: 'лоток пролистан');

      for (var i = 0; i < 4; i++) {
        await gesture.moveBy(const Offset(0, -30));
        await tester.pump();
        expect(feedback(), findsNothing);
      }
      await gesture.up();
      await tester.pump(const Duration(seconds: 1));
      expect(packingPainter(tester).state.placements, isEmpty);
      expect(
        find.byKey(Key('tray_piece_${level.trayOrder[0]}')),
        findsOneWidget,
      );
    });

    testWidgets('вертикальный жест поднимает кусок: он над пальцем, превью и '
        'укладка — по формуле; лоток во время драга не листается',
        (tester) async {
      await pumpNarrow(tester);
      final level = level0();
      final id = level.trayOrder[0];
      final target = level.slice.solution[id]!;
      final scroll = trayScroll(tester);
      final scrollBefore = scroll.pixels;

      final start = tester.getCenter(find.byKey(Key('tray_piece_$id')));
      final gesture = await tester.startGesture(start);
      await gesture.moveBy(const Offset(-6, -24));
      await tester.pump();
      expect(feedback(), findsOneWidget, reason: 'драг начался');
      expectAboveFinger(tester, start + const Offset(-6, -24), 'после подъёма');

      // Горизонталь зажатым пальцем — лоток стоит.
      await gesture.moveBy(const Offset(-90, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(150, 0));
      await tester.pump();
      expect(scroll.pixels, scrollBefore);

      final finger = pointerFor(tester, level, id, target);
      await gesture.moveTo(finger);
      await tester.pump();
      expectAboveFinger(tester, finger, 'над полем');
      final pv = packingPainter(tester).dragPreview!;
      expect(pv.valid, isTrue);
      expect({for (final c in pv.cells) '${c.x},${c.y}'},
          cellsAt(level, id, target));

      await gesture.up();
      await tester.pump();
      expect(feedback(), findsNothing);
      expect(packingPainter(tester).state.placements[id], target);
      expect(scroll.pixels, scrollBefore);
    });

    testWidgets('регрессия «непрерывный жест»: кусок идёт за каждым шагом '
        'пальца и укладывается одним касанием', (tester) async {
      await pumpNarrow(tester);
      final level = level0();
      final id = level.trayOrder[0];
      final target = level.slice.solution[id]!;

      var finger = tester.getCenter(find.byKey(Key('tray_piece_$id')));
      final gesture = await tester.startGesture(finger);
      Future<void> step(Offset by) async {
        finger += by;
        await gesture.moveBy(by);
        await tester.pump();
      }

      // До slop — кандидат, куска над пальцем ещё нет.
      await step(const Offset(2, -6));
      expect(feedback(), findsNothing);
      await step(const Offset(-3, -8));
      expect(feedback(), findsNothing);
      // Дальше — драг; вверх и вбок вперемешку.
      const path = [
        Offset(4, -12),
        Offset(-15, -20),
        Offset(25, -18),
        Offset(-40, -10),
        Offset(30, -25),
        Offset(-12, -30),
        Offset(18, 5),
        Offset(-22, -16),
      ];
      for (var i = 0; i < path.length; i++) {
        await step(path[i]);
        expect(feedback(), findsOneWidget, reason: 'шаг $i');
        expectAboveFinger(tester, finger, 'шаг $i');
      }
      final to = pointerFor(tester, level, id, target);
      final from = finger;
      for (var i = 1; i <= 10; i++) {
        await step(Offset.lerp(from, to, i / 10)! - finger);
        expectAboveFinger(tester, finger, 'подход $i');
      }
      await gesture.up();
      await tester.pump();
      expect(packingPainter(tester).state.placements[id], target);
      expect(find.textContaining('уложено 1 / '), findsOneWidget);
    });

    testWidgets('кусок, перекладываемый с поля, — та же геометрия',
        (tester) async {
      await pumpNarrow(tester);
      final level = level0();
      final id = level.trayOrder[0];
      final target = level.slice.solution[id]!;

      // Уложить кусок в эталонную клетку.
      final lift = await tester.startGesture(
        tester.getCenter(find.byKey(Key('tray_piece_$id'))),
      );
      await lift.moveBy(const Offset(0, -30));
      await tester.pump();
      await lift.moveTo(pointerFor(tester, level, id, target));
      await tester.pump();
      await lift.up();
      await tester.pump();
      expect(packingPainter(tester).state.placements[id], target);

      // Взять его с поля за одну из клеток: захват сразу, кусок над пальцем.
      final piece = level.slice.pieces.firstWhere((p) => p.id == id);
      final cell = packingPainter(tester).cellSize;
      final origin = boardOrigin(tester);
      final c0 = piece.cells.first;
      final grab = origin +
          Offset(
            (target.x + c0.x + 0.5) * cell,
            (target.y + c0.y + 0.5) * cell,
          );
      final gesture = await tester.startGesture(grab);
      await tester.pump();
      expect(feedback(), findsOneWidget);
      expectAboveFinger(tester, grab, 'на захвате с поля');

      final finger = pointerFor(tester, level, id, target);
      await gesture.moveTo(finger);
      await tester.pump();
      expectAboveFinger(tester, finger, 'перекладка');
      final pv = packingPainter(tester).dragPreview!;
      expect(pv.valid, isTrue);
      expect({for (final c in pv.cells) '${c.x},${c.y}'},
          cellsAt(level, id, target));
      await gesture.up();
      await tester.pump();
      expect(packingPainter(tester).state.placements[id], target);
    });
  });

  group('GameScreen — кусок встаёт в лоток на ближайшее место (Ронин-1/12)', () {
    const liftGap = 32.0;

    PreparedLevel level0() => prepareLevel(
      RoninParts.parts[0].mask,
      seed: RoninParts.parts[0].seed,
    );

    Future<void> pumpNarrow(WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: GameScreen()));
      await tester.pump();
    }

    ScrollPosition trayScroll(WidgetTester tester) => tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byKey(const Key('packing_tray')),
            matching: find.byType(Scrollable),
          ),
        )
        .position;

    List<int> trayOrder(WidgetTester tester) =>
        packingPainter(tester).state.trayOrder;

    Rect trayRect(WidgetTester tester) =>
        tester.getRect(find.byKey(const Key('packing_tray')));

    /// Кладёт `level.trayOrder[0]` жестом в эталонную клетку; возвращает id.
    Future<int> layFirstPiece(WidgetTester tester, PreparedLevel level) async {
      final id = level.trayOrder[0];
      final target = level.slice.solution[id]!;
      final piece = level.slice.pieces.firstWhere((p) => p.id == id);
      var w = 0;
      var h = 0;
      for (final c in piece.cells) {
        if (c.x + 1 > w) w = c.x + 1;
        if (c.y + 1 > h) h = c.y + 1;
      }
      final origin = tester.getTopLeft(
        find.byWidgetPredicate(
          (x) => x is CustomPaint && x.painter is PackingPainter,
        ),
      );
      final cell = packingPainter(tester).cellSize;
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(Key('tray_piece_$id'))),
      );
      await gesture.moveBy(const Offset(0, -30));
      await tester.pump();
      await gesture.moveTo(
        Offset(
          origin.dx + target.x * cell + 0.3 * cell + w * cell / 2,
          origin.dy + target.y * cell - 0.3 * cell + h * cell + liftGap,
        ),
      );
      await tester.pump();
      await gesture.up();
      await tester.pump();
      expect(packingPainter(tester).state.placements[id], target);
      return id;
    }

    /// Берёт уложенный кусок [id] с поля за одну из его клеток.
    Future<TestGesture> grabFromField(
      WidgetTester tester,
      PreparedLevel level,
      int id,
    ) async {
      final target = level.slice.solution[id]!;
      final piece = level.slice.pieces.firstWhere((p) => p.id == id);
      final origin = tester.getTopLeft(
        find.byWidgetPredicate(
          (x) => x is CustomPaint && x.painter is PackingPainter,
        ),
      );
      final cell = packingPainter(tester).cellSize;
      final c0 = piece.cells.first;
      final gesture = await tester.startGesture(
        origin +
            Offset(
              (target.x + c0.x + 0.5) * cell,
              (target.y + c0.y + 0.5) * cell,
            ),
      );
      await tester.pump();
      expect(find.byKey(const Key('packing_drag_feedback')), findsOneWidget);
      return gesture;
    }

    /// Число кусков ряда лотка, чей центр левее [x] (глобальная точка).
    int piecesLeftOf(WidgetTester tester, double x) {
      var n = 0;
      for (final id in trayOrder(tester)) {
        final finder = find.byKey(Key('tray_piece_$id'));
        if (finder.evaluate().isEmpty) continue;
        if (tester.getCenter(finder).dx < x) n++;
      }
      return n;
    }

    testWidgets('кусок с поля, отпущенный над первым куском лотка, встаёт '
        'первым', (tester) async {
      await pumpNarrow(tester);
      final level = level0();
      final id = await layFirstPiece(tester, level);
      final before = trayOrder(tester);
      final first = tester.getTopLeft(find.byKey(Key('tray_piece_${before[0]}')));

      final gesture = await grabFromField(tester, level, id);
      await gesture.moveTo(Offset(first.dx + 1, trayRect(tester).bottom - 8));
      await tester.pump();
      await gesture.up();
      await tester.pump(const Duration(seconds: 1));

      expect(packingPainter(tester).state.placements, isEmpty);
      expect(trayOrder(tester), [id, ...before]);
    });

    testWidgets('кусок с поля, отпущенный над серединой лотка, встаёт между '
        'соседями', (tester) async {
      await pumpNarrow(tester);
      final level = level0();
      final id = await layFirstPiece(tester, level);
      final before = trayOrder(tester);
      // Правее центра второго куска — место 2 (после двух первых).
      final second = tester.getCenter(find.byKey(Key('tray_piece_${before[1]}')));

      final gesture = await grabFromField(tester, level, id);
      await gesture.moveTo(Offset(second.dx + 3, trayRect(tester).bottom - 8));
      await tester.pump();
      await gesture.up();
      await tester.pump(const Duration(seconds: 1));

      expect(trayOrder(tester),
          [before[0], before[1], id, ...before.sublist(2)]);
    });

    testWidgets('кусок лотка, перетащенный левее первого, — первый '
        '(перестановка)', (tester) async {
      await pumpNarrow(tester);
      final level = level0();
      final order = level.trayOrder;
      final first = tester.getTopLeft(find.byKey(Key('tray_piece_${order[0]}')));

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(Key('tray_piece_${order[1]}'))),
      );
      await gesture.moveBy(const Offset(0, -30));
      await tester.pump();
      expect(find.byKey(const Key('packing_drag_feedback')), findsOneWidget);
      await gesture.moveTo(Offset(first.dx + 1, trayRect(tester).bottom - 8));
      await tester.pump();
      await gesture.up();
      await tester.pump(const Duration(seconds: 1));

      expect(packingPainter(tester).state.placements, isEmpty);
      expect(trayOrder(tester), [order[1], order[0], ...order.sublist(2)]);
    });

    /// Якорь поля, который дал бы кусок [id] при пальце в [finger] (формула
    /// `_anchorAt`: левый верхний угол поднятого куска, округление).
    ({int x, int y}) fieldAnchorFor(
      WidgetTester tester,
      PreparedLevel level,
      int id,
      Offset finger,
    ) {
      final piece = level.slice.pieces.firstWhere((p) => p.id == id);
      var w = 0;
      var h = 0;
      for (final c in piece.cells) {
        if (c.x + 1 > w) w = c.x + 1;
        if (c.y + 1 > h) h = c.y + 1;
      }
      final origin = tester.getTopLeft(
        find.byWidgetPredicate(
          (x) => x is CustomPaint && x.painter is PackingPainter,
        ),
      );
      final cell = packingPainter(tester).cellSize;
      return (
        x: ((finger.dx - w * cell / 2 - origin.dx) / cell).round(),
        y: ((finger.dy - liftGap - h * cell - origin.dy) / cell).round(),
      );
    }

    bool onField(({int x, int y}) a) =>
        a.x >= 0 && a.x < 10 && a.y >= 0 && a.y < 14;

    testWidgets('палец у верхней кромки лотка важнее якоря на поле: кусок с '
        'поля уходит в лоток к пальцу', (tester) async {
      await pumpNarrow(tester);
      final level = level0();
      final id = await layFirstPiece(tester, level);
      final finger = Offset(180, trayRect(tester).top + 4);
      expect(onField(fieldAnchorFor(tester, level, id, finger)), isTrue,
          reason: 'условие теста: угол куска ещё над полем');
      final expected = piecesLeftOf(tester, finger.dx);
      final before = trayOrder(tester);

      final gesture = await grabFromField(tester, level, id);
      await gesture.moveTo(finger);
      await tester.pump();
      expect(packingPainter(tester).dragPreview, isNull,
          reason: 'над лотком превью укладки нет');
      await gesture.up();
      await tester.pump(const Duration(seconds: 1));

      expect(packingPainter(tester).state.placements, isEmpty);
      expect(trayOrder(tester),
          [...before.take(expected), id, ...before.skip(expected)]);
    });

    testWidgets('палец у верхней кромки лотка: кусок лотка переставляется, а '
        'не укладывается на поле', (tester) async {
      await pumpNarrow(tester);
      final level = level0();
      final order = level.trayOrder;
      final id = order[1];
      final finger = Offset(180, trayRect(tester).top + 4);
      expect(onField(fieldAnchorFor(tester, level, id, finger)), isTrue,
          reason: 'условие теста: угол куска ещё над полем');

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(Key('tray_piece_$id'))),
      );
      await gesture.moveBy(const Offset(0, -30));
      await tester.pump();
      final rest = [...order]..remove(id);
      final expected = piecesLeftOf(tester, finger.dx);
      await gesture.moveTo(finger);
      await tester.pump();
      await gesture.up();
      await tester.pump(const Duration(seconds: 1));

      expect(packingPainter(tester).state.placements, isEmpty);
      expect(trayOrder(tester),
          [...rest.take(expected), id, ...rest.skip(expected)]);
    });

    testWidgets('кусок лотка, отпущенный вне поля и лотка, остаётся на своём '
        'месте', (tester) async {
      await pumpNarrow(tester);
      final level = level0();
      final order = level.trayOrder;

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(Key('tray_piece_${order[1]}'))),
      );
      await gesture.moveBy(const Offset(0, -30));
      await tester.pump();
      await gesture.moveTo(const Offset(5, 10));
      await tester.pump();
      await gesture.up();
      await tester.pump(const Duration(seconds: 1));

      expect(trayOrder(tester), order);
    });

    testWidgets('кусок с поля, отпущенный вне поля и лотка при прокрученном '
        'ряде, встаёт у пальца, а не в конец', (tester) async {
      await pumpNarrow(tester);
      final level = level0();
      final id = await layFirstPiece(tester, level);
      final scroll = trayScroll(tester);
      expect(scroll.maxScrollExtent, greaterThan(0.0),
          reason: 'ряд лотка должен листаться на узком экране');
      scroll.jumpTo(scroll.maxScrollExtent / 2);
      await tester.pump();
      final offsetBefore = scroll.pixels;
      const fingerX = 180.0;
      final expected = piecesLeftOf(tester, fingerX);
      final count = trayOrder(tester).length;
      expect(expected, inInclusiveRange(1, count - 1),
          reason: 'точка пальца внутри ряда: не в начале и не в конце');

      final gesture = await grabFromField(tester, level, id);
      // Над топбаром: ни поле, ни лоток.
      await gesture.moveTo(const Offset(fingerX, 10));
      await tester.pump();
      await gesture.up();
      await tester.pump(const Duration(seconds: 1));

      final after = trayOrder(tester);
      expect(packingPainter(tester).state.placements, isEmpty);
      expect(after.indexOf(id), expected);
      expect(after.last, isNot(id));
      expect(scroll.pixels, offsetBefore,
          reason: 'место было видно — лоток не двигается');
    });

    testWidgets('возврат на место вне видимой части: лоток прокручивается к '
        'куску', (tester) async {
      await pumpNarrow(tester);
      final level = level0();
      final id = await layFirstPiece(tester, level);
      final scroll = trayScroll(tester);
      final gesture = await grabFromField(tester, level, id);
      // Палец у правого края экрана: x зажимается в видимую часть ряда,
      // кусок встаёт у правого края и может выступать за него.
      await gesture.moveTo(const Offset(359, 10));
      await tester.pump();
      await gesture.up();
      // Кадр с новым рядом; прокрутка стартует после него и идёт анимацией.
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(seconds: 1));

      final order = trayOrder(tester);
      expect(order.contains(id), isTrue);
      expect(order.last, isNot(id));
      final rect = tester.getRect(find.byKey(Key('tray_piece_$id')));
      final viewport = tester.getRect(find
          .descendant(
            of: find.byKey(const Key('packing_tray')),
            matching: find.byType(Scrollable),
          )
          .first);
      expect(rect.left, greaterThanOrEqualTo(viewport.left - 0.01));
      expect(rect.right, lessThanOrEqualTo(viewport.right + 0.01));
      expect(scroll.pixels, greaterThan(0.0),
          reason: 'место справа вне видимой части — лоток прокручен');
    });

    testWidgets('«Очистить поле» при прокрученном лотке — лоток в начало',
        (tester) async {
      await pumpNarrow(tester);
      final level = level0();
      await layFirstPiece(tester, level);
      final scroll = trayScroll(tester);
      scroll.jumpTo(scroll.maxScrollExtent);
      await tester.pump();
      expect(scroll.pixels, greaterThan(0.0));

      await tester.tap(find.byKey(const Key('clear_field')));
      await tester.pump();

      expect(scroll.pixels, 0.0);
      expect(trayOrder(tester), level.trayOrder);
    });
  });

  group('GameScreen — чит-меню (Ронин-1/13, D-018)', () {
    Future<void> openMenu(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('cheat_button')));
      await _pumpFrames(tester);
    }

    testWidgets('кнопка чит-меню есть (kDevTools по умолчанию true)',
        (tester) async {
      expect(kDevTools, isTrue);
      await pumpGame(tester);
      expect(find.byKey(const Key('cheat_button')), findsOneWidget);
    });

    testWidgets('«Уровень N»: открыта деталь N, собрано N−1 деталей',
        (tester) async {
      for (final i in const [2, 7]) {
        SharedPreferences.setMockInitialValues({});
        await pumpGame(tester);
        await openMenu(tester);
        await tester.tap(find.byKey(Key('cheat_level_$i')));
        await _pumpFrames(tester);

        expect(tester.widget<GameScreen>(find.byType(GameScreen)).levelIndex, i);
        expect(find.text('ДЕТАЛЬ ${i + 1} / ${RoninParts.parts.length}'),
            findsOneWidget);
        expect(await ProgressService().getCollectedCount(), i);
      }
    });

    testWidgets('«Уровень» понижает прогресс: с детали 6 на деталь 2',
        (tester) async {
      SharedPreferences.setMockInitialValues({'current_level': 5});
      await pumpGame(tester, level: 5);
      await openMenu(tester);
      await tester.tap(find.byKey(const Key('cheat_level_1')));
      await _pumpFrames(tester);

      expect(await ProgressService().getCollectedCount(), 1);
      expect(find.text('ДЕТАЛЬ 2 / ${RoninParts.parts.length}'), findsOneWidget);
    });

    testWidgets('«Сбросить на начало»: прогресс 0, деталь 1', (tester) async {
      SharedPreferences.setMockInitialValues({'current_level': 5});
      await pumpGame(tester, level: 5);
      await openMenu(tester);
      await tester.tap(find.byKey(const Key('cheat_reset')));
      await _pumpFrames(tester);

      expect(tester.widget<GameScreen>(find.byType(GameScreen)).levelIndex, 0);
      expect(find.text('ДЕТАЛЬ 1 / ${RoninParts.parts.length}'), findsOneWidget);
      expect(await ProgressService().getCollectedCount(), 0);
    });

    testWidgets(
        '«Закончить уровень»: пауза «деталь собрана», деталь засчитана',
        (tester) async {
      SharedPreferences.setMockInitialValues({'current_level': 3});
      await pumpGame(tester, level: 3);
      await openMenu(tester);
      await tester.tap(find.byKey(const Key('cheat_finish_level')));
      await _pumpFrames(tester);

      expect(find.byType(GameScreen), findsOneWidget);
      expect(find.byKey(const Key('packing_complete')), findsOneWidget);
      expect(find.byKey(const Key('done_next_button')), findsOneWidget);
      expect(find.byKey(const Key('done_to_ship_button')), findsOneWidget);
      expect(await ProgressService().getCollectedCount(), 4);
    });
  });

  group('GameScreen — нарезка «Крупные куски» (Ронин-1/07)', () {
    testWidgets('поле 10×14, клетка 34, число кусков из prepareLevel', (
      tester,
    ) async {
      await pumpGame(tester);
      final painter = packingPainter(tester);
      expect(painter.state.silhouette.width, 10);
      expect(painter.state.silhouette.height, 14);
      expect(painter.cellSize, 34.0);

      final expected = prepareLevel(
        RoninParts.parts[0].mask,
        seed: RoninParts.parts[0].seed,
      ).slice.pieces.length;
      expect(find.text('уложено 0 / $expected кусков'), findsOneWidget);
    });

    testWidgets(
      'лоток не выше 160 px на всех деталях',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        for (var i = 0; i < RoninParts.parts.length; i++) {
          await tester.pumpWidget(
            MaterialApp(
              home: GameScreen(key: ValueKey('part$i'), levelIndex: i),
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
              reason: 'деталь ${i + 1}',
            );
          }
        }
      },
    );
  });
}
