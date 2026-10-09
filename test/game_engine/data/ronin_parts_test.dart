import 'package:flutter_test/flutter_test.dart';
import 'package:explosive_tetris/game_engine/data/ronin_parts.dart';

const double _eps = 1e-6;

/// Клетки плиты в сетке её секции (с учётом origin плиты).
Set<(int, int)> _sectionCells(RoninPartDef part) => {
      for (final c in part.mask.cells)
        (part.sectionCol + c.x, part.sectionRow + c.y),
    };

/// Клетки детали на корабле как прямоугольники (клетки рисунка).
List<({double x, double y, double size})> _shipRects(RoninPartDef part) => [
      for (final c in part.mask.cells) part.cellOnShip(c.x, c.y),
    ];

/// Прямоугольники имеют общую сторону ненулевой длины.
bool _sharesSide(({double x, double y, double size}) a,
    ({double x, double y, double size}) b) {
  final overlapX = (a.x + a.size < b.x + b.size ? a.x + a.size : b.x + b.size) -
      (a.x > b.x ? a.x : b.x);
  final overlapY = (a.y + a.size < b.y + b.size ? a.y + a.size : b.y + b.size) -
      (a.y > b.y ? a.y : b.y);
  final verticalSide = ((a.x + a.size - b.x).abs() < _eps ||
          (b.x + b.size - a.x).abs() < _eps) &&
      overlapY > _eps;
  final horizontalSide = ((a.y + a.size - b.y).abs() < _eps ||
          (b.y + b.size - a.y).abs() < _eps) &&
      overlapX > _eps;
  return verticalSide || horizontalSide;
}

/// Прямоугольники перекрываются или касаются (замкнутое пересечение).
bool _overlapsOrTouches(({double x, double y, double size}) a,
    ({double x, double y, double size}) b) {
  return a.x <= b.x + b.size + _eps &&
      b.x <= a.x + a.size + _eps &&
      a.y <= b.y + b.size + _eps &&
      b.y <= a.y + a.size + _eps;
}

bool _platesTouch(RoninPartDef a, RoninPartDef b) {
  final rb = _shipRects(b);
  for (final ra in _shipRects(a)) {
    for (final r in rb) {
      if (_sharesSide(ra, r)) return true;
    }
  }
  return false;
}

