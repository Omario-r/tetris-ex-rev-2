# MODULE — game_engine/data

> Паспорт модуля. 30–50 строк. Единственное, что другие агенты знают о модуле,
> не читая код. Обновляется в сессии, где менялся интерфейс/зависимости/инварианты.

## Назначение

Контент: дев-детали корабля (`ShipParts`) и старая карта 4 объектов × 4 фрагмента = 16
уровней (`LevelMap`). Данные, не логика.

## Публичный интерфейс

- `ShipParts.parts` — `static const List<ShipPartDef>` (3 дев-детали: маска-заглушка +
  якорь в сетке корабля). Единый источник ФОРМЫ: `parts[i].mask` рисуется и как мишень
  дев-уровня `i`, и как деталь корабля (`ShipPainter`) → они совпадают.
- `LevelMap.levelAt(levelIndex)` — `LevelTemplate` для `levelIndex` 0..15. Дев-уровни 0..2 —
  детали корабля (мишень = `ShipParts.parts[i].mask`); 3..15 — старая карта объектов.
- `LevelMap.objects` — `static final List<ObjectTemplate>` (4×4). В дев-потоке НЕ
  используется (`levelAt(0..2)` идёт мимо); остаётся для эпика «Контент».

## Зависит от

- `game_engine/models` — `LevelTemplate`, `TargetMask`, `FragmentDef`, `ObjectTemplate`.

## От него зависят

- `presentation/screens` — `game_screen` (`levelAt`).
- `presentation/widgets` — `ship.dart`/`ShipPainter` (`ShipParts` — форма деталей).

## Инварианты

- Дев-уровни 0..2 = детали корабля: `levelAt(i).targetMask == ShipParts.parts[i].mask`
  (форма собранного на уровне = деталь корабля). Площадь каждой детали кратна 4 (VISION).
- `levelAt` для 3..15 — старая карта объектов (`index~/4`, `index%4`); в дев-потоке
  недостижима (после 3-го уровня — сброс к 0).
- `LevelMap` — `static final`, НЕ `const` (`LevelTemplate` не const). `ShipParts` — `const`.
- Контент — прототипный/временный. ⚠ Мишени объекта 0 (стены 25, крыши 15) НЕ кратны 4;
  заменяются в эпике «Контент» (в дев-потоке уже не показываются).

## Как проверить

`flutter test test/game_engine/data/level_map_test.dart test/game_engine/data/ship_parts_test.dart`.
