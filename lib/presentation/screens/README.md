# MODULE — presentation/screens

> Паспорт модуля. 30–50 строк. Единственное, что другие агенты знают о модуле,
> не читая код. Обновляется в сессии, где менялся интерфейс/зависимости/инварианты.

## Назначение

Экраны и склейка партии: игровой экран укладки (эпик «Укладка», Стори 02 — на ядре
`game_engine/packing`), экран сборки фрагмента, экран собранного объекта и экран корабля
мета-каркаса. Композиционный корень: собирает ядро, данные и виджеты.

## Публичный интерфейс

- `GameScreen({levelIndex=0})` — `StatefulWidget` на **ядре укладки** (эпик «Укладка»,
  Стори 02 T2). **Уровень строит `prepareLevel`**
  (Ронин-1/07 T2): `_rebuild()` зовёт `prepareLevel(RoninParts.parts[levelIndex].mask,
  GameScreen.sliceConfig, seed: part.seed + _seedOffset)` и берёт `silhouette`, `slice`. Поле —
  10×14; экран геометрию поля не выводит,
  читает размер из `silhouette`. `LevelMap` остался источником `fragmentIndex`. Уложенные
  клетки — куски рисунка (Ронин-1/03): `_rebuild` запоминает `_targetX/_targetY`
  (`prepared.targetX/targetY`, сдвиг маски в поле), `PackingPainter` получает
  `art: RoninArt.shared`, `part: RoninParts.parts[_fragmentIndex]`, `targetX/targetY`;
  материала детали (`_partMaterial`, `ShipMaterials`) у экрана нет. Нарезка (`prepared.slice`) →
  `PackController`/`PackState`
  (весь набор в лотке). Игрок тянет кусочки из лотка в силуэт; заполнил без дыр
  (`PackState.isComplete`) → **деталь собрана** → пауза с выбором маршрута (Ронин-1/05 T1,
  см. «Завершение»). Ни гравитации, ни таймера, ни
  проигрыша; отдельного игрового цикла нет — только лёгкий пульс-`AnimationController`
  (`repeat(reverse)`) для ободка «готово». Старое тетрис-ядро (`game`/`rules`/`BoardPainter`/
  `GameHud`) `GameScreen` больше не тянет.
- Макет (сверху вниз, канон мокапа `docs/design/ukladka-field.html`): топбар (44) → прогресс
  `.prog`/`.proglbl` → поле (силуэт, центрировано, `Expanded`) → лоток `.tray`/`.traylbl`.
  Прогресс-бар — заполнение силуэта (`occupiedCells.length / silhouette.cells.length`,
  градиент `rust→hazardOrange`), подпись «уложено N / M кусков» (N=`placements.length`,
  M=`pieces.length`). Строка прогресса — `SizedBox(_progZoneHeight=34)`; справа в ней
  кнопка-текст «ОЧИСТИТЬ ПОЛЕ» (`Key('clear_field')`, Ронин-1/08 T2): `Positioned`-оверлей
  поверх строки с зоной нажатия ≥ 40×32 (строку не раздвигает); активна (цвет
  `hazardOrange`), когда `placements` не пусто, иначе серая подписи и `onTap: null`;
  нажатие → `_cancelDrag()` + `PackController.clear()` (все куски в лоток в исходном
  порядке). Есть в release. Порядок лотка — `prepared.trayOrder` (перемешан от seed
  уровня, D-007), не порядок id.
- Лоток фиксированного размера (Ронин-1/08 T2): `Key('packing_tray')`, ширина — вся
  (с внешними отступами 12), высота `_trayZoneHeight` = 2·1 рамка + 2·12 паддинг + 160 ряд
  кусков (`_trayRowMaxHeight`) + 6 зазор + 14 подпись (`_trayLabelHeight`) = **206**; ряд
  кусков — `SizedBox(160)` с горизонтальным скроллом, куски по центру по вертикали. Лоток не
  сжимается по мере опустения — поле над ним не прыгает. Та же `_trayZoneHeight` уходит в
  расчёт клетки поля.
