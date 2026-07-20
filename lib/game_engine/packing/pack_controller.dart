import 'pack_piece.dart';
import 'pack_state.dart';

/// Оркестрация укладки: размещение/переклад/снятие кусочков поверх
/// `PackState`, с валидацией «внутри силуэта + без пересечений».
///
/// Как `GameController`: невозможная команда — **no-op**, исключений не
/// бросаем.
class PackController {
  PackState _state;

  PackController(PackState initial) : _state = initial;

  PackState get state => _state;

  /// true, если кусочек `pieceId` (из набора `s.pieces`) целиком помещается
  /// в `origin=(atX,atY)`: каждая его клетка входит в `s.silhouette` и не
  /// пересекается с `s.occupiedCells` уже уложенных кусочков.
  ///
  /// `ignoreId` исключает из проверки пересечений сам перекладываемый
  /// кусочек (используется в `move`).
  static bool canPlace(
    PackState s,
    int pieceId,
    int atX,
    int atY, {
    int? ignoreId,
  }) {
    final piece = _findPiece(s, pieceId);
    if (piece == null) return false;

    final occupied = <({int x, int y})>{};
    for (final entry in s.placements.entries) {
      if (entry.key == ignoreId) continue;
      final other = _findPiece(s, entry.key);
      if (other == null) continue;
      final origin = entry.value;
      for (final cell in other.cells) {
        occupied.add((x: origin.x + cell.x, y: origin.y + cell.y));
      }
    }

    for (final cell in piece.cells) {
      final x = atX + cell.x;
      final y = atY + cell.y;
      if (!s.silhouette.contains(x, y)) return false;
      if (occupied.contains((x: x, y: y))) return false;
    }
    return true;
  }

  static PackPiece? _findPiece(PackState s, int pieceId) {
    for (final piece in s.pieces) {
      if (piece.id == pieceId) return piece;
    }
    return null;
  }

  /// Укладывает кусочек `pieceId` из лотка в `origin=(atX,atY)`.
  /// No-op, если `pieceId` не в лотке или позиция невалидна.
  void place(int pieceId, int atX, int atY) {
    if (!_state.trayOrder.contains(pieceId)) return;
    if (!canPlace(_state, pieceId, atX, atY)) return;

    final placements = Map<int, ({int x, int y})>.from(_state.placements);
    placements[pieceId] = (x: atX, y: atY);
    final trayOrder = List<int>.from(_state.trayOrder)..remove(pieceId);
    _state = _state.copyWith(placements: placements, trayOrder: trayOrder);
  }

  /// Перекладывает уже уложенный кусочек `pieceId` в новую позицию.
  /// Пересечение проверяется против ОСТАЛЬНЫХ уложенных (сам кусочек не
  /// мешает себе). No-op, если кусочек не уложен или позиция невалидна.
  void move(int pieceId, int atX, int atY) {
    if (!_state.placements.containsKey(pieceId)) return;
    if (!canPlace(_state, pieceId, atX, atY, ignoreId: pieceId)) return;

    final placements = Map<int, ({int x, int y})>.from(_state.placements);
    placements[pieceId] = (x: atX, y: atY);
    _state = _state.copyWith(placements: placements);
  }

  /// Снимает уложенный кусочек обратно в конец лотка. No-op, если кусочек
  /// не уложен.
  void remove(int pieceId) {
    if (!_state.placements.containsKey(pieceId)) return;

    final placements = Map<int, ({int x, int y})>.from(_state.placements)
      ..remove(pieceId);
    final trayOrder = List<int>.from(_state.trayOrder)..add(pieceId);
    _state = _state.copyWith(placements: placements, trayOrder: trayOrder);
  }
}
