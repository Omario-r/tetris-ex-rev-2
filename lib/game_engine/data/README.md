# MODULE — game_engine/data

> Паспорт модуля. 30–50 строк. Единственное, что другие агенты знают о модуле,
> не читая код. Обновляется в сессии, где менялся интерфейс/зависимости/инварианты.

## Назначение

Контент: разметка «Ронина» (`RoninParts` — 13 деталей на сетке 44×108, канон Дизайнера) и
карта уровней (`LevelMap`), по одному уровню на деталь. Данные, не логика. `ShipParts` (7
дев-деталей v1) — **осиротевший**: вытеснен `RoninParts` (Ронин-1/01 T2), физический выпил
файла и его теста — Стори 06 (решение PO 2026-07-29). До T3 `LevelMap` ещё строит уровни из
`ShipParts` — переезд на `RoninParts` (поле 10×14, центрирование) в T3.

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
- `LevelMap.levelAt(levelIndex)` — `LevelTemplate`; на T2 источник ещё `ShipParts` (не тронут
  этой задачей).

## Зависит от

- `game_engine/models` — `LevelTemplate`, `TargetMask`.

## От него зависят

- `presentation/screens` — `game_screen` (`levelAt`).
- `presentation/widgets` — `ship.dart`/`ShipPainter` (пока форма деталей — `ShipParts`; переезд
  на `RoninParts` — T3).

## Инварианты

- `RoninParts.parts`: ровно 13, `id` уникальны, `order` — перестановка 1..13; каждая
  `mask.isWellFormed`, bbox ≤ 10×14; `cells` == число `#` в маске, 60 ≤ `cells` ≤ 80; маска
  связна по 4-соседству, origin — точный bbox; деталь целиком внутри `RoninGrid`; детали
  попарно не пересекаются; объединение всех 13 — 960 клеток, связно (`ronin_parts_test.dart`).
  Проходимость (нарезка + эталонная укладка, сиды 0/1/2, все 13) — `ronin_packing_test.dart`.
- Уровни (пока) = дев-детали: `levelAt(i).targetMask == ShipParts.parts[i].mask`; число
  уровней = `ShipParts.parts.length` (= `kShipPartCount`) — сменится на `RoninParts` в T3.
  Мишень **floor-anchored** (`targetY = boardHeight - mask.height`) — снимается вместе с
  гравитацией в T3 (центрирование в поле 10×14).
- `LevelMap` — `static final`, НЕ `const`. `ShipParts`/`RoninParts` — `const`.
- Дев-контент масок — прототипный (не относится к `RoninParts`: канон Дизайнера, 1:1 перенос).
  Проходимость дев-деталей: структурно + содержательно (`content_packing_test.dart`).

## Как проверить

`flutter test test/game_engine/data/`.
