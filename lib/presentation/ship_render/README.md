# MODULE — presentation/ship_render

> Паспорт модуля. 30–50 строк. Единственное, что другие агенты знают о модуле,
> не читая код. Обновляется в сессии, где менялся интерфейс/зависимости/инварианты.

## Назначение

Рисунок корабля в Dart (процедурно, без PNG): сцена в px рисунка системы
`docs/design/ship-render.js`, два слоя (D-011) — корпус и предметы, контур борта,
формы предметов; экран корабля-композит и сэмплинг клетки детали. Экраны/поле
берут рисунок только через интерфейс `ShipArt`.

## Публичный интерфейс

- `abstract class ShipArt` (`ship_art.dart`): `sceneSize` (W×H, px рисунка);
  `toScene(x, y)` — клетка рисунка → px; `hullPicture` — слой 0, корпус без
  предметов; `objectsPicture` — слой 1, предметы; `outline` — контур борта +
  гондолы; `objectShape(partId)` — форма предмета (`'sensor'`, `'rcs_fl'`,
  `'rcs_fr'`), px рисунка, иначе `ArgumentError`; `backdrop` — подложка клетки поля
  там, где рисунка нет (фона в слоях нет; у «Ронина» `#070A11` — середина фона эталона).
- `RoninArt implements ShipArt` (`ronin_art.dart`) — порт `ship-render.js` 1:1 в
  объёме «Ронина-1». `RoninArt.shared` — общий экземпляр на запуск (экран корабля и
  поле укладки). Статики: `cellPx` (`C=24`), `ox/oy`, `width/height`, `rows`,
  `px()/py()`, `cx`, `span`, `plates`. `mulberry32(seed)` — рандом эталона.
  `ShipObject`, `roninObjects` — параметры форм предметов (в `RoninPartDef` их нет).
- `ShipCompositePainter({art, collectedCount, revealPartIndex?, revealProgress=1})`
  (`ship_composite_painter.dart`) — экран корабля по `ronin-ship.html`: кадр
  `frameOf(art)` = `x 44..W−44, y 26..H−14` вписан в `size` по центру (поля сцены
  обрезаны клипом кадра); контур `outline` штрихом `shipOutlineColor` 1 px экрана;
  собранные (`order ≤ collectedCount`, клампится 0..15) — плиты: один клип
  (объединение клеток) + `hullPicture`, затем предметы: один клип (формы) +
  `objectsPicture`. Деталь `revealPartIndex` при `0 < revealProgress < 1` —
  отдельный клип/replay со scale от центра bbox детали; при 1 — в общем клипе.
- `paintPartCell(canvas, art, part, c, r, dst)` (`ship_cell_sampler.dart`) — одна
  клетка маски детали → `dst` (клип `dst`, подложка `backdrop`, масштаб + сдвиг);
  плита — `hullPicture`, предмет — `hullPicture` + `objectsPicture`.
  `shipCellRect(art, part, c, r)` — та же клетка в px рисунка (источник сэмплинга).
- `paintPartCells(canvas, art, part, cells, {origin, cellSize})` — точка входа поля
  укладки (Ронин-1/03): клетки маски `cells` → `origin + (c, r) * cellSize`; один клип
  (объединение клеток) → `backdrop` → один replay на слой. Растр клетки = `paintPartCell`
  в том же прямоугольнике (тест). Пустой `cells` — ничего не рисует.

## Зависит от

- `dart:ui` / `package:flutter/painting.dart` — `Picture`, `Path`, `TextPainter`.
- `game_engine/data` — `RoninParts`/`RoninPartDef` (`cellOnShip`, `layer`, `order`).

## От него зависят

- `presentation/screens` — `ship_screen` (`ShipCompositePainter`, `RoninArt.shared`),
  `game_screen` (`RoninArt.shared` → `PackingPainter`).
- `presentation/widgets` — `PackingPainter` (`ShipArt`, `paintPartCells`; Ронин-1/03).

## Инварианты

- Раскладка плит детерминирована и совпадает с эталоном JS (39 плит, тест держит
  `x, y, w, h, kind, i, jl, rv`). Порядок вызовов `rnd()` в нарезке не менять.
- Картинки записываются один раз на экземпляр (`late final`); экраны берут один
  общий `RoninArt.shared` на запуск. Собранное и уложенное на поле = один клип-путь
  на слой, не по клетке.
- Клетка поля и клетка корабля сэмплируют одно и то же: под рисунком — `backdrop`
  в обеих точках входа (`paintPartCell`/`paintPartCells`), иначе вид разъедется.
- `objectsPicture` — только под клипом `objectShape(id)` или поверх `hullPicture`
  (в конце слоя повторён штрих контура корпуса — так он совпадает с полным рисунком).
- Не переносится (Ронин-2): фон, «РОНИН», люк, гондолы-объёмы, радиатор, корма.
  Текст — системный sans-serif bold, сжат до ширины `Arial Narrow`; тень σ = blur/4.

## Как проверить

`flutter test test/presentation/ship_render/` — эталоны, растр слоёв, контур,
формы предметов, композит при 0/3/15, сэмплинг клетки и клеток поля.
