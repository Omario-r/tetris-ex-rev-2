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
/// `imgOf` в `docs/design/ronin-draw.js`. Клип — [dst], под рисунком —
/// подложка [ShipArt.backdrop] (как у [paintPartCells]), один replay на слой.
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
    ..drawPaint(Paint()..color = art.backdrop)
    ..translate(dst.left, dst.top)
    ..scale(dst.width / src.width, dst.height / src.height)
    ..translate(-src.left, -src.top)
    ..drawPicture(art.hullPicture);
  if (!part.isPlate) canvas.drawPicture(art.objectsPicture);
  canvas.restore();
}

/// Клетки [cells] маски [part] (координаты маски) — куски рисунка в
/// масштабе детали; клетка (c, r) ложится в
/// `Rect.fromLTWH(origin.dx + c * cellSize, origin.dy + r * cellSize, cellSize, cellSize)`.
/// Один clip (объединение прямоугольников клеток) и один replay на слой.
///
/// Точка входа поля укладки (Ронин-1/03): клип → подложка
/// [ShipArt.backdrop] → «px рисунка → поле» (клетка маски (0, 0) =
/// [shipCellRect] → [origin], масштаб `cellSize / ширина клетки рисунка`) →
/// [ShipArt.hullPicture], у предмета ещё [ShipArt.objectsPicture]. Растр
/// клетки совпадает с [paintPartCell] в том же прямоугольнике. Пустой [cells] —
/// ничего не рисует.
void paintPartCells(
  Canvas canvas,
  ShipArt art,
  RoninPartDef part,
  Iterable<({int x, int y})> cells, {
  required Offset origin,
  required double cellSize,
}) {
  final clip = Path();
  var any = false;
  for (final cell in cells) {
    clip.addRect(
      Rect.fromLTWH(
        origin.dx + cell.x * cellSize,
        origin.dy + cell.y * cellSize,
        cellSize,
        cellSize,
      ),
    );
    any = true;
  }
  if (!any) return;

  final src = shipCellRect(art, part, 0, 0);
  final k = cellSize / src.width;
  canvas
    ..save()
    ..clipPath(clip)
    ..drawPaint(Paint()..color = art.backdrop)
    ..translate(origin.dx, origin.dy)
    ..scale(k, k)
    ..translate(-src.left, -src.top)
    ..drawPicture(art.hullPicture);
  if (!part.isPlate) canvas.drawPicture(art.objectsPicture);
  canvas.restore();
}
