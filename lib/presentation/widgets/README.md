# MODULE — presentation/widgets

> Паспорт модуля. 30–50 строк. Единственное, что другие агенты знают о модуле,
> не читая код. Обновляется в сессии, где менялся интерфейс/зависимости/инварианты.

## Назначение

Переиспользуемые виджеты/пейнтеры: отрисовка укладки нового ядра (силуэт,
уложенные кусочки, снап-превью). Экраны (`screens`) собирают их вместе. Корабль рисует
`presentation/ship_render` (`ShipCompositePainter`); прежний плоский пейнтер корабля
(`ship.dart`) выпилен в Ронин-1/06 T1 — число деталей = `RoninParts.parts.length`.

`BoardPainter` (отрисовка старого тетрис-поля) и `GameHud` (панель управления
старого ядра: крестовина, softDrop, кнопка взрыва) удалены целиком (эпик
«Укладка», Стори 02 T3) — старое ядро (`game`/`rules`) больше не рисуется,
`GameScreen` с Стори 02 T2 работает на `PackingPainter`.

## Публичный интерфейс

- `PackingPainter({state, cellSize, art, part, targetX, targetY, excludePieceId, dragPreview})` —
  `CustomPainter` укладки (эпик «Укладка», Стори 01 T3, канон утверждён эпик «Укладка» Стори 02
  T1). Порядок: фон `boardBg` (`#16191D`) → ghost незаполненных клеток силуэта
  (`BlockTheme.ghostTarget`, канон `GhostTargetOverlay`/токен `ghostTarget`) → **уложенные клетки
  — куски рисунка корабля** (канон `el-cell-filled`, Ронин-1/03): все клетки
  `occupiedCellsExcluding` одним вызовом `ship_render/paintPartCells` (`art` — `ShipArt`, `part` —
  `RoninPartDef` уровня; клетка поля (x, y) ↔ клетка маски (x − `targetX`, y − `targetY`),
  `origin = (targetX, targetY) * cellSize`; `targetX/Y` = `PreparedLevel.targetX/Y`) → `seam`
  (`PackingPainter.seam`, токен `hsla(220 14% 4% / 55%)`) — 1 px по прямоугольнику каждой
  уложенной клетки со сдвигом +0.5 (как `strokeRect` мокапа), все — одним путём (общая граница
  соседей — одна линия) → снап-превью. Плоского материала на поле нет. `excludePieceId` —
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
  `PackingPainter.paintPiece` (публичный статик) — единая точка правды «как выглядит сырой
  кусочек» (`el-block`), экран рисует им лоток/drag-фидбэк графитом; поле им не рисуется. Только вид — не знает про drag-жесты (логика в
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

- `game_engine/data` — `RoninPartDef` — деталь уровня в `PackingPainter` (Ронин-1/03).
- `game_engine/packing` (`PackPiece`, `PackState`) — `packing_painter`.
- `presentation/ship_render` — `ShipArt`, `paintPartCells` (`packing_painter`, Ронин-1/03).
- `presentation/theme` — `BlockMaterial`, `BlockTheme`, `BlockPaintUtils`, оверлей
  `GhostTargetOverlay`. `game_engine/game`,
  `game_engine/models`, `ScrapBlockSkin`, `CanisterChargePainter`/`ChargeIconState`,
  `HaloHighlightOverlay` больше не зависимости `widgets` — их тянул только
  `BoardPainter`/`GameHud`, удалённые эпик «Укладка» Стори 02 T3.

## От него зависят

- `presentation/screens` — `game_screen` (`PackingPainter`, эпик «Укладка» Стори 02 T2).
  `ship_screen` и `cheat_menu` от `widgets` не зависят.

## Инварианты

- Только вид: пейнтеры не содержат игровой логики.
- `shouldRepaint` завязан на `state`/анимацию; мутабельное состояние в пейнтере не хранить.
  `PackingPainter.shouldRepaint` — по `state`, `cellSize`, `art`, `part`, `targetX/Y`,
  `excludePieceId`, `dragPreview`.
- Поле: уложенное — рисунок корабля + `seam`; лоток и кусок в руке — сырой графит
  (`paintPiece`). Контраст «сырьё → корабль» — канон, не смешивать.

## Как проверить

`flutter test test/game_engine/data/ronin_parts_test.dart test/presentation/packing_painter_test.dart`
(тесты корабля — `test/presentation/ship_render/`).
