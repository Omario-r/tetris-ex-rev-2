# MODULE — application

> Паспорт модуля. 30–50 строк. Единственное, что другие агенты знают о модуле,
> не читая код. Обновляется в сессии, где менялся интерфейс/зависимости/инварианты.

## Назначение

Прикладной слой между ядром и UI. Сейчас — персист прогресса (`ProgressService`).
Слой тонкий: игровой цикл фактически живёт в экране (см. инварианты).

## Публичный интерфейс

- `ProgressService`:
  - `getCurrentLevel() → Future<int>` — текущий уровень 0.._max (по умолчанию 0).
  - `setCurrentLevel(int)` — сохранить (значение clamp-ится в 0.._max).
  - `advanceOnWin() → Future<int>` — следующий уровень, не выше `_max`. Звать только после победы.
  - `reset()` — сброс прогресса (только отладка/тесты).
  - `_max` — **не хардкод**: `ShipParts.parts.length - 1` (эпик «Контент» — единый источник
    истины числа уровней; см. hotfix 2026-07-11 — было захардкожено `15` из «Мета-каркаса»,
    разошлось с `LevelMap` (7 уровней) и роняло приложение на холодном старте с устаревшим
    persist-значением).
- `GameLoop` (`StatelessWidget`) — СТУБ (`Placeholder`), нигде не используется.
  Реальный цикл — в `presentation/screens/game_screen`. Кандидат на удаление (см. BACKLOG).

## Зависит от

- `game_engine/data` — `ShipParts.parts.length` (единый источник истины `_max`). Внешнее:
  `shared_preferences` (persist), `flutter` (стуб `GameLoop`).

## От него зависят

- `presentation` — `main.dart` и `game_screen` используют `ProgressService`.

## Инварианты

- Персист только через `shared_preferences`, ключ `current_level`, значение clamp 0.._max.
- Провал уровня = повтор (без `advanceOnWin`); `advanceOnWin` никогда не превышает `_max`.
- `getCurrentLevel()` клампит НА ЧТЕНИИ — устаревший/повреждённый persist (значение из старой
  сборки с другим числом уровней) самовосстанавливается до валидного, а не крашит `LevelMap`.
- Слой не импортирует `presentation` (импорты только вниз); импортирует `game_engine/data`
  (разрешено — импорт строго вниз по слоям, см. ARCHITECTURE).
- `game_loop.dart` — стуб: не наращивать от него игровой цикл, он живёт в экране.

## Как проверить

`flutter test test/application/progress_service_test.dart`.
