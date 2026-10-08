import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game_engine/data/ronin_parts.dart';
import '../theme/block_material.dart';

/// Число деталей единого корабля — **выводится** из `RoninParts.parts.length`
/// (единый источник истины: канон Дизайнера `docs/design/ronin-parts.js`,
/// перенесено Ронин-1/01 T3, было `ShipParts.parts.length` = 7).
///
/// Связка «N уровней ↔ N деталей»: прогресс сборки клампится этим числом,
/// собрано = `min(current_level, kShipPartCount)`. Не `const` (длина списка не
/// константа) — использовать только в рантайме, не в const-контексте.
final int kShipPartCount = RoninParts.parts.length;

/// Рисует единый корабль из деталей `RoninParts.parts` (разметка v2: плиты
/// обшивки и предметы поверх, каждая в своём масштабе; позиции — через
/// `RoninPartDef.cellOnShip`, корабль вписывается в `size` по bbox всех
/// клеток): первые [collectedCount] деталей установлены (залиты), остальные —
/// контуром. Порядок рисования: слой 0 (плиты), затем слой 1 (предметы).
///
/// **Отрисовка временная (Ронин-1/01 T3):** плоская заливка — заменяется
/// композитом из рисунка «Ронина» в Стори 02 эпика Ронин-1 (канон —
/// `docs/design/ronin-ship.html`), этот пейнтер целиком заменяется там же.
/// Материал заливки — один временный `BlockMaterial.graphite` на все детали
/// (решение Постановщика по эскалации T3, 2026-07-29: карта `ShipMaterials`
/// не годится — она на 7 дев-деталей, под детали «Ронина» материалов нет и
/// канона на них тоже нет; палитра под заведомо неканоничный временный
/// пейнтер не изобретается). `ShipMaterials` в этот модуль больше не приходит.
///
/// Каждая деталь — форма-маска `RoninPartDef.mask`, та же, что мишень уровня в
/// `LevelMap` (см. `LevelMap.levelAt`), поэтому собранное на уровне совпадает с
/// деталью на корабле. Деталь [revealPartIndex] рисуется масштабом [revealProgress]
/// от центра — эффект появления (Стори 03).
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
    // Рамка корабля в клетках рисунка: bbox всех клеток всех деталей.
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    for (final part in RoninParts.parts) {
      for (final c in part.mask.cells) {
        final r = part.cellOnShip(c.x, c.y);
        if (r.x < minX) minX = r.x;
        if (r.y < minY) minY = r.y;
        if (r.x + r.size > maxX) maxX = r.x + r.size;
        if (r.y + r.size > maxY) maxY = r.y + r.size;
      }
    }
    final frameW = maxX - minX;
    final frameH = maxY - minY;
    // Рамка не квадратная — вписываем по меньшей стороне без растяжения
    // пропорций, по центру.
    final k = math.min(size.width / frameW, size.height / frameH);
    final ox = (size.width - frameW * k) / 2;
    final oy = (size.height - frameH * k) / 2;

    final installedFill = Paint()..color = BlockMaterial.graphite.color;
    final installedStroke = Paint()
      ..color = Colors.black26
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final ghostStroke = Paint()
      ..color = Colors.white38
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Сначала плиты обшивки (слой 0), затем предметы поверх (слой 1); внутри
    // слоя — по order (список уже отсортирован).
    for (final layer in const [0, 1]) {
      for (int i = 0; i < RoninParts.parts.length; i++) {
        final part = RoninParts.parts[i];
        if (part.layer != layer) continue;
        final collected = i < collectedCount;
        // Только заработанная деталь (revealPartIndex) масштабируется от центра.
        final scale = collected && i == revealPartIndex ? revealProgress : 1.0;
        if (scale <= 0) continue;

        canvas.save();
        if (scale != 1.0) {
          final cx = ox +
              (part.shipX + part.mask.width / part.scale / 2 - minX) * k;
          final cy = oy +
              (part.shipY + part.mask.height / part.scale / 2 - minY) * k;
          canvas.translate(cx, cy);
          canvas.scale(scale);
          canvas.translate(-cx, -cy);
        }
        for (final c in part.mask.cells) {
          final r = part.cellOnShip(c.x, c.y);
          final rect = Rect.fromLTWH(
            ox + (r.x - minX) * k,
            oy + (r.y - minY) * k,
            r.size * k,
            r.size * k,
          );
          if (collected) {
            // Плоская заливка временным материалом (см. doc-комментарий класса).
            canvas.drawRect(rect, installedFill);
            canvas.drawRect(rect, installedStroke);
          } else {
            canvas.drawRect(rect, ghostStroke);
          }
        }
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(ShipPainter oldDelegate) =>
      oldDelegate.collectedCount != collectedCount ||
      oldDelegate.revealPartIndex != revealPartIndex ||
      oldDelegate.revealProgress != revealProgress;
}
