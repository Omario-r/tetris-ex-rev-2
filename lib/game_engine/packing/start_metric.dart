import '../models/target_mask.dart';
import 'pack_slicer.dart';

/// Метрика старта (DESIGN.md § «Сложность старта»): на пустом поле для каждого
/// куска — число сдвигов (без поворотов), при которых все его клетки внутри
/// силуэта.
class StartMetric {
  /// Среднее число мест по кускам.
  final double placesPerPiece;

  /// Число мест у самого зажатого куска.
  final int minPlaces;

  const StartMetric(this.placesPerPiece, this.minPlaces);
}

/// Считает [StartMetric] нарезки [slice] силуэта [silhouette].
///
/// Сдвиг — левый-верх куска `(x, y)`, `x` в `0..width-1`, `y` в `0..height-1`
/// (клетки поля). Место — сдвиг, при котором для каждой клетки куска
/// `silhouette.contains(x + c.x, y + c.y)` (за пределами поля — не место).
/// Каждый кусок считается отдельно, одинаковые формы — каждая своим счётом.
StartMetric startMetric(TargetMask silhouette, PackSlice slice) {
  var total = 0;
  var minPlaces = -1;
  for (final piece in slice.pieces) {
    var places = 0;
    for (var y = 0; y < silhouette.height; y++) {
      for (var x = 0; x < silhouette.width; x++) {
        if (piece.cells.every((c) => silhouette.contains(x + c.x, y + c.y))) {
          places++;
        }
      }
    }
    total += places;
    if (minPlaces < 0 || places < minPlaces) minPlaces = places;
  }
  final count = slice.pieces.length;
  return StartMetric(
    count == 0 ? 0 : total / count,
    minPlaces < 0 ? 0 : minPlaces,
  );
}
