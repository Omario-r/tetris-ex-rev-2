# MODULE — game_engine/data

> Паспорт модуля. 30–50 строк. Единственное, что другие агенты знают о модуле,
> не читая код. Обновляется в сессии, где менялся интерфейс/зависимости/инварианты.

## Назначение

Контент: детали корабля (`ShipParts`) и карта уровней (`LevelMap`), по одному уровню на деталь.
Данные, не логика. Старая карта объектов (4×4, «коллекция объектов») удалена (эпик «Контент»,
Стори 02) — модель v1 «один корабль», не коллекция.

## Публичный интерфейс

- `ShipParts.parts` — `static const List<ShipPartDef>` (7 деталей корабля v1: маска-форма +
  якорь в сетке корабля `gridSize=12`). Единый источник ФОРМЫ: `parts[i].mask` рисуется и как
  мишень уровня `i`, и как деталь корабля (`ShipPainter`) → они совпадают. Детали смыкаются
  в один связный силуэт «звездолёт с крыльями» (порядок = порядок сборки).
- `LevelMap.levelAt(levelIndex)` — `LevelTemplate` для `levelIndex` 0..`ShipParts.parts.length-1`
  (= `kShipPartCount-1`). Мишень = `ShipParts.parts[i].mask`, поставлена **у самого дна поля**
  (пол — опора для падающих фигур; Стори 02 — было со свободным зазором, убрали).

## Зависит от

- `game_engine/models` — `LevelTemplate`, `TargetMask`, `FragmentDef`, `ObjectTemplate`.

## От него зависят

- `presentation/screens` — `game_screen` (`levelAt`).
- `presentation/widgets` — `ship.dart`/`ShipPainter` (`ShipParts` — форма деталей).

## Инварианты

- Все уровни = детали корабля: `levelAt(i).targetMask == ShipParts.parts[i].mask` (форма
  собранного на уровне = деталь корабля). Число уровней = `ShipParts.parts.length`
  (= `kShipPartCount`). Правило «площадь кратна 4» снято (VISION, эпик «Контент») — узнаваемость
  в приоритете, неровности закрывает расчистка.
- Мишень **floor-anchored**: `targetY = boardHeight - mask.height` (без зазора) — падающая
  фигура естественно ложится на дно ровно по мишени; убирает риск «мишень висит в воздухе»,
  недостижимая без опоры.
- `LevelMap` — `static final`, НЕ `const` (`LevelTemplate` не const). `ShipParts` — `const`.
- Контент масок деталей — прототипный, шлифуется по скриншотам (VISION: узнаваемость в приоритете).

## Как проверить

`flutter test test/game_engine/data/level_map_test.dart test/game_engine/data/ship_parts_test.dart`.
