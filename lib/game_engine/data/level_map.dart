import '../models/level_template.dart';
import 'ronin_parts.dart';

/// Карта уровней «Ронина»: `RoninParts.parts.length` уровней, деталь с
/// `order == i + 1` (`RoninParts.parts[i]`) ↔ уровень `i`.
class LevelMap {
  /// Поле укладки фиксировано для всех уровней (не зависит от размера детали;
  /// `docs/DESIGN.md` § «Разметка деталей»).
  static const int fieldWidth = 10;
  static const int fieldHeight = 14;

  /// Уровни «Ронина»: мишень — деталь `RoninParts.parts[i]`, вписанная в поле
  /// [fieldWidth]×[fieldHeight] и отцентрованная по обеим осям. Гравитации в
  /// укладке нет — прежний floor-anchor (мишень у дна поля) снят.
  ///
  /// [LevelTemplate.targetMask] — маска **размера поля** (не детали): деталь
  /// вложена в неё через [TargetMask.padTo] со сдвигом [LevelTemplate.targetX]/
  /// [LevelTemplate.targetY] — эти же координаты понадобятся Стори 03 для
  /// сэмплинга рисунка «Ронина» в уложенные клетки.
  static final List<LevelTemplate> _levels = [
    for (int i = 0; i < RoninParts.parts.length; i++) _levelFor(RoninParts.parts[i], i),
  ];

  static LevelTemplate _levelFor(RoninPartDef part, int fragmentIndex) {
    final targetX = (fieldWidth - part.mask.width) ~/ 2;
    final targetY = (fieldHeight - part.mask.height) ~/ 2;
    return LevelTemplate(
      boardWidth: fieldWidth,
      boardHeight: fieldHeight,
      targetMask: part.mask.padTo(
        width: fieldWidth,
        height: fieldHeight,
        dx: targetX,
        dy: targetY,
      ),
      targetX: targetX,
      targetY: targetY,
      objectId: 0,
      fragmentIndex: fragmentIndex,
    );
  }

  /// Возвращает LevelTemplate для уровня levelIndex (0..RoninParts.parts.length-1).
  static LevelTemplate levelAt(int levelIndex) {
    assert(levelIndex >= 0 && levelIndex < _levels.length);
    return _levels[levelIndex];
  }
}
