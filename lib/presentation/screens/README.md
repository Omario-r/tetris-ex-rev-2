# MODULE — presentation/screens

> Паспорт модуля. 30–50 строк. Единственное, что другие агенты знают о модуле,
> не читая код. Обновляется в сессии, где менялся интерфейс/зависимости/инварианты.

## Назначение

Экраны и склейка партии: игровой экран укладки (эпик «Укладка», Стори 02 — на ядре
`game_engine/packing`), экран сборки фрагмента, экран собранного объекта и экран корабля
мета-каркаса. Композиционный корень: собирает ядро, данные и виджеты.

## Публичный интерфейс

- `GameScreen({levelIndex=0})` — `StatefulWidget` на **ядре укладки** (эпик «Укладка»,
  Стори 02 T2). Силуэт уровня — `LevelMap.levelAt(levelIndex).targetMask`, **поле фиксировано
  10×14** для всех 13 уровней (Ронин-1/01 T3: `LevelMap.fieldWidth/Height`, деталь центрирована
  в поле, `targetMask` уже размера поля) — экран геометрию поля из мишени не выводит, только
  читает её размер. Материал уложенных
  клеток `_partMaterial` — один временный `BlockMaterial.graphite` на все 13 деталей (Ронин-1/01
  T3, было `ShipMaterials.defaultMaterials.materialForPart(fragmentIndex)`: 7-элементная карта
  не покрывала 13 деталей «Ронина» — `RangeError` на 8-м уровне; `ShipMaterials` из экрана
  больше не читается для этого поля). Нарезка `slicePolyomino(silhouette, seed:_seed)` →
  `PackController`/`PackState`
  (весь набор в лотке). Игрок тянет кусочки из лотка в силуэт; заполнил без дыр
  (`PackState.isComplete`) → **деталь собрана** → прежний мета-поток
  (`ProgressService.advanceOnWin` → `ShipScreen.reveal`). Ни гравитации, ни таймера, ни
  проигрыша; отдельного игрового цикла нет — только лёгкий пульс-`AnimationController`
  (`repeat(reverse)`) для ободка «готово». Старое тетрис-ядро (`game`/`rules`/`BoardPainter`/
  `GameHud`) `GameScreen` больше не тянет.
- Макет (сверху вниз, канон мокапа `docs/design/ukladka-field.html`): топбар (44) → прогресс
  `.prog`/`.proglbl` → поле (силуэт, центрировано, `Expanded`) → лоток `.tray`/`.traylbl`.
  Прогресс-бар — заполнение силуэта (`occupiedCells.length / silhouette.cells.length`,
  градиент `rust→hazardOrange`), подпись «уложено N / M кусков» (N=`placements.length`,
  M=`pieces.length`).
- Размер клетки поля — **адаптивный**: `_computeCellSize(constraints, boardWidth, boardHeight)`
  = `max(8, min(34.0 канон, (maxHeight - 44 топбар - 34 прогресс - 132 лоток - 16 паддинг
  поля)/boardHeight, (maxWidth - 16 паддинг поля)/boardWidth))` (внутри
  `LayoutBuilder`+`SafeArea`); канон 34px — поле 10×14 при клетке 34 (Ронин-1/01 T4, было 40px
  под мелкие дев-силуэты ≤4×3), на коротких экранах клетка ужимается (нижний порог 8px).
  Клетка хранится в поле `_cellSize` (обновляется в `build`) — нужна pointer-обработчикам.
- Панель поля — канон `.board` мокапа (`ukladka-field.html:85-86`, возврат Гейта 3 T2):
  `_boardPadding=8.0` между рамкой панели и сеткой силуэта — вокруг мишени читается подложка
  `boardBg`, обводка снап-превью на крайних клетках не срезается клипом. Габарит панели =
  `boardPixelWidth/Height + 2*_boardPadding`. Реализовано `SizedBox` (внешний габарит) →
  `DecoratedBox` (фон/рамка/радиус/glow — НЕ `Container`: у `Container` фон+рамка
  автоматически добавили бы к паддингу ещё толщину рамки и сжали холст `CustomPaint`, см.
  инварианты) → `ClipRRect` (скругление 10 для содержимого) → `Padding(_boardPadding)` →
  `Listener`/`CustomPaint` (`_boardKey` без изменений).
  Клетка лотка `_trayCellSize=32.0` (~0.8 полевой, канон мокапа/прототипа Стори 01).
