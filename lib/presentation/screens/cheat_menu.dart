import 'package:flutter/material.dart';

import '../../application/build_info.dart';
import '../../game_engine/data/ronin_parts.dart';

/// Оверлей чит-меню (дев-инструменты, D-018): строка сборки, выбор уровня,
/// «Сбросить на начало», «Закончить уровень».
///
/// Показывается через [showCheatMenu] (bottom sheet). Вход на него — только под
/// `kDevTools` (см. `GameScreen`). Сама логика читов живёт в `GameScreen` и
/// передаётся колбэками; меню — только вид.
class CheatMenu extends StatelessWidget {
  /// Открыть деталь `levelIndex` (0-based): корабль собран до неё.
  final void Function(int levelIndex) onSelectLevel;

  /// Сбросить прогресс и начать с детали 1.
  final VoidCallback onResetGame;

  /// Закончить текущий уровень: все куски укладываются, дальше обычная пауза.
  final VoidCallback onFinishLevel;

  /// Сколько уровней предлагать в «Уровне». `null` (по умолчанию) — все детали
  /// корабля `RoninParts.parts.length` (не можем задать дефолтом: длина списка
  /// не `const`). Единый источник истины «N уровней ↔ N деталей».
  final int? levelCount;

  const CheatMenu({
    super.key,
    required this.onSelectLevel,
    required this.onResetGame,
    required this.onFinishLevel,
    this.levelCount,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Чит-меню', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Сборка: ${buildLabel()}',
                key: const Key('cheat_build'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              _section(context, 'Уровень', [
                for (
                  int i = 0;
                  i < (levelCount ?? RoninParts.parts.length);
                  i++
                )
                  ElevatedButton(
                    key: Key('cheat_level_$i'),
                    onPressed: () => onSelectLevel(i),
                    child: Text('${i + 1}'),
                  ),
              ]),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton(
                    key: const Key('cheat_reset'),
                    onPressed: onResetGame,
                    child: const Text('Сбросить на начало'),
                  ),
                  ElevatedButton(
                    key: const Key('cheat_finish_level'),
                    onPressed: onFinishLevel,
                    child: const Text('Закончить уровень'),
                  ),
                ],
              ),
            ],
          ),
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
  required VoidCallback onResetGame,
  required VoidCallback onFinishLevel,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => CheatMenu(
      onSelectLevel: onSelectLevel,
      onResetGame: onResetGame,
      onFinishLevel: onFinishLevel,
    ),
  );
}
