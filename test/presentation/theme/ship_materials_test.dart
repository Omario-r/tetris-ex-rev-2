import 'package:flutter_test/flutter_test.dart';

import 'package:explosive_tetris/game_engine/data/ship_parts.dart';
import 'package:explosive_tetris/presentation/theme/block_material.dart';
import 'package:explosive_tetris/presentation/theme/ship_materials.dart';

void main() {
  group('ShipMaterials', () {
    test('defaultMaterials покрывает ровно все детали корабля', () {
      final m = ShipMaterials.defaultMaterials;
      for (int i = 0; i < ShipParts.parts.length; i++) {
        expect(m.materialForPart(i), isA<BlockMaterial>());
      }
      // карта ровно на N деталей — за пределами RangeError
      expect(() => m.materialForPart(ShipParts.parts.length), throwsRangeError);
    });

    test('materialForPart возвращает заданный материал детали', () {
      final m = ShipMaterials([BlockMaterial.rust, BlockMaterial.gunmetal]);
      expect(m.materialForPart(0), BlockMaterial.rust);
      expect(m.materialForPart(1), BlockMaterial.gunmetal);
    });

    test('дефолтная карта соответствует секциям «Ронина» v4', () {
      final m = ShipMaterials.defaultMaterials;
      expect(m.materialForPart(0), BlockMaterial.darkNiche); // нос
      expect(m.materialForPart(5), BlockMaterial.gunmetal); // двигатель
      expect(m.materialForPart(6), BlockMaterial.matteBlack); // хвост
    });

    test('пустая карта запрещена (assert)', () {
      expect(() => ShipMaterials(const []), throwsA(isA<AssertionError>()));
    });
  });
}
