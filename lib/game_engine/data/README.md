# MODULE — game_engine/data

> Паспорт модуля. 30–50 строк. Единственное, что другие агенты знают о модуле,
> не читая код. Обновляется в сессии, где менялся интерфейс/зависимости/инварианты.

## Назначение

Контент: разметка «Ронина» v3 (`RoninParts` — 19 деталей: 12 плит обшивки по секциям в своём масштабе и 7 предметов поверх — датчик, визор половинами, два люка, два RCS; D-010…D-012, D-016; канон Дизайнера) и
карта уровней (`LevelMap`, поле укладки 10×14, по одному уровню на деталь). Данные, не логика.
Дев-детали v1 (7 штук) выпилены в Ронин-1/06 T1: единственный источник контента — `RoninParts`.

## Публичный интерфейс

- `RoninSection` — секция обшивки: `id` (`'prow'`|`'bridge'`|`'fwd'`), `scale` (клеток поля на
  клетку рисунка: 2|3|4), `originX`/`originY` (левый-верх сетки на корабле, клетки рисунка),
  `cols`/`rows` (размер сетки секции в её клетках).
- `RoninPartDef` — деталь: `id`, `order` (1..N, порядок сборки), `layer` (0 — плита обшивки,
  1 — предмет поверх), `module` (`'prow'`|`'bridge'`|`'fwd'`), `title` (для топбара), `cells`
  (бюджет уровня), `seed` (канонный seed нарезки, не `null`), `mask` (`TargetMask`, bbox-маска).
  Плита: `sectionId`, `sectionCol`/`sectionRow` (origin маски в клетках секции). Предмет:
  `objectKind` (`'sensor'`|`'rcs'`|`'visor'`|`'hatch'`), `objectScale`, `objectX`/`objectY` (левый-верх маски на
  корабле, клетки рисунка, дробные). Геттеры: `isPlate`, `scale`, `shipX`/`shipY`,
  `cellOnShip(c, r)` → `(x, y, size)` — клетка маски на корабле в клетках рисунка
  (`shipX + c/scale`, `1/scale`). Внимание: `origin` в каноне — у секции и предмета клетки
  рисунка корабля, у плиты клетки её секции.
- `RoninParts.sections` (3 секции: нос `s=2`, мостик `s=3`, пояс `s=4`) и `RoninParts.parts` —
  `static const`, 19 деталей, отсортированы по `order` (индекс == `order - 1`). Источник —
  `docs/design/ronin-parts.js` v3 (канон Дизайнера), перенесён 1:1 вместе с seed (все заданы).
  `sectionById(id)` / `partAtOrder(order)` / `byId(id)` (неизвестный `id` → `ArgumentError`).
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
- `presentation/ship_render` — `RoninParts` (форма и позиции деталей корабля, тот же источник,
  что и мишени уровней).
- `presentation/widgets` — `PackingPainter` (`RoninPartDef` — деталь уровня).
- `application` — `ProgressService._max` (`RoninParts.parts.length - 1`).

## Инварианты

- `RoninParts.parts`: ровно 19 (12 плит + 7 предметов), `id` уникальны, `order` — 1..N по индексу; `layer` ∈ {0, 1};
  каждая `mask.isWellFormed`, bbox ≤ 10×14; `cells` == число `#` в маске, `cells` ≤ 80; маска
  связна по 4-соседству, точный bbox. Плита: секция существует, маска внутри сетки секции;
  плиты одной секции не пересекаются; площадь всех плит Σ `cells/scale²` = 60 клеток рисунка;
  у плиты нет одинарных шипов (клетки с пустотой по обе стороны по оси; край секции не в счёт).
  Предмет: `objectKind/Scale/X/Y` заданы. Каждая плита с `order ≥ 2` касается плиты с меньшим
  `order`, каждый предмет перекрывает/касается такой плиты (`ronin_parts_test.dart`).
  Проходимость (нарезка + эталонная укладка на канонном `seed`, все 19) — `ronin_packing_test.dart`. Эталонные нарезки канонных seed (v3) —
  `pack_slicer_test.dart`, `slice_config_test.dart`; рамп старта — `start_metric_test.dart`.
- Уровни = детали «Ронина»: `levelAt(i).targetMask` — поле 10×14 с деталью `RoninParts.parts[i]`,
  вложенной через `padTo` со сдвигом `targetX`/`targetY`; число уровней = `RoninParts.parts.length`
  («N деталей ↔ N уровней»). Мишень **центрирована**, НЕ floor-anchored (`level_map_test.dart`).
- `LevelMap` — `static final`, НЕ `const`. `RoninParts` — `const`.

## Как проверить

`flutter test test/game_engine/data/`.
