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

/// Рисует единый корабль из деталей `RoninParts.parts`: первые [collectedCount]
/// деталей установлены (залиты), остальные — контуром.
///
/// **Отрисовка временная (Ронин-1/01 T3):** плоская заливка — заменяется
/// композитом из рисунка «Ронина» в Стори 02 эпика Ронин-1 (канон —
/// `docs/design/ronin-ship.html`), этот пейнтер целиком заменяется там же.
/// Материал заливки — один временный `BlockMaterial.graphite` на все детали
/// (решение Постановщика по эскалации T3, 2026-07-29: карта `ShipMaterials`
/// не годится — она на 7 дев-деталей, под 13 деталей «Ронина» материалов нет и
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
    const cols = RoninGrid.cols;
    const rows = RoninGrid.rows;
    // Сетка не квадратная (44×108) — вписываем по меньшей стороне без
    // растяжения пропорций.
    final cellByWidth = size.width / cols;
    final cellByHeight = size.height / rows;
    final cell = cellByWidth < cellByHeight ? cellByWidth : cellByHeight;
    final ox = (size.width - cell * cols) / 2;
    final oy = (size.height - cell * rows) / 2;

    final installedFill = Paint()..color = BlockMaterial.graphite.color;
    final installedStroke = Paint()
      ..color = Colors.black26
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final ghostStroke = Paint()
      ..color = Colors.white38
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 0; i < RoninParts.parts.length; i++) {
      final part = RoninParts.parts[i];
      final collected = i < collectedCount;
      // Только заработанная деталь (revealPartIndex) масштабируется от центра.
      final scale = collected && i == revealPartIndex ? revealProgress : 1.0;
      if (scale <= 0) continue;

      canvas.save();
      if (scale != 1.0) {
        final cx = ox + (part.originCol + part.mask.width / 2) * cell;
        final cy = oy + (part.originRow + part.mask.height / 2) * cell;
        canvas.translate(cx, cy);
        canvas.scale(scale);
        canvas.translate(-cx, -cy);
      }
      for (final c in part.mask.cells) {
        final rect = Rect.fromLTWH(
          ox + (part.originCol + c.x) * cell,
          oy + (part.originRow + c.y) * cell,
          cell,
          cell,
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

  @override
  bool shouldRepaint(ShipPainter oldDelegate) =>
      oldDelegate.collectedCount != collectedCount ||
      oldDelegate.revealPartIndex != revealPartIndex ||
      oldDelegate.revealProgress != revealProgress;
}
