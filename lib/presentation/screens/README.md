# MODULE — presentation/screens

> Паспорт модуля. 30–50 строк. Единственное, что другие агенты знают о модуле,
> не читая код. Обновляется в сессии, где менялся интерфейс/зависимости/инварианты.

## Назначение

Экраны и склейка партии: игровой экран (держит игровой цикл), экран сборки фрагмента,
экран собранного объекта и экран корабля мета-каркаса. Композиционный корень: собирает
ядро, данные и виджеты.

## Публичный интерфейс

- `GameScreen({levelIndex=0})` — `StatefulWidget`. Держит `AnimationController` (цикл ~60fps →
  `controller.tick(dt)`), `GameController`; рисует топбар + `BoardPainter` + `GameHud`; на победе
  зовёт `ProgressService.advanceOnWin` и открывает авто-показ корабля.
- Размер клетки поля (Стори 02 T4) — **адаптивный**, не константа: колонка
  (топбар + поле + `GameHud`) обёрнута в `LayoutBuilder` внутри `SafeArea`;
  `_computeCellSize(constraints, boardWidth, boardHeight)` = `min(28.0 канон,
  (constraints.maxHeight - 44 топбар - 150 HUD) / boardHeight, constraints.maxWidth
  / boardWidth)` — на высоких экранах (≥812 логич.) даёт канонные 28px как раньше,
  на коротких (вплоть до 640 логич.) сжимается ровно настолько, чтобы топбар+поле+HUD
  влезли без `RenderFlex overflow`, скроллов нет. Топбар (44) и зона HUD (150) — те же
  константы, что несут T2/T3 (`GameHud._hudHeight`), НЕ пересчитываются.
- Топбар (Стори 02 T3, канон `.topbar`/`.chip`/`.chip .sw`/`.pausebtn`, высота 44) заменил
  старый «Level N + иконки»: слева чип «ДЕТАЛЬ N/7» (N = `fragmentIndex+1`, 7 = `kShipPartCount`,
  без имени секции — решение PO) со свотчем материала текущей детали
  (`ShipMaterials.defaultMaterials.materialForPart(level.fragmentIndex)`), справа dev-кнопки в
  стиле `.pausebtn` (40×40, `matteBlack`/`gunmetal`, глиф `hudIcon` `#B1B7BE`) — те же ключи и
  поведение читов/корабля, что раньше. Кнопки паузы нет (решение PO 2026-07-18).
- `ShipScreen()` — ручной статичный экран корабля: `ShipPainter` по `min(current_level,
  kShipPartCount)`; читает `ProgressService`. Вход — `Key('ship_button')` на `GameScreen`.
- `ShipScreen.reveal({collectedCount, onNext, isComplete})` — авто-показ прироста после
  победы: фиксированное число деталей, кнопка `Key('ship_next_button')` «Далее»
  (или «Начать заново», если `isComplete`), без «Назад».
- `CheatMenu({onSelectLevel, onInstantWin, onSetShipParts, onSetCharges})` / `showCheatMenu(...)`
  — дев-читы (bottom sheet). Только вид: логика — колбэки в `GameScreen`. Вход —
  `Key('cheat_button')`, виден лишь под `kDebugMode`. Читы: выбор уровня, мгновенная победа,
  состояние корабля (N=0..`kShipPartCount`), заряды взрыва (N=0..5, эпик «Взрыв», Стори 01;
  выставляет `GameController.setCharges` напрямую в активной партии). `levelCount` по умолчанию
  `null` → `kShipPartCount` уровней.

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
- Поток после победы: Game → `ProgressService.advanceOnWin` → `ShipScreen.reveal`
  (деталь +1) → «Далее» → Game(следующий). На последнем дев-уровне (индекс
  `kShipPartCount-1`) → корабль 3/3 + «Начать заново» → `ProgressService.reset()` → Game(0).
- Экран корабля открывается `Navigator.push` (НЕ `pushReplacement`): `GameScreen` остаётся
  под стеком, «Назад» из `AppBar` возвращает в ту же партию.
- У `GameScreen` нет `AppBar` → его `body` обёрнут в `SafeArea` вручную; иначе шапка
  (в т.ч. кнопка «Корабль») уходит под системный статус-бар/вырез и не нажимается.
- Чит-меню — только дев-сборка: вход рисуется под `if (kDebugMode)`; читы имитируются на
  мета-уровне (`ProgressService` + навигация), движок (`game_engine`) не трогают.
- `CheatMenu` — контент внутри `SingleChildScrollView` (`showModalBottomSheet(...,
  isScrollControlled: true)`): секций стало 4 (эпик «Взрыв» добавил «Заряды взрыва»), на
  маленьких экранах без скролла контент переполняет sheet (`RenderFlex overflow`, hotfix
  2026-07-11). Новую секцию читов добавлять — не забывать, что скролл уже есть, отдельно
  оборачивать не нужно.

## Как проверить

`flutter test test/presentation/game_screen_test.dart test/navigation_test.dart
test/presentation/ship_screen_test.dart test/presentation/cheat_menu_test.dart
test/presentation/win_flow_test.dart`.