bool _objectMeetsPlate(RoninPartDef object, RoninPartDef plate) {
  final rb = _shipRects(plate);
  for (final ra in _shipRects(object)) {
    for (final r in rb) {
      if (_overlapsOrTouches(ra, r)) return true;
    }
  }
  return false;
}

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
  final parts = RoninParts.parts;
  final plates = parts.where((p) => p.isPlate).toList();
  final objects = parts.where((p) => !p.isPlate).toList();

  test('разметка v3: 19 деталей — 12 плит и 7 предметов, 3 секции', () {
    expect(parts.length, equals(19));
    expect(plates.length, equals(12));
    expect(objects.length, equals(7));
    expect(RoninParts.sections.length, equals(3));
  });

  test('id уникальны', () {
    final ids = parts.map((p) => p.id).toSet();
    expect(ids.length, equals(parts.length));
  });

  test('order — 1..N по индексу списка', () {
    final orders = parts.map((p) => p.order).toList();
    expect(orders, equals(List<int>.generate(parts.length, (i) => i + 1)),
        reason: 'order по возрастанию 1..N без пропусков, индекс == order-1');
  });

  test('layer ∈ {0, 1}', () {
    for (final part in parts) {
      expect(part.layer, anyOf(0, 1), reason: 'деталь ${part.id}');
    }
  });

  test('partAtOrder/byId адресуют те же детали, что и индекс списка', () {
    for (final part in parts) {
      expect(RoninParts.partAtOrder(part.order).id, equals(part.id));
      expect(RoninParts.byId(part.id).id, equals(part.id));
    }
  });

  test('byId с неизвестным id бросает ArgumentError', () {
    expect(() => RoninParts.byId('no-such-part'), throwsArgumentError);
  });

  test('sectionById: известные секции находятся, неизвестный — ArgumentError', () {
    for (final section in RoninParts.sections) {
      expect(RoninParts.sectionById(section.id).id, equals(section.id));
    }
    expect(() => RoninParts.sectionById('no-such-section'), throwsArgumentError);
  });

  test('каждая маска well-formed и не превышает поле укладки 10×14', () {
    for (final part in parts) {
      expect(part.mask.isWellFormed, isTrue, reason: 'деталь ${part.id}');
      expect(part.mask.width, lessThanOrEqualTo(10), reason: 'деталь ${part.id}');
      expect(part.mask.height, lessThanOrEqualTo(14), reason: 'деталь ${part.id}');
    }
  });

  test('cells совпадает с числом # в маске; cells ≤ 80', () {
    for (final part in parts) {
      expect(part.mask.cells.length, equals(part.cells),
          reason: 'деталь ${part.id}');
      expect(part.cells, lessThanOrEqualTo(80), reason: 'деталь ${part.id}');
    }
  });

  test('каждая маска связна по 4-соседству', () {
    for (final part in parts) {
      final cells = {for (final c in part.mask.cells) (c.x, c.y)};
      expect(_isConnected(cells), isTrue, reason: 'деталь ${part.id}');
    }
  });

  test('маска — точный bbox: нет пустых краевых строк/столбцов', () {
    for (final part in parts) {
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

  test('плита: секция существует, маска целиком внутри сетки секции', () {
    for (final part in plates) {
      expect(part.sectionId, isNotNull, reason: 'плита ${part.id}');
      final section = RoninParts.sectionById(part.sectionId!);
      expect(part.sectionCol + part.mask.width, lessThanOrEqualTo(section.cols),
          reason: 'плита ${part.id}');
      expect(part.sectionRow + part.mask.height, lessThanOrEqualTo(section.rows),
          reason: 'плита ${part.id}');
    }
  });

  test('плиты одной секции попарно не пересекаются (в клетках секции)', () {
    for (final section in RoninParts.sections) {
      final all = <(int, int)>{};
      var total = 0;
      for (final part in plates.where((p) => p.sectionId == section.id)) {
        final cells = _sectionCells(part);
        total += cells.length;
        all.addAll(cells);
      }
      expect(all.length, equals(total),
          reason: 'плиты секции ${section.id} пересекаются');
    }
  });

  test('площадь всех плит в клетках рисунка = 60', () {
    var area = 0.0;
    for (final part in plates) {
      area += part.cells / (part.scale * part.scale);
    }
    expect(area, closeTo(60, _eps));
  });

  test('предметы v3: датчик, визор ×2, люк ×2, RCS ×2', () {
    final kinds = <String, int>{};
    for (final part in objects) {
      kinds.update(part.objectKind!, (n) => n + 1, ifAbsent: () => 1);
    }
    expect(kinds, equals({'sensor': 1, 'visor': 2, 'hatch': 2, 'rcs': 2}));
  });

  test('предмет: objectKind, objectScale, objectX/Y заданы', () {
    expect(objects, isNotEmpty);
    for (final part in objects) {
      expect(part.objectKind, isNotNull, reason: 'предмет ${part.id}');
      expect(part.objectScale, isNotNull, reason: 'предмет ${part.id}');
      expect(part.objectX, isNotNull, reason: 'предмет ${part.id}');
      expect(part.objectY, isNotNull, reason: 'предмет ${part.id}');
    }
  });

  test('нет одинарных шипов: у клетки плиты не бывает пустоты по обе стороны', () {
    // Как `thin` в docs/design/tools-smooth-plates.py: по сетке секции; сторона
    // за краем секции (край корпуса) шипом не считается.
    for (final section in RoninParts.sections) {
      final owner = <(int, int), String>{};
      for (final part in plates.where((p) => p.sectionId == section.id)) {
        for (final c in _sectionCells(part)) {
          owner[c] = part.id;
        }
      }
      bool inGrid(int c, int r) =>
          c >= 0 && c < section.cols && r >= 0 && r < section.rows;
      for (final e in owner.entries) {
        final (c, r) = e.key;
        final id = e.value;
        bool other(int cc, int rr) => owner[(cc, rr)] != id;
        final horizontal = inGrid(c - 1, r) &&
            inGrid(c + 1, r) &&
            other(c - 1, r) &&
            other(c + 1, r);
        final vertical = inGrid(c, r - 1) &&
            inGrid(c, r + 1) &&
            other(c, r - 1) &&
            other(c, r + 1);
        expect(horizontal || vertical, isFalse,
            reason: 'плита $id: одинарный шип в клетке секции ${section.id} ($c, $r)');
      }
    }
  });

  test('cellOnShip: клетка (c, r) = shipX + c/scale, размер 1/scale', () {
    for (final part in parts) {
      final r = part.cellOnShip(3, 2);
      expect(r.x, closeTo(part.shipX + 3 / part.scale, _eps));
      expect(r.y, closeTo(part.shipY + 2 / part.scale, _eps));
      expect(r.size, closeTo(1 / part.scale, _eps));
    }
  });

  test('каждая плита с order ≥ 2 касается плиты с меньшим order', () {
    for (final part in plates.where((p) => p.order >= 2)) {
      final earlier = plates.where((p) => p.order < part.order);
      expect(earlier.any((p) => _platesTouch(part, p)), isTrue,
          reason: 'плита ${part.id} не касается собранных до неё плит');
    }
  });

  test('каждый предмет перекрывается или касается плиты с меньшим order', () {
    for (final part in objects) {
      final earlier = plates.where((p) => p.order < part.order);
      expect(earlier.any((p) => _objectMeetsPlate(part, p)), isTrue,
          reason: 'предмет ${part.id} не лежит на собранной до него плите');
    }
  });
}
