# MODULE — game_engine/data

> Паспорт модуля. 30–50 строк. Единственное, что другие агенты знают о модуле,
> не читая код. Обновляется в сессии, где менялся интерфейс/зависимости/инварианты.

## Назначение

Контент: разметка «Ронина» (`RoninParts` — 13 деталей на сетке 44×108, канон Дизайнера) и
карта уровней (`LevelMap`, поле укладки 10×14, по одному уровню на деталь). Данные, не логика.
`ShipParts` (7 дев-деталей v1) — **осиротевший**: вытеснен `RoninParts` (Ронин-1/01 T2), а с T3
`LevelMap` тоже строится из `RoninParts` — `ShipParts` больше никем в `lib/` не читается (кроме
самого `ship_parts.dart`). Физический выпил файла и его теста — Стори 06 (решение PO 2026-07-29).

## Публичный интерфейс

- `RoninGrid` — сетка корабля: `cols=44`, `rows=108`, `renderCell=4`, `originCol=2` (клетка
  рендера = 4×4 клетки сетки, сетка сдвинута относительно рендера на `originCol`).
- `RoninPartDef` — деталь: `id`, `order` (1..13, порядок сборки), `module`
  (`'prow'`|`'bridge'`|`'fwd'`), `title` (для топбара), `originCol`/`originRow` (левый-верх bbox
  маски в координатах `RoninGrid`), `cells` (бюджет уровня), `seed` (пока `null` везде —
  подбирается в Стори 04), `mask` (`TargetMask`, bbox-маска детали).
- `RoninParts.parts` — `static const List<RoninPartDef>`, 13 деталей «Ронина-1», отсортированы
  по `order` (индекс == `order - 1`). Источник — `docs/design/ronin-parts.js` (канон Дизайнера,
  утв. PO 2026-07-29), перенесён 1:1 без правок формы. `partAtOrder(order)` / `byId(id)`
  (неизвестный `id` → `ArgumentError`).
- `ShipParts.parts` — 7 дев-деталей, `gridSize=12`. **Осиротевший**: работающий код на него не
  ссылается (кроме `ship_parts.dart`/его теста), держится зелёным до выпила в Стори 06.
- `LevelMap` (Ронин-1/01 T3): `fieldWidth=10`/`fieldHeight=14` — поле укладки фиксировано для
  ВСЕХ уровней (не зависит от размера детали). `levelAt(levelIndex)` (0..`RoninParts.parts.length-1`)
  → `LevelTemplate`, деталь `i` ↔ `RoninParts.parts[i]` (order `i+1`): `targetMask` —
  `part.mask.padTo(width: fieldWidth, height: fieldHeight, dx: targetX, dy: targetY)` (маска уже
  **размера поля**, деталь отцентрована внутри неё по `targetX`/`targetY` — обеим осям; эти же
  координаты понадобятся Стори 03 для сэмплинга рисунка). Прежний floor-anchor снят вместе с
  гравитацией (укладка не роняет фигуры).

## Зависит от

- `game_engine/models` — `LevelTemplate`, `TargetMask` (`padTo`).

## От него зависят

- `presentation/screens` — `game_screen` (`levelAt`).
- `presentation/widgets` — `ship.dart`/`ShipPainter` (форма деталей — `RoninParts`, тот же
  источник, что и мишени уровней).
- `application` — `ProgressService._max` (`RoninParts.parts.length - 1`).

## Инварианты

- `RoninParts.parts`: ровно 13, `id` уникальны, `order` — перестановка 1..13; каждая
  `mask.isWellFormed`, bbox ≤ 10×14; `cells` == число `#` в маске, 60 ≤ `cells` ≤ 80; маска
  связна по 4-соседству, origin — точный bbox; деталь целиком внутри `RoninGrid`; детали
  попарно не пересекаются; объединение всех 13 — 960 клеток, связно (`ronin_parts_test.dart`).
  Проходимость (нарезка + эталонная укладка, сиды 0/1/2, все 13) — `ronin_packing_test.dart`.
- Уровни = детали «Ронина»: `levelAt(i).targetMask` — поле 10×14 с деталью `RoninParts.parts[i]`,
  вложенной через `padTo` со сдвигом `targetX`/`targetY`; число уровней = `RoninParts.parts.length`
  (= `kShipPartCount`). Мишень **центрирована**, НЕ floor-anchored (`level_map_test.dart`).
- `LevelMap` — `static final`, НЕ `const`. `ShipParts`/`RoninParts` — `const`.
- Дев-контент масок — прототипный (не относится к `RoninParts`: канон Дизайнера, 1:1 перенос).
  Проходимость дев-деталей: структурно + содержательно (`content_packing_test.dart`, оставлен
  зелёным на осиротевших данных до Стори 06).

## Как проверить

`flutter test test/game_engine/data/`.
