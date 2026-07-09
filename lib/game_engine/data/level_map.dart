import '../models/level_template.dart';
import 'ship_parts.dart';

/// Карта уровней корабля: `ShipParts.parts.length` уровней, деталь `i` ↔ уровень `i`.
class LevelMap {
  /// Уровни корабля: мишень = форма детали корабля (`ShipParts.parts[i].mask`),
  /// поставлена у самого дна поля (пол — естественная опора для падающих фигур).
  /// Мишень центрируется по X.
  static final List<LevelTemplate> _levels = [
    for (int i = 0; i < ShipParts.parts.length; i++)
      LevelTemplate(
        boardWidth: 10,
        boardHeight: 20,
        targetMask: ShipParts.parts[i].mask,
        targetX: (10 - ShipParts.parts[i].mask.width) ~/ 2,
        targetY: 20 - ShipParts.parts[i].mask.height,
        objectId: 0,
        fragmentIndex: i,
      ),
  ];

  /// Возвращает LevelTemplate для уровня levelIndex (0..ShipParts.parts.length-1).
  static LevelTemplate levelAt(int levelIndex) {
    assert(levelIndex >= 0 && levelIndex < _levels.length);
    return _levels[levelIndex];
  }
}
