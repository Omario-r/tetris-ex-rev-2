import '../models/target_mask.dart';

/// Секция обшивки «Ронина»: свой масштаб и своя сетка клеток
/// (канон — `docs/design/ronin-parts.js`, `docs/DESIGN.md` § «Разметка деталей»).
class RoninSection {
  /// Идентификатор секции: `'prow'` | `'bridge'` | `'fwd'`.
  final String id;

  /// Клеток поля на клетку рисунка корабля: 2 | 3 | 4.
  final int scale;

  /// Левый-верх сетки секции на корабле, в клетках рисунка `ship-render.js`.
  final int originX;
  final int originY;

  /// Размер сетки секции в её собственных клетках.
  final int cols;
  final int rows;

  const RoninSection({
    required this.id,
    required this.scale,
    required this.originX,
    required this.originY,
    required this.cols,
    required this.rows,
  });
}

/// Деталь «Ронина» разметки v2: форма ([mask]) + место на корабле + метаданные
/// сборки/укладки. Два вида: плита обшивки ([layer] 0, участок сетки секции) и
/// предмет поверх ([layer] 1, свой масштаб и место на корабле; D-010…D-012).
///
/// Источник — `docs/design/ronin-parts.js` (канон Дизайнера): переносится
/// ровно то, что там лежит. Смысл `origin` в каноне разный: у секции и у
/// предмета — клетки рисунка корабля, у плиты — клетки её секции
/// ([sectionCol]/[sectionRow]).
class RoninPartDef {
  /// Стабильный идентификатор детали (`'prow'`, `'fwd1_cl'` и т.п.).
  final String id;

  /// Порядок сборки на корабле, 1..15 без пропусков; уровень N ↔ деталь с
  /// `order == N`.
  final int order;

  /// Слой: 0 — плита обшивки, 1 — предмет поверх (D-011).
  final int layer;

  /// Группа детали на корабле (`'prow'` | `'bridge'` | `'fwd'`).
  final String module;

  /// Название детали для топбара игрового экрана (напр. «Нос»).
  final String title;

  /// Число клеток детали (бюджет уровня, ≤ 80).
  final int cells;

  /// Канонный seed нарезки детали на куски (подобран Продюсером, Стори 04).
  final int seed;

  /// bbox-маска детали, `#` — клетка детали.
  final TargetMask mask;

  /// Плита: идентификатор секции и origin маски в клетках секции.
  final String? sectionId;
  final int sectionCol;
  final int sectionRow;

  /// Предмет: вид (`'sensor'` | `'rcs'`), масштаб и левый-верх маски на
  /// корабле в клетках рисунка (дробные).
  final String? objectKind;
  final double? objectScale;
  final double? objectX;
  final double? objectY;

  const RoninPartDef({
    required this.id,
    required this.order,
    required this.layer,
    required this.module,
    required this.title,
    required this.cells,
    required this.seed,
    required this.mask,
    this.sectionId,
    this.sectionCol = 0,
    this.sectionRow = 0,
    this.objectKind,
    this.objectScale,
    this.objectX,
    this.objectY,
  });

  /// true — плита обшивки (слой 0), false — предмет (слой 1).
  bool get isPlate => layer == 0;

  /// Масштаб детали (клеток поля на клетку рисунка): секции у плиты, свой у
  /// предмета.
  double get scale => isPlate
      ? RoninParts.sectionById(sectionId!).scale.toDouble()
      : objectScale!;

  /// Левый-верх маски на корабле, клетки рисунка.
  double get shipX => isPlate
      ? RoninParts.sectionById(sectionId!).originX + sectionCol / scale
      : objectX!;
  double get shipY => isPlate
      ? RoninParts.sectionById(sectionId!).originY + sectionRow / scale
      : objectY!;

  /// Клетка (c, r) маски на корабле: левый-верх и сторона, клетки рисунка.
  ({double x, double y, double size}) cellOnShip(int c, int r) =>
      (x: shipX + c / scale, y: shipY + r / scale, size: 1 / scale);
}

