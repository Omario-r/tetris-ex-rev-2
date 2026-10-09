import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:explosive_tetris/game_engine/data/ronin_parts.dart';
import 'package:explosive_tetris/game_engine/models/target_mask.dart';
import 'package:explosive_tetris/game_engine/packing/pack_piece.dart';
import 'package:explosive_tetris/game_engine/packing/pack_state.dart';
import 'package:explosive_tetris/game_engine/packing/slice_config.dart';
import 'package:explosive_tetris/presentation/ship_render/ronin_art.dart';
import 'package:explosive_tetris/presentation/ship_render/ship_cell_sampler.dart';
import 'package:explosive_tetris/presentation/theme/block_material.dart';
import 'package:explosive_tetris/presentation/theme/block_theme.dart';
import 'package:explosive_tetris/presentation/widgets/packing_painter.dart';

/// Силуэт 2×1, обе клетки в S — два однокелеточных кусочка (id 1 и 2) уложены
/// каждый в свою клетку. Достаточно для проверки исключения поднятого куска
/// без лишней сложности нарезки/связности.
PackState _twoPieceState() {
  const silhouette = TargetMask(rows: ['##']);
  return const PackState(
    silhouette: silhouette,
    placements: {1: (x: 0, y: 0), 2: (x: 1, y: 0)},
    pieces: [
      PackPiece(id: 1, cells: [(x: 0, y: 0)]),
      PackPiece(id: 2, cells: [(x: 0, y: 0)]),
    ],
    trayOrder: [],
  );
}

/// Пейнтер с рисунком «Ронина» и деталью [partId] (по умолчанию `bridge_c`)
/// без сдвига маски — для тестов, где важен не кусок рисунка, а остальное.
PackingPainter _painter(
  PackState state, {
  String partId = 'bridge_c',
  int targetX = 0,
  int targetY = 0,
  int? excludePieceId,
  PackDragPreview? dragPreview,
}) {
  return PackingPainter(
    state: state,
    cellSize: 34.0,
    art: RoninArt.shared,
    part: RoninParts.byId(partId),
    targetX: targetX,
    targetY: targetY,
    excludePieceId: excludePieceId,
    dragPreview: dragPreview,
  );
}

/// Рисует [draw] на холст [width]×[height] и отдаёт RGBA-байты растра.
Future<ByteData> _rasterBytes(
  int width,
  int height,
  void Function(Canvas) draw,
) async {
  final recorder = ui.PictureRecorder();
  draw(Canvas(recorder));
  final image = await recorder.endRecording().toImage(width, height);
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  image.dispose();
  return data;
}

/// Пиксель ([x], [y]) растра шириной [width] как `[r, g, b, a]`.
List<int> _px(ByteData data, int width, int x, int y) {
  final i = (y * width + x) * 4;
  return [for (var k = 0; k < 4; k++) data.getUint8(i + k)];
}

/// Каналы [a] и [b] совпадают с допуском [tol].
bool _close(List<int> a, List<int> b, [int tol = 2]) {
  for (var k = 0; k < 4; k++) {
    if ((a[k] - b[k]).abs() > tol) return false;
  }
  return true;
}

int _sum(List<int> p) => p[0] + p[1] + p[2];

List<int> _rgbaOf(Color c) => [
  (c.r * 255).round(),
  (c.g * 255).round(),
  (c.b * 255).round(),
  (c.a * 255).round(),
];

