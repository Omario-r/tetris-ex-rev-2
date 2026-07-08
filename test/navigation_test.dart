import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:explosive_tetris/main.dart';
import 'package:explosive_tetris/presentation/screens/game_screen.dart';

/// Точка входа приложения: `main.dart` грузит сохранённый уровень из prefs.
/// (Пост-победный поток проверяется в `test/presentation/win_flow_test.dart`.)
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('main.dart загружает уровень 5 из prefs', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues({'current_level': 5});

    await tester.pumpWidget(const AppRoot());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final gameScreen = tester.widget<GameScreen>(find.byType(GameScreen));
    expect(gameScreen.levelIndex, 5);
  });

  testWidgets('main.dart загружает уровень 0 если prefs пуст', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const AppRoot());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final gameScreen = tester.widget<GameScreen>(find.byType(GameScreen));
    expect(gameScreen.levelIndex, 0);
  });
}