/// Разметка «Ронина-1» v2: 15 деталей — плиты обшивки по трём секциям (нос,
/// мостик, носовой пояс) и предметы поверх (канон Дизайнера,
/// `docs/design/ronin-parts.js`, D-010…D-012).
class RoninParts {
  /// Секции обшивки: нос `s = 2`, мостик `s = 3`, носовой пояс `s = 4`.
  static const List<RoninSection> sections = [
    RoninSection(id: 'prow', scale: 2, originX: 5, originY: 0, cols: 10, rows: 6),
    RoninSection(id: 'bridge', scale: 3, originX: 4, originY: 2, cols: 21, rows: 6),
    RoninSection(id: 'fwd', scale: 4, originX: 3, originY: 4, cols: 36, rows: 16),
  ];

  /// 15 деталей, отсортированы по [RoninPartDef.order] по возрастанию:
  /// индекс == `order - 1`.
  static const List<RoninPartDef> parts = [
    RoninPartDef(
      id: 'prow',
      order: 1,
      layer: 0,
      module: 'prow',
      title: 'Нос',
      cells: 44,
      seed: 1,
      sectionId: 'prow',
      sectionCol: 0,
      sectionRow: 0,
      mask: TargetMask(rows: [
        '##########',
        '##########',
        '##########',
        '##########',
        '..##......',
        '..##......',
      ]),
    ),
    RoninPartDef(
      id: 'sensor',
      order: 2,
      layer: 1,
      module: 'prow',
      title: 'Датчик носа',
      cells: 41,
      seed: 4,
      objectKind: 'sensor',
      objectScale: 7,
      objectX: 7,
      objectY: -1.199,
      mask: TargetMask(rows: [
        '...#...',
        '...#...',
        '..###..',
        '..###..',
        '.#####.',
        '#######',
        '#######',
        '#######',
        '#######',
      ]),
    ),
    RoninPartDef(
      id: 'bridge_c',
      order: 3,
      layer: 0,
      module: 'bridge',
      title: 'Мостик, визор',
      cells: 36,
      seed: 0,
      sectionId: 'bridge',
      sectionCol: 5,
      sectionRow: 0,
      mask: TargetMask(rows: [
        '....#####.',
        '....####..',
        '#...####..',
        '##########',
        '..#######.',
        '...#####..',
      ]),
    ),
    RoninPartDef(
      id: 'bridge_l',
      order: 4,
      layer: 0,
      module: 'bridge',
      title: 'Мостик, левый борт',
      cells: 37,
      seed: 1,
      sectionId: 'bridge',
      sectionCol: 0,
      sectionRow: 0,
      mask: TargetMask(rows: [
        '######..',
        '######..',
        '#####...',
        '#####...',
        '#######.',
        '########',
      ]),
    ),
    RoninPartDef(
      id: 'bridge_r',
      order: 5,
      layer: 0,
      module: 'bridge',
      title: 'Мостик, правый борт',
      cells: 44,
      seed: 0,
      sectionId: 'bridge',
      sectionCol: 13,
      sectionRow: 0,
      mask: TargetMask(rows: [
        '.#######',
        '########',
        '########',
        '..######',
        '.#######',
        '########',
      ]),
    ),
    RoninPartDef(
      id: 'fwd1_cl',
      order: 6,
      layer: 0,
      module: 'fwd',
      title: 'Носовой пояс, верх — левее киля',
      cells: 66,
      seed: 1,
      sectionId: 'fwd',
      sectionCol: 9,
      sectionRow: 0,
      mask: TargetMask(rows: [
        '#########.',
        '##########',
        '.#########',
        '.########.',
        '.########.',
        '#########.',
        '##########',
        '.......###',
      ]),
    ),
    RoninPartDef(
      id: 'fwd1_cr',
      order: 7,
      layer: 0,
      module: 'fwd',
      title: 'Носовой пояс, верх — правее киля',
      cells: 64,
      seed: 6,
      sectionId: 'fwd',
      sectionCol: 18,
      sectionRow: 0,
      mask: TargetMask(rows: [
        '##########',
        '.#########',
        '.########.',
        '#########.',
        '#########.',
        '##########',
        '.#########',
      ]),
    ),
    RoninPartDef(
      id: 'fwd1_r',
      order: 8,
      layer: 0,
      module: 'fwd',
      title: 'Носовой пояс, верх — правая скула',
      cells: 68,
      seed: 4,
      sectionId: 'fwd',
      sectionCol: 27,
      sectionRow: 0,
      mask: TargetMask(rows: [
        '.########',
        '.########',
        '#########',
        '#########',
        '#########',
        '.########',
        '.########',
        '.####....',
        '#####....',
      ]),
    ),
    RoninPartDef(
      id: 'rcs_fr',
      order: 9,
      layer: 1,
      module: 'fwd',
      title: 'RCS-квад, нос справа',
      cells: 43,
      seed: 8,
      objectKind: 'rcs',
      objectScale: 8,
      objectX: 11.688,
      objectY: 3.944,
      mask: TargetMask(rows: [
        '.###...',
        '.###...',
        '#####..',
        '#######',
        '#######',
        '#######',
        '#####..',
        '.###...',
        '.###...',
      ]),
    ),
    RoninPartDef(
      id: 'fwd2_r',
      order: 10,
      layer: 0,
      module: 'fwd',
      title: 'Носовой пояс, низ — правая скула',
      cells: 70,
      seed: 0,
      sectionId: 'fwd',
      sectionCol: 27,
      sectionRow: 7,
      mask: TargetMask(rows: [
        '.....####',
        '.....####',
        '#########',
        '#########',
        '.########',
        '#########',
        '#########',
        '#########',
        '#########',
      ]),
    ),
    RoninPartDef(
      id: 'fwd1_l',
      order: 11,
      layer: 0,
      module: 'fwd',
      title: 'Носовой пояс, верх — левая скула',
      cells: 72,
      seed: 2,
      sectionId: 'fwd',
      sectionCol: 0,
      sectionRow: 0,
      mask: TargetMask(rows: [
        '#########.',
        '#########.',
        '##########',
        '##########',
        '##########',
        '#########.',
        '#########.',
        '...######.',
      ]),
    ),
    RoninPartDef(
      id: 'rcs_fl',
      order: 12,
      layer: 1,
      module: 'fwd',
      title: 'RCS-квад, нос слева',
      cells: 43,
      seed: 0,
      objectKind: 'rcs',
      objectScale: 8,
      objectX: 2.438,
      objectY: 3.944,
      mask: TargetMask(rows: [
        '...###.',
        '...###.',
        '..#####',
        '#######',
        '#######',
        '#######',
        '..#####',
        '...###.',
        '...###.',
      ]),
    ),
    RoninPartDef(
      id: 'fwd2_l',
      order: 13,
      layer: 0,
      module: 'fwd',
      title: 'Носовой пояс, низ — левая скула',
      cells: 76,
      seed: 5,
      sectionId: 'fwd',
      sectionCol: 0,
      sectionRow: 7,
      mask: TargetMask(rows: [
        '###.......',
        '#########.',
        '##########',
        '#########.',
        '#########.',
        '#########.',
        '#########.',
        '#########.',
        '#########.',
      ]),
    ),
    RoninPartDef(
      id: 'fwd2_cl',
      order: 14,
      layer: 0,
      module: 'fwd',
      title: 'Носовой пояс, низ — левее киля',
      cells: 80,
      seed: 4,
      sectionId: 'fwd',
      sectionCol: 9,
      sectionRow: 7,
      mask: TargetMask(rows: [
        '#######...',
        '##########',
        '.########.',
        '#########.',
        '#########.',
        '##########',
        '#########.',
        '#########.',
        '#########.',
      ]),
    ),
    RoninPartDef(
      id: 'fwd2_cr',
      order: 15,
      layer: 0,
      module: 'fwd',
      title: 'Носовой пояс, низ — правее киля',
      cells: 80,
      seed: 2,
      sectionId: 'fwd',
      sectionCol: 18,
      sectionRow: 7,
      mask: TargetMask(rows: [
        '.#########',
        '.########.',
        '#########.',
        '#########.',
        '##########',
        '.########.',
        '#########.',
        '#########.',
        '#########.',
      ]),
    ),
  ];

  /// Секция по [id]; неизвестный id — [ArgumentError].
  static RoninSection sectionById(String id) => sections.firstWhere(
        (s) => s.id == id,
        orElse: () => throw ArgumentError('Неизвестный id секции: $id'),
      );

  /// Деталь по порядку сборки ([order] 1..15).
  static RoninPartDef partAtOrder(int order) => parts[order - 1];

  /// Деталь по [id]; неизвестный id — [ArgumentError].
  static RoninPartDef byId(String id) => parts.firstWhere(
        (p) => p.id == id,
        orElse: () => throw ArgumentError('Неизвестный id детали: $id'),
      );
}
