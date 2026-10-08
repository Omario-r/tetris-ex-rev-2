import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:explosive_tetris/application/progress_service.dart';
import 'package:explosive_tetris/game_engine/packing/slice_config.dart';
import 'package:explosive_tetris/presentation/screens/cheat_menu.dart';
import 'package:explosive_tetris/presentation/screens/game_screen.dart';
import 'package:explosive_tetris/presentation/screens/ship_screen.dart';
import 'package:explosive_tetris/presentation/ship_render/ship_composite_painter.dart';
import 'package:explosive_tetris/presentation/widgets/ship.dart';

ShipCompositePainter _shipPainter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((cp) => cp.painter)
    .whereType<ShipCompositePainter>()
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

  testWidgets('Чит «состояние корабля»: N=2 → прогресс=2 → корабль 2/N',
      (tester) async {
    await pumpGame(tester);

    await tester.tap(find.byKey(const Key('cheat_button')));
    await _pumpFrames(tester);

    await tester.tap(find.byKey(const Key('cheat_ship_parts_2')));
    await _pumpFrames(tester, const Duration(seconds: 2));

    expect(await ProgressService().getCollectedCount(), 2);

    await tester.tap(find.byKey(const Key('ship_button')));
    await _pumpFrames(tester);
    expect(find.byType(ShipScreen), findsOneWidget);
    expect(_shipPainter(tester).collectedCount, 2);
  });

  testWidgets('Чит «состояние корабля»: N=15 → собрано 15 → корабль 15/15',
      (tester) async {
    await pumpGame(tester);

    await tester.tap(find.byKey(const Key('cheat_button')));
    await _pumpFrames(tester);

    final last = Key('cheat_ship_parts_$kShipPartCount');
    await tester.scrollUntilVisible(
      find.byKey(last),
      200.0,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(last));
    await _pumpFrames(tester, const Duration(seconds: 2));

    expect(await ProgressService().getCollectedCount(), kShipPartCount);

    await tester.tap(find.byKey(const Key('ship_button')));
    await _pumpFrames(tester);
    expect(_shipPainter(tester).collectedCount, kShipPartCount);
    expect(find.text('$kShipPartCount / $kShipPartCount'), findsOneWidget);
  });

  testWidgets('Чит «выбор уровня» прогресс не меняет', (tester) async {
    SharedPreferences.setMockInitialValues({'current_level': 5});
    await pumpGame(tester, level: 5);

    await tester.tap(find.byKey(const Key('cheat_button')));
    await _pumpFrames(tester);
    await tester.tap(find.byKey(const Key('cheat_level_2')));
    await _pumpFrames(tester);

    expect(tester.widget<GameScreen>(find.byType(GameScreen)).levelIndex, 2);
    expect(await ProgressService().getCollectedCount(), 5);
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
    expect(find.text('ДЕТАЛЬ 3 / $kShipPartCount'), findsOneWidget);
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

  testWidgets('Чит «мгновенная победа»: прогресс +1 и пауза «деталь собрана»',
      (tester) async {
    SharedPreferences.setMockInitialValues({'current_level': 0});
    await pumpGame(tester, level: 0);

    await tester.tap(find.byKey(const Key('cheat_button')));
    await _pumpFrames(tester);

    await tester.tap(find.byKey(const Key('cheat_instant_win')));
    await _pumpFrames(tester);

    // Пауза на том же экране: автоперехода на корабль нет.
    expect(find.byType(GameScreen), findsOneWidget);
    expect(find.byType(ShipScreen), findsNothing);
    expect(find.byKey(const Key('packing_complete')), findsOneWidget);
    expect(find.byKey(const Key('done_next_button')), findsOneWidget);
    expect(find.byKey(const Key('done_to_ship_button')), findsOneWidget);
    expect(await ProgressService().getCollectedCount(), 1);
  });

  group('Секция «Нарезка: калибровка»', () {
    Future<void> pumpMenu(
      WidgetTester tester, {
      required SliceConfig current,
      required ValueChanged<SliceConfig> onSet,
    }) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CheatMenu(
              onSelectLevel: (_) {},
              onInstantWin: () {},
              onSetShipParts: (_) {},
              feedMode: FeedMode.fullSet,
              onSetFeedMode: (_) {},
              onReshuffle: () {},
              onSolve: () {},
              sliceConfig: current,
              onSetSliceConfig: onSet,
            ),
          ),
        ),
      );
    }

    const labels = {
      SliceConfig.bigPieces: 'Крупные куски',
      SliceConfig.spikyPieces: 'Колючие куски',
    };

    testWidgets(
      'кнопки в порядке SliceConfig.values, текущая отмечена «✓ »',
      (tester) async {
        for (final current in SliceConfig.values) {
          await pumpMenu(tester, current: current, onSet: (_) {});
          expect(find.text('Нарезка: калибровка'), findsOneWidget);
          for (final config in SliceConfig.values) {
            final button = find.byKey(Key('slice_config_${config.name}'));
            expect(button, findsOneWidget);
            final label = labels[config]!;
            expect(
              find.descendant(
                of: button,
                matching: find.text(config == current ? '✓ $label' : label),
              ),
              findsOneWidget,
              reason: '$config при текущей $current',
            );
          }
        }
        // Порядок кнопок слева направо — как у SliceConfig.values.
        final xs = [
          for (final c in SliceConfig.values)
            tester.getTopLeft(find.byKey(Key('slice_config_${c.name}'))).dx,
        ];
        expect(xs, orderedEquals([...xs]..sort()));
      },
    );

    testWidgets('две кнопки нарезки, подпись «Колючие куски»', (tester) async {
      await pumpMenu(tester, current: SliceConfig.bigPieces, onSet: (_) {});
      expect(SliceConfig.values.length, 2);
      expect(find.byKey(const Key('slice_config_bigPieces')), findsOneWidget);
      expect(find.byKey(const Key('slice_config_spikyPieces')), findsOneWidget);
      expect(find.text('Колючие куски'), findsOneWidget);
    });

    testWidgets('тап по кнопке отдаёт в колбэк выбранную конфигурацию', (
      tester,
    ) async {
      final picked = <SliceConfig>[];
      await pumpMenu(tester, current: SliceConfig.bigPieces, onSet: picked.add);
      for (final config in SliceConfig.values) {
        await tester.tap(find.byKey(Key('slice_config_${config.name}')));
      }
      expect(picked, SliceConfig.values);
    });
  });
}
