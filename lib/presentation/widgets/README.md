# MODULE — presentation/widgets

> Паспорт модуля. 30–50 строк. Единственное, что другие агенты знают о модуле,
> не читая код. Обновляется в сессии, где менялся интерфейс/зависимости/инварианты.

## Назначение

Переиспользуемые виджеты/пейнтеры: отрисовка укладки нового ядра (силуэт,
уложенные кусочки, снап-превью) и единый корабль мета-каркаса. Экраны
(`screens`) собирают их вместе.

`BoardPainter` (отрисовка старого тетрис-поля) и `GameHud` (панель управления
старого ядра: крестовина, softDrop, кнопка взрыва) удалены целиком (эпик
«Укладка», Стори 02 T3) — старое ядро (`game`/`rules`) больше не рисуется,
`GameScreen` с Стори 02 T2 работает на `PackingPainter`.

## Публичный интерфейс

- `ShipPainter({collectedCount, revealPartIndex, revealProgress})` — единый корабль из
  `kShipPartCount` деталей: первые `collectedCount` установлены, остальные — контуром;
  `collectedCount` клампится 0..`kShipPartCount`. Каждая деталь — маска `RoninParts.parts[i].mask`
  (та же, что мишень уровня → совпадают), якорь — `RoninParts.parts[i].originCol`/`originRow`.
  Деталь `revealPartIndex` рисуется масштабом `revealProgress` (0..1) от центра — эффект появления
  (Стори 03); по умолчанию все статичны. Центрирование/масштаб — по сетке `RoninGrid.cols ×
  RoninGrid.rows` (44×108, не квадратная — вписывается по меньшей стороне без растяжения
  пропорций; пейнтер не зависит от числа деталей). **Отрисовка временная (Ронин-1/01 T3):**
  плоская заливка одним материалом `BlockMaterial.graphite` на ВСЕ собранные детали (без
  `ShipMaterials` — параметр `materials` убран вместе с зависимостью от `theme`; решение
  Постановщика по эскалации T3, 2026-07-29: 7-элементная карта `ShipMaterials.defaultMaterials`
  не покрывает 13 деталей «Ронина», расширять её под заведомо неканоничный временный пейнтер не
  стали). Заменяется композитом из рисунка «Ронина» в Стори 02 эпика Ронин-1.
- `kShipPartCount` (`ship.dart`) — **`final`, выводится из `RoninParts.parts.length`** (= 13,
  было `ShipParts.parts.length` = 7 до Ронин-1/01 T3). Единый источник «N деталей ↔ N уровней».
  Не `const` — только рантайм. Форма деталей живёт в `game_engine/data/ronin_parts`.
