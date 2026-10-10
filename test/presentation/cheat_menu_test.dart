import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:explosive_tetris/application/build_info.dart';
import 'package:explosive_tetris/game_engine/data/ronin_parts.dart';
import 'package:explosive_tetris/presentation/screens/cheat_menu.dart';
import 'package:explosive_tetris/presentation/screens/game_screen.dart';

/// Число деталей корабля = число уровней (единый источник — `RoninParts`).
final int _partCount = RoninParts.parts.length;

/// Прокачивает кадры без `pumpAndSettle` — `GameScreen` держит пульс-контроллер.
Future<void> _pumpFrames(
  WidgetTester tester, [
  Duration d = const Duration(milliseconds: 500),
]) async {
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

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('cheat_button')));
    await _pumpFrames(tester);
  }

  testWidgets('Кнопка читов есть (kDevTools по умолчанию) и открывает меню', (
    tester,
  ) async {
    expect(kDevTools, isTrue);
    await pumpGame(tester);

    expect(find.byKey(const Key('cheat_button')), findsOneWidget);

    await openMenu(tester);

    expect(find.byType(CheatMenu), findsOneWidget);
    expect(find.text('Чит-меню'), findsOneWidget);
  });

  testWidgets('Строка сборки: «Сборка: dev» без --dart-define', (tester) async {
    await pumpGame(tester);
    await openMenu(tester);

    expect(find.byKey(const Key('cheat_build')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('cheat_build'))).data,
      'Сборка: ${buildLabel()}',
    );
    expect(find.text('Сборка: dev'), findsOneWidget);
  });

  testWidgets('«Уровень» предлагает ровно по числу деталей, + две кнопки', (
    tester,
  ) async {
    await pumpGame(tester);
    await openMenu(tester);

    expect(find.text('Уровень'), findsOneWidget);
    for (int i = 0; i < _partCount; i++) {
      expect(find.byKey(Key('cheat_level_$i')), findsOneWidget);
    }
    expect(find.byKey(Key('cheat_level_$_partCount')), findsNothing);
    expect(find.byKey(const Key('cheat_reset')), findsOneWidget);
    expect(find.text('Сбросить на начало'), findsOneWidget);
    expect(find.byKey(const Key('cheat_finish_level')), findsOneWidget);
    expect(find.text('Закончить уровень'), findsOneWidget);
  });

  testWidgets('Старых читов в меню нет', (tester) async {
    await pumpGame(tester, level: 1);
    await openMenu(tester);

    for (final key in const [
      'cheat_instant_win',
      'cheat_ship_parts_0',
      'cheat_ship_parts_2',
      'cheat_reshuffle',
      'cheat_solve',
      'cheat_charges_0',
      'cheat_open_prototype',
    ]) {
      expect(find.byKey(Key(key)), findsNothing, reason: key);
    }
    for (final text in const [
      'Победить',
      'Состояние корабля',
      'Пересобрать нарезку',
      'Решить',
      'Подача',
      'Лоток-3',
    ]) {
      expect(find.text(text), findsNothing, reason: text);
    }
  });

  testWidgets(
    'Чит-меню не переполняется на маленьком экране (390×844) и кнопки '
    'доступны через скролл',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(
        const MaterialApp(home: GameScreen(levelIndex: 0)),
      );
      await tester.pump();

      await openMenu(tester);

      expect(
        tester.takeException(),
        isNull,
        reason:
            'чит-меню не должно переполняться (регрессия hotfix 2026-07-11)',
      );

      await tester.scrollUntilVisible(
        find.byKey(const Key('cheat_finish_level')),
        200.0,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.byKey(const Key('cheat_finish_level')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
