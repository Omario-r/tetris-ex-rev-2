# MODULE — presentation/widgets

> Паспорт модуля. 30–50 строк. Единственное, что другие агенты знают о модуле,
> не читая код. Обновляется в сессии, где менялся интерфейс/зависимости/инварианты.

## Назначение

Переиспользуемые виджеты/пейнтеры: отрисовка поля, панель управления (HUD) и
единый корабль мета-каркаса. Экраны (`screens`) собирают их вместе.

## Публичный интерфейс

- `BoardPainter(state, cellSize, theme, levelMaterial, shipMaterials, {scrapSkin, tntSkin, animValue})` — `CustomPainter`
  поля: фон `boardBg` (токен DESIGN.md, `#16191D`) + тонкие линии сетки `gridLine`
  (`#9097A2` @ 6%, по границам клеток, Стори 01 T4), ghost-мишень (незаполненные `S`),
  уложенные блоки, пульс dirty-halo, drop-ghost (normal), падающая фигура. Уложенные
  блоки красятся материалом детали из `shipMaterials` если в мишени (`S`), иначе
  `scrapSkin` («сырой» вид, Стори 01 T3).
- `GameHud(controller, state)` — `StatelessWidget`: кнопки движения/поворота/softDrop +
  arm (крипер) + detonate; активность через `state.canArm/canDetonate`. Под кнопкой arm —
  числовой индикатор `state.charges` (`Key('charges_indicator')`): белый при `charges > 0`,
  `Colors.redAccent` на 0 (эпик «Взрыв», Стори 01). `canArm` уже учитывает `charges > 0` —
  кнопка arm сама димится на 0 (см. `game_engine/game` README).
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

## Зависит от

- `game_engine/game` — `GameState`, `GameController`.
- `game_engine/models` — `Board`, `FallingPiece`.
- `game_engine/data` — `ShipParts` (форма деталей = мишеней; `ship.dart`).
- `presentation/theme` — `BlockMaterial`, `BlockTheme`, `TntSkin`, `ScrapBlockSkin`,
  `ShipMaterials`, оверлеи.

## От него зависят

- `presentation/screens` — `game_screen` (board_painter + hud), `ship_screen` (ship_painter).

## Инварианты

- Только вид: пейнтеры не содержат игровой логики; ввод игрока идёт лишь через команды
  `GameController` (HUD зовёт `controller.*`).
- `shouldRepaint` завязан на `state`/анимацию; мутабельное состояние в пейнтере не хранить.
- `ShipPainter.collectedCount` всегда клампится 0..`kShipPartCount`. Форма деталей — из
  `ShipParts` (data), та же, что мишень уровня → совпадают. `revealProgress` масштабирует
  лишь деталь `revealPartIndex`.

## Как проверить

`flutter test test/presentation/board_painter_test.dart test/presentation/hud_test.dart
test/presentation/ship_screen_test.dart test/game_engine/data/ship_parts_test.dart`.
