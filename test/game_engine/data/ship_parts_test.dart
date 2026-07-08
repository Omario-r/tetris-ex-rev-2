import 'package:flutter_test/flutter_test.dart';
import 'package:explosive_tetris/game_engine/data/ship_parts.dart';
import 'package:explosive_tetris/presentation/widgets/ship.dart';

void main() {
  test('ровно kShipPartCount деталей', () {
    expect(ShipParts.parts.length, equals(kShipPartCount));
  });

  test('площадь каждой детали кратна 4 (правило VISION)', () {
    for (int i = 0; i < ShipParts.parts.length; i++) {
      final area = ShipParts.parts[i].mask.cells.length;
      expect(area % 4, equals(0), reason: 'деталь $i: площадь $area не кратна 4');
    }
  });

  test('детали влезают в сетку корабля', () {
    for (final p in ShipParts.parts) {
      expect(p.shipX + p.mask.width, lessThanOrEqualTo(ShipParts.gridSize));
      expect(p.shipY + p.mask.height, lessThanOrEqualTo(ShipParts.gridSize));
    }
  });
}
