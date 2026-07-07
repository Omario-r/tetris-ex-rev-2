# MODULE — game_engine/rules

> Паспорт модуля. 30–50 строк. Единственное, что другие агенты знают о модуле,
> не читая код. Обновляется в сессии, где менялся интерфейс/зависимости/инварианты.

## Назначение

Чистые правила движка над структурами `models`: коллизии, halo/победа, взрыв,
генерация фигур. Без состояния партии (оно — в `game`) и без Flutter.

## Публичный интерфейс

- `CollisionDetector` (static): `isValidPosition`, `canMove`, `canMoveDown`,
  `canRotateCW`, `canMoveDownExplosive`.
- `HaloCalculator` (static): `computeHalo8(S, w, h) → H`; `checkWin(board, S, H) → bool`.
- `ExplosionHandler.explodeFootprint(fp, board) → Map<int,Set<int>>` — стирает клетки под фигурой (мутирует board).
- `PieceGenerator` (abstract): `next()`, `preview(n)`; реализации `SevenBagGenerator({seed})`, `FixedSequenceGenerator(seq)`.
- `rotation.dart` — пустой стуб (`// TODO`). Вращение реализовано в `models/piece.dart`
  (`rotateCW`) + `CollisionDetector.canRotateCW`. Файл — кандидат на удаление (см. BACKLOG).

## Зависит от

- `game_engine/models` — `Board`, `FallingPiece`, `Piece`, `PieceType`
  (взаимная зависимость: `models/level_template` зовёт `HaloCalculator`; см. ARCHITECTURE).

## От него зависят

- `game_engine/models` — `LevelTemplate` → `computeHalo8`.
- `game_engine/game` — коллизии, взрыв, halo, генератор.
- `presentation/screens` — `SevenBagGenerator` при старте партии.

## Инварианты

- Чистый Dart: `import 'package:flutter/...'` запрещён.
- Вращение без wall kicks: `canRotateCW == false` → поворот не применяется (no-op).
- Normal-коллизия = стены + дно + занятые клетки. Explosive вниз (`canMoveDownExplosive`)
  игнорирует блоки, проверяет только дно; горизонталь и поворот — обычная коллизия.
- `H` = 8-соседи `S` вне `S`, обрезанные полем; `H` за краем поля в `checkWin` игнорируется.
  Победа: все `S` заняты И все `H` пусты.
- Взрыв стирает только занятые клетки под отпечатком; гравитации после взрыва НЕТ (by design).
- Детерминизм: `SevenBagGenerator(seed)` / `FixedSequenceGenerator` — база всех тестов
  (нюанс `preview()` описан в `randomizer.dart`).

## Как проверить

`flutter test test/game_engine/rules/` (collision, explosion, halo, randomizer, rotation).
