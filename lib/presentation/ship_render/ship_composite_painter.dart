import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/rendering.dart';

import '../../game_engine/data/ronin_parts.dart';
import 'ship_art.dart';
import 'ship_cell_sampler.dart';

/// Экран корабля-композит (канон — `docs/design/ronin-ship.html`, слои — D-011):
/// контур борта «сюда дорастёт» тонким штрихом `shipOutline`, поверх —
/// собранные детали (`order ≤ collectedCount`) из рисунка [art]: сначала все
/// плиты (слой корпуса под клипом их клеток на корабле), потом предметы (слой
/// предметов под клипом их форм). Сетки клеток на корабле нет.
///
/// Кадр — прямоугольник сцены [frameOf] (поля рисунка обрезаны, как в мокапе),
/// вписан в `size` с сохранением пропорций по центру. Один клип-путь и один
/// `drawPicture` на слой; деталь [revealPartIndex] во время появления
/// (`0 < revealProgress < 1`) рисуется отдельно — масштабом [revealProgress]
/// от центра её прямоугольника на корабле.
class ShipCompositePainter extends CustomPainter {
  /// Рисунок корабля.
  final ShipArt art;

  /// Сколько деталей собрано (0..`RoninParts.parts.length`), клампится.
  final int collectedCount;

  /// Индекс детали в `RoninParts.parts`, которая «въезжает» (scale-in);
  /// `null` — все статичны.
  final int? revealPartIndex;

  /// Прогресс появления [revealPartIndex]: 0 (нет) .. 1 (на месте).
  final double revealProgress;

  ShipCompositePainter({
    required this.art,
    required int collectedCount,
    this.revealPartIndex,
    this.revealProgress = 1,
  }) : collectedCount = collectedCount.clamp(0, RoninParts.parts.length);

  /// Токен `shipOutline` `hsla(215 14% 52% / 16%)` (DESIGN.md).
  static final Color shipOutlineColor = const HSLColor.fromAHSL(
    0.16,
    215,
    0.14,
    0.52,
  ).toColor();

  /// Кадр мокапа в px рисунка: `sx = 44, sy = 26, sw = W − 88, sh = H − 40`.
  static Rect frameOf(ShipArt art) {
    final s = art.sceneSize;
    return Rect.fromLTWH(44, 26, s.width - 88, s.height - 40);
  }

  /// Область детали на корабле, px рисунка: плита — объединение её клеток,
  /// предмет — его форма (как `shipRegion` в `ronin-draw.js`).
  static Path _region(ShipArt art, RoninPartDef part, [Path? into]) {
    final p = into ?? Path();
    if (!part.isPlate) {
      p.addPath(art.objectShape(part.id), Offset.zero);
      return p;
    }
    for (final cell in part.mask.cells) {
      p.addRect(shipCellRect(art, part, cell.x, cell.y));
    }
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final f = frameOf(art);
    final k = math.min(size.width / f.width, size.height / f.height);
    if (!(k > 0) || !k.isFinite) return;
    final w = f.width * k, h = f.height * k;
    final tx = (size.width - w) / 2 - f.left * k;
    final ty = (size.height - h) / 2 - f.top * k;

    canvas
      ..save()
      ..clipRect(
        Rect.fromLTWH((size.width - w) / 2, (size.height - h) / 2, w, h),
      );

    // Контур борта — в координатах экрана, штрих 1 px экрана.
    final m = Float64List.fromList([
      k,
      0,
      0,
      0,
      0,
      k,
      0,
      0,
      0,
      0,
      1,
      0,
      tx,
      ty,
      0,
      1,
    ]);
    canvas.drawPath(
      art.outline.transform(m),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = shipOutlineColor,
    );

    canvas
      ..translate(tx, ty)
      ..scale(k);

    final animating = revealPartIndex != null && revealProgress < 1;
    for (final layer in const [0, 1]) {
      final picture = layer == 0 ? art.hullPicture : art.objectsPicture;
      final region = Path();
      var any = false;
      RoninPartDef? reveal;
      for (var i = 0; i < RoninParts.parts.length; i++) {
        final part = RoninParts.parts[i];
        if (part.layer != layer || part.order > collectedCount) continue;
        if (animating && i == revealPartIndex) {
          reveal = part;
          continue;
        }
        _region(art, part, region);
        any = true;
      }
      if (any) {
        canvas
          ..save()
          ..clipPath(region)
          ..drawPicture(picture)
          ..restore();
      }
      if (reveal != null && revealProgress > 0) {
        final c = art.toScene(
          reveal.shipX + reveal.mask.width / reveal.scale / 2,
          reveal.shipY + reveal.mask.height / reveal.scale / 2,
        );
        canvas
          ..save()
          ..translate(c.dx, c.dy)
          ..scale(revealProgress)
          ..translate(-c.dx, -c.dy)
          ..clipPath(_region(art, reveal))
          ..drawPicture(picture)
          ..restore();
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(ShipCompositePainter oldDelegate) =>
      oldDelegate.art != art ||
      oldDelegate.collectedCount != collectedCount ||
      oldDelegate.revealPartIndex != revealPartIndex ||
      oldDelegate.revealProgress != revealProgress;
}