- `PackingPainter({state, cellSize, shipMaterials, excludePieceId, partMaterial, dragPreview})` —
  `CustomPainter` укладки (эпик «Укладка», Стори 01 T3, канон утверждён эпик «Укладка» Стори 02
  T1): фон `boardBg` (`#16191D`) + ghost незаполненных клеток силуэта (`BlockTheme.ghostTarget`,
  канон `GhostTargetOverlay`/токен `ghostTarget`) + уложенные кусочки
  (`BlockPaintUtils.paintElBlock`, канон `el-block`) + живое снап-превью драга
  (`el-drop-ok`/`el-drop-bad`, эпик «Укладка» Стори 02 T1). Материал уложенных клеток: если
  `partMaterial` (`BlockMaterial?`) задан — ВСЕ уложенные клетки красятся ИМ (единый материал =
  собранная деталь, канон `el-cell-filled`, эпик «Укладка» Стори 02 T1); если `null` — прежнее
  поведение прототипа, циклический выбор из `ShipMaterials.defaultMaterials` по
  `pieceId % kShipPartCount` (`PackingPainter.materialForPiece`, публичный статик). `excludePieceId` —
  пропустить отрисовку уложенного кусочка (экран рисует его отдельно как floating drag-фидбэк,
  чтобы не дублировать). `dragPreview` (`PackDragPreview?`, эпик «Укладка» Стори 02 T1) —
  снап-превью текущего драга: если задан, поверх ghost/уложенных клеток рисуется по каждой клетке
  `dragPreview.cells` (АБСОЛЮТНЫЕ клетки силуэта; клетки вне `[0..width)×[0..height)` молча
  пропускаются) рамка 2px + заливка — `dropOk`/`dropOkFill` при `valid:true`, иначе
  `dropBad`/`dropBadFill`; `null` — превью не рисуется. Новые цвет-токены `docs/DESIGN.md`,
  размещены на классе как `static const Color` рядом с `boardBg`: `dropOk`/`dropOkFill` (снап
  «ляжет»), `dropBad`/`dropBadFill` (снап «нельзя»), `trayBg` (фон лотка), `doneGlow`
  (пульс-ободок собранной детали, канон `board.complete`; `trayBg`/`doneGlow` пока только
  токены-константы, потребитель — `presentation/screens`, эпик «Укладка» Стори 02 T2).
  `PackingPainter.paintPiece` (публичный статик) — единая точка правды «как выглядит кусочек»,
  переиспользуется экраном для лотка/drag-фидбэка. Только вид — не знает про drag-жесты (логика в
  `presentation/screens`). `PackingPainter.occupiedCellsExcluding(state, excludePieceId)`
  (публичный статик, возврат Стори 04 T5) — клетки всех размещённых кусочков `state`, кроме
  `excludePieceId` (`null` или не встречается в `placements` → эквивалент `state.occupiedCells`).
  Используется вместо `state.occupiedCells` в ghost-цикле `paint`: кусок, взятый в руку
  (`excludePieceId`), немедленно освобождает свои клетки для ghost мишени — канон мокапа
  (`liftPlaced`), при том что в движке (`PackState`/`PackController`) кусок остаётся в
  `placements` до дропа (осознанное отличие реализации, см. модуль `game_engine/packing`).
- `PackDragPreview({cells, valid})` (`packing_painter.dart`, эпик «Укладка» Стори 02 T1) —
  маленький immutable DTO снап-превью: `cells` (`List<({int x, int y})>`, тот же тип клетки, что у
  `PackState.occupiedCells`) — абсолютные клетки силуэта под текущим якорем драга; `valid` —
  можно ли класть. Равенство по значению (`==`/`hashCode`) — на нём держится
  `PackingPainter.shouldRepaint`.

## Зависит от

- `game_engine/data` — `RoninParts` (форма деталей = мишеней; `ship.dart`, Ронин-1/01 T3, было
  `ShipParts`).
- `game_engine/packing` (`PackPiece`, `PackState`) — `packing_painter`.
- `presentation/theme` — `BlockMaterial`, `BlockTheme`, `BlockPaintUtils`, оверлей
  `GhostTargetOverlay`; `ShipMaterials` — только `packing_painter` (`shipMaterials`/циклический
  fallback), `ship.dart` от неё больше не зависит (Ронин-1/01 T3). `game_engine/game`,
  `game_engine/models`, `ScrapBlockSkin`, `CanisterChargePainter`/`ChargeIconState`,
  `HaloHighlightOverlay` больше не зависимости `widgets` — их тянул только
  `BoardPainter`/`GameHud`, удалённые эпик «Укладка» Стори 02 T3.

## От него зависят

- `presentation/screens` — `game_screen` (`PackingPainter`, эпик «Укладка» Стори 02 T2),
  `ship_screen` (`ship_painter`).

## Инварианты

- Только вид: пейнтеры не содержат игровой логики.
- `shouldRepaint` завязан на `state`/анимацию; мутабельное состояние в пейнтере не хранить.
- `ShipPainter.collectedCount` всегда клампится 0..`kShipPartCount`. Форма деталей — из
  `RoninParts` (data), та же, что мишень уровня → совпадают. `revealProgress` масштабирует
  лишь деталь `revealPartIndex`. Материал собранных деталей — единый временный
  `BlockMaterial.graphite` (не по индексу/карте — см. «Публичный интерфейс»).

## Как проверить

`flutter test test/presentation/ship_screen_test.dart test/game_engine/data/ronin_parts_test.dart
test/presentation/packing_painter_test.dart`.
