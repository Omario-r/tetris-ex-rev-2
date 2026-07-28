import 'package:flutter_test/flutter_test.dart';
import 'package:explosive_tetris/game_engine/data/ship_parts.dart';

/// Абсолютные клетки детали в сетке корабля (с учётом якоря).
Set<(int, int)> _shipCells(int i) {
  final p = ShipParts.parts[i];
  return {for (final c in p.mask.cells) (p.shipX + c.x, p.shipY + c.y)};
}

void main() {
  test('корабль v1 — 7 деталей', () {
    expect(ShipParts.parts.length, equals(7));
  });

  // «kShipPartCount выводится из parts.length» убран (Ронин-1/01 T3): с этой
  // задачи `kShipPartCount` (`ship.dart`) — из `RoninParts.parts.length`, а
  // `ShipParts` — осиротевший дев-контент (выпил в Стори 06); единый источник
  // «N деталей ↔ N уровней» больше НЕ совпадает с `ShipParts.parts.length` —
  // это ожидаемо, не регрессия.

  test('площадь каждой детали ≥ 4 (правило «кратно 4» снято — VISION)', () {
    for (int i = 0; i < ShipParts.parts.length; i++) {
      final area = ShipParts.parts[i].mask.cells.length;
      expect(area, greaterThanOrEqualTo(4), reason: 'деталь $i: площадь $area');
    }
  });

  test('детали влезают в сетку корабля', () {
    for (final p in ShipParts.parts) {
      expect(p.shipX + p.mask.width, lessThanOrEqualTo(ShipParts.gridSize));
      expect(p.shipY + p.mask.height, lessThanOrEqualTo(ShipParts.gridSize));
    }
  });

  test('детали не накладываются (клетки уникальны)', () {
    final all = <(int, int)>{};
    var total = 0;
    for (int i = 0; i < ShipParts.parts.length; i++) {
      final cells = _shipCells(i);
      total += cells.length;
      all.addAll(cells);
    }
    expect(all.length, equals(total), reason: 'детали пересекаются в сетке');
  });

  test('детали смыкаются в один связный силуэт (4-связность)', () {
    final all = <(int, int)>{};
    for (int i = 0; i < ShipParts.parts.length; i++) {
      all.addAll(_shipCells(i));
    }
    // Заливка от первой клетки по 4-соседству — должна накрыть весь силуэт.
    final start = all.first;
    final seen = <(int, int)>{start};
    final stack = [start];
    while (stack.isNotEmpty) {
      final (x, y) = stack.removeLast();
      for (final (nx, ny) in [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]) {
        if (all.contains((nx, ny)) && seen.add((nx, ny))) {
          stack.add((nx, ny));
        }
      }
    }
    expect(seen.length, equals(all.length),
        reason: 'силуэт распадается на несвязные части');
  });
}
