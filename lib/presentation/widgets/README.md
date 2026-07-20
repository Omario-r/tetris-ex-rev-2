# MODULE — presentation/widgets

> Паспорт модуля. 30–50 строк. Единственное, что другие агенты знают о модуле,
> не читая код. Обновляется в сессии, где менялся интерфейс/зависимости/инварианты.

## Назначение

Переиспользуемые виджеты/пейнтеры: отрисовка поля, панель управления (HUD) и
единый корабль мета-каркаса. Экраны (`screens`) собирают их вместе. Плюс (эпик
«Укладка», Стори 01 T3) пейнтер прототипа нового ядра укладки.

## Публичный интерфейс

- `BoardPainter(state, cellSize, theme, levelMaterial, shipMaterials, {scrapSkin, animValue})` —
  `CustomPainter` поля: фон `boardBg` (токен DESIGN.md, `#16191D`) + тонкие линии сетки `gridLine`
  (`#9097A2` @ 6%, по границам клеток, Стори 01 T4), ghost-мишень (незаполненные `S`),
  уложенные блоки, пульс dirty-halo, drop-ghost, падающая фигура. Уложенные блоки
  красятся материалом детали из `shipMaterials` если в мишени (`S`) — рендер `el-block`
  (`ProceduralBlockSkin`, `theme`), иначе `scrapSkin` — рендер `el-scrap` («сырой» вид,
  Стори 01 T3). Падающая фигура (normal mode) — канон `el-piece`
  (`BlockPaintUtils.paintElBlock`, нейтральный `graphite`, не красится материалом до
  лока, Стори 01 T5); drop-ghost (normal mode) — канон `el-drop`
  (`BlockPaintUtils.paintElDrop`, только контур, без заливки, Стори 01 T5). Взведённая
  (`PieceMode.explosive`) падающая фигура — канон `el-piece-armed`
  (`BlockPaintUtils.paintElPieceArmed`, `pulse` — тот же, что у `HaloHighlightOverlay`);
  её drop-ghost — канон `el-drop-armed` (`BlockPaintUtils.paintElDropArmed`), клетки —
  `armedGhostCells(fp, board)` (публичный, `@visibleForTesting`: отпечаток = клетки
  фигуры, сдвинутые так, что нижняя клетка встаёт в последний ряд поля; занятые клетки
  игнорируются — `CollisionDetector.canMoveDownExplosive` видит только дно, Стори 01 T6).
  `TntSkin` удалён (Стори 02 T1) — уже не использовался для падающей фигуры с Стори 01 T6.
  `levelMaterial` — legacy-параметр конструктора, оставлен для совместимости API,
  отрисовку не влияет (Стори 01 T5).
- `GameHud(controller, state, {animValue})` — `StatelessWidget`, фиксированная зона 150 высотой
  (Стори 02 T2, канон `docs/design/game-field.html` `.hud`/`.ctl`), 14px side padding, дети —
  `Stack`+`Positioned` 1:1 с мокапом: слева классическая крестовина (`Key('ctl_rot')` `⟳` сверху
  над парой `Key('ctl_left')`/`Key('ctl_right')` `◀`/`▶`), справа `Key('ctl_drop')` `⤓` softDrop
  сгруппирован с кнопкой взрыва. Кнопки движения — `_CtlButton` (58×58 круг, `matteBlack`
  `#1D2025`, рамка 1px `gunmetal` `#32363E`, глиф `hudIcon` `#B1B7BE` — иконки Material
  `refresh`/`chevron_left`/`chevron_right`/`south`; инсет-бевел приближён теми же двумя
  полупрозрачными полосами, что `_BoomButton`). Плюс одна объединённая кнопка взрыва
  `Key('boom_button')` — «канистра-заряд» (Стори 02 T1, канон `docs/design/game-field.html`
  `.boom`/`.can`/`.armedcore`/`.cnt`), заменившая прежние отдельные arm/detonate. State-машина
  (UI-триггер, своей логики нет): **Взведён** (`state.canDetonate`) → тап `controller.detonate`;
  иначе **Готов** (`state.charges > 0`) → тап `controller.armExplosive` (активность —
  `state.canArm`, `canArm` уже учитывает `charges > 0`); иначе **Пусто** — неактивна, opacity
  ~0.55. Иконка — `CanisterChargePainter` (`presentation/theme`); `animValue` (0..1,
  по умолчанию 0.0) прокидывается насквозь как `pulse` — тот же тикер, что `BoardPainter`,
  свой таймер `GameHud` не заводит. Бейдж `×N` — `Key('charges_indicator')` (`state.charges`),
  фон `hazardOrange`/текст тёмный (обычно), `gunmetal`/серый текст (Пусто).
