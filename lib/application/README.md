# MODULE — application

> Паспорт модуля. 30–50 строк. Единственное, что другие агенты знают о модуле,
> не читая код. Обновляется в сессии, где менялся интерфейс/зависимости/инварианты.

## Назначение

Прикладной слой между ядром и UI. Сейчас — персист прогресса (`ProgressService`).
Слой тонкий: игровой цикл фактически живёт в экране (см. инварианты).

## Публичный интерфейс

- `ProgressService`:
  - `getCurrentLevel() → Future<int>` — текущий уровень 0..15 (по умолчанию 0).
  - `setCurrentLevel(int)` — сохранить (значение clamp-ится в 0..15).
  - `advanceOnWin() → Future<int>` — следующий уровень, не выше 15. Звать только после победы.
  - `reset()` — сброс прогресса (только отладка/тесты).
- `GameLoop` (`StatelessWidget`) — СТУБ (`Placeholder`), нигде не используется.
  Реальный цикл — в `presentation/screens/game_screen`. Кандидат на удаление (см. BACKLOG).

## Зависит от

- Ничего из `lib/`. Внешнее: `shared_preferences` (persist), `flutter` (стуб `GameLoop`).

## От него зависят

- `presentation` — `main.dart` и `game_screen` используют `ProgressService`.

## Инварианты

- Персист только через `shared_preferences`, ключ `current_level`, значение clamp 0..15.
- Провал уровня = повтор (без `advanceOnWin`); `advanceOnWin` никогда не превышает 15.
- Слой не импортирует `presentation` (импорты только вниз); сейчас не импортирует и `game_engine`.
- `game_loop.dart` — стуб: не наращивать от него игровой цикл, он живёт в экране.

## Как проверить

`flutter test test/application/progress_service_test.dart`.
