import 'package:flutter_test/flutter_test.dart';
import 'package:explosive_tetris/game_engine/models/target_mask.dart';

void main() {
  group('TargetMask contains — крест', () {
    test('вертикальная перекладина (2,0)', () {
      expect(defaultTargetMask.contains(2, 0), isTrue);
    });

    test('горизонтальная перекладина (0,2)', () {
      expect(defaultTargetMask.contains(0, 2), isTrue);
    });

    test('угол (0,0) не в кресте', () {
      expect(defaultTargetMask.contains(0, 0), isFalse);
    });

    test('угол (5,5) не в кресте', () {
      expect(defaultTargetMask.contains(5, 5), isFalse);
    });

    test('пересечение перекладин (3,3)', () {
      expect(defaultTargetMask.contains(3, 3), isTrue);
    });
  });

  group('TargetMask cells', () {
    test('количество клеток == 20', () {
      expect(defaultTargetMask.cells.length, equals(20));
    });

    test('все координаты в диапазоне 0..5', () {
      for (final cell in defaultTargetMask.cells) {
        expect(cell.x, inInclusiveRange(0, 5));
        expect(cell.y, inInclusiveRange(0, 5));
      }
    });

    test('contains == true для каждой клетки из cells', () {
      for (final cell in defaultTargetMask.cells) {
        expect(defaultTargetMask.contains(cell.x, cell.y), isTrue);
      }
    });
  });

  group('TargetMask contains — вне окна (границы, без исключений)', () {
    test('contains(6, 0) — за правым краем 6×6', () {
      expect(defaultTargetMask.contains(6, 0), isFalse);
    });

    test('contains(0, 6) — за нижним краем 6×6', () {
      expect(defaultTargetMask.contains(0, 6), isFalse);
    });

    test('contains(-1, 0) — отрицательный localX', () {
      expect(defaultTargetMask.contains(-1, 0), isFalse);
    });

    test('contains(0, -1) — отрицательный localY', () {
      expect(defaultTargetMask.contains(0, -1), isFalse);
    });

    test('contains(6, 5) — бит-индекс -1 из трейса краша', () {
      expect(defaultTargetMask.contains(6, 5), isFalse);
    });

    test('смоук: валидная клетка внутри окна не задета фиксом', () {
      expect(defaultTargetMask.contains(2, 0), isTrue);
    });
  });

  group('TargetMask через rows — соответствие строк клеткам', () {
    test('1x1 "#" содержит (0,0)', () {
      const m = TargetMask(rows: ['#']);
      expect(m.contains(0, 0), isTrue);
    });

    test('2x2 верхний-левый угол занят', () {
      const m = TargetMask(rows: ['#.', '..']);
      expect(m.contains(0, 0), isTrue);
      expect(m.contains(1, 0), isFalse);
      expect(m.contains(0, 1), isFalse);
      expect(m.contains(1, 1), isFalse);
    });

    test('2x2 нижний-правый угол занят', () {
      const m = TargetMask(rows: ['..', '.#']);
      expect(m.contains(1, 1), isTrue);
      expect(m.contains(0, 0), isFalse);
    });

    test('width/height берутся из rows', () {
      const m = TargetMask(rows: ['###', '###']);
      expect(m.width, equals(3));
      expect(m.height, equals(2));
    });
  });

  group('TargetMask.isWellFormed', () {
    test('true на нормальной маске', () {
      const m = TargetMask(rows: ['##', '##']);
      expect(m.isWellFormed, isTrue);
    });

    test('false на строках разной длины', () {
      const m = TargetMask(rows: ['##', '#']);
      expect(m.isWellFormed, isFalse);
    });

    test('false на пустом списке rows (без падения)', () {
      const m = TargetMask(rows: []);
      expect(m.isWellFormed, isFalse);
    });

    test('false на строках нулевой длины (без падения)', () {
      const m = TargetMask(rows: ['', '']);
      expect(m.isWellFormed, isFalse);
    });
  });

  group('TargetMask.padTo', () {
    test('кладёт исходные клетки со сдвигом', () {
      const m = TargetMask(rows: ['##', '##']);
      final padded = m.padTo(width: 6, height: 6, dx: 2, dy: 2);
      expect(padded.width, equals(6));
      expect(padded.height, equals(6));
      for (final cell in m.cells) {
        expect(padded.contains(cell.x + 2, cell.y + 2), isTrue);
      }
    });

    test('не добавляет чужих клеток — совпадает число клеток', () {
      const m = TargetMask(rows: ['##', '##']);
      final padded = m.padTo(width: 6, height: 6, dx: 2, dy: 2);
      expect(padded.cells.length, equals(m.cells.length));
    });

    test('клетки вне окна сдвига не появляются на исходном месте', () {
      const m = TargetMask(rows: ['##', '##']);
      final padded = m.padTo(width: 6, height: 6, dx: 2, dy: 2);
      expect(padded.contains(0, 0), isFalse);
    });
  });
}
