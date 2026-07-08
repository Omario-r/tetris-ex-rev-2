import 'package:flutter/material.dart';

import '../../game_engine/data/ship_parts.dart';

/// Число деталей единого корабля — **выводится** из `ShipParts.parts.length`
/// (единый источник истины: добавили деталь в `ShipParts` → число выросло само).
///
/// Связка «N уровней ↔ N деталей»: прогресс сборки клампится этим числом,
/// собрано = `min(current_level, kShipPartCount)`. Не `const` (длина списка не
/// константа) — использовать только в рантайме, не в const-контексте.
final int kShipPartCount = ShipParts.parts.length;

/// Рисует единый корабль из деталей `ShipParts.parts`: первые [collectedCount]
/// деталей установлены (залиты), остальные — контуром.
///
/// Каждая деталь — это форма-маска (та же, что мишень уровня в `LevelMap`), поэтому
/// собранное на уровне совпадает с деталью на корабле. Деталь [revealPartIndex]
/// рисуется масштабом [revealProgress] от центра — эффект появления (Стори 03).
class ShipPainter extends CustomPainter {
  /// Сколько деталей уже собрано (0..[kShipPartCount]). Клампится в конструкторе.
  final int collectedCount;

  /// Индекс детали, которая «въезжает» (scale-in). `null` — все статичны.
  final int? revealPartIndex;

  /// Прогресс появления детали [revealPartIndex]: 0 (нет) .. 1 (на месте).
  final double revealProgress;

  ShipPainter({
    required int collectedCount,
    this.revealPartIndex,
    this.revealProgress = 1.0,
  }) : collectedCount = collectedCount.clamp(0, kShipPartCount);

  @override
  void paint(Canvas canvas, Size size) {
    const grid = ShipParts.gridSize;
    final cell = (size.width < size.height ? size.width : size.height) / grid;
    final ox = (size.width - cell * grid) / 2;
    final oy = (size.height - cell * grid) / 2;

    final fillPaint = Paint()..color = Colors.deepOrange;
    final installedStroke = Paint()
      ..color = Colors.black26
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final ghostStroke = Paint()
      ..color = Colors.white38
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 0; i < ShipParts.parts.length; i++) {
      final part = ShipParts.parts[i];
      final collected = i < collectedCount;
      // Только заработанная деталь (revealPartIndex) масштабируется от центра.
      final scale = collected && i == revealPartIndex ? revealProgress : 1.0;
      if (scale <= 0) continue;

      canvas.save();
      if (scale != 1.0) {
        final cx = ox + (part.shipX + part.mask.width / 2) * cell;
        final cy = oy + (part.shipY + part.mask.height / 2) * cell;
        canvas.translate(cx, cy);
        canvas.scale(scale);
        canvas.translate(-cx, -cy);
      }
      for (final c in part.mask.cells) {
        final rect = Rect.fromLTWH(
          ox + (part.shipX + c.x) * cell,
          oy + (part.shipY + c.y) * cell,
          cell,
          cell,
        );
        if (collected) {
          canvas.drawRect(rect, fillPaint);
          canvas.drawRect(rect, installedStroke);
        } else {
          canvas.drawRect(rect, ghostStroke);
        }
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ShipPainter oldDelegate) =>
      oldDelegate.collectedCount != collectedCount ||
      oldDelegate.revealPartIndex != revealPartIndex ||
      oldDelegate.revealProgress != revealProgress;
}