- Размер клетки поля — **адаптивный**: `_computeCellSize(constraints, boardWidth, boardHeight)`
  = `max(8, min(34.0 канон, (maxHeight - 44 топбар - 34 прогресс - 206 лоток - 16 паддинг
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
  Клетка лотка `_trayCellSize = min(32, 160 / h)` (32 — канон мокапа/прототипа Стори 01, ~0.8
  полевой), `h` — наибольшая высота куска уровня (`max(cell.y)+1`); считается один раз в
  `_rebuild()`, та же величина и по ширине — ряд лотка не выше 160 px при любом куске
  (Ронин-1/07 T2).
- **Конфигурация нарезки** (dev-переключатель Ронин-1/07; значения `bigPieces` — «Крупные куски» и `spikyPieces` — «Колючие куски», Ронин-1/04 T3):
  `static SliceConfig GameScreen.sliceConfig` (по умолчанию `bigPieces`, в т.ч. в release)
  живёт вне `State` до перезапуска приложения и действует на все уровни. Смена в чит-меню
  (`_cheatSetSliceConfig`) → запись в поле + `_restartLevel()` (пересборка текущего уровня с
  ТЕКУЩИМ `_seedOffset`, сброс драга); `_seedOffset` — сдвиг от канонного `RoninPartDef.seed` детали (стартует с 0); «Пересобрать нарезку» = `_seedOffset++` + тот же `_restartLevel()`.
- Топбар (канон `.topbar`/`.title`/`.pausebtn` мокапа `ukladka-field.html`, высота 44,
  Ронин-1/01 T4): слева заголовок из двух строк — `.kick` «ДЕТАЛЬ N / M»
  (N=`fragmentIndex+1`, M=`RoninParts.parts.length`=15) и `.name` название детали заглавными
  (`RoninParts.parts[fragmentIndex].title.toUpperCase()`, напр. «НОС»); свотча
  материала в топбаре больше нет (был у прежнего чипа, Стори 02 T3). Справа dev-кнопки
  (`Key('cheat_button')` под `kDebugMode`, `Key('ship_button')`). Виджеты `_PartTitle`
  (заменил `_PartChip`/`_Swatch`) / `_DevButton`. Заголовок — `Expanded` (зазор 8 до кнопок),
  строка `.name` в `FittedBox(scaleDown, centerLeft)`: длинное название ужимается, не
  переносится и не переполняет топбар от 360 dp (Ронин-1/01 T5).
- Drag-and-drop — сырые pointer-события `Listener` (`onPointerDown/Move/Up/Cancel`, НЕ
  `GestureDetector.onPan*` — фикс возврата Гейта 2 Стори 01: лоток
  `SingleChildScrollView(Axis.horizontal)` выигрывал `onPan*` в gesture arena, кусок не
  следовал за пальцем; raw pointer в арене не участвует). **Захват с лотка — по направлению**
  (Ронин-1/08 T3): касание куска лотка драг не стартует, а запоминает кандидата
  (`_candidateId`/`_candidateDown` + позиция прокрутки на касании); на движении дальше
  `kTouchSlop` (18): `|dy| ≥ |dx|` → `_startDrag` с текущей точкой, иначе кандидат сброшен и
  жест остаётся прокрутке лотка (её recognizer один в арене и выигрывает на касании) — в этом
  касании драг уже не стартует. Отпускание/отмена без старта — сброс, ничего не уложено.
  **После старта драга лоток не листается:** `_freezeTrayScroll` → `_trayScroll.position
  .jumpTo(позиция на касании)` — новая активность позиции утилизирует начатый drag прокрутки
  (`Scrollable._drag = null`), дальнейшие движения и отпускание этого пальца лоток не двигают и
  не бросают инерцией; сдвиг лотка в пределах slop откатывается. С поля
  (`_onBoardPointerDown`) захват сразу — поле не листается. Плавающий фидбэк
  `Key('packing_drag_feedback')` (graphite). **Геометрия поднятого куска** — один метод
  `_dragPieceRect(pointer, piece)`: размер = клетка поля × габарит куска, `left = p.x − w/2`,
  `top = p.y − _dragLiftGap(32) − h` (по центру X, низ выше пальца на 32 ≈ 1 клетка; подбирается
  на устройстве); им пользуются и `_buildFeedback`, и `_anchorAt`. Отпустил над силуэтом → `place`/`move`, вне поля с уложенного → `remove` (в лоток),
  `onPointerCancel` → сброс без укладки. Клетки лотка/драга — `graphite`
  (`el-piece-tray`/`el-piece-drag`), уложенные — куски рисунка детали (`PackingPainter`, Ронин-1/03).
  Снап-превью (`el-drop-ok`/`el-drop-bad`) пересчитывается в `build` (`_computePreview` →
  `PackController.canPlace`) и передаётся `PackingPainter.dragPreview`.
- Завершение — **пауза «деталь собрана»** (Ронин-1/05 T1, канон `.proglbl.done`/`.donebtns`
  мокапа `ukladka-field.html`): `isComplete` (и чит «Победить») → сразу, идемпотентно
  (`_markDone`, флаг `_done`) `ProgressService.completeLevel(levelIndex)` + пауза; автоперехода
  нет. На паузе: строка над полем — `Key('packing_complete')` «ДЕТАЛЬ СОБРАНА» (по центру,
  `hazardOrange` 12 px, .24em, тень `doneGlow` blur 12; «Очистить поле» скрыта); пульс-ободок
  `doneGlow` на поле; зона лотка заменена `Key('done_buttons')` той же высоты 206 (ряд кнопок
  сверху, отступы 14/10/10, зазор 10, подпись лотка — пустое место): слева
  `Key('done_to_ship_button')` «К кораблю» (`gunmetal`/`matteBlack`/`#cbd2d9`), справа
  `Key('done_next_button')` «Следующая деталь» (основная: рамка 2 `hazardOrange`, `#f0d6c2`),
  высота 44, радиус 10, 12 px .05em (`_DoneButton`). На последней детали — одна «К кораблю»
  на всю ширину в основном стиле. Поле и лоток касаний не принимают (`_done` в
  pointer-обработчиках). Переходы дожидаются записи прогресса (`_progressSaved`), повторное
  нажатие игнорируется (`_leaving`): «Следующая деталь» → `GameScreen(levelIndex+1)`;
  «К кораблю» → `ShipScreen.afterWin(collectedCount: levelIndex+1, onContinue: →
  GameScreen(levelIndex+1))`; на последней → `ShipScreen.finale()`. Пересборка уровня
  дев-читами нарезки снимает паузу. Solve-хук `_solveAll()`
  (раскладка по `PackSlice.solution`) — дев-кнопка `Key('cheat_solve')` И programmatic-хук
  для тестов (доводит до `isComplete` без симуляции drag). `FeedMode {fullSet, tray3}`
  объявлен в `game_screen.dart` (в `tray3` в лотке первые 3 из `trayOrder` + индикатор «+N»).
