# MODULE — game_engine/rules

> Паспорт модуля. 30–50 строк. Единственное, что другие агенты знают о модуле,
> не читая код. Обновляется в сессии, где менялся интерфейс/зависимости/инварианты.

## Назначение

Чистые правила над структурами `models`: halo/победа. Старое ядро партии (тетрис —
коллизии/взрыв/генератор фигур) удалено (эпик «Укладка», Стори 02 T4). Без Flutter.

## Публичный интерфейс

- `HaloCalculator` (static): `computeHalo8(S, w, h) → H`; `checkWin(board, S, H) → bool`.
- `rotation.dart` — пустой стуб (`// TODO`), мёртвый код. Кандидат на удаление —
  Стори 03 (см. BACKLOG).

## Зависит от

- `game_engine/models` — `Board` (через `checkWin`)
  (взаимная зависимость: `models/level_template` зовёт `HaloCalculator`; см. ARCHITECTURE).

## От него зависят

- `game_engine/models` — `LevelTemplate` → `computeHalo8`.

## Инварианты

- Чистый Dart: `import 'package:flutter/...'` запрещён.
- `H` = 8-соседи `S` вне `S`, обрезанные полем; `H` за краем поля в `checkWin` игнорируется.
  Победа: все `S` заняты И все `H` пусты.

## Как проверить

`flutter test test/game_engine/rules/` (halo, rotation).
