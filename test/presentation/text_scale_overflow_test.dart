import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:explosive_tetris/presentation/screens/game_screen.dart';
import 'package:explosive_tetris/presentation/screens/ship_screen.dart';

/// Экраны игры и корабля не переполняются при крупном системном шрифте
/// (D-018, Ронин-1/13 T1: «bottom overflowed by 3 pixels» на телефоне PO).

const _sizes = [Size(375, 667), Size(402, 874), Size(430, 932)];
const _scales = [1.0, 1.2, 1.5];

/// Индексы деталей 1, 13, 17 (0-based).
const _levels = [0, 12, 16];

Future<void> _pumpFrames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => SharedPreferences.setMockInitialValues({}));

  void configure(WidgetTester tester, Size size, double scale) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  for (final size in _sizes) {
    for (final scale in _scales) {
      final tag = '${size.width.toInt()}×${size.height.toInt()}, шрифт ×$scale';

      testWidgets('GameScreen: детали 1/13/17 и пауза без overflow ($tag)', (
        tester,
      ) async {
        configure(tester, size, scale);
        for (final level in _levels) {
          await tester.pumpWidget(
            MaterialApp(
              home: GameScreen(key: ValueKey(level), levelIndex: level),
            ),
          );
          await _pumpFrames(tester);
          expect(tester.takeException(), isNull, reason: 'деталь ${level + 1}');
        }

        // Пауза «деталь собрана» (кнопки на месте лотка) — через чит-меню.
        await tester.tap(find.byKey(const Key('cheat_button')));
        await _pumpFrames(tester);
        expect(tester.takeException(), isNull, reason: 'чит-меню');
        await tester.scrollUntilVisible(
          find.byKey(const Key('cheat_finish_level')),
          100.0,
          scrollable: find.byType(Scrollable).last,
        );
        await tester.tap(find.byKey(const Key('cheat_finish_level')));
        await _pumpFrames(tester);
        expect(find.byKey(const Key('packing_complete')), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'пауза');
      });

      testWidgets('ShipScreen без overflow ($tag)', (tester) async {
        configure(tester, size, scale);
        final screens = <Widget>[
          const ShipScreen(),
          ShipScreen.afterWin(collectedCount: 3, onContinue: () {}),
          const ShipScreen.finale(animateLast: false),
        ];
        for (var i = 0; i < screens.length; i++) {
          await tester.pumpWidget(
            MaterialApp(
              home: KeyedSubtree(key: ValueKey(i), child: screens[i]),
            ),
          );
          await _pumpFrames(tester);
          expect(tester.takeException(), isNull, reason: 'режим $i');
        }
      });
    }
  }
}