- `ShipScreen({art})` — ручной экран корабля-композит (канон `docs/design/ronin-ship.html`,
  Ронин-1/02 T2): фон `spaceBg`, без `AppBar`. Верх `.dtop` (поля 16, отступ 4, высота 38):
  слева `Key('ship_back_button')` 34×34 (`matteBlack`/`gunmetal`/глиф `hudIcon`, `pop`),
  по центру «РОНИН · СБОРКА» (9 px) и `Key('ship_collected_text')` «N / 15» (13 px; N =
  `ProgressService.getCollectedCount()` 0..15, читается один раз в `initState`), справа
  пустое место 34 (кнопки «⤢» нет). Центр — `ShipCompositePainter`
  (`ship_render`) на всю свободную область. Низ — `Key('ship_continue_button')`
  «Продолжить сборку» (поля 16, высота 44, радиус 10, рамка 2 `hazardOrange`) → `pop`.
  `SafeArea(minimum: bottom 22)` (`.safe.b`). `art` — рисунок (`ShipArt`), `null` →
  `RoninArt.shared` (картинки слоёв записываются раз за запуск; тот же экземпляр рисует поле). Вход —
  `Key('ship_button')` на `GameScreen`.
- `ShipScreen.afterWin({required collectedCount, required onContinue, art})` — маршрут
  «К кораблю» с паузы (Ронин-1/05 T1): тот же макет, деталь `collectedCount-1` въезжает
  scale-in (400 мс, easeOut), без «Назад» (слева пустое место 34), «Продолжить сборку»
  (`ship_continue_button`) → `onContinue`. Прогресс не читает и не пишет.
