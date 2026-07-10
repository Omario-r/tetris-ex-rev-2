# MODULE — game_engine/game

> Паспорт модуля. 30–50 строк. Единственное, что другие агенты знают о модуле,
> не читая код. Обновляется в сессии, где менялся интерфейс/зависимости/инварианты.

## Назначение

Состояние партии и оркестрация ядра: `GameState` (снапшот) и `GameController`
(команды игрока + шаг времени `tick`). Связывает `models` и `rules` в игру.

## Публичный интерфейс

- `GamePhase{spawning,falling,won,lost}`.
- `GameState{board,fallingPiece?,phase,generator,level,charges}` c `copyWith(clearFallingPiece)`
  и геттерами `dirtyHalo`, `canArm`, `canDetonate`, `isWin`, `isLost`. `charges` — заряды взрыва
  на партию; дефолт `level.chargeBudget` (не передан явно → берётся из уровня).
- `GameController(initialState, gravityInterval=0.5)`: `state`; команды
  `moveLeft/moveRight/rotateCW/softDrop/armExplosive/detonate/setCharges`; `tick(dt)`.
  `setCharges(n)` — дев-чит, выставляет заряды напрямую (см. `presentation/screens/CheatMenu`).

## Зависит от

- `game_engine/models` — `Board`, `FallingPiece`, `Piece`, `LevelTemplate`.
- `game_engine/rules` — `CollisionDetector`, `ExplosionHandler`, `HaloCalculator`, `PieceGenerator`.

## От него зависят

- `presentation/screens` — `game_screen` держит `GameController`, гоняет `tick`.
- `presentation/widgets` — `board_painter`/`hud` читают `GameState`, `hud` шлёт команды.

## Инварианты

- Публичные команды возвращают `void`; невозможное действие = **no-op**, исключений нет.
  Команды применяются только в фазе `falling` (кроме `tick`).
- Состояние меняется только через `GameController`; `state` заменяется через `copyWith`.
  `Board` при lock/взрыве мутируется на месте (тот же объект).
- `tick(dt)`: `won/lost` → выход; `spawning` → спавн в `(x=3, y=0)`, занятость спавна → `lost`;
  `falling` → аккумулятор гравитации, затем lock (normal) или полёт/авто-детонация (explosive).
- `armExplosive` — ровно раз на фигуру (`normal→explosive`, `armedUsed`, необратимо), списывает
  1 заряд; на `charges == 0` — **no-op** (заряд не взводится, `charges` не уходит в минус).
  `detonate` — вручную или авто у пола. Победа проверяется после каждого lock и каждого взрыва.
- Поражение — только переполнение спавна. Гравитации после взрыва нет.
- `charges` не переносятся между уровнями/партиями: новый `GameState` (новый уровень —
  `presentation/screens/GameScreen` пересоздаёт `GameController`) заново берёт `level.chargeBudget`.

## Как проверить

`flutter test test/game_engine/game/` и `test/integration/golden_scenario_test.dart`.
