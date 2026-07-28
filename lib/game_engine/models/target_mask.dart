/// Форма Target-окна как строки символов, сверху вниз.
///
/// Каждая строка — ряд клеток окна: `#` — клетка силуэта, любой другой
/// символ (по конвенции — `.`) — пустая клетка. Все строки одной длины,
/// список строк непуст (см. [rows]). Строковое представление вместо битовой
/// маски снимает потолок 64 бит (было окно ≤ 8×8) — детали до 10×14 клеток
/// (100+ бит) в `int` не влезали.
class TargetMask {
  /// Строки окна сверху вниз: `#` — клетка силуэта, любой другой символ —
  /// пустая. Все строки одной длины, список непуст.
  final List<String> rows;

  const TargetMask({required this.rows});

  /// Инвариант окна: список строк непуст, строки непусты и одной длины.
  /// Проверяется тестами (и инвариант-тестом разметки), а не assert'ом в
  /// конструкторе: const-конструктор не может читать `rows.length`, а маски
  /// деталей обязаны быть `const`.
  bool get isWellFormed =>
      rows.isNotEmpty &&
      rows.first.isNotEmpty &&
      rows.every((r) => r.length == rows.first.length);

  int get height => rows.length;
  int get width => rows.first.length;

  /// true если клетка (localX, localY) входит в S.
  /// Вне окна (localX/localY отрицательны или ≥ width/height) — честный
  /// `false` без исключения (поведение сохраняется).
  bool contains(int localX, int localY) {
    if (localX < 0 || localX >= width || localY < 0 || localY >= height) {
      return false;
    }
    return rows[localY][localX] == '#';
  }

  /// Возвращает все локальные координаты клеток S, обход сверху вниз,
  /// слева направо (порядок сохраняется — на нём стоят тесты движка).
  List<({int x, int y})> get cells {
    final result = <({int x, int y})>[];
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        if (contains(x, y)) {
          result.add((x: x, y: y));
        }
      }
    }
    return result;
  }

  /// Новая маска размера [width]×[height], в которую эта вложена со сдвигом
  /// ([dx], [dy]); клетки вне исходной — пустые. Нужна для центрирования
  /// детали в фиксированном поле укладки.
  TargetMask padTo({
    required int width,
    required int height,
    required int dx,
    required int dy,
  }) {
    final newRows = List<String>.generate(height, (y) {
      final buffer = StringBuffer();
      for (var x = 0; x < width; x++) {
        buffer.write(contains(x - dx, y - dy) ? '#' : '.');
      }
      return buffer.toString();
    });
    return TargetMask(rows: newRows);
  }
}

/// Дефолтная маска MVP: крест толщиной 2 в окне 6×6.
const defaultTargetMask = TargetMask(
  rows: ['..##..', '..##..', '######', '######', '..##..', '..##..'],
);
