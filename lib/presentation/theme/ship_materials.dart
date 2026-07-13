import 'block_material.dart';

/// Карта материалов деталей единого корабля.
///
/// Единый источник цвета для `ShipPainter` и (T3) перекраски клетки в
/// `BoardPainter`. Не хардкодит единственный корабль (адресуемость под #6).
/// Не меняет формы мишеней/укладку/halo — заморозка ядра цела.
class ShipMaterials {
  /// Карта деталь→материал. Индекс = индекс детали из `ShipParts.parts`.
  final List<BlockMaterial> _materials;

  /// Создаёт карту из списка материалов. Длина списка должна совпадать с
  /// `ShipParts.parts.length` (v1 = 7), иначе — `AssertionError`.
  ShipMaterials(List<BlockMaterial> materials)
      : _materials = List.unmodifiable(materials);

  /// Возвращает материал для детали с индексом [partIndex].
  BlockMaterial materialForPart(int partIndex) {
    return _materials[partIndex];
  }

  /// Дефолтная карта материалов для корабля v1 по референсу «Ронин» v4.
  ///
  /// Секции корабля (по референсу):
  /// - prow (нос, деталь 0): DARK
  /// - bridge (мостик, деталь 1): GRAF2
  /// - fwd (передняя секция, деталь 2): GRAF
  /// - bandA (оранжевый пояс, детали 3-4): GRAF (крылья — базовый графит)
  /// - mid (средняя секция, деталь 5): GUN (двигатель — gunmetal)
  /// - bandB (задняя секция, деталь 6): BLACKM (хвост — матовый чёрный)
  static ShipMaterials defaultMaterials = ShipMaterials([
    BlockMaterial.darkNiche,    // 0 — нос (DARK)
    BlockMaterial.graphiteDark, // 1 — верхний корпус (GRAF2)
    BlockMaterial.graphiteDark, // 2 — нижний корпус (GRAF2)
    BlockMaterial.graphite,     // 3 — левое крыло (GRAF)
    BlockMaterial.graphite,     // 4 — правое крыло (GRAF)
    BlockMaterial.gunmetal,     // 5 — двигатель (GUN)
    BlockMaterial.matteBlack,   // 6 — хвостовой киль (BLACKM)
  ]);
}
