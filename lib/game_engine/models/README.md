# MODULE — game_engine/models

> Паспорт модуля. 30–50 строк. Единственное, что другие агенты знают о модуле,
> не читая код. Обновляется в сессии, где менялся интерфейс/зависимости/инварианты.

## Назначение

Структуры данных ядра: маска мишени и шаблоны уровня/объекта/фрагмента.
Падающая фигура тетриса (`FallingPiece`/`Piece`) удалена вместе со старым ядром
партии (эпик «Укладка», Стори 02 T4); поле (`Board`/`Cell`) и halo-логика победы
удалены следом (эпик «Укладка», Стори 03 T2). Чистый Dart.

## Публичный интерфейс

- `TargetMask{width,height,mask}` c `contains(x,y)`, `cells`; `defaultTargetMask` (крест 6×6, `0x30CFFF30C`).
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
- `TargetMask` MSB-first: бит `b = (w*h−1) − (y*w + x)`; окна до 8×8 (64-битный `int`).
- `LevelTemplate` — НЕ const (`defaultLevel`, `LevelMap` создают экземпляры в рантайме).
- `defaultTargetMask`/`defaultLevel` — фикстура тестов движка, НЕ игровой уровень: не удалять.

## Как проверить

`flutter test test/game_engine/models/` (target_mask, level_template).