- `ShipScreen.finale({art, animateLast = true})` — финал «Ронина-1»: собрано N (15 / 15),
  последняя деталь въезжает при `animateLast`; ни «Назад», ни кнопок; на месте кнопки
  (высота 44) — `Key('ship_finale_text')` «ПРОДОЛЖЕНИЕ СЛЕДУЕТ» (стиль «ДЕТАЛЬ СОБРАНА»);
  только в `kDebugMode` под ней `TextButton` `Key('ship_dev_reset')` «Сброс прогресса (dev)» →
  `ProgressService.reset()` → `pushReplacement(GameScreen(0))`. Прогресс финал не трогает.
- `CheatMenu({onSelectLevel, onInstantWin, onSetShipParts, feedMode, onSetFeedMode,
  onReshuffle, onSolve, sliceConfig, onSetSliceConfig, levelCount?})` / `showCheatMenu(...)` — дев-читы (bottom sheet).
  Только вид: логика — колбэки в `GameScreen`. Вход — `Key('cheat_button')`, виден лишь под
  `kDebugMode`. Секции: выбор уровня (прогресс не меняет), мгновенная победа (пауза
  «деталь собрана», `_markDone`), состояние корабля (N=0..`kShipPartCount`, пишет
  `setCollectedCount(N)` — «15» даёт 15 / 15), **подача** (`Key('feed_full')`/`Key('feed_tray3')`
  — тумблер `FeedMode`), **нарезка: калибровка** (Ронин-1/07; по кнопке на значение
  `Key('slice_config_<имя>')` (две — `bigPieces` «Крупные куски», `spikyPieces` «Колючие куски») в порядке `SliceConfig.values`, текущая —
  префикс «✓ »; перед секцией «Нарезка (dev)»), **нарезка (dev)** (`Key('cheat_reshuffle')` — пересобрать; `Key('cheat_solve')`
  — solve-хук). Зарядов взрыва и «Прототипа укладки» больше нет (выпил в Стори 02).
  `levelCount` по умолчанию `null` → `kShipPartCount` уровней.

## Зависит от

- `game_engine/packing` (`PackController`/`PackState`/`PackPiece`/`SliceConfig`/`prepareLevel`),
  `game_engine/models` (`TargetMask`), `game_engine/data` (`LevelMap`, `RoninParts` — только
  чтение, название детали для топбара, Ронин-1/01 T4),
  `application` (`ProgressService`), `presentation/theme` (`BlockMaterial`; `ShipMaterials` — нет,
  Ронин-1/03), `presentation/widgets` (`PackingPainter`; `kShipPartCount` из `ship.dart` —
  только `cheat_menu`, `game_screen` с Ронин-1/05 T1 берёт `RoninParts.parts.length`),
  `presentation/ship_render` (`ship_screen`: `ShipCompositePainter`,
  `ShipArt`, `RoninArt.shared`; `game_screen`: `RoninArt.shared` для поля, Ронин-1/03; Ронин-1/02
  T2 — `ShipPainter` экраном больше не используется). `GameScreen` больше НЕ зависит от
  `game_engine/game`, `game_engine/rules`, `widgets/board_painter`, `widgets/hud`,
  `theme/level_skin` (пересадка на укладку, Стори 02 T2).
