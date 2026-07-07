# MODULE — presentation/widgets

> Паспорт модуля. 30–50 строк. Единственное, что другие агенты знают о модуле,
> не читая код. Обновляется в сессии, где менялся интерфейс/зависимости/инварианты.

## Назначение

Переиспользуемые виджеты/пейнтеры: отрисовка поля, панель управления (HUD),
отрисовка объекта-корабля и единого корабля мета-каркаса. Экраны (`screens`) собирают их вместе.

## Публичный интерфейс

- `BoardPainter(state, cellSize, theme, levelMaterial, {tntSkin, animValue})` — `CustomPainter`
  поля: фон, ghost-мишень (незаполненные `S`), уложенные блоки, пульс dirty-halo,
  drop-ghost (normal), падающая фигура.
- `GameHud(controller, state)` — `StatelessWidget`: кнопки движения/поворота/softDrop +
  arm (крипер) + detonate; активность через `state.canArm/canDetonate`.
- `ObjectFragmentGridPainter(objectTemplate, completedFragmentIndex, animProgress)` —
  сетка фрагментов объекта, новая деталь въезжает анимацией scale.
- `ObjectFullPainter(objectTemplate)` — собранный объект целиком, статично.
- `ShipPainter({collectedCount})` — единый корабль из 3 деталей-заглушек: первые
  `collectedCount` установлены (залиты), остальные — контуром. `collectedCount` клампится 0..3.
- `Ship.parts` / `ShipPart` / `kShipPartCount` (`ship.dart`) — модель корабля: список из
  `kShipPartCount = 3` деталей-заглушек (нормализованные `Rect` в сетке 10×10). Единый
  источник истины «3 детали ↔ 3 уровня» для эпика «Мета-каркас».

## Зависит от

- `game_engine/game` — `GameState`, `GameController`.
- `game_engine/models` — `Board`, `FallingPiece`, `ObjectTemplate`.
- `presentation/theme` — `BlockMaterial`, `BlockTheme`, `TntSkin`, оверлеи.
- `ship.dart` — только `flutter/material` (модель-заглушка без ядра).

## От него зависят

- `presentation/screens` — `game_screen` (board_painter + hud), `level_complete`
  (grid painter), `object_complete` (full painter).

## Инварианты

- Только вид: пейнтеры не содержат игровой логики; ввод игрока идёт лишь через команды
  `GameController` (HUD зовёт `controller.*`).
- Пейнтеры объекта считают сетку объекта 10×10, маску фрагмента 5×5 — привязка к текущей
  раскладке `LevelMap`; при смене контента синхронизировать.
- `shouldRepaint` завязан на `state`/анимацию; мутабельное состояние в пейнтере не хранить.
- `ShipPainter.collectedCount` всегда клампится 0..`kShipPartCount`; корабль-заглушка не
  зависит от `LevelMap`/ядра (в отличие от пейнтеров объекта).

## Как проверить

`flutter test test/presentation/board_painter_test.dart test/presentation/hud_test.dart`.
