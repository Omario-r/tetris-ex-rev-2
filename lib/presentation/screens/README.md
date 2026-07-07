# MODULE — presentation/screens

> Паспорт модуля. 30–50 строк. Единственное, что другие агенты знают о модуле,
> не читая код. Обновляется в сессии, где менялся интерфейс/зависимости/инварианты.

## Назначение

Экраны и склейка партии: игровой экран (держит игровой цикл), экран сборки фрагмента,
экран собранного объекта и экран корабля мета-каркаса. Композиционный корень: собирает
ядро, данные и виджеты.

## Публичный интерфейс

- `GameScreen({levelIndex=0})` — `StatefulWidget`. Держит `AnimationController` (цикл ~60fps →
  `controller.tick(dt)`), `GameController`; рисует `BoardPainter` + `GameHud`; на победе
  зовёт `ProgressService.advanceOnWin` и ведёт навигацию.
- `LevelCompleteScreen({completedLevelIndex, onNext})` — сетка фрагментов объекта,
  анимированная установка новой детали.
- `ObjectCompleteScreen({completedObjectId, onNext})` — экран собранного объекта.
- `ShipScreen()` — статичный экран корабля: `ShipPainter` по `min(current_level, kShipPartCount)`;
  читает `ProgressService.getCurrentLevel()`. Вход — кнопка-иконка `Key('ship_button')` на `GameScreen`.

## Зависит от

- `game_engine/game`, `game_engine/models`, `game_engine/data`, `game_engine/rules` (`randomizer`),
  `application` (`ProgressService`), `presentation/theme`, `presentation/widgets`.
- Это композиционный корень — потому зависимостей больше «правила трёх модулей»; ожидаемо
  для верхнего экрана, глубже дробить незачем.

## От него зависят

- `lib/main.dart` — точка входа (`ProgressService` → `GameScreen(levelIndex)`).

## Инварианты

- Игровой цикл живёт ЗДЕСЬ (не в `application/game_loop`, который стуб):
  `AnimationController.repeat` → `_onTick` → `controller.tick(dt)` → `setState`.
- Навигация: захватить `NavigatorState` (`Navigator.of(context)`) ДО `pushReplacement`;
  после ухода с экрана `context` не трогать (проверка `mounted`). Победа обрабатывается один раз (`_winHandled`).
- Поток экранов: Game → LevelComplete → (ObjectComplete в конце объекта) → Game(следующий).
  После уровня 15 — переход на 0.
- Экран корабля открывается `Navigator.push` (НЕ `pushReplacement`): `GameScreen` остаётся
  под стеком, «Назад» из `AppBar` возвращает в ту же партию.

## Как проверить

`flutter test test/presentation/game_screen_test.dart test/navigation_test.dart
test/level_complete_screen_test.dart test/object_complete_screen_test.dart`.
