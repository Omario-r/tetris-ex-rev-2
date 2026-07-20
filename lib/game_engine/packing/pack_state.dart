import '../models/target_mask.dart';
import 'pack_piece.dart';

/// Иммутабельный снапшот состояния укладки: силуэт + размещённые кусочки +
/// лоток. Мутации — только через `PackController` (`place`/`move`/`remove`),
/// сам класс лишь хранит данные и вычисляет производные (`occupiedCells`,
/// `isComplete`).
class PackState {
  /// Целевой силуэт S, в его локальных координатах.
  final TargetMask silhouette;

  /// `pieceId → origin` (левый-верхний угол кусочка в координатах силуэта);
  /// содержит только уложенные кусочки.
  final Map<int, ({int x, int y})> placements;

  /// Полный набор кусочков нарезки (по `id`), включая уложенные и лоток.
  final List<PackPiece> pieces;

  /// Id кусочков, ещё не уложенных (порядок лотка).
  final List<int> trayOrder;

  const PackState({
    required this.silhouette,
    required this.placements,
    required this.pieces,
    required this.trayOrder,
  });

  PackPiece _pieceById(int id) => pieces.firstWhere((p) => p.id == id);

  /// Все клетки уложенных кусочков в координатах силуэта (клетка кусочка +
  /// его `origin`). При корректных (провалидированных `canPlace`) переходах
  /// пересечений здесь не бывает.
  Set<({int x, int y})> get occupiedCells {
    final result = <({int x, int y})>{};
    for (final entry in placements.entries) {
      final piece = _pieceById(entry.key);
      final origin = entry.value;
      for (final cell in piece.cells) {
        result.add((x: origin.x + cell.x, y: origin.y + cell.y));
      }
    }
    return result;
  }

  /// true, если все клетки `silhouette.cells` покрыты уложенными кусочками
  /// ровно один раз (без дыр и без пересечений) — «деталь собрана».
  bool get isComplete {
    final placedCells = <({int x, int y})>[];
    for (final entry in placements.entries) {
      final piece = _pieceById(entry.key);
      final origin = entry.value;
      for (final cell in piece.cells) {
        placedCells.add((x: origin.x + cell.x, y: origin.y + cell.y));
      }
    }
    final placedSet = placedCells.toSet();
    if (placedSet.length != placedCells.length) {
      // Пересечение: одна и та же клетка покрыта дважды.
      return false;
    }
    final silhouetteCells = silhouette.cells.toSet();
    if (placedSet.length != silhouetteCells.length) return false;
    return placedSet.containsAll(silhouetteCells);
  }

  PackState copyWith({
    TargetMask? silhouette,
    Map<int, ({int x, int y})>? placements,
    List<PackPiece>? pieces,
    List<int>? trayOrder,
  }) {
    return PackState(
      silhouette: silhouette ?? this.silhouette,
      placements: placements ?? this.placements,
      pieces: pieces ?? this.pieces,
      trayOrder: trayOrder ?? this.trayOrder,
    );
  }
}
