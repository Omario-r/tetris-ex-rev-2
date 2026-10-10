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
  предметов; `objectsPicture` — слой 1, предметы; `fieldBuildPicture` — корпус
  для клетки поля в сборке (без кромок деталей и контура, без щелей-огней);
  `fieldDonePicture` — корпус для собранной детали на поле (без кромок и
  контура, со щелями-огнями; оба — лениво, с кешем); `outline` — контур борта +
  гондолы; `objectShape(partId)` — форма предмета (`'sensor'`, `'rcs_fl'`,
  `'rcs_fr'`, `'visor_l'`/`'visor_r'`, `'hatch_l'`/`'hatch_r'` — формы v3, D-016),
  px рисунка, иначе `ArgumentError`; `backdrop` — подложка клетки поля
  там, где рисунка нет (фона в слоях нет; у «Ронина» `#070A11` — середина фона эталона);
  `fieldLayer(ShipFieldLayer)` — слой рисунка для клетки поля в сборке (D-017, лениво, по
  записи на слой, с кешем). `enum ShipFieldLayer` (`ship_art.dart`): `hullBase` /
  `hullAccents` / `hullLights` и `objectsBase` / `objectsAccents` / `objectsLights` —
  основа (без кромок, контура, света, краски, цветных элементов) и она же + цветные
  элементы / + свет; `paint` — только краска корпуса на прозрачном фоне. Слои `objects*` —
  только под клипом формы предмета.
- `RoninArt implements ShipArt` (`ronin_art.dart`) — порт `ship-render.js` v3
  (D-016) 1:1 в объёме «Ронина-1». `RoninArt.shared` — общий экземпляр на запуск
  (экран корабля и поле укладки). Статики: `cellPx` (`C=24`), `ox/oy`,
  `width/height`, `rows`, `ronin1Rows` (= 8), `px()/py()`, `cx`, `span`, `plates`.
  `mulberry32(seed)` — рандом эталона. `ShipObject`, `roninObjects` — параметры форм
  предметов (в `RoninPartDef` их нет; `flip` = сопло `rcs` / `half` визора / `side`
  люка). Корпус — одна функция `_drawHull({edges, lights, paint, accents})` (=
  `render({…})`, D-017): строки 0..7 — плиты = плиты `RoninParts` (материал по секции,
  `jl` по индексу плиты, кромки по границе детали при `edges`), строки 8+ —
  генератор `plates`; сетка/потёки только в 8+; швы поясов `[8, 13, 18, 21, 25]`;
  щели-огни при `lights`, контур при `edges`, краска корпуса (`_drawPaint`: шеврон,
  «V V - 7 7», «7 7»; «РОНИН» не портирован) при `paint`; цветных элементов на корпусе
  нет (`accents` — на будущее). Слой 1 — `_drawObjects({lights, paint, accents})`:
  датчик, визор, люки, RCS; при `lights` — строб и огонёк датчика, стёкла визора, при
  `accents` — оранжевая полоса люков. По умолчанию все флаги `true` — `hullPicture`,
  `objectsPicture`, `fieldDonePicture` прежние.
- `ShipCompositePainter({art, collectedCount, revealPartIndex?, revealProgress=1})`
  (`ship_composite_painter.dart`) — экран корабля по `ronin-ship.html`: кадр
  `frameOf(art)` = `x 44..W−44, y 26..H−14` вписан в `size` по центру (поля сцены
  обрезаны клипом кадра); контур `outline` штрихом `shipOutlineColor` 1 px экрана;
  собранные (`order ≤ collectedCount`, клампится 0..N) — плиты: один клип
  (объединение клеток) + `hullPicture`, затем предметы: один клип (формы) +
  `objectsPicture`. Деталь `revealPartIndex` при `0 < revealProgress < 1` —
  отдельный клип/replay со scale от центра bbox детали; при 1 — в общем клипе.
- `paintPartCells(canvas, art, part, cells, {origin, cellSize, assembled = false,
  colors})` (`ship_cell_sampler.dart`) — точка входа поля укладки (D-016, порт
  `drawCell`/`tileRelief`/`rivets`/`crispEdge` из `ronin-draw.js`): клетки маски
  `cells` → `origin + (c, r) * cellSize`, рисунок в масштабе детали. **Сборка**
  (`assembled: false`): плитки — один клип из `RRect` клеток (отступ `s = cellSize/34`,
  радиус `3s`); плита — один replay `fieldBuildPicture`, предмет — плоский
  `colors.colorAt` клетки (нет `colors` — `backdrop` + `objectsPicture`); рельеф ×1,4
  (полосы `3s`: верх белый 12,6 %, низ чёрный 49 %, лево белый 5,6 %, право чёрный
  25,2 %), после клипа 4 заклёпки `r = 1,5s` в `4s` от углов — чёрные 85 % при
  `colors.isDark`, иначе 45 %. **Собрано** (`assembled: true`): один клип
  (объединение клеток), один replay — плита `fieldDonePicture`, предмет
  `objectsPicture` (фон не заливается); у плиты — чёткая кромка по сторонам без соседа
  в маске, в px поля (верх белая 2 px 14 % на 1,5 + тёмная 1 px 55 % по краю; лево
  белая 7 %, низ тёмная 35 %, право тёмная 22 %, каждая + 1 px 55 %). Пустой `cells` —
  ничего не рисует.
