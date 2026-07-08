import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../application/progress_service.dart';
import '../widgets/ship.dart';

/// Экран корабля. Два режима:
///
/// - **ручной** (`ShipScreen()`) — статичный вид собранного к моменту корабля,
///   `min(current_level, kShipPartCount)` деталей; читает [ProgressService];
///   есть «Назад» (Стори 01).
/// - **авто-показ** (`ShipScreen.reveal(...)`) — после победы: фиксированное число
///   деталей, кнопка «Далее»/«Начать заново», без «Назад» (Стори 03). Эффект
///   появления детали добавляется в T2.
class ShipScreen extends StatelessWidget {
  final int? _revealCount;
  final VoidCallback? _onNext;
  final bool _isComplete;

  const ShipScreen({super.key})
    : _revealCount = null,
      _onNext = null,
      _isComplete = false;

  /// Авто-показ прироста после победы: корабль с [collectedCount] деталями и кнопкой
  /// «Далее» (или «Начать заново», если [isComplete] — собран последний уровень).
  const ShipScreen.reveal({
    super.key,
    required int collectedCount,
    required VoidCallback onNext,
    bool isComplete = false,
  }) : _revealCount = collectedCount,
       _onNext = onNext,
       _isComplete = isComplete;

  @override
  Widget build(BuildContext context) {
    return _onNext != null ? _buildReveal(context) : _buildManual(context);
  }

  /// Ручной режим (Стори 01): читает прогресс, статичный вид, «Назад».
  Widget _buildManual(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Корабль')),
      body: FutureBuilder<int>(
        future: ProgressService().getCurrentLevel(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final collected = math.min(snapshot.data!, kShipPartCount);
          return _shipBody(context, collected);
        },
      ),
    );
  }

  /// Авто-показ (Стори 03): фиксированное число деталей + кнопка перехода.
  Widget _buildReveal(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Корабль'),
        automaticallyImplyLeading: false,
      ),
      body: _shipBody(
        context,
        _revealCount!,
        action: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: ElevatedButton(
            key: const Key('ship_next_button'),
            onPressed: _onNext,
            child: Text(_isComplete ? 'Начать заново' : 'Далее'),
          ),
        ),
      ),
    );
  }

  Widget _shipBody(BuildContext context, int collected, {Widget? action}) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: CustomPaint(
              size: const Size(300, 300),
              painter: ShipPainter(collectedCount: collected),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Собрано $collected из $kShipPartCount',
            key: const Key('ship_collected_text'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        ?action,
      ],
    );
  }
}
