import '../models/level_template.dart';
import 'ship_parts.dart';

/// Базовый бюджет зарядов per level — минимум по форме мишени `ShipParts.parts[i].mask`
/// (эпик «Взрыв», Стори 02, без изменения самих мишеней):
/// - Уровни 1, 2 (верхний/нижний корпус, сплошной прямоугольник 4×3) и 6 (хвост,
///   сплошной квадрат 2×2) — падение стандартных тетромино укладывает их **без единого
///   взрыва** (доказано реальным дропом ещё в «Контенте»: `level_playthrough_test.dart`,
///   3×I и 1×O). База **0**.
/// - Уровень 5 (двигатель 4×2, `#### / .##.`) — сужение по бокам нижнего ряда: обычным
///   падением легко перелить блок за пределы `S` в `H` по краям. База **1**.
/// - Уровни 0 (нос 4×2, `.##. / ####`), 3 и 4 (крылья 3×3, ступенчатый треугольник) —
///   самые неровные мишени: нижний ряд шире/уже верхнего, точная укладка тетромино без
///   заезда в `H` практически невозможна. База **2**.
const List<int> _baseChargeBudgets = [2, 0, 0, 2, 2, 1, 0];

/// Комфортный запас, добавляемый к базе на КАЖДОМ уровне (решение PO 2026-07-13,
/// возврат Гейта 2 Стори 02): игрок не застревает при сборке/плейтесте до реального
/// баланса. Осознанно ослабляет «дефицит ощущается» (цель эпика) — настоящий тюнинг
/// сложности отложен в эпик #5 «Плейтест» (VISION: баланс по метрикам плейтеста).
const int _poComfortBuffer = 2;

/// Итоговый бюджет per level = база + запас PO. Индекс == уровень.
/// Эффективно `[4, 2, 2, 4, 4, 3, 2]`.
final List<int> _chargeBudgets = [
  for (final base in _baseChargeBudgets) base + _poComfortBuffer,
];

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
