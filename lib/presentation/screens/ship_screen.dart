import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../application/progress_service.dart';
import '../widgets/ship.dart';

/// Экран корабля: статичный вид единого корабля, собранного к текущему моменту.
///
/// Число собранных деталей = `min(current_level, kShipPartCount)` — связка
/// «пройден уровень N → деталь N», прогресс не выходит за [kShipPartCount].
/// Читает прогресс через [ProgressService]; сборка сохраняется между запусками.
class ShipScreen extends StatelessWidget {
  const ShipScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Корабль')),
      body: FutureBuilder<int>(
        future: ProgressService().getCurrentLevel(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final collected = math.min(snapshot.data!, kShipPartCount);
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
            ],
          );
        },
      ),
    );
  }
}
