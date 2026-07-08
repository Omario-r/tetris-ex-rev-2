import '../models/target_mask.dart';

/// Деталь корабля: форма ([mask]) + место в сетке корабля.
///
/// [mask] — единый источник истины формы: одна и та же маска рисуется и как
/// мишень уровня (то, что игрок собирает на поле), и как деталь на корабле —
/// поэтому «деталь на уровне» и «деталь корабля» совпадают.
class ShipPartDef {
  /// Форма детали. Узнаваемость в приоритете; правило «площадь кратна 4» снято
  /// (VISION, эпик «Контент») — неровные места закрывает расчистка.
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

/// Детали единого корабля v1 (эпик «Контент»). Единый источник формы:
/// [parts]`[i]`.mask == мишень дев-уровня `i` (см. `LevelMap.levelAt`) и деталь `i`
/// на корабле (`ShipPainter`). Порядок = порядок сборки (деталь `i` ↔ уровень `i`).
///
/// Раскладка — узнаваемый силуэт «звездолёт с крыльями», собираемый снизу-вверх/
/// от центра к краям: нос → корпус → крылья → двигатель → киль. Все детали
/// смыкаются в один связный силуэт (без наложений и разрывов). Точные формы —
/// прототипные, шлифуются по скриншотам (VISION: узнаваемость в приоритете).
class ShipParts {
  /// Квадратная сетка корабля, в которую вписан силуэт.
  static const int gridSize = 12;

  /// 7 деталей, порядок = порядок сборки. Маски — MSB-first, читаются построчно
  /// сверху-вниз (см. `TargetMask`); в комментариях показан рисунок клеток.
  static const List<ShipPartDef> parts = [
    // 0 — Нос / кабина (4×2): .##. / ####
    ShipPartDef(
      mask: TargetMask(width: 4, height: 2, mask: 0x6F),
      shipX: 4,
      shipY: 0,
    ),
    // 1 — Верхний корпус (4×3): #### / #### / ####
    ShipPartDef(
      mask: TargetMask(width: 4, height: 3, mask: 0xFFF),
      shipX: 4,
      shipY: 2,
    ),
    // 2 — Нижний корпус (4×3): #### / #### / ####
    ShipPartDef(
      mask: TargetMask(width: 4, height: 3, mask: 0xFFF),
      shipX: 4,
      shipY: 5,
    ),
    // 3 — Левое крыло (3×3): ..# / .## / ### (смыкается с корпусом справа)
    ShipPartDef(
      mask: TargetMask(width: 3, height: 3, mask: 0x5F),
      shipX: 1,
      shipY: 4,
    ),
    // 4 — Правое крыло (3×3): #.. / ##. / ### (смыкается с корпусом слева)
    ShipPartDef(
      mask: TargetMask(width: 3, height: 3, mask: 0x137),
      shipX: 8,
      shipY: 4,
    ),
    // 5 — Двигатель / сопло (4×2): #### / .##. (сужается книзу)
    ShipPartDef(
      mask: TargetMask(width: 4, height: 2, mask: 0xF6),
      shipX: 4,
      shipY: 8,
    ),
    // 6 — Хвостовой киль / выхлоп (2×2): ## / ##
    ShipPartDef(
      mask: TargetMask(width: 2, height: 2, mask: 0xF),
      shipX: 5,
      shipY: 10,
    ),
  ];
}
