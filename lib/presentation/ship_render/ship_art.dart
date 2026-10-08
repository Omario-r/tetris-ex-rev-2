import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Рисунок корабля: сцена в px рисунка (система `docs/design/ship-render.js`),
/// два слоя (D-011): корпус без предметов и предметы поверх.
///
/// Экраны и поле укладки обращаются к рисунку только через этот интерфейс —
/// следующий корабль подключается своей реализацией (сейчас — `RoninArt`).
abstract class ShipArt {
  /// W × H сцены, px рисунка.
  Size get sceneSize;

  /// Клетка рисунка → px сцены (как `px()`/`py()` эталона).
  Offset toScene(double x, double y);

  /// Слой 0: корпус без предметов. Записывается один раз и кешируется.
  ui.Picture get hullPicture;

  /// Слой 1: предметы (без плит корпуса). Записывается один раз и кешируется.
  /// Рисуется только под клипом формы предмета ([objectShape]).
  ui.Picture get objectsPicture;

  /// Контур борта «сюда дорастёт» (корпус + гондолы), px рисунка; штрих —
  /// токен `shipOutline`.
  Path get outline;

  /// Форма предмета слоя 1 по id детали (`'sensor'`, `'rcs_fl'`, `'rcs_fr'`),
  /// px рисунка; неизвестный id — [ArgumentError].
  Path objectShape(String partId);
}
