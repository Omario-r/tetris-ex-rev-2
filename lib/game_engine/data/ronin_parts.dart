import '../models/target_mask.dart';

/// Сетка корабля «Ронин»: клетка рендера = 4×4 клетки сетки, сетка сдвинута
/// относительно рендера на [originCol] (канон разметки — `docs/design/ronin-parts.js`,
/// `docs/DESIGN.md` § «Модель модулей Ронин-1»).
class RoninGrid {
  static const int cols = 44;
  static const int rows = 108;
  static const int renderCell = 4;
  static const int originCol = 2;
}

/// Деталь «Ронина»: форма ([mask]) + место в сетке корабля ([originCol],
/// [originRow]) + метаданные сборки/укладки.
///
/// Источник — `docs/design/ronin-parts.js` (канон Дизайнера, утв. PO
/// 2026-07-29): переносится ровно то, что там лежит, без правок формы.
class RoninPartDef {
  /// Стабильный идентификатор детали (`'prow_l'` и т.п.).
  final String id;

  /// Порядок сборки на корабле, 1..13 без пропусков; уровень N ↔ деталь с
  /// `order == N`.
  final int order;

  /// Группа детали на корабле (`'prow'` | `'bridge'` | `'fwd'`).
  final String module;

  /// Название детали для топбара игрового экрана (напр. «Нос, левый борт»).
  final String title;

  /// Левый-верх bbox маски в координатах сетки [RoninGrid].
  final int originCol;
  final int originRow;

  /// Число клеток детали (бюджет уровня, 60..80 — VISION).
  final int cells;

  /// Фиксированный seed нарезки детали на кусочки; `null` — ещё не подобран
  /// (Стори 04).
  final int? seed;

  /// bbox-маска детали, `#` — клетка детали.
  final TargetMask mask;

  const RoninPartDef({
    required this.id,
    required this.order,
    required this.module,
    required this.title,
    required this.originCol,
    required this.originRow,
    required this.cells,
    required this.seed,
    required this.mask,
  });
}

