import '../models/level_template.dart';
import '../models/target_mask.dart';
import '../models/fragment_def.dart';
import '../models/object_template.dart';
import 'ship_parts.dart';

/// Карта всех уровней: 4 объекта × 4 фрагмента = 16 уровней.
class LevelMap {
  // ВАЖНО: static final, не const — LevelTemplate не является const-классом
  static final List<ObjectTemplate> objects = [
    // Объект 0 — "Домик"
    ObjectTemplate(
      id: 0,
      name: 'Домик',
      fragments: [
        // Фрагмент 0 — Крыша левая
        FragmentDef(
          anchorX: 0,
          anchorY: 0,
          level: LevelTemplate(
            boardWidth: 10,
            boardHeight: 20,
            targetMask: TargetMask(width: 5, height: 5, mask: 0x119DFF),
            targetX: 0,
            targetY: 15,
            moveLimit: null,
            objectId: 0,
            fragmentIndex: 0,
          ),
        ),
        // Фрагмент 1 — Крыша правая
        FragmentDef(
          anchorX: 5,
          anchorY: 0,
          level: LevelTemplate(
            boardWidth: 10,
            boardHeight: 20,
            targetMask: TargetMask(width: 5, height: 5, mask: 0x10C73DF),
            targetX: 5,
            targetY: 15,
            moveLimit: null,
            objectId: 0,
            fragmentIndex: 1,
          ),
        ),
        // Фрагмент 2 — Стена левая
        FragmentDef(
          anchorX: 0,
          anchorY: 5,
          level: LevelTemplate(
            boardWidth: 10,
            boardHeight: 20,
            targetMask: TargetMask(width: 5, height: 5, mask: 0x1FFFFFF),
            targetX: 0,
            targetY: 15,
            moveLimit: null,
            objectId: 0,
            fragmentIndex: 2,
          ),
        ),
        // Фрагмент 3 — Стена правая
        FragmentDef(
          anchorX: 5,
          anchorY: 5,
          level: LevelTemplate(
            boardWidth: 10,
            boardHeight: 20,
            targetMask: TargetMask(width: 5, height: 5, mask: 0x1FFFFFF),
            targetX: 5,
            targetY: 15,
            moveLimit: null,
            objectId: 0,
            fragmentIndex: 3,
          ),
        ),
      ],
    ),
    // Объект 1 — заглушка
    ObjectTemplate(
      id: 1,
      name: 'Объект 1',
      fragments: [
        for (var i = 0; i < 4; i++)
          FragmentDef(
            anchorX: (i % 2) * 5,
            anchorY: (i ~/ 2) * 5,
            level: LevelTemplate(
              boardWidth: 10,
              boardHeight: 20,
              targetMask: TargetMask(width: 5, height: 5, mask: 0x1FFFFFF),
              targetX: 2,
              targetY: 15,
              moveLimit: null,
              objectId: 1,
              fragmentIndex: i,
            ),
          ),
      ],
    ),
    // Объект 2 — заглушка
    ObjectTemplate(
      id: 2,
      name: 'Объект 2',
      fragments: [
        for (var i = 0; i < 4; i++)
          FragmentDef(
            anchorX: (i % 2) * 5,
            anchorY: (i ~/ 2) * 5,
            level: LevelTemplate(
              boardWidth: 10,
              boardHeight: 20,
              targetMask: TargetMask(width: 5, height: 5, mask: 0x1FFFFFF),
              targetX: 2,
              targetY: 15,
              moveLimit: null,
              objectId: 2,
              fragmentIndex: i,
            ),
          ),
      ],
    ),
    // Объект 3 — заглушка
    ObjectTemplate(
      id: 3,
      name: 'Объект 3',
      fragments: [
        for (var i = 0; i < 4; i++)
          FragmentDef(
            anchorX: (i % 2) * 5,
            anchorY: (i ~/ 2) * 5,
            level: LevelTemplate(
              boardWidth: 10,
              boardHeight: 20,
              targetMask: TargetMask(width: 5, height: 5, mask: 0x1FFFFFF),
              targetX: 2,
              targetY: 15,
              moveLimit: null,
              objectId: 3,
              fragmentIndex: i,
            ),
          ),
      ],
    ),
  ];

  /// Дев-уровни мета-каркаса (0..2): мишень = форма детали корабля
  /// (`ShipParts.parts[i].mask`), чтобы собранное на уровне совпадало с деталью.
  /// Мишень центрируется по X и ставится у низа поля.
  static final List<LevelTemplate> _devLevels = [
    for (int i = 0; i < ShipParts.parts.length; i++)
      LevelTemplate(
        boardWidth: 10,
        boardHeight: 20,
        targetMask: ShipParts.parts[i].mask,
        targetX: (10 - ShipParts.parts[i].mask.width) ~/ 2,
        targetY: 20 - ShipParts.parts[i].mask.height - 2,
        objectId: 0,
        fragmentIndex: i,
      ),
  ];

  /// Возвращает LevelTemplate для уровня levelIndex (0..15).
  ///
  /// Дев-уровни 0..2 — детали корабля (`_devLevels`, единый источник формы
  /// `ShipParts`); 3..15 — старая карта объектов (в дев-потоке недостижимы).
  static LevelTemplate levelAt(int levelIndex) {
    assert(levelIndex >= 0 && levelIndex < 16);
    if (levelIndex < _devLevels.length) return _devLevels[levelIndex];
    final obj = objects[levelIndex ~/ 4];
    return obj.fragments[levelIndex % 4].level;
  }
}