- `ShipPainter({collectedCount, revealPartIndex, revealProgress, materials})` — единый корабль из
  `kShipPartCount` деталей: первые `collectedCount` установлены (залиты материалом из `materials`),
  остальные — контуром; `collectedCount` клампится 0..`kShipPartCount`. Каждая деталь — маска
  `ShipParts.parts[i].mask` (та же, что мишень уровня → совпадают). `materials` — `ShipMaterials`
  (по умолчанию `defaultMaterials`). Деталь `revealPartIndex` рисуется масштабом `revealProgress`
  (0..1) от центра — эффект появления (Стори 03); по умолчанию все статичны. Центрирование/масштаб —
  по `ShipParts.gridSize` (пейнтер не зависит от числа деталей).
- `kShipPartCount` (`ship.dart`) — **`final`, выводится из `ShipParts.parts.length`** (v1 = 7).
  Единый источник «N деталей ↔ N уровней». Не `const` — только рантайм. Форма деталей живёт в
  `game_engine/data/ship_parts`.
- `PackingPainter({state, cellSize, shipMaterials, excludePieceId})` — `CustomPainter` прототипа
  укладки (эпик «Укладка», Стори 01 T3): фон `boardBg` (`#16191D`) + ghost незаполненных клеток
  силуэта (`BlockTheme.ghostTarget`, канон `GhostTargetOverlay`/токен `ghostTarget`) + уложенные
  кусочки (`BlockPaintUtils.paintElBlock`, канон `el-block`). Материал кусочка — циклический
  выбор из `ShipMaterials.defaultMaterials` по `pieceId % kShipPartCount`
  (`PackingPainter.materialForPiece`, публичный статик) — различает соседние кусочки на
  существующей палитре, новых цветов не заводит. `excludePieceId` — пропустить отрисовку
  уложенного кусочка (экран рисует его отдельно как floating drag-фидбэк, чтобы не дублировать).
  `PackingPainter.paintPiece` (публичный статик) — единая точка правды «как выглядит кусочек»,
  переиспользуется экраном для лотка/drag-фидбэка. Только вид — не знает про drag-жесты
  (логика в `presentation/screens/packing_prototype_screen`).

## Зависит от

- `game_engine/game` — `GameState`, `GameController`.
- `game_engine/models` — `Board`, `FallingPiece`.
- `game_engine/data` — `ShipParts` (форма деталей = мишеней; `ship.dart`).
- `game_engine/packing` (`PackPiece`, `PackState`) — только `packing_painter` (эпик «Укладка»,
  Стори 01 T3); `board_painter`/`hud`/`ship_painter` эту зависимость не тянут.
- `presentation/theme` — `BlockMaterial`, `BlockTheme`, `BlockPaintUtils`,
  `ScrapBlockSkin`, `ShipMaterials`, `CanisterChargePainter`/`ChargeIconState`
  (Стори 02 T1, кнопка взрыва), оверлеи (`GhostTargetOverlay`,
  `HaloHighlightOverlay`). `TntSkin`/`CreeperFacePainter` удалены (Стори 02 T1,
  Minecraft-остатки) — не зависимость `widgets`.

## От него зависят

- `presentation/screens` — `game_screen` (board_painter + hud), `ship_screen` (ship_painter),
  `packing_prototype_screen` (packing_painter, Стори 01 T3).

## Инварианты

- Только вид: пейнтеры не содержат игровой логики; ввод игрока идёт лишь через команды
  `GameController` (HUD зовёт `controller.*`).
- `shouldRepaint` завязан на `state`/анимацию; мутабельное состояние в пейнтере не хранить.
- `ShipPainter.collectedCount` всегда клампится 0..`kShipPartCount`. Форма деталей — из
  `ShipParts` (data), та же, что мишень уровня → совпадают. `revealProgress` масштабирует
  лишь деталь `revealPartIndex`.

## Как проверить

`flutter test test/presentation/board_painter_test.dart test/presentation/hud_test.dart
test/presentation/ship_screen_test.dart test/game_engine/data/ship_parts_test.dart
test/presentation/packing_prototype_screen_test.dart`.