- Топбар (канон `.topbar`/`.title`/`.pausebtn` мокапа `ukladka-field.html`, высота 44,
  Ронин-1/01 T4): слева заголовок из двух строк — `.kick` «ДЕТАЛЬ N / 13»
  (N=`fragmentIndex+1`, 13=`kShipPartCount`) и `.name` название детали заглавными
  (`RoninParts.parts[fragmentIndex].title.toUpperCase()`, напр. «НОС, ЛЕВЫЙ БОРТ»); свотча
  материала в топбаре больше нет (был у прежнего чипа, Стори 02 T3). Справа dev-кнопки
  (`Key('cheat_button')` под `kDebugMode`, `Key('ship_button')`). Виджеты `_PartTitle`
  (заменил `_PartChip`/`_Swatch`) / `_DevButton`.
- Drag-and-drop — сырые pointer-события `Listener` (`onPointerDown/Move/Up/Cancel`, НЕ
  `GestureDetector.onPan*` — фикс возврата Гейта 2 Стори 01: лоток
  `SingleChildScrollView(Axis.horizontal)` выигрывал `onPan*` в gesture arena, кусок не
  следовал за пальцем; raw pointer в арене не участвует). Тащим из лотка/с поля, офсет
  `_dragLiftPx=56`px над пальцем, плавающий фидбэк `Key('packing_drag_feedback')` (graphite).
  Отпустил над силуэтом → `place`/`move`, вне поля с уложенного → `remove` (в лоток),
  `onPointerCancel` → сброс без укладки. Клетки лотка/драга — `graphite`
  (`el-piece-tray`/`el-piece-drag`), уложенные — материал детали (`PackingPainter.partMaterial`).
  Снап-превью (`el-drop-ok`/`el-drop-bad`) пересчитывается в `build` (`_computePreview` →
  `PackController.canPlace`) и передаётся `PackingPainter.dragPreview`.
- Завершение: `Key('packing_complete')` при `isComplete` (баннер «ДЕТАЛЬ СОБРАНА», без
  кнопки «Заново») + пульс-ободок `doneGlow` на поле; через ~900 мс идемпотентно
  (`_winHandled`/`_winScheduled`) — прежний мета-поток `_onWin`. Solve-хук `_solveAll()`
  (раскладка по `PackSlice.solution`) — дев-кнопка `Key('cheat_solve')` И programmatic-хук
  для тестов (доводит до `isComplete` без симуляции drag). `FeedMode {fullSet, tray3}`
  объявлен в `game_screen.dart` (в `tray3` в лотке первые 3 из `trayOrder` + индикатор «+N»).
- `ShipScreen()` — ручной статичный экран корабля: `ShipPainter` по `min(current_level,
  kShipPartCount)`; читает `ProgressService`. Вход — `Key('ship_button')` на `GameScreen`.
- `ShipScreen.reveal({collectedCount, onNext, isComplete})` — авто-показ прироста после
  победы: фиксированное число деталей, кнопка `Key('ship_next_button')` «Далее»
  (или «Начать заново», если `isComplete`), без «Назад».
- `CheatMenu({onSelectLevel, onInstantWin, onSetShipParts, feedMode, onSetFeedMode,
  onReshuffle, onSolve, levelCount?})` / `showCheatMenu(...)` — дев-читы (bottom sheet).
  Только вид: логика — колбэки в `GameScreen`. Вход — `Key('cheat_button')`, виден лишь под
  `kDebugMode`. Секции: выбор уровня, мгновенная победа (мета-уровень, `_handleWin`),
  состояние корабля (N=0..`kShipPartCount`), **подача** (`Key('feed_full')`/`Key('feed_tray3')`
  — тумблер `FeedMode`), **нарезка** (`Key('cheat_reshuffle')` — пересобрать; `Key('cheat_solve')`
  — solve-хук). Зарядов взрыва и «Прототипа укладки» больше нет (выпил в Стори 02).
  `levelCount` по умолчанию `null` → `kShipPartCount` уровней.

## Зависит от

