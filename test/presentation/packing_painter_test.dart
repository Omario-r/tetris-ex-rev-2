import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:explosive_tetris/game_engine/models/target_mask.dart';
import 'package:explosive_tetris/game_engine/packing/pack_piece.dart';
import 'package:explosive_tetris/game_engine/packing/pack_state.dart';
import 'package:explosive_tetris/presentation/theme/block_material.dart';
import 'package:explosive_tetris/presentation/theme/ship_materials.dart';
import 'package:explosive_tetris/presentation/widgets/packing_painter.dart';

/// Силуэт 2×1, обе клетки в S — два однокелеточных кусочка (id 1 и 2) уложены
/// каждый в свою клетку. Достаточно для проверки цвета уложенных клеток без
/// лишней сложности нарезки/связности.
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

/// Рендерит [painter] на изображение [width]×[height] и возвращает RGBA-байты
/// пикселя в глобальных координатах ([x],[y]) как `(r, g, b, a)`.
Future<(int, int, int, int)> _samplePixel(
  CustomPainter painter,
  int width,
  int height,
  int x,
  int y,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  painter.paint(canvas, Size(width.toDouble(), height.toDouble()));
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final data = byteData!;
  final i = (y * width + x) * 4;
  return (
    data.getUint8(i),
    data.getUint8(i + 1),
    data.getUint8(i + 2),
    data.getUint8(i + 3),
  );
}

void main() {
  group('PackingPainter — partMaterial (единый материал детали)', () {
    test('с partMaterial уложенные клетки разных кусочков — одного цвета '
        '(материал детали, не циклическая палитра)', () async {
      final state = _twoPieceState();
      const cellSize = 34.0; // baseCellSize — центр клетки далеко от бевела.
      const material = BlockMaterial.hazardOrange;

      final painter = PackingPainter(
        state: state,
        cellSize: cellSize,
        shipMaterials: ShipMaterials.defaultMaterials,
        partMaterial: material,
      );

      // Центры клетки 0 (кусочек id 1) и клетки 1 (кусочек id 2, +cellSize по X).
      final cell0 = await _samplePixel(painter, 68, 34, 17, 17);
      final cell1 = await _samplePixel(painter, 68, 34, 51, 17);

      final expected = (
        (material.color.r * 255).round(),
        (material.color.g * 255).round(),
        (material.color.b * 255).round(),
        255,
      );

      expect(
        cell0,
        equals(expected),
        reason: 'клетка кусочка id 1 должна быть покрашена partMaterial',
      );
      expect(
        cell1,
        equals(expected),
        reason:
            'клетка кусочка id 2 должна быть покрашена ТЕМ ЖЕ '
            'partMaterial, а не циклической палитрой по pieceId',
      );
      expect(
        cell0,
        equals(cell1),
        reason: 'единый материал детали — все уложенные клетки одного цвета',
      );
    });

    test('без partMaterial (null) — прежнее поведение: не падает, материалы '
        'могут отличаться по pieceId (обратная совместимость)', () async {
      final state = _twoPieceState();
      final painter = PackingPainter(
        state: state,
        cellSize: 34.0,
        shipMaterials: ShipMaterials.defaultMaterials,
      );

      expect(
        () => painter.paint(Canvas(ui.PictureRecorder()), const Size(68, 34)),
        returnsNormally,
      );
    });
  });

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
      final painter = PackingPainter(
        state: emptyState(),
        cellSize: 34.0,
        shipMaterials: ShipMaterials.defaultMaterials,
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
      final painter = PackingPainter(
        state: emptyState(),
        cellSize: 34.0,
        shipMaterials: ShipMaterials.defaultMaterials,
        dragPreview: const PackDragPreview(cells: [(x: 2, y: 2)], valid: false),
      );

      expect(
        () => painter.paint(Canvas(ui.PictureRecorder()), const Size(136, 136)),
        returnsNormally,
      );
    });

    test('shouldRepaint реагирует на появление/смену dragPreview', () {
      final state = emptyState();
      final withoutPreview = PackingPainter(
        state: state,
        cellSize: 34.0,
        shipMaterials: ShipMaterials.defaultMaterials,
      );
      final withValidPreview = PackingPainter(
        state: state,
        cellSize: 34.0,
        shipMaterials: ShipMaterials.defaultMaterials,
        dragPreview: const PackDragPreview(cells: [(x: 0, y: 0)], valid: true),
      );
      final withInvalidPreview = PackingPainter(
        state: state,
        cellSize: 34.0,
        shipMaterials: ShipMaterials.defaultMaterials,
        dragPreview: const PackDragPreview(cells: [(x: 0, y: 0)], valid: false),
      );
      final withSameValidPreview = PackingPainter(
        state: state,
        cellSize: 34.0,
        shipMaterials: ShipMaterials.defaultMaterials,
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
      final painter = PackingPainter(
        state: emptyState(),
        cellSize: 34.0,
        shipMaterials: ShipMaterials.defaultMaterials,
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

    test('shouldRepaint реагирует на смену partMaterial', () {
      final state = emptyState();
      final withoutMaterial = PackingPainter(
        state: state,
        cellSize: 34.0,
        shipMaterials: ShipMaterials.defaultMaterials,
      );
      final withMaterial = PackingPainter(
        state: state,
        cellSize: 34.0,
        shipMaterials: ShipMaterials.defaultMaterials,
        partMaterial: BlockMaterial.rust,
      );

      expect(withMaterial.shouldRepaint(withoutMaterial), isTrue);
      expect(withoutMaterial.shouldRepaint(withMaterial), isTrue);
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
      final state = _twoPieceState();
      final painter = PackingPainter(
        state: state,
        cellSize: 34.0,
        shipMaterials: ShipMaterials.defaultMaterials,
        excludePieceId: 1,
      );

      expect(
        () => painter.paint(Canvas(ui.PictureRecorder()), const Size(68, 34)),
        returnsNormally,
      );
    });
  });
}
