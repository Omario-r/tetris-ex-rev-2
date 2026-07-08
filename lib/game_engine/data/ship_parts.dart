import '../models/target_mask.dart';

/// Деталь корабля мета-каркаса: форма ([mask]) + место в сетке корабля.
///
/// [mask] — единый источник истины формы: одна и та же маска рисуется и как
/// мишень уровня (то, что игрок собирает на поле), и как деталь на корабле —
/// поэтому «деталь на уровне» и «деталь корабля» совпадают.
class ShipPartDef {
  /// Форма детали (заглушка-прямоугольник). Площадь кратна 4 (правило VISION).
  final TargetMask mask;

  /// Якорь детали в сетке корабля [ShipParts.gridSize] (левый-верх).
  final int shipX;
  final int shipY;

  const ShipPartDef({
    required this.mask,
    required this.shipX,
    required this.shipY,
  });
}

/// Дев-детали корабля (заглушки). Единый источник формы для эпика «Мета-каркас»:
/// [parts]`[i]`.mask == мишень дев-уровня `i` (см. `LevelMap.levelAt`). Реальные
/// детали и мишени спроектирует эпик «Контент».
class ShipParts {
  /// Сетка корабля для раскладки деталей (кораблик вписан в неё).
  static const int gridSize = 10;

  /// 3 детали, порядок = порядок сборки (деталь `i` ↔ уровень `i`). Сложены в
  /// грубый силуэт «ракеты»: нос → корпус → основание.
  static const List<ShipPartDef> parts = [
    // Нос — 2×2 (площадь 4).
    ShipPartDef(
      mask: TargetMask(width: 2, height: 2, mask: 0xF),
      shipX: 4,
      shipY: 1,
    ),
    // Корпус — 4×4 (площадь 16).
    ShipPartDef(
      mask: TargetMask(width: 4, height: 4, mask: 0xFFFF),
      shipX: 3,
      shipY: 3,
    ),
    // Основание — 6×2 (площадь 12).
    ShipPartDef(
      mask: TargetMask(width: 6, height: 2, mask: 0xFFF),
      shipX: 2,
      shipY: 7,
    ),
  ];
}
