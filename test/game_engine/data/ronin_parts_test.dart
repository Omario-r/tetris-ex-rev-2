import 'package:flutter_test/flutter_test.dart';
import 'package:explosive_tetris/game_engine/data/ronin_parts.dart';

/// Абсолютные клетки детали в сетке «Ронина» (с учётом origin).
Set<(int, int)> _gridCells(RoninPartDef part) => {
      for (final c in part.mask.cells) (part.originCol + c.x, part.originRow + c.y),
    };

/// true, если множество [cells] связно по 4-соседству.
bool _isConnected(Set<(int, int)> cells) {
  if (cells.isEmpty) return true;
  final start = cells.first;
  final seen = <(int, int)>{start};
  final stack = [start];
  while (stack.isNotEmpty) {
    final (x, y) = stack.removeLast();
    for (final n in [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]) {
      if (cells.contains(n) && seen.add(n)) stack.add(n);
    }
  }
  return seen.length == cells.length;
}

void main() {
  test('«Ронин-1»: ровно 13 деталей', () {
    expect(RoninParts.parts.length, equals(13));
  });

  test('id уникальны', () {
    final ids = RoninParts.parts.map((p) => p.id).toSet();
    expect(ids.length, equals(RoninParts.parts.length));
  });

  test('order — перестановка 1..13, список отсортирован по order', () {
    final orders = RoninParts.parts.map((p) => p.order).toList();
    expect(orders, equals(List<int>.generate(13, (i) => i + 1)),
        reason: 'order по возрастанию 1..13 без пропусков, индекс == order-1');
  });

  test('partAtOrder/byId адресуют те же детали, что и индекс списка', () {
    for (final part in RoninParts.parts) {
      expect(RoninParts.partAtOrder(part.order).id, equals(part.id));
      expect(RoninParts.byId(part.id).id, equals(part.id));
    }
  });

  test('byId с неизвестным id бросает ArgumentError', () {
    expect(() => RoninParts.byId('no-such-part'), throwsArgumentError);
  });

  test('каждая маска well-formed и не превышает поле укладки 10×14', () {
    for (final part in RoninParts.parts) {
      expect(part.mask.isWellFormed, isTrue, reason: 'деталь ${part.id}');
      expect(part.mask.width, lessThanOrEqualTo(10), reason: 'деталь ${part.id}');
      expect(part.mask.height, lessThanOrEqualTo(14), reason: 'деталь ${part.id}');
    }
  });

  test('cells совпадает с числом # в маске; 60 ≤ cells ≤ 80', () {
    for (final part in RoninParts.parts) {
      expect(part.mask.cells.length, equals(part.cells),
          reason: 'деталь ${part.id}');
      expect(part.cells, inInclusiveRange(60, 80), reason: 'деталь ${part.id}');
    }
  });

  test('каждая маска связна по 4-соседству', () {
    for (final part in RoninParts.parts) {
      final cells = {for (final c in part.mask.cells) (c.x, c.y)};
      expect(_isConnected(cells), isTrue, reason: 'деталь ${part.id}');
    }
  });

  test('origin описывает точный bbox — нет пустых краевых строк/столбцов', () {
    for (final part in RoninParts.parts) {
      final mask = part.mask;
      bool hasCellInRow(int y) =>
          List.generate(mask.width, (x) => mask.contains(x, y)).contains(true);
      bool hasCellInCol(int x) =>
          List.generate(mask.height, (y) => mask.contains(x, y)).contains(true);
      expect(hasCellInRow(0), isTrue, reason: 'деталь ${part.id}: пустая верхняя строка');
      expect(hasCellInRow(mask.height - 1), isTrue,
          reason: 'деталь ${part.id}: пустая нижняя строка');
      expect(hasCellInCol(0), isTrue, reason: 'деталь ${part.id}: пустой левый столбец');
      expect(hasCellInCol(mask.width - 1), isTrue,
          reason: 'деталь ${part.id}: пустой правый столбец');
    }
  });

  test('каждая деталь целиком внутри сетки корабля', () {
    for (final part in RoninParts.parts) {
      expect(part.originCol + part.mask.width, lessThanOrEqualTo(RoninGrid.cols),
          reason: 'деталь ${part.id}');
      expect(part.originRow + part.mask.height, lessThanOrEqualTo(RoninGrid.rows),
          reason: 'деталь ${part.id}');
    }
  });

  test('детали попарно не пересекаются на сетке', () {
    final all = <(int, int)>{};
    var total = 0;
    for (final part in RoninParts.parts) {
      final cells = _gridCells(part);
      total += cells.length;
      all.addAll(cells);
    }
    expect(all.length, equals(total), reason: 'детали пересекаются в сетке');
  });

  test('суммарно 960 клеток, объединение всех деталей связно по 4-соседству', () {
    final all = <(int, int)>{};
    for (final part in RoninParts.parts) {
      all.addAll(_gridCells(part));
    }
    expect(all.length, equals(960));
    expect(_isConnected(all), isTrue,
        reason: 'объединение деталей «Ронина-1» распадается на несвязные части');
  });
}
