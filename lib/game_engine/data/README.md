# MODULE — game_engine/data

> Паспорт модуля. 30–50 строк. Единственное, что другие агенты знают о модуле,
> не читая код. Обновляется в сессии, где менялся интерфейс/зависимости/инварианты.

## Назначение

Контент: детали корабля (`ShipParts`) и старая карта 4 объектов × 4 фрагмента = 16
уровней (`LevelMap`). Данные, не логика.

## Публичный интерфейс

- `ShipParts.parts` — `static const List<ShipPartDef>` (7 деталей корабля v1: маска-форма +
  якорь в сетке корабля `gridSize=12`). Единый источник ФОРМЫ: `parts[i].mask` рисуется и как
  мишень дев-уровня `i`, и как деталь корабля (`ShipPainter`) → они совпадают. Детали смыкаются
  в один связный силуэт «звездолёт с крыльями» (порядок = порядок сборки).
- `LevelMap.levelAt(levelIndex)` — `LevelTemplate` для `levelIndex` 0..15. Дев-уровни 0..6 —
  детали корабля (мишень = `ShipParts.parts[i].mask`); 7..15 — старая карта объектов.
- `LevelMap.objects` — `static final List<ObjectTemplate>` (4×4). В дев-потоке НЕ
  используется (`levelAt(0..6)` идёт мимо); ретайр из дев-потока — Стори 02 эпика «Контент».

## Зависит от

- `game_engine/models` — `LevelTemplate`, `TargetMask`, `FragmentDef`, `ObjectTemplate`.

## От него зависят

- `presentation/screens` — `game_screen` (`levelAt`).
- `presentation/widgets` — `ship.dart`/`ShipPainter` (`ShipParts` — форма деталей).

## Инварианты

- Дев-уровни 0..6 = детали корабля: `levelAt(i).targetMask == ShipParts.parts[i].mask`
  (форма собранного на уровне = деталь корабля). Число дев-уровней = `ShipParts.parts.length`
  (= `kShipPartCount`). Правило «площадь кратна 4» снято (VISION, эпик «Контент») — узнаваемость
  в приоритете, неровности закрывает расчистка.
- `levelAt` для 7..15 — старая карта объектов (`index~/4`, `index%4`); в дев-потоке
  недостижима (после последнего дев-уровня — сброс к 0).
- `LevelMap` — `static final`, НЕ `const` (`LevelTemplate` не const). `ShipParts` — `const`.
- Контент масок деталей — прототипный, шлифуется по скриншотам (VISION: узнаваемость в приоритете).
  Проходимость мишеней и ретайр старой карты объектов — Стори 02 эпика «Контент».

## Как проверить

`flutter test test/game_engine/data/level_map_test.dart test/game_engine/data/ship_parts_test.dart`.
