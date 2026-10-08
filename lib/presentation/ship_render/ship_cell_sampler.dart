import 'package:flutter/painting.dart';

import '../../game_engine/data/ronin_parts.dart';
import 'ship_art.dart';

/// Клетка ([c], [r]) маски детали на корабле — прямоугольник в px рисунка
/// (`cellOnShip` → [ShipArt.toScene]); сторона — клетка рисунка / масштаб детали.
Rect shipCellRect(ShipArt art, RoninPartDef part, int c, int r) {
  final cell = part.cellOnShip(c, r);
  final tl = art.toScene(cell.x, cell.y);
  final br = art.toScene(cell.x + cell.size, cell.y + cell.size);
  return Rect.fromPoints(tl, br);
}

/// Сэмплинг клетки (точка входа поля укладки, Стори 03): кусок рисунка под
/// клеткой ([c], [r]) маски [part] в масштабе детали — в прямоугольник [dst]
/// холста [canvas].
///
/// Плита — слой корпуса ([ShipArt.hullPicture]); предмет — корпус и поверх
/// слой предметов ([ShipArt.objectsPicture]): вместе это полный рисунок, как
/// `imgOf` в `docs/design/ronin-draw.js`. Клип — [dst], один replay на слой.
void paintPartCell(
  Canvas canvas,
  ShipArt art,
  RoninPartDef part,
  int c,
  int r,
  Rect dst,
) {
  final src = shipCellRect(art, part, c, r);
  canvas
    ..save()
    ..clipRect(dst)
    ..translate(dst.left, dst.top)
    ..scale(dst.width / src.width, dst.height / src.height)
    ..translate(-src.left, -src.top)
    ..drawPicture(art.hullPicture);
  if (!part.isPlate) canvas.drawPicture(art.objectsPicture);
  canvas.restore();
}
