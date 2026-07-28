# MODULE — game_engine/models

> Паспорт модуля. 30–50 строк. Единственное, что другие агенты знают о модуле,
> не читая код. Обновляется в сессии, где менялся интерфейс/зависимости/инварианты.

## Назначение

Структуры данных ядра: маска мишени и шаблоны уровня/объекта/фрагмента.
Падающая фигура тетриса (`FallingPiece`/`Piece`) удалена вместе со старым ядром
партии (эпик «Укладка», Стори 02 T4); поле (`Board`/`Cell`) и halo-логика победы
удалены следом (эпик «Укладка», Стори 03 T2). Чистый Dart.

## Публичный интерфейс

- `TargetMask{rows}` — строки `#`/`.` сверху вниз (см. «Инварианты»); `width`/`height` —
  геттеры от `rows`; `contains(x,y)`, `cells`, `padTo({width,height,dx,dy})` (вкладывает
  маску в окно большего размера со сдвигом — центрирование детали в поле);
  `isWellFormed` — геттер-инвариант (не `assert` в конструкторе, см. «Инварианты»).
  `defaultTargetMask` (крест 6×6, строки `..##..`/`######`).
- `LevelTemplate{boardWidth,boardHeight,targetMask,targetX,targetY,objectId,fragmentIndex}`;
  `defaultLevel`. `objectId`/`fragmentIndex` — ключ для `presentation/theme`
  (`LevelSkin.materialForObjectFragment`), не связаны с моделью «объектов» (удалена
  в эпике «Контент», Стори 02).

## Зависит от

- Ни от чего внутри `game_engine` (чистые структуры данных).

## От него зависят

- `game_engine/packing`, `game_engine/data` — типы данных.
- `presentation/theme`, `presentation/widgets`, `presentation/screens` — чтение состояния/шаблонов.

## Инварианты

- Координаты: `(0,0)` слева сверху, `y` растёт вниз; линейный индекс `i = y*width + x`.
- `TargetMask` хранит форму как `List<String>` (строки сверху вниз, `#`/`.`), НЕ
  битовой маской — снимает потолок 8×8 (64-битный `int`): окно любого размера
  (детали «Ронина» до 10×14 — 100+ бит не влезли бы в `int`).
- `TargetMask.contains(x,y)` вне окна (`x`/`y` < 0 или ≥ width/height) — честный
  `false`, без исключений (границы проверяются до чтения `rows`; фикс
  краша `Invalid argument(s): -1`, укладка/04 T1).
- `TargetMask` — const-конструктор БЕЗ `assert` на форму `rows` (const-конструктор
  не может читать `rows.length`/`rows.first.length` — это сделало бы масковые
  литералы деталей не-const, а `ShipParts.parts`/`RoninParts.parts` обязаны быть
  `static const`). Инвариант окна (список непуст, строки непусты и одной длины)
  живёт в геттере `isWellFormed`, безопасном на любом `rows` (включая пустой) —
  проверяется тестами модуля и инвариант-тестом разметки контента, не рантаймом.
- `LevelTemplate` — НЕ const (`defaultLevel`, `LevelMap` создают экземпляры в рантайме).
- `defaultTargetMask`/`defaultLevel` — фикстура тестов движка, НЕ игровой уровень: не удалять.

## Как проверить

`flutter test test/game_engine/models/` (target_mask, level_template).
