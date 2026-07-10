import '../models/level_template.dart';
import 'ship_parts.dart';

/// Бюджет зарядов взрыва per level (эпик «Взрыв», Стори 02). Индекс == уровень.
///
/// Рассуждение (по форме мишени `ShipParts.parts[i].mask`, без изменения самих мишеней):
/// - Уровни 1, 2 (верхний/нижний корпус, сплошной прямоугольник 4×3) и 6 (хвост,
///   сплошной квадрат 2×2) — падение стандартных тетромино укладывает их **без единого
///   взрыва** (доказано реальным дропом ещё в «Контенте»: `level_playthrough_test.dart`,
///   3×I и 1×O). Бюджет **0** — не выдаём «про запас» то, что не требуется ни разу.
/// - Уровень 5 (двигатель 4×2, `#### / .##.`) — сужение по бокам нижнего ряда: обычным
///   падением легко перелить блок за пределы `S` в `H` по краям. Бюджет **1**.
/// - Уровни 0 (нос 4×2, `.##. / ####`), 3 и 4 (крылья 3×3, ступенчатый треугольник) —
///   самые неровные мишени: нижний ряд шире/уже верхнего, точная укладка тетромино без
///   заезда в `H` практически невозможна. Бюджет **2**.
const List<int> _chargeBudgets = [2, 0, 0, 2, 2, 1, 0];

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
        chargeBudget: _chargeBudgets[i],
      ),
  ];

  /// Возвращает LevelTemplate для уровня levelIndex (0..ShipParts.parts.length-1).
  static LevelTemplate levelAt(int levelIndex) {
    assert(levelIndex >= 0 && levelIndex < _levels.length);
    return _levels[levelIndex];
  }
}