void main() {
  group(
    'PackingPainter — уложенные клетки из рисунка корабля (Ронин-1/03)',
    () {
      // Настоящий уровень: деталь bridge_c отцентрована в поле 10×14, на поле
      // лежит один кусок эталонной раскладки, остальное — мишень.
      const cs = 34.0;
      const fieldW = 340, fieldH = 476;
      final part = RoninParts.byId('bridge_c');
      final prepared = prepareLevel(part.mask, seed: part.seed);
      final placedId = prepared.slice.solution.keys.first;
      final state = PackState(
        silhouette: prepared.silhouette,
        placements: {placedId: prepared.slice.solution[placedId]!},
        pieces: prepared.slice.pieces,
        trayOrder: prepared.trayOrder,
      );
      final occupied = state.occupiedCells.toList()
        ..sort((a, b) => a.y != b.y ? a.y - b.y : a.x - b.x);
      final ghostCell = prepared.silhouette.cells.firstWhere(
        (c) => !state.occupiedCells.contains(c),
      );

      PackingPainter fieldPainter({int? excludePieceId}) => PackingPainter(
        state: state,
        cellSize: cs,
        art: RoninArt.shared,
        part: part,
        targetX: prepared.targetX,
        targetY: prepared.targetY,
        excludePieceId: excludePieceId,
      );

      Future<ByteData> paintField({int? excludePieceId}) => _rasterBytes(
        fieldW,
        fieldH,
        (g) => fieldPainter(
          excludePieceId: excludePieceId,
        ).paint(g, const Size(340, 476)),
      );

      /// Эталон клетки поля [f]: её клетка маски через `paintPartCell`.
      Future<ByteData> paintReferenceCell(
        ({int x, int y}) f, {
        bool assembled = false,
      }) => _rasterBytes(
        fieldW,
        fieldH,
        (g) => paintPartCell(
          g,
          RoninArt.shared,
          part,
          f.x - prepared.targetX,
          f.y - prepared.targetY,
          Rect.fromLTWH(f.x * cs, f.y * cs, cs, cs),
          assembled: assembled,
        ),
      );

      /// Эталон ghost: фон поля + `ghostTarget` в клетке [f].
      Future<ByteData> paintReferenceGhost(({int x, int y}) f) =>
          _rasterBytes(fieldW, fieldH, (g) {
            g.drawRect(
              const Rect.fromLTWH(0, 0, 340, 476),
              Paint()..color = PackingPainter.boardBg,
            );
            BlockTheme.ghostTarget.paint(
              g,
              Rect.fromLTWH(f.x * cs, f.y * cs, cs, cs),
            );
          });

      test('уложенная клетка — кусок рисунка своей клетки маски: '
          '≠ графит, ≠ boardBg, = paintPartCell (центр клетки)', () async {
        // Центр плитки рельефом не задет (полосы — по краям 3s).
        final field = await paintField();
        final graphite = _rgbaOf(BlockMaterial.graphite.color);
        final board = _rgbaOf(PackingPainter.boardBg);
        for (final f in occupied) {
          final ref = await paintReferenceCell(f);
          final x = ((f.x + 0.5) * cs).floor(), y = ((f.y + 0.5) * cs).floor();
          final got = _px(field, fieldW, x, y);
          expect(
            _close(got, _px(ref, fieldW, x, y)),
            isTrue,
            reason: 'клетка $f: $got против эталона ${_px(ref, fieldW, x, y)}',
          );
          expect(
            _close(got, board),
            isFalse,
            reason: 'клетка $f — не фон поля',
          );
          expect(
            _close(got, graphite),
            isFalse,
            reason: 'клетка $f — не графит',
          );
        }
      });

      test('незанятая клетка силуэта — ghost, как было', () async {
        final field = await paintField();
        final ref = await paintReferenceGhost(ghostCell);
        for (var dy = 2; dy < 32; dy++) {
          for (var dx = 2; dx < 32; dx++) {
            final x = ghostCell.x * 34 + dx, y = ghostCell.y * 34 + dy;
            expect(
              _close(_px(field, fieldW, x, y), _px(ref, fieldW, x, y)),
              isTrue,
              reason: 'ghost-клетка $ghostCell, пиксель ($x, $y)',
            );
          }
        }
      });

      test('сборка: уложенная клетка — плитка, угол клетки прозрачен до фона '
          'поля, швов seam нет', () async {
        final field = await paintField();
        final board = _rgbaOf(PackingPainter.boardBg);
        for (final f in occupied) {
          final x = (f.x * cs).floor(), y = (f.y * cs).floor();
          expect(
            _close(_px(field, fieldW, x, y), board),
            isTrue,
            reason: 'угол клетки $f — фон поля (вне скругления плитки)',
          );
        }
      });

      test('assembled: деталь целиком — граница клеток внутри детали не '
          'темнее центра, внешний край темнее (чёткая кромка)', () async {
        final done = await _rasterBytes(
          fieldW,
          fieldH,
          (g) => PackingPainter(
            state: state,
            cellSize: cs,
            art: RoninArt.shared,
            part: part,
            targetX: prepared.targetX,
            targetY: prepared.targetY,
            assembled: true,
          ).paint(g, const Size(340, 476)),
        );
        final build = await paintField();
        // Клетка с соседом справа в той же уложенной группе — граница внутри.
        final f = occupied.firstWhere(
          (c) => occupied.contains((x: c.x + 1, y: c.y)),
        );
        final ex = ((f.x + 1) * cs).floor(), ey = ((f.y + 0.5) * cs).floor();
        final cx = ((f.x + 0.5) * cs).floor();
        expect(
          _close(_px(done, fieldW, ex, ey), _px(done, fieldW, cx, ey), 12),
          isTrue,
          reason: 'собрано: граница клеток = центр клетки (плиток нет)',
        );
        expect(
          _sum(_px(build, fieldW, ex, ey)),
          lessThan(_sum(_px(done, fieldW, ex, ey))),
          reason: 'в сборке между плитками — зазор (фон поля)',
        );
        // Внешний край детали: верхняя клетка без соседа сверху в маске.
        final top = occupied.firstWhere(
          (c) => !part.mask.contains(
            c.x - prepared.targetX,
            c.y - prepared.targetY - 1,
          ),
        );
        final tx = ((top.x + 0.5) * cs).floor(), ty = (top.y * cs).floor();
        final ref = await paintReferenceCell(top, assembled: true);
        expect(
          _sum(_px(done, fieldW, tx, ty)),
          lessThan(_sum(_px(done, fieldW, tx, ((top.y + 0.5) * cs).floor()))),
          reason: 'кромка: внешний край темнее центра клетки',
        );
        expect(
          _close(_px(done, fieldW, tx, ty), _px(ref, fieldW, tx, ty)),
          isTrue,
          reason: 'кромка поля = кромка paintPartCell той же клетки',
        );
      });

      test('excludePieceId — клетки поднятого куска снова ghost', () async {
        final field = await paintField(excludePieceId: placedId);
        final f = occupied.first;
        final ref = await paintReferenceGhost(f);
        final x = ((f.x + 0.5) * cs).floor(), y = ((f.y + 0.5) * cs).floor();
        expect(
          _close(_px(field, fieldW, x, y), _px(ref, fieldW, x, y)),
          isTrue,
          reason: 'клетка $f поднятого куска — ghost мишени',
        );
      });

      test('shouldRepaint реагирует на смену детали, но не на ту же', () {
        final base = fieldPainter();
        final same = fieldPainter();
        final other = PackingPainter(
          state: state,
          cellSize: cs,
          art: RoninArt.shared,
          part: RoninParts.byId('sensor'),
          targetX: prepared.targetX,
          targetY: prepared.targetY,
        );
        expect(other.shouldRepaint(base), isTrue);
        expect(same.shouldRepaint(base), isFalse);
        final assembled = PackingPainter(
          state: state,
          cellSize: cs,
          art: RoninArt.shared,
          part: part,
          targetX: prepared.targetX,
          targetY: prepared.targetY,
          assembled: true,
        );
        expect(assembled.shouldRepaint(base), isTrue);
        final colors = PartCellColors(
          width: part.mask.width,
          height: part.mask.height,
          colors: List.filled(
            part.mask.width * part.mask.height,
            const Color(0xFF404040),
          ),
        );
        PackingPainter withColors() => PackingPainter(
          state: state,
          cellSize: cs,
          art: RoninArt.shared,
          part: part,
          targetX: prepared.targetX,
          targetY: prepared.targetY,
          cellColors: colors,
        );
        expect(withColors().shouldRepaint(base), isTrue);
        expect(withColors().shouldRepaint(withColors()), isFalse);
      });
    },
  );

  group('PackingPainter — dragPreview (снап-превью drop-ok/drop-bad)', () {
    PackState emptyState() {
      const silhouette = TargetMask(rows: ['####', '####', '####', '####']);
      return const PackState(
        silhouette: silhouette,
        placements: {},
        pieces: [],
        trayOrder: [],
      );
    }

    test('valid:true — рисует без исключений (клетки внутри и за границами '
        'силуэта, за границами должны молча пропускаться)', () {
      final painter = _painter(
        emptyState(),
        dragPreview: const PackDragPreview(
          cells: [(x: 0, y: 0), (x: 1, y: 0), (x: -1, y: 0), (x: 99, y: 99)],
          valid: true,
        ),
      );

      expect(
        () => painter.paint(Canvas(ui.PictureRecorder()), const Size(136, 136)),
        returnsNormally,
      );
    });

    test('valid:false — рисует без исключений', () {
      final painter = _painter(
        emptyState(),
        dragPreview: const PackDragPreview(cells: [(x: 2, y: 2)], valid: false),
      );

      expect(
        () => painter.paint(Canvas(ui.PictureRecorder()), const Size(136, 136)),
        returnsNormally,
      );
    });

    test('shouldRepaint реагирует на появление/смену dragPreview', () {
      final state = emptyState();
      final withoutPreview = _painter(state);
      final withValidPreview = _painter(
        state,
        dragPreview: const PackDragPreview(cells: [(x: 0, y: 0)], valid: true),
      );
      final withInvalidPreview = _painter(
        state,
        dragPreview: const PackDragPreview(cells: [(x: 0, y: 0)], valid: false),
      );
      final withSameValidPreview = _painter(
        state,
        dragPreview: const PackDragPreview(cells: [(x: 0, y: 0)], valid: true),
      );

      expect(
        withValidPreview.shouldRepaint(withoutPreview),
        isTrue,
        reason: 'null → превью — должен перерисоваться',
      );
      expect(
        withInvalidPreview.shouldRepaint(withValidPreview),
        isTrue,
        reason: 'смена valid true→false — должен перерисоваться',
      );
      expect(
        withSameValidPreview.shouldRepaint(withValidPreview),
        isFalse,
        reason: 'равный по значению PackDragPreview — repaint не нужен',
      );
    });

    test('клетки у краёв поля (углы силуэта) — рисует плашку без исключений '
        '(возврат Стори 04 T4: RRect-плашка на клетку, инсет 3px)', () {
      final painter = _painter(
        emptyState(),
        dragPreview: const PackDragPreview(
          cells: [
            (x: 0, y: 0), // левый-верхний угол силуэта
            (x: 3, y: 0), // правый-верхний угол (последний столбец)
            (x: 0, y: 3), // левый-нижний угол (последняя строка)
            (x: 3, y: 3), // правый-нижний угол силуэта 4×4
          ],
          valid: true,
        ),
      );

      expect(
        () => painter.paint(Canvas(ui.PictureRecorder()), const Size(136, 136)),
        returnsNormally,
      );
    });

    test('shouldRepaint реагирует на смену сдвига маски targetX/targetY', () {
      final state = emptyState();
      final base = _painter(state);
      expect(_painter(state, targetX: 1).shouldRepaint(base), isTrue);
      expect(_painter(state, targetY: 1).shouldRepaint(base), isTrue);
    });
  });

  group('PackingPainter.occupiedCellsExcluding (возврат Стори 04 T5 — '
      'ghost под поднятым куском)', () {
    test('excludePieceId: null — совпадает с state.occupiedCells', () {
      final state = _twoPieceState();

      final result = PackingPainter.occupiedCellsExcluding(state, null);

      expect(result, equals(state.occupiedCells));
    });

    test('уложенный кусок исключён — его клеток нет в результирующем сете', () {
      final state = _twoPieceState();

      final result = PackingPainter.occupiedCellsExcluding(state, 1);

      expect(
        result,
        isNot(contains((x: 0, y: 0))),
        reason: 'клетка кусочка id 1 (снят с поля — в руке) не занята',
      );
      expect(
        result,
        contains((x: 1, y: 0)),
        reason: 'клетка кусочка id 2 (остался на поле) занята по-прежнему',
      );
      expect(result.length, equals(state.occupiedCells.length - 1));
    });

    test(
      'excludePieceId не из placements (драг из лотка) — сет не меняется',
      () {
        final state = _twoPieceState();

        final result = PackingPainter.occupiedCellsExcluding(state, 99);

        expect(result, equals(state.occupiedCells));
      },
    );

    test('смоук paint: уложенный кусок + excludePieceId его id — не бросает '
        '(ghost на месте поднятого куска рисуется без исключений)', () {
      final painter = _painter(_twoPieceState(), excludePieceId: 1);

      expect(
        () => painter.paint(Canvas(ui.PictureRecorder()), const Size(68, 34)),
        returnsNormally,
      );
    });
  });
}