- `paintPartCell(canvas, art, part, c, r, dst, {assembled, colors})` — одна клетка в
  квадрат `dst`: делегирует `paintPartCells` с одной клеткой (вид совпадает в обеих
  фазах). `shipCellRect(art, part, c, r)` — клетка в px рисунка (источник).
- `Future<PartCellColors> partCellColors(art, part)` — преобладающий цвет каждой клетки
  маски (`domColor`): корзины 4 бита на канал, пиксели альфы < 128 не считаются, итог —
  средний цвет победившей корзины (нет пикселей — `#171A1E` эталона); источник плиты —
  `fieldBuildPicture`, предмета — `objectsPicture`; деталь растрируется целиком один раз
  (8 px на клетку, `toImage` + `toByteData`, premultiplied → straight). Кеш результата
  по `part.id` на запуск (второй вызов — тот же объект). `PartCellColors({width,
  height, colors})` — неизменяемый: `colorAt(c, r)`, `isDark(c, r)` = яркость
  `0.2126R + 0.7152G + 0.0722B < 0.2` (0..1).

## Зависит от

- `dart:ui` / `package:flutter/painting.dart` — `Picture`, `Path`, `TextPainter`.
- `game_engine/data` — `RoninParts`/`RoninPartDef` (`cellOnShip`, `layer`, `order`).

## От него зависят

- `presentation/screens` — `ship_screen` (`ShipCompositePainter`, `RoninArt.shared`),
  `game_screen` (`RoninArt.shared` → `PackingPainter`, `partCellColors` — Ронин-1/10).
- `presentation/widgets` — `PackingPainter` (`ShipArt`, `paintPartCells`,
  `PartCellColors`; Ронин-1/03, 1/10).

## Инварианты

- Раскладка плит детерминирована и совпадает с эталоном JS (39 плит, тест держит
  `x, y, w, h, kind, i, jl, rv`). Порядок вызовов `rnd()` в нарезке не менять;
  плиты генератора с `y < 8` генерируются, но не рисуются, потёки `wr` расходуют
  ГСЧ и при пропуске (раскладка строк 8+ не меняется).
- Плиты «Ронина-1» в рисунке = плиты-детали `RoninParts` (порядок списка → `jl`);
  заливка плиты — один путь из клеток (+.3 px): при replay в масштабе внутри плиты
  нет щелей сглаживания.
- Картинки записываются один раз на экземпляр (`late final`); экраны берут один
  общий `RoninArt.shared` на запуск. Собранное и уложенное на поле = один клип-путь
  на слой, не по клетке.
- Клетка поля: плита — без подложки (её клетки рисунок заливает целиком), предмет в
  сборке без `colors` — на `backdrop`; собранный предмет — без подложки (виден фон
  поля, как в эталоне). `paintPartCell` = `paintPartCells` одной клетки (делегирование).
- `partCellColors` кеширует только готовый результат (не незавершённый `Future`):
  в widget-тестах `toImage` вне `runAsync` не завершается, такой `Future` в кеше
  подвесил бы последующих ждущих.
- `objectsPicture` — только под клипом `objectShape(id)` или поверх `hullPicture`;
  предметы лежат поверх контура корпуса (повтора контура в слое 1 нет, v3).
- Не переносится (Ронин-2): фон, «РОНИН», люк, гондолы-объёмы (и их огни), радиатор, корма.
  Текст — системный sans-serif bold, сжат до ширины `Arial Narrow`; тень σ = blur/4.

## Как проверить

`flutter test test/presentation/ship_render/` — эталоны, растр слоёв (плиты по
деталям, визор/люк вне корпуса, щель-огонь и кромки в `field*Picture`), контур,
формы предметов, слои поля D-017 (`fieldLayer`: щель, шеврон, полоса люка, стекло
визора, огонёк датчика по слоям), композит при 0/3/N, клетка поля (плитка/собрано, кромка),
`partCellColors` (шеврон, стекло/рама визора, `isDark`, кеш).
