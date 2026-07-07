# MODULE — game_engine/models

> Паспорт модуля. 30–50 строк. Единственное, что другие агенты знают о модуле,
> не читая код. Обновляется в сессии, где менялся интерфейс/зависимости/инварианты.

## Назначение

Структуры данных ядра: поле, тетромино, падающая фигура, маска мишени и шаблоны
уровня/объекта/фрагмента. Чистый Dart, без логики правил (правила — в `rules`).

## Публичный интерфейс

- `Board(width, height)` — сетка `Cell`; `getCell/setCell/isOccupied/isInside/clear/copyWith`.
- `Cell.empty()` / `Cell.occupied()`, `CellState` — состояние клетки.
- `PieceType{I,O,T,S,Z,J,L}`; `Piece(type, matrix)` c `rotateCW()` и `cells`; `PieceFactory.create(type)` — 7 стартовых форм.
- `PieceMode{normal,explosive}`; `FallingPiece{piece,x,y,mode,armedUsed}` c `boardCells`, `copyWith`.
- `TargetMask{width,height,mask}` c `contains(x,y)`, `cells`; `defaultTargetMask` (крест 6×6, `0x30CFFF30C`).
- `LevelTemplate{boardWidth,boardHeight,targetMask,targetX,targetY,moveLimit?,objectId,fragmentIndex}` — при создании вычисляет `S` и `H`; `defaultLevel`.
- `ObjectTemplate{id,name,fragments}` (ровно 4); `FragmentDef{anchorX,anchorY,level}`.

## Зависит от

- `game_engine/rules` — `LevelTemplate` зовёт `HaloCalculator.computeHalo8` при создании
  (взаимная зависимость: `rules` зависит от `models`; см. ARCHITECTURE).

## От него зависят

- `game_engine/rules`, `game_engine/game`, `game_engine/data` — типы данных.
- `presentation/theme`, `presentation/widgets`, `presentation/screens` — чтение состояния/шаблонов.

## Инварианты

- Координаты: `(0,0)` слева сверху, `y` растёт вниз; линейный индекс `i = y*width + x`.
- `Board` мутируется только через `setCell/clear`; `isOccupied` вне поля → `false`.
  `getCell/setCell` предполагают клетку внутри поля (`assert`).
- `Piece.rotateCW` = транспонирование 4×4 + реверс строк (только CW); матрица всегда 4×4.
- `TargetMask` MSB-first: бит `b = (w*h−1) − (y*w + x)`; окна до 8×8 (64-битный `int`).
- `LevelTemplate` — НЕ const (`defaultLevel`, `LevelMap` создают экземпляры в рантайме).
- `defaultTargetMask`/`defaultLevel` — фикстура тестов движка, НЕ игровой уровень: не удалять.

## Как проверить

`flutter test test/game_engine/models/` (board, piece, falling_piece, target_mask, level_template).