/// Разметка «Ронина-1»: 13 деталей носа и мостика на сетке 44×108
/// (канон Дизайнера, `docs/design/ronin-parts.js`, утв. PO 2026-07-29).
/// Остальной борт (~37 деталей) — «Ронин-2».
class RoninParts {
  /// 13 деталей, отсортированы по [RoninPartDef.order] по возрастанию:
  /// индекс == `order - 1`.
  static const List<RoninPartDef> parts = [
    RoninPartDef(
      id: 'prow_l',
      order: 1,
      module: 'prow',
      title: 'Нос, левый борт',
      originCol: 12,
      originRow: 0,
      cells: 80,
      seed: null,
      mask: TargetMask(rows: [
        '##########',
        '##########',
        '##########',
        '##########',
        '##########',
        '##########',
        '##########',
        '##########',
      ]),
    ),
    RoninPartDef(
      id: 'prow_r',
      order: 2,
      module: 'prow',
      title: 'Нос, правый борт',
      originCol: 22,
      originRow: 0,
      cells: 80,
      seed: null,
      mask: TargetMask(rows: [
        '##########',
        '##########',
        '##########',
        '##########',
        '##########',
        '##########',
        '##########',
        '##########',
      ]),
    ),
    RoninPartDef(
      id: 'bridge_c',
      order: 3,
      module: 'bridge',
      title: 'Мостик, визор',
      originCol: 17,
      originRow: 8,
      cells: 72,
      seed: null,
      mask: TargetMask(rows: [
        '.########.',
        '.########.',
        '.########.',
        '.########.',
        '##########',
        '##########',
        '##########',
        '##########',
      ]),
    ),
    RoninPartDef(
      id: 'bridge_l',
      order: 4,
      module: 'bridge',
      title: 'Мостик, левый борт',
      originCol: 8,
      originRow: 8,
      cells: 76,
      seed: null,
      mask: TargetMask(rows: [
        '##########',
        '##########',
        '##########',
        '##########',
        '#########.',
        '#########.',
        '#########.',
        '#########.',
      ]),
    ),
    RoninPartDef(
      id: 'bridge_r',
      order: 5,
      module: 'bridge',
      title: 'Мостик, правый борт',
      originCol: 26,
      originRow: 8,
      cells: 76,
      seed: null,
      mask: TargetMask(rows: [
        '##########',
        '##########',
        '##########',
        '##########',
        '.#########',
        '.#########',
        '.#########',
        '.#########',
      ]),
    ),
    RoninPartDef(
      id: 'fwd1_cl',
      order: 6,
      module: 'fwd',
      title: 'Носовой пояс, верх — левее киля',
      originCol: 12,
      originRow: 16,
      cells: 72,
      seed: null,
      mask: TargetMask(rows: [
        '..########',
        '##########',
        '##########',
        '##########',
        '##########',
        '..########',
        '..####....',
        '..####....',
        '..####....',
        '..####....',
      ]),
    ),
    RoninPartDef(
      id: 'fwd1_cr',
      order: 7,
      module: 'fwd',
      title: 'Носовой пояс, верх — правее киля',
      originCol: 22,
      originRow: 16,
      cells: 72,
      seed: null,
      mask: TargetMask(rows: [
        '########..',
        '##########',
        '##########',
        '##########',
        '##########',
        '########..',
        '....####..',
        '....####..',
        '....####..',
        '....####..',
      ]),
    ),
    RoninPartDef(
      id: 'fwd1_l',
      order: 8,
      module: 'fwd',
      title: 'Носовой пояс, верх — левая скула',
      originCol: 4,
      originRow: 16,
      cells: 74,
      seed: null,
      mask: TargetMask(rows: [
        '##########',
        '########..',
        '########..',
        '########..',
        '########..',
        '##########',
        '...#######',
        '...#######',
        '......####',
        '......####',
      ]),
    ),
    RoninPartDef(
      id: 'fwd1_r',
      order: 9,
      module: 'fwd',
      title: 'Носовой пояс, верх — правая скула',
      originCol: 30,
      originRow: 16,
      cells: 74,
      seed: null,
      mask: TargetMask(rows: [
        '##########',
        '..########',
        '..########',
        '..########',
        '..########',
        '##########',
        '#######...',
        '#######...',
        '####......',
        '####......',
      ]),
    ),
    RoninPartDef(
      id: 'fwd2_cl',
      order: 10,
      module: 'fwd',
      title: 'Носовой пояс, низ — левее киля',
      originCol: 12,
      originRow: 22,
      cells: 68,
      seed: null,
      mask: TargetMask(rows: [
        '......####',
        '......####',
        '......####',
        '......####',
        '..########',
        '##########',
        '##########',
        '..########',
        '..########',
        '..########',
      ]),
    ),
    RoninPartDef(
      id: 'fwd2_cr',
      order: 11,
      module: 'fwd',
      title: 'Носовой пояс, низ — правее киля',
      originCol: 22,
      originRow: 22,
      cells: 68,
      seed: null,
      mask: TargetMask(rows: [
        '####......',
        '####......',
        '####......',
        '####......',
        '########..',
        '##########',
        '##########',
        '########..',
        '########..',
        '########..',
      ]),
    ),
    RoninPartDef(
      id: 'fwd2_l',
      order: 12,
      module: 'fwd',
      title: 'Носовой пояс, низ — левая скула',
      originCol: 4,
      originRow: 22,
      cells: 74,
      seed: null,
      mask: TargetMask(rows: [
        '###.......',
        '###.......',
        '######....',
        '######....',
        '##########',
        '########..',
        '########..',
        '##########',
        '##########',
        '##########',
      ]),
    ),
    RoninPartDef(
      id: 'fwd2_r',
      order: 13,
      module: 'fwd',
      title: 'Носовой пояс, низ — правая скула',
      originCol: 30,
      originRow: 22,
      cells: 74,
      seed: null,
      mask: TargetMask(rows: [
        '.......###',
        '.......###',
        '....######',
        '....######',
        '##########',
        '..########',
        '..########',
        '##########',
        '##########',
        '##########',
      ]),
    ),
  ];

  /// Деталь по порядку сборки ([order] 1..13).
  static RoninPartDef partAtOrder(int order) => parts[order - 1];

  /// Деталь по [id]; неизвестный id — [ArgumentError].
  static RoninPartDef byId(String id) => parts.firstWhere(
        (p) => p.id == id,
        orElse: () => throw ArgumentError('Неизвестный id детали: $id'),
      );
}