- `cheat_menu.dart` импортирует `FeedMode` из `game_screen.dart` (взаимный импорт —
  допустим в Dart; enum живёт у экрана, меню лишь типизирует параметр).
- `ship_screen.dart` ↔ `game_screen.dart` — взаимный импорт (Ронин-1/05 T1): игра открывает
  корабль, финал (дев-сброс) возвращает в `GameScreen(0)`; `afterWin` возвращает в игру
  колбэком `onContinue` от `GameScreen`.
- Это композиционный корень — потому зависимостей больше «правила трёх модулей»; ожидаемо
  для верхнего экрана, глубже дробить незачем.

## От него зависят

- `lib/main.dart` — точка входа (`ProgressService.getCollectedCount()`: `== N` →
  `ShipScreen.finale(animateLast: false)`, иначе `GameScreen(levelIndex: собрано)`).

## Инварианты

- Отдельного игрового цикла больше НЕТ (ядро укладки без гравитации/тиков): вместо
  gravity-тикера — лёгкий пульс-`AnimationController.repeat(reverse)` только для ободка
  «готово». Состояние укладки мутируется `PackController` (`place`/`move`/`remove`) в
  pointer-обработчиках, не по тику.
- Мутация ядра (`PackController`) — только через сам контроллер; `PackState`/`PackPiece`
  иммутабельны. Невалидная укладка — no-op контроллера (не бросает).
- Навигация: захватить `NavigatorState` (`Navigator.of(context)`) ДО `pushReplacement`;
  после ухода с экрана `context` не трогать (проверка `mounted`). Сборка детали
  обрабатывается один раз (`_done`) — сразу, без задержки; чит «мгновенная победа» — так же.
- Поток после сборки (Ронин-1/05 T1): Game → `completeLevel` (+1 сразу) → пауза →
  «Следующая деталь» → Game(следующий) | «К кораблю» → `ShipScreen.afterWin` →
  «Продолжить сборку» → Game(следующий). Прогресс +1 ровно один раз на обоих маршрутах.
  На последней детали (индекс N−1) → только «К кораблю» → `ShipScreen.finale` (15 / 15,
  «продолжение следует»); прогресс НЕ сбрасывается, «Начать заново» нет — сброс только
  дев-кнопкой финала. Перезапуск при собрано N открывает финал (`main.dart`).
- Ручной экран корабля открывается `Navigator.push` (НЕ `pushReplacement`; `afterWin`/`finale`
  — наоборот, `pushReplacement` с паузы): `GameScreen` остаётся
  под стеком, «Назад» (`ship_back_button`) или «Продолжить сборку» возвращают в ту же партию.
- У `GameScreen` нет `AppBar` → его `body` обёрнут в `SafeArea` вручную; иначе шапка
  (в т.ч. кнопка «Корабль») уходит под системный статус-бар/вырез и не нажимается.
- Drag: `_boardKey` — origin координат клеток поля (globalToLocal). Якорь укладки —
  клетка, ближайшая к верх-левому углу `_dragPieceRect` (`(local / cell).round()`), вне
  `0..width-1 × 0..height-1` → `null`; снап-превью и `_endDrag` используют один расчёт
  `_anchorAt`, а фидбэк — тот же `_dragPieceRect` (превью, итог и рисунок не расходятся).
- Кусок лотка — только `Listener` (не `GestureDetector`/`onPan`, см. выше); виджет
  куска лотка исчезает на старте драга, но события пальца доходят до его `Listener` —
  путь hit-test закреплён на касании.
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