- `game_engine/packing` (`PackController`/`PackState`/`PackPiece`/`slicePolyomino`),
  `game_engine/models` (`TargetMask`), `game_engine/data` (`LevelMap`, `RoninParts` — только
  чтение, название детали для топбара, Ронин-1/01 T4),
  `application` (`ProgressService`), `presentation/theme` (`BlockMaterial`/`ShipMaterials`),
  `presentation/widgets` (`PackingPainter`, `ship`). `GameScreen` больше НЕ зависит от
  `game_engine/game`, `game_engine/rules`, `widgets/board_painter`, `widgets/hud`,
  `theme/level_skin` (пересадка на укладку, Стори 02 T2).
- `cheat_menu.dart` импортирует `FeedMode` из `game_screen.dart` (взаимный импорт —
  допустим в Dart; enum живёт у экрана, меню лишь типизирует параметр).
- Это композиционный корень — потому зависимостей больше «правила трёх модулей»; ожидаемо
  для верхнего экрана, глубже дробить незачем.

## От него зависят

- `lib/main.dart` — точка входа (`ProgressService` → `GameScreen(levelIndex)`).

## Инварианты

- Отдельного игрового цикла больше НЕТ (ядро укладки без гравитации/тиков): вместо
  gravity-тикера — лёгкий пульс-`AnimationController.repeat(reverse)` только для ободка
  «готово». Состояние укладки мутируется `PackController` (`place`/`move`/`remove`) в
  pointer-обработчиках, не по тику.
- Мутация ядра (`PackController`) — только через сам контроллер; `PackState`/`PackPiece`
  иммутабельны. Невалидная укладка — no-op контроллера (не бросает).
- Навигация: захватить `NavigatorState` (`Navigator.of(context)`) ДО `pushReplacement`;
  после ухода с экрана `context` не трогать (проверка `mounted`). Победа обрабатывается
  один раз (`_winHandled`); укладка-завершение планирует её через ~900 мс (`_winScheduled`),
  чит «мгновенная победа» — сразу.
- Поток после победы: Game → `ProgressService.advanceOnWin` → `ShipScreen.reveal`
  (деталь +1) → «Далее» → Game(следующий). На последнем дев-уровне (индекс
  `kShipPartCount-1`) → корабль N/N + «Начать заново» → `ProgressService.reset()` → Game(0).
- Экран корабля открывается `Navigator.push` (НЕ `pushReplacement`): `GameScreen` остаётся
  под стеком, «Назад» из `AppBar` возвращает в ту же партию.
- У `GameScreen` нет `AppBar` → его `body` обёрнут в `SafeArea` вручную; иначе шапка
  (в т.ч. кнопка «Корабль») уходит под системный статус-бар/вырез и не нажимается.
- Drag: `_boardKey` — origin координат клеток поля (globalToLocal). Якорь укладки —
  клетка под верх-левым углом всплывшего куска (`pointer - _dragLiftPx`, `.floor()`);
  снап-превью и `_endDrag` используют один расчёт `_anchorAt` (не расходятся).
- Панель поля НЕ красить через `Container.decoration` с рамкой поверх фикс-`width`/`height`:
  `Container` сам добавляет к любому паддингу ещё толщину рамки (`Border.dimensions`) как
  внутренний отступ, из-за чего `CustomPaint` внутри тесной обвязки сжимается на толщину
  рамки и перестаёт совпадать с `boardPixelWidth`/`Height` (на них держится якорь драга,
  `_anchorAt`/`_globalToLocal`). Канон — `SizedBox`(внешний габарит) → `DecoratedBox`(красит
  без вставки отступа) → `ClipRRect`(скругление) → `Padding(_boardPadding)` → `CustomPaint`.
- Чит-меню — только дев-сборка: вход рисуется под `if (kDebugMode)`; читы «выбор уровня»/
  «мгновенная победа»/«состояние корабля» имитируются на мета-уровне (`ProgressService` +
  навигация), ядро укладки не трогают; «подача»/«пересобрать»/«решить» работают с ядром
  экрана через `setState`.
- `CheatMenu` — контент внутри `SingleChildScrollView` (`showModalBottomSheet(...,
  isScrollControlled: true)`): на маленьких экранах без скролла контент переполняет sheet
  (`RenderFlex overflow`, hotfix 2026-07-11). Новую секцию читов добавлять — не забывать,
  что скролл уже есть, отдельно оборачивать не нужно.

## Как проверить

`flutter test test/presentation/game_screen_test.dart test/navigation_test.dart
test/presentation/ship_screen_test.dart test/presentation/cheat_menu_test.dart
test/presentation/win_flow_test.dart`.
