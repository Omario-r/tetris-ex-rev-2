import 'package:flutter/material.dart';

import '../widgets/ship.dart';

/// Верхняя граница кнопок чита «заряды взрыва» (0.._maxCheatCharges) — с запасом
/// над плейсхолдер-бюджетом (эпик «Взрыв», Стори 01/02).
const _maxCheatCharges = 5;

/// Оверлей чит-меню для дев-сборки: минимальный список кнопок.
///
/// Показывается через [showCheatMenu] (bottom sheet). Вход на него — только под
/// `kDebugMode` (см. `GameScreen`). Сама логика читов живёт в `GameScreen` и
/// передаётся колбэками; меню — только вид.
class CheatMenu extends StatelessWidget {
  /// Перезапустить игру на уровне с индексом `levelIndex` (0-based).
  final void Function(int levelIndex) onSelectLevel;

  /// Мгновенная победа: засчитать текущий уровень пройденным.
  final VoidCallback onInstantWin;

  /// Задать «собрано N деталей» (N = 0..[kShipPartCount]).
  final void Function(int parts) onSetShipParts;

  /// Задать число зарядов взрыва в текущей партии (эпик «Взрыв»).
  final void Function(int charges) onSetCharges;

  /// Сколько дев-уровней предлагать в «выборе уровня». `null` (по умолчанию) —
  /// все детали корабля [kShipPartCount] (не можем задать дефолтом: `kShipPartCount`
  /// не `const`). Единый источник истины «N уровней ↔ N деталей».
  final int? levelCount;

  const CheatMenu({
    super.key,
    required this.onSelectLevel,
    required this.onInstantWin,
    required this.onSetShipParts,
    required this.onSetCharges,
    this.levelCount,
  });

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
            _section(context, 'Выбор уровня', [
              for (int i = 0; i < (levelCount ?? kShipPartCount); i++)
                ElevatedButton(
                  key: Key('cheat_level_$i'),
                  onPressed: () => onSelectLevel(i),
                  child: Text('${i + 1}'),
                ),
            ]),
            _section(context, 'Мгновенная победа', [
              ElevatedButton(
                key: const Key('cheat_instant_win'),
                onPressed: onInstantWin,
                child: const Text('Победить'),
              ),
            ]),
            _section(context, 'Состояние корабля', [
              for (int n = 0; n <= kShipPartCount; n++)
                ElevatedButton(
                  key: Key('cheat_ship_parts_$n'),
                  onPressed: () => onSetShipParts(n),
                  child: Text('$n'),
                ),
            ]),
            _section(context, 'Заряды взрыва', [
              for (int n = 0; n <= _maxCheatCharges; n++)
                ElevatedButton(
                  key: Key('cheat_charges_$n'),
                  onPressed: () => onSetCharges(n),
                  child: Text('$n'),
                ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title, List<Widget> buttons) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: buttons),
        ],
      ),
    );
  }
}

/// Открывает [CheatMenu] как bottom sheet.
Future<void> showCheatMenu(
  BuildContext context, {
  required void Function(int levelIndex) onSelectLevel,
  required VoidCallback onInstantWin,
  required void Function(int parts) onSetShipParts,
  required void Function(int charges) onSetCharges,
}) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (_) => CheatMenu(
      onSelectLevel: onSelectLevel,
      onInstantWin: onInstantWin,
      onSetShipParts: onSetShipParts,
      onSetCharges: onSetCharges,
    ),
  );
}
