import 'package:flutter/material.dart';

import '../widgets/ship.dart';

/// Оверлей чит-меню для дев-сборки: минимальный список кнопок.
///
/// Показывается через [showCheatMenu] (bottom sheet). Вход на него — только под
/// `kDebugMode` (см. `GameScreen`). Сама логика читов живёт в `GameScreen` и
/// передаётся колбэками; меню — только вид.
class CheatMenu extends StatelessWidget {
  /// Задать «собрано N деталей» (N = 0..[kShipPartCount]).
  final void Function(int parts) onSetShipParts;

  const CheatMenu({super.key, required this.onSetShipParts});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Чит-меню (dev)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Text(
              'Состояние корабля',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (int n = 0; n <= kShipPartCount; n++)
                  ElevatedButton(
                    key: Key('cheat_ship_parts_$n'),
                    onPressed: () => onSetShipParts(n),
                    child: Text('$n'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Открывает [CheatMenu] как bottom sheet.
Future<void> showCheatMenu(
  BuildContext context, {
  required void Function(int parts) onSetShipParts,
}) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (_) => CheatMenu(onSetShipParts: onSetShipParts),
  );
}
