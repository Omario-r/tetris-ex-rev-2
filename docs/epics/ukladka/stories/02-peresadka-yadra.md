# STORY 02 — Пересадка ядра и выпил старого

**Эпик:** Укладка — новое ядро сборки детали
**Статус:** в работе (нарезана на задачи 2026-07-22; Постановщик ведёт)

> Вердикт PO «Да» на контрольной точке (Стори 01) получен 2026-07-20; дизайн-гейт
> снят 2026-07-22 (мокап `docs/design/ukladka-field.html` утверждён PO). Стори
> нарезана и едет. См. «Открытые вопросы к PO» — закрыт.

## Ценность

Пользователь может **играть в основном игровом экране новым ядром укладки** (без
гравитации, таймера и проигрыша: перетаскивает кусочки в силуэт детали, всегда
может переложить), чтобы **основной поток игры шёл на новом ядре**, — а старое
тетрис-ядро и взрыв **удалены из проекта без зомби-кода**.

## Критерии приёмки

- [ ] `game_screen` работает на укладка-движке из Стори 01: выбор уровня →
  укладка кусочков в силуэт детали → «силуэт заполнен без дыр» = деталь собрана
  → прирост корабля (мета из эпиков #2–#4 работает как есть).
- [ ] Старого ядра в основном потоке нет: гравитация, тики падения, спавн
  тетромино **удалены** (не спрятаны за флагом); в игре нет падающих фигур.
- [ ] Взрыв удалён целиком: кнопка, заряды, HUD-элементы взрыва — нет мёртвых
  кнопок/индикаторов на экране, нет вызовов `rules/explosion` из основного потока.
- [ ] Тесты, покрывавшие удалённое поведение (падение/спавн/коллизии тетромино/
  взрыв/заряды), **сняты или адаптированы в этой же стори** — проект остаётся
  зелёным: `flutter analyze` — 0, `flutter test` — зелёный.
- [ ] Чит-меню продолжает работать в новом ядре (выбор уровня, мгновенное
  завершение, установка состояния корабля — VISION «тестируемость без прохождения»).

## Не входит

- Движок укладки и генератор нарезки — готовы в Стори 01, здесь только
  подключаются к основному экрану.
- Финальная чистка давно висящего мёртвого кода (`rules/rotation.dart`,
  `application/game_loop.dart`-стуб) и адаптация дев-контента/сквозного смоука —
  Стори 03. Здесь снимаем только тесты, ломающиеся из-за выпила старого ядра.
- Вращение кусочков.
- Новая иконка приложения (канистра-заряд) — хвост перед стором (BACKLOG).

## Контекст для нарезки

- **`game_screen` — единственный композиционный корень партии** (ARCHITECTURE):
  тянет ядро, данные, виджеты, игровой цикл (`AnimationController`/`Ticker`).
  Пересадка = замена внутренностей партии, мета-обвязка (переход к кораблю,
  прогресс `ProgressService`) сохраняется.
- **Выпил взрыва тянет шире, чем кажется** (риск эпика): заряды вплетены в HUD,
  уровни, тесты (эпик #3 «gotovnost/02-vzryv-knopka»). Резать честно: кнопка,
  заряды, HUD-элементы, `rules/explosion`-вызовы, связанные тесты.
- **Зелёный после стори — обязателен.** Удаление старого ядра ломает тесты,
  которые его покрывают; поэтому их снятие/адаптация — часть ЭТОЙ стори, не
  откладывается в Стори 03 (иначе проект красный между стори).
- **Условие победы меняется:** было «halo пусто вокруг мишени + расчистка взрывом»
  (эпик «Контент»), стало «силуэт заполнен без дыр». Проверить, что мета-переход
  (деталь собрана → прирост корабля → финал-сброс) завязан на новое условие.
- Модули под удаление/правку — по карте ARCHITECTURE: `game_engine/game`,
  `game_engine/rules` (collision/explosion/randomizer/rotation — что относится к
  падению/взрыву), `presentation/screens/game_screen`, `presentation/widgets/hud`.
  При нарезке держать «правило трёх модулей» — вероятно несколько задач.

## Затронутые модули

- `lib/presentation/screens/` — `game_screen` на новое ядро; `cheat_menu`
  (прототип-вход из Стори 01 → чистовой вход, если решит Постановщик).
- `lib/game_engine/` — выпил старого ядра партии (спавн/падение/коллизии
  тетромино, взрыв); подключение укладка-движка из Стори 01.
- `lib/presentation/widgets/` — `hud` (выпил элементов взрыва/зарядов), пейнтеры.

> Затрагивает > 3 модулей на уровне стори → при `веди эпик` резать на несколько
> задач по ≤ 3 модуля каждая.

## Открытые вопросы к PO

_Закрыт._ Решение PO 2026-07-20: **(A) дизайн-сессия сначала.** Перед декомпозицией
Стори 02 проводится дизайн-сессия (`system/DIZAINER.md`) на канон нового игрового
экрана (топбар без взрыва/зарядов, лоток кусочков, силуэт детали); Стори 02
режется и едет уже на утверждённых мокапах. Инициирует сессию PO командой
«дизайн-сессия по эпику Укладка». До готовых мокапов Стори 02 не декомпозируется
(предусловие декомпозиции — `POSTANOVSHCHIK.md` § 3: «Затронутые экраны» должны
быть утверждены PO).

## Задачи

> Нарезано Постановщиком 2026-07-22 (после дизайн-сессии и закрытия хвоста
> Стори 01). Порядок = порядок выполнения. Зависимость строго линейная:
> T1 (пейнтер+токены) → T2 (пересадка экрана, потребляет T1) → T3 (выпил старого
> UI, безопасен после T2) → T4 (выпил старого ядра-движка, безопасен после T3).
> Выпил старого ядра разнесён по модулям (риск «выпил тянет шире» + правило трёх
> модулей): T3 — presentation-слой (`widgets`/`theme`), T4 — движок
> (`game`/`rules`/`models`). Финальная зачистка (`level_map`/`level_template`/
> `halo`/`chargeBudget`/`rotation`/`game_loop`, сквозной смоук по всему контенту,
> `Board`) — Стори 03; здесь оставляем их компилируемыми и зелёными.

### T1 — Токены укладки + канон пейнтера (снап-превью, материал детали)
- **Статус:** сделана (2026-07-22). `flutter analyze` — 0 ошибок/предупреждений
  (`flutter analyze` → «No issues found!»). `flutter test` — 391/391 зелёных
  (полный прогон), в т.ч. новый `test/presentation/packing_painter_test.dart`
  (6/6: partMaterial красит клетки разных кусочков в один цвет — проверено
  пиксель-сэмплингом рендера; без `partMaterial` поведение не падает; `dragPreview`
  не падает на valid:true/false и на клетках за границами силуэта; `shouldRepaint`
  реагирует на появление/смену `dragPreview` и `partMaterial`, не реагирует на
  равный по значению `PackDragPreview`). Существующие тесты пейнтера/прототипа
  (`packing_prototype_screen_test.dart`, весь сквозной прогон) не задеты — новые
  поля `partMaterial`/`dragPreview` опциональны. Паспорт
  `lib/presentation/widgets/README.md` обновлён (новые возможности `PackingPainter`,
  `PackDragPreview`, новые токены). Визуал (оранжевый/красный, материал) —
  проверка Постановщика на Гейте 2, вне скоупа этой задачи.
- **Рекомендованный агент:** Исполнитель · Claude (Sonnet, `ispolnitel`)
- **Цель:** привести `PackingPainter` к утверждённому канону мокапа укладки —
  живое снап-превью при драге (оранжевый «ляжет» / красный «нельзя»), уложенные
  клетки цветом **материала детали** (а не циклической палитрой прототипа), плюс
  ввести новые цвет-токены. Пейнтерная база, которую потребляет T2.
- **Модули (≤ 3):** `lib/presentation/widgets/` (паспорт: `lib/presentation/widgets/README.md`) — `packing_painter.dart`; `lib/presentation/theme/` (паспорт: `lib/presentation/theme/README.md`) — размещение новых цвет-токенов.
- **Что сделать:**
  1. **Новые токены.** Добавь как `static const Color` (вычисли ARGB из HSL
     детерминированно, как существующий `hudIcon`/`boardBg` — HSL-спеки уже в
     `docs/DESIGN.md`, строки `dropOk`/`dropBad`/`trayBg`/`doneGlow`). Размести на
     `PackingPainter` рядом с существующим `boardBg` (файл-держатель визуал-канона
     укладки), с `///`-комментарием «токен docs/DESIGN.md»:
     `dropOk` `hsl(23 62% 55% /90%)`, `dropOkFill` `hsl(23 62% 46% /20%)`,
     `dropBad` `hsl(2 60% 50% /60%)`, `dropBadFill` `hsl(2 60% 42% /18%)`,
     `trayBg` `hsl(220 13% 9%)`, `doneGlow` `hsl(30 70% 60% /55%)`.
  2. **Материал детали для уложенных клеток.** Добавь в конструктор
     `PackingPainter` необязательное поле `BlockMaterial? partMaterial`. Если
     задано — ВСЕ уложенные клетки красятся `partMaterial` (единый материал =
     собранная деталь корабля, канон `el-cell-filled`). Если `null` — прежнее
     поведение (циклическая `materialForPiece`) сохраняется без изменений
     (обратная совместимость: T1 не трогает вызовы). Учти `partMaterial` в
     `shouldRepaint`.
  3. **Снап-превью (drop-ok / drop-bad).** Добавь необязательное поле
     `PackDragPreview? dragPreview`, где `PackDragPreview` — маленький
     immutable-класс в `packing_painter.dart`:
     `final List<PackCell> cells; final bool valid;` (`cells` — АБСОЛЮТНЫЕ клетки
     силуэта, куда ляжет кусок при текущем якоре драга; `valid` — можно ли класть).
     Если `dragPreview != null`, поверх ghost и уложенных клеток нарисуй по каждой
     клетке `cells`: рамка 2px + заливка — `dropOk`/`dropOkFill` при `valid`,
     иначе `dropBad`/`dropBadFill` (канон `el-drop-ok`/`el-drop-bad`; рисуй ТОЛЬКО
     клетки, попадающие в границы поля — клетки вне `[0..width)×[0..height)`
     пропускай, как в мокапе). Учти `dragPreview` в `shouldRepaint`.
     `PackCell` — существующий тип клетки из `pack_piece.dart`/`pack_state.dart`
     (используй тот же, что у `PackState.occupiedCells`; не заводи новый).
  4. Обнови doc-комментарий класса и паспорт `widgets`: `PackingPainter` теперь
     умеет снап-превью и единый материал детали; перечисли новые токены.
- **Арх-дельта:** нет (связей между модулями не меняет; токены — внутри `theme`/
  `widgets`, зависимость `widgets → theme` уже есть).
- **Дизайн-референс:** мокап `docs/design/ukladka-field.html`, каталог элементов:
  `el-drop-ok` (снап «ляжет»: сплошной контур `dropOk` + заливка `dropOkFill`),
  `el-drop-bad` (снап «нельзя»: `dropBad` + `dropBadFill`), `el-cell-filled`
  (уложено = материал детали, воксель `el-block`), `el-cell-target` (ghost
  силуэта — уже есть, `ghostTarget`). Токены — `docs/DESIGN.md` (значения выше в
  «Что сделать» п.1). Уложенные клетки — материал детали (единый), НЕ циклическая
  палитра прототипа.
- **Результат (как проверить):** `flutter analyze` — 0; `flutter test` — зелёный
  (существующие тесты пейнтера/прототипа не падают, т.к. новые поля
  необязательны). Добавь юнит/виджет-тест на `PackingPainter`: (а) с `partMaterial`
  уложенные клетки одного цвета; (б) с `dragPreview(valid:true/false)` пейнтер не
  падает и `shouldRepaint` реагирует на смену превью. Визуал (оранжевый/красный,
  материал) сверяет Постановщик на Гейте 2.
- **DoD задачи:** код + тест пейнтера; обновлён паспорт `lib/presentation/widgets/README.md`
  (новые возможности `PackingPainter`, новые токены); `analyze` 0, `test` зелёный.

### T2 — Пересадка `GameScreen` на ядро укладки (мета-обвязка сохранена)
- **Статус:** сделана (2026-07-22). `flutter analyze` — «No issues found!» (0);
  `flutter test` — 381/381 зелёных (было 391; −10 из удалённого
  `packing_prototype_screen_test.dart`). `GameScreen` пересажен на ядро укладки:
  силуэт из `LevelMap.levelAt(levelIndex).targetMask`, материал детали
  `materialForPart(fragmentIndex)`, нарезка `slicePolyomino` → `PackController`;
  drag-логика (сырые pointer-события `Listener`) перенесена из удалённого
  прототипа; снап-превью через `PackingPainter.dragPreview` (T1), уложенные клетки
  — `partMaterial` (T1); топбар (`_PartChip`/`_DevButton`) сохранён; прогресс-бар
  `rust→hazardOrange`, лоток `trayBg` + подпись + тумблер `FeedMode`/«+N»; победа
  `PackState.isComplete` → баннер `packing_complete` + пульс `doneGlow` → ~900 мс →
  прежний мета-поток `_onWin` (дословно). Solve-хук `_solveAll` (`Key('cheat_solve')`
  + programmatic для тестов). Старое ядро (`game`/`rules`/`BoardPainter`/`GameHud`/
  `level_skin`) `GameScreen` больше не импортирует (файлы движка живы — выпил в
  T3/T4). Удалён `packing_prototype_screen.dart` + его тест. Чит-меню: убраны
  заряды и «Прототип укладки», добавлены «Подача» (`feed_full`/`feed_tray3`),
  «Пересобрать нарезку» (`cheat_reshuffle`), «Решить» (`cheat_solve`). Переписаны
  тесты `game_screen_test`/`cheat_menu_test`/`win_flow_test` под укладку;
  `navigation_test` не менялся (не ассертил старое ядро); `golden_scenario_test`
  не тронут (живёт до T4). **Заметка для T3/Стори 03:** win_flow гоняет один
  уровень укладкой (solve-хук) + мета-ветку последнего уровня читом — полный
  прогон всего контента реальной укладкой отложен в Стори 03.
- **Рекомендованный агент:** Исполнитель (**тяжёлая**) · Claude (Opus, `ispolnitel-heavy`)
- **Цель:** основной игровой экран играется новым ядром укладки по утверждённому
  мокапу: тянешь кусочки из лотка в силуэт детали, снап-превью, заполнил без дыр
  → деталь собрана → прежний мета-поток (прирост корабля). Старое ядро из
  `GameScreen` отключено (файлы движка ещё существуют — их выпил в T3/T4).
- **Модули (≤ 3):** `lib/presentation/screens/` (паспорт: `lib/presentation/screens/README.md`) — `game_screen.dart` (переписать нутро партии), `cheat_menu.dart` (читы под новое ядро), удалить `packing_prototype_screen.dart` (замещён). Потребляет (только чтение) `game_engine/packing`, `game_engine/data` (`LevelMap`), `presentation/widgets` (`PackingPainter` из T1), `presentation/theme`.
- **Что сделать:**
  1. **Силуэт уровня.** В `initState`/при выборе уровня бери силуэт из
     `LevelMap.levelAt(widget.levelIndex).targetMask` (единый источник «уровень i
     ↔ деталь i» сохраняется), `fragmentIndex = level.fragmentIndex`, материал
     детали `ShipMaterials.defaultMaterials.materialForPart(fragmentIndex)`.
  2. **Ядро укладки.** По образцу `packing_prototype_screen.dart`: поле `_seed`,
     `_rebuild()` → `slice = slicePolyomino(silhouette, seed:_seed)`,
     `PackController(PackState(silhouette, placements:{}, pieces: slice.pieces,
     trayOrder:[все id]))`; сохраняй `slice.solution` для solve-хука (п.9).
  3. **Drag-and-drop.** Перенеси из прототипа как есть логику сырых pointer-событий
     (`Listener` `onPointerDown/Move/Up/Cancel`, НЕ `GestureDetector.onPan*` —
     это фикс возврата Гейта 2 Стори 01, лоток-скролл выигрывал арену):
     `_onBoardPointerDown`, `_startDrag`, `_onDragUpdate`, `_endDrag`,
     `_cancelDrag`, `_globalToLocal`, `_pieceAt`, `_pieceBoundsPx`,
     `_dragLiftPx=56`, `_boardKey`, `_stackKey`, плавающий фидбэк `_buildFeedback`
     (`Positioned` в `Stack`, офсет над пальцем). Лоток — `Listener` на каждом
     кусочке. Клетки лотка/драга красятся **graphite** — передавай
     `BlockMaterial.graphite` в `PackingPainter.paintPiece(...)` при отрисовке
     кусочка в лотке и плавающего фидбэка (как прототип передаёт материал в
     `_PieceCellsPainter`; сырой кусок `el-piece-tray`/`el-piece-drag`).
     Уложенные клетки — материал детали (через `PackingPainter.partMaterial`, T1).
  4. **Снап-превью.** При КАЖДОМ `onPointerMove` (в `_onDragUpdate`, через
     `setState`) пересчитывай якорь (клетка поля под верх-левым углом всплывшего
     куска, как в `_endDrag`) и валидность через
     `PackController.canPlace(state, pieceId, atX, atY, ignoreId: fromTray ? null
     : pieceId)`; собери абсолютные `cells` куска при этом якоре и передавай
     `PackingPainter(dragPreview: PackDragPreview(cells, valid))` (T1) — поле
     подсвечивает оранжевым/красным. Когда драга нет — `dragPreview: null`.
     Точная сигнатура `PackDragPreview` уже реализована в T1 — сверься с
     `packing_painter.dart` (`cells` — список record-клеток `({int x, int y})`,
     тот же тип, что у `PackState.occupiedCells`; отдельного `PackCell` в проекте
     нет).
  5. **Топбар.** Сохрани как есть уже существующие в текущем `game_screen.dart`
     виджеты `_PartChip` (чип «ДЕТАЛЬ N/7» со свотчем материала детали) и
     `_DevButton` (dev-кнопки): слева чип, справа кнопки — чит (`Key('cheat_button')`,
     под `kDebugMode`) и корабль (`Key('ship_button')`). Их код переносить/
     переписывать не нужно — только сохранить при переписывании нутра экрана.
     Гамбургер/имя секции из
     мокапа — иллюстративны, НЕ реализуем (имён деталей в контенте нет — решение
     PO из Стори-02-T3).
  6. **Прогресс-бар.** Под топбаром — `.prog` (высота 6, `matteBlack` фон,
     `gunmetal` рамка 1px, radius 3) с полосой заполнения шириной
     `occupiedCells.length / silhouette.cells.length`, градиент `rust→hazardOrange`;
     подпись `.proglbl` «уложено N / M кусков» (N = `state.placements.length`,
     M = `state.pieces.length`).
  7. **Лоток (мокап `.tray`/`.traylbl`).** Нижняя полка: фон `trayBg` (T1), рамка
     `gunmetal` 1px, скруглены верхние углы (radius 14), горизонтальный скролл-ряд
     кусочков (как в прототипе, `SingleChildScrollView(Axis.horizontal)`); подпись
     «ЛОТОК · ПОЛНЫЙ НАБОР» / «ЛОТОК · ПОРЦИЯ-3». Тумблер подачи `FeedMode
     {fullSet, tray3}` (перенеси enum в `game_screen.dart`): в `tray3` показывай
     первые 3 из `trayOrder` + индикатор «+N» на остаток. Режим хранится в
     состоянии экрана, переключается из чит-меню (п.8).
  8. **Чит-меню (`cheat_menu.dart`).** Убери из сигнатуры `showCheatMenu`/`CheatMenu`
     колбэки `onSetCharges` и `onOpenPrototype` (взрыв и прототип уходят). Добавь
     `FeedMode feedMode` (текущий) + `ValueChanged<FeedMode> onSetFeedMode`
     (секция «Подача»: `Key('feed_full')`/`Key('feed_tray3')`) — это и есть
     «тумблер подачи в чит-меню» из границ эпика. Оставь читы: выбор уровня,
     мгновенная победа, состояние корабля. **Мгновенная победа** остаётся
     мета-уровневой (`_handleWin` → `advanceOnWin`), движок не трогает. Добавь
     дев-чит «Пересобрать нарезку» (`_reshuffle`, инкремент `_seed`) — удобство
     дев-сборки. Помни: контент чит-меню уже в `SingleChildScrollView` — новую
     секцию отдельно не оборачивать. Добавь в `showCheatMenu`/`CheatMenu`
     параметр `VoidCallback onReshuffle` и кнопку `Key('cheat_reshuffle')` в чит-
     листе; `GameScreen` реализует его как `_reshuffle` (`setState` → инкремент
     `_seed` → `_rebuild`).
  9. **Победа / завершение.** Условие победы — `state.isComplete` (силуэт заполнен
     без дыр), НЕ старое `GameState.isWin`. Конкретная реализация (не «интерпретируй
     мокап»): переиспользуй структуру `_buildCompleteBanner` из прототипа —
     `Positioned.fill` поверх `Stack`, `Key('packing_complete')`, полупрозрачная
     подложка (`Colors.black54`), по центру `Column`: текст «ДЕТАЛЬ СОБРАНА»
     (белый, ~22, bold). Дополнительно на `Container` поля навесь пульс-ободок
     `BoxShadow` цветом `doneGlow` (канон `board.complete`), амплитуда по значению
     `AnimationController`. Кнопку «Заново» из прототипа НЕ показывай — вместо неё
     через ~900 мс идемпотентно (`_winHandled`) запусти прежний мета-поток `_onWin`
     (`ProgressService.advanceOnWin` → `ShipScreen.reveal(...)` → «Далее»/«Начать
     заново», последний уровень → `reset()` → `GameScreen(0)`) — эту обвязку
     сохрани дословно. Пульс `doneGlow` — лёгкий `AnimationController` (repeat),
     заменяет прежний gravity-тикер; отдельного игрового цикла больше нет.
     **Solve-хук:** метод `_solveAll()` (раскладывает по `slice.solution` через
     `_controller.place`) под `kDebugMode` (дев-кнопка в чит-меню, `Key('cheat_solve')`)
     И как programmatic-хук для тестов — довести уровень до `isComplete` без
     симуляции drag-жестов (как в прототипе).
  10. **Выпил из `GameScreen`.** Убери: `GameController`, `GameState`,
      `BoardPainter`, `GameHud`, win/lose-текст-оверлей, gravity-тик
      (`_onTick`/`tick`), импорты `game_engine/game`, `game_engine/rules/randomizer`,
      `game_engine/models/board`, `widgets/board_painter`, `widgets/hud`,
      `theme/level_skin`. Адаптивный `_computeCellSize` пересчитай под новый макет
      (топбар + прогресс + поле + лоток влезают без `RenderFlex overflow` на 375×812
      и на коротких экранах; поле центрируется). `game_screen.dart` больше НЕ
      импортирует старое ядро.
  11. **Удали** `packing_prototype_screen.dart` (замещён основным экраном) и его
      тест `test/presentation/packing_prototype_screen_test.dart`. Убери из
      `cheat_menu` любые следы «Прототип укладки».
- **Арх-дельта:** `presentation/screens` теперь тянет `game_engine/packing` в
  `GameScreen` (а не только в снятом прототипе); зависимость `screens → game`,
  `screens → rules(randomizer)`, `screens → widgets(board_painter/hud)`,
  `screens → theme(level_skin)` из `GameScreen` УБРАНА (движок/HUD выпиливаются в
  T3/T4). В `ARCHITECTURE.md` строку `screens` не меняем сейчас (пока существуют
  старые модули — их удаление и правка схемы в T3/T4); зафиксируй факт в паспорте
  `screens`: `GameScreen` — на ядре укладки, прототип-экран удалён.
- **Дизайн-референс:** мокап `docs/design/ukladka-field.html`. Элементы:
  `.topbar`+`.chip` (чип детали — как в Стори-02-T3), `.prog`/`.proglbl`
  (прогресс заполнения), `.tray`/`.traylbl` (лоток + подпись, токен `trayBg`),
  `el-piece-tray`/`el-piece-drag` (кусок в лотке/руке — graphite, офсет над
  пальцем), `el-cell-filled` (уложено — материал детали), `el-drop-ok`/
  `el-drop-bad` (снап-превью, из T1), done-card + `board.complete` (пульс
  `doneGlow`). Токены: `trayBg` `hsl(220 13% 9%)`, `doneGlow` `hsl(30 70% 60% /55%)`,
  `graphite` `#484E56`, `gunmetal` `#32363E`, `matteBlack` `#1D2025`, градиент
  прогресса `rust #994C29 → hazardOrange #BE642D`.
- **Результат (как проверить):** `flutter analyze` — 0; `flutter test` — зелёный.
  Перепиши сломанные пересадкой тесты В ЭТОЙ ЖЕ задаче:
  `test/presentation/game_screen_test.dart` (укладка-UI: топбар-чип, лоток,
  прогресс, завершение через solve-хук → мета-поток), `test/presentation/cheat_menu_test.dart`
  (нет зарядов/прототипа, есть тумблер подачи), `test/navigation_test.dart` (если
  ассертит старый экран), `test/presentation/win_flow_test.dart` — доведи до
  ЗЕЛЁНОГО минимальным прогоном укладки (один уровень до `isComplete` через
  solve-хук → `ShipScreen.reveal`); **полный прогон всего контента до собранного
  корабля — Стори 03** (оставь заметку). `test/integration/golden_scenario_test.dart`
  в T2 НЕ трогай — он импортирует старое ядро, которое ещё существует (файлы живы
  до T4), поэтому остаётся зелёным; его удаление — T4. Поведение (drag следует за пальцем,
  снап оранжевый/красный, «деталь собрана») сверяет Постановщик на Гейте 2 на
  устройстве/Preview.
- **DoD задачи:** код + переписанные тесты; удалён прототип-экран и его тест;
  обновлён паспорт `lib/presentation/screens/README.md` (GameScreen на укладке,
  прототип удалён, читы под новое ядро); `analyze` 0, `test` зелёный.

### T3 — Выпил старого игрового UI: `BoardPainter`, `GameHud`, осиротевшие скины
- **Статус:** сделана (2026-07-22). Удалены `lib/presentation/widgets/board_painter.dart`,
  `lib/presentation/widgets/hud.dart` + тесты `board_painter_test.dart`/`hud_test.dart`.
  Grep-гейт по `lib/`, `test/`, `tool/` подтвердил чистоту — удалены осиротевшие
  скины `theme/level_skin.dart` (+ тест), `theme/scrap_block_skin.dart` (+ тест) и
  `HaloHighlightOverlay` (из `theme/overlays.dart`, статик-поле `BlockTheme.haloHighlight`
  из `block_theme.dart`) — единственным потребителем всех троих был `BoardPainter`.
  `GhostTargetOverlay` оставлен (нужен `PackingPainter`). `canister_charge_painter.dart`
  (+ `ChargeIconState`) **оставлен намеренно** — его единственный оставшийся
  потребитель `tool/generate_app_icon.dart` (генератор иконки приложения), grep по
  `lib/`/`test/` был бы ложным сигналом «осиротел». `block_material`/`block_paint_utils`
  (`paintElBlock` для `PackingPainter`)/`ship_materials`/`overlays.dart`
  (`GhostTargetOverlay`) не тронуты. Проверка: `flutter analyze` → «No issues found!»
  (0); `flutter test` → 353/353 зелёных (было 381; −28 из 4 удалённых тестовых файлов);
  `grep -rn "BoardPainter\|GameHud\|board_painter\|hud.dart" lib test` — только
  doc-комментарии/паспорта (историческая справка, не живые импорты), 0 живых ссылок.
  Паспорта `lib/presentation/widgets/README.md` и `lib/presentation/theme/README.md`
  обновлены (удалённые файлы, актуальные «Зависит от»/«От него зависят»). Старое
  ядро-движок (`game`/`rules`/`models`) не тронуто — его выпил в T4.
- **Рекомендованный агент:** Исполнитель · Claude (Sonnet, `ispolnitel`)
- **Цель:** удалить из presentation-слоя виджеты старого тетрис-ядра и их
  тесты + скины темы, ставшие ничьими после T2 — без зомби-кода.
- **Модули (≤ 3):** `lib/presentation/widgets/` (паспорт: README) — удалить `board_painter.dart`, `hud.dart`; `lib/presentation/theme/` (паспорт: README) — удалить осиротевшие скины.
- **Что сделать:**
  1. Удали `lib/presentation/widgets/board_painter.dart`, `lib/presentation/widgets/hud.dart`
     и тесты `test/presentation/board_painter_test.dart`, `test/presentation/hud_test.dart`.
  2. **Осиротевшие скины темы — удаляй ТОЛЬКО при grep-чистоте** (`grep -rn` по
     `lib/`, `test/` И `tool/` не находит живого импорта, кроме удаляемого файла и
     его теста). Кандидаты: `theme/level_skin.dart` (+ `level_skin_test.dart`) —
     `LevelSkin.materialForLevelIndex` использовал только `GameScreen`/`BoardPainter`;
     `theme/scrap_block_skin.dart` (+ `scrap_block_skin_test.dart`) — «scrap»-вид
     рисовал только `BoardPainter`. Проверь `block_theme.dart` (оверлеи): удали
     `HaloHighlightOverlay`, ТОЛЬКО если его больше никто не тянет; `GhostTargetOverlay`
     нужен `PackingPainter` — **оставить**. Если кандидат ещё кем-то используется —
     не удаляй, оставь заметку (это уже Стори 03).
  3. **НЕ удаляй:** `canister_charge_painter.dart` (+ enum `ChargeIconState`) —
     после выпила `hud.dart` его единственный оставшийся потребитель НЕ в `lib/`, а
     `tool/generate_app_icon.dart` (генератор иконки приложения для
     `flutter_launcher_icons`, см. `pubspec.yaml`); grep только по `lib/`/`test/`
     покажет файл осиротевшим — это ложный сигнал, НЕ удаляй (урок эпика
     «Готовность»: единый источник кнопки И иконки приложения). `block_material.dart`,
     `block_paint_utils.dart` (`paintElBlock` нужен `PackingPainter`),
     `ship_materials.dart`, `procedural_block_skin.dart`/`block_skin.dart` (если
     используются `paintElBlock`/кораблём), `overlays.dart` (`GhostTargetOverlay`).
  4. Обнови паспорта `widgets`/`theme` README (удалённые файлы) и, если удалил
     скины, соответствующие строки.
- **Арх-дельта:** связи между МОДУЛЯМИ не рвутся (и `widgets`, и `theme` остаются);
  меняется лишь состав файлов внутри. Строку `widgets`/`theme` в таблице
  `ARCHITECTURE.md` не трогаем (модули живы). Если по факту `theme` перестаёт
  зависеть от чего-либо — отметь в паспорте.
- **Дизайн-референс:** нет (чистое удаление, видимого не добавляет; после T2
  экран уже на укладке).
- **Результат (как проверить):** `flutter analyze` — 0 (нет висящих импортов);
  `flutter test` — зелёный; `grep -rn "BoardPainter\|GameHud\|board_painter\|hud.dart"
  lib test` не находит живых ссылок.
- **DoD задачи:** удалены файлы + тесты; обновлены паспорта `widgets`/`theme`;
  `analyze` 0, `test` зелёный, grep-чисто.

### T4 — Выпил старого ядра-движка: `game`, `rules`(взрыв/коллизии/генератор), падающая фигура
- **Статус:** не начата — ТЗ дополнено Постановщиком 2026-07-22 после эскалации
  Исполнителя (grep-гейт нашёл два неучтённых теста-потребителя в
  `game_engine/data`; решение и обоснование — в «Заметках по выполнению» ниже).
- **Рекомендованный агент:** Исполнитель · Claude (Sonnet, `ispolnitel`)
- **Цель:** удалить движок старого ядра (состояние партии, взрыв, коллизии,
  генератор, падающая фигура) и его тесты — после того как presentation его уже
  не тянет (T2/T3). Модуль `game` исчезает.
- **Модули (≤ 3):** `lib/game_engine/game/` (паспорт: README) — удалить целиком; `lib/game_engine/rules/` (паспорт: README) — удалить взрыв/коллизии/генератор; `lib/game_engine/models/` (паспорт: README) — удалить падающую фигуру/фигуру.
  Плюс **тест-only касание** `game_engine/data`: снять два теста старого ядра
  (п. 4а ниже) + одна строка паспорта. Логика/файлы `lib/game_engine/data/` НЕ
  меняются — это не 4-й модуль по смыслу правила (правило трёх охраняет от
  многомодульных ЛОГИЧЕСКИХ правок; снятие тестов удаляемого поведения по
  критерию приёмки №4 стори идёт туда, где эти тесты лежат).
- **Что сделать:**
  1. Удали `lib/game_engine/game/game_controller.dart`, `game_state.dart` (модуль
     `game` становится пустым → удали каталог и `game/README.md`) + тесты
     `test/game_engine/game/game_controller_test.dart`, `game_state_test.dart`.
  2. Удали `lib/game_engine/rules/explosion.dart`, `collision.dart`, `randomizer.dart`
     + тесты `explosion_test.dart`, `collision_test.dart`, `randomizer_test.dart`.
     **Оставь** `rules/halo.dart` (его зовёт `models/level_template`) и
     `rules/rotation.dart` (мёртвый стуб — его выпил в Стори 03).
  3. Удали `lib/game_engine/models/falling_piece.dart`, `piece.dart` + тесты
     `falling_piece_test.dart`, `piece_test.dart`. **Оставь** `target_mask.dart`
     (силуэт укладки), `level_template.dart`, `board.dart` (`Board` ещё держит
     `board_test.dart`/`halo`; его зачистка — Стори 03).
  4. Удали интеграционный `test/integration/golden_scenario_test.dart` (гонял
     старое ядро; сквозной смоук укладки пишется в Стори 03). Этот файл прописан
     в смоук-команде в ДВУХ местах — `docs/ARCHITECTURE.md` («Команды и смоук-тест»)
     и `PROJECT.md` («Смоук-тест / запуск проекта»); убери ссылку на удаляемый файл
     из ОБОИХ (иначе документированная смоук-команда сломается на несуществующем
     файле). Полный новый укладка-смоук по всему контенту — Стори 03; здесь только
     снимаем мёртвую ссылку.
  4а. **Сними два теста старого ядра в `game_engine/data`** (решение Постановщика
     по эскалации 2026-07-22, вариант (а) — см. «Заметки»):
     удали `test/game_engine/data/level_playthrough_test.dart` (сквозной прогон
     реальным падением `GameController.tick` — семантический дубль удаляемого
     `golden_scenario_test`) и `test/game_engine/data/level_charge_budget_test.dart`
     (гоняет `armExplosive`/`detonate`; его «структурная» часть проверяет
     `chargeBudget` — данные взрыва, которые Стори 03 удаляет целиком, тест
     обречённых данных не сохраняем). В паспорте `lib/game_engine/data/README.md`
     в «Как проверить» убери `level_playthrough_test.dart` из команды (остаются
     `level_map_test.dart` и `ship_parts_test.dart`); `lib/`-файлы модуля `data`
     НЕ трогай.
  5. **Перед удалением — grep-гейт:** каждый файл удаляй, лишь убедившись
     `grep -rn` по `lib/` и `test/`, что живых импортов (кроме удаляемых и их
     тестов) нет. После п. 4а полный список потребителей закрыт (сверено
     Постановщиком grep'ом 2026-07-22); если всплывёт ещё кто-то — стоп,
     эскалация Постановщику (нарезка кривая).
- **Арх-дельта (применяет Исполнитель в своём коммите):** в `docs/ARCHITECTURE.md`
  — **удалить строку модуля `game`** из таблицы «## Модули»; в строке `rules`
  описание сузить до «halo/победа (+ стуб rotation)»; в строке `models` убрать
  упоминания `FallingPiece`/`Piece` (осталось: поле/маска/шаблон уровня). В «Схема
  связей» убрать `game` из блока `game_engine` и стрелку `game ──► rules`;
  оставить `models ◄──► rules` (через `level_template → halo`) и `packing ──► models`.
  В `presentation/widgets`/`screens` строках убрать зависимость от `game` (её уже
  нет по факту T2/T3). Примечание про `charges`/взрыв в сквозных соглашениях —
  снять.
- **Дизайн-референс:** нет.
- **Результат (как проверить):** `flutter analyze` — 0; `flutter test` — зелёный;
  `grep -rn "GameController\|GameState\|ExplosionHandler\|CollisionDetector\|FallingPiece\|SevenBag\|explosion.dart\|collision.dart"
  lib test` не находит живых ссылок из основного потока.
- **DoD задачи:** удалены файлы + тесты + каталог `game` + два теста
  `game_engine/data` (п. 4а); применена арх-дельта (`ARCHITECTURE.md`); обновлены
  паспорта `rules`/`models` README (снятые файлы) и строка «Как проверить» в
  `data/README.md`; `analyze` 0, `test` зелёный, grep-чисто.

## Заметки по выполнению

- **T4 — эскалация Постановщику (2026-07-22), задача не начата в коде.**
  Перед первым удалением прошёл grep-гейт по ТЗ (п. «Что сделать» шаг 5) —
  `grep -rn` по `lib/` и `test/` на каждый удаляемый файл/символ
  (`GameController`, `GameState`, `randomizer.dart`/`SevenBagGenerator`/
  `FixedSequenceGenerator`, `explosion.dart`, `collision.dart`,
  `falling_piece.dart`/`FallingPiece`). Помимо файлов и тестов, перечисленных в
  ТЗ (`game_controller_test.dart`, `game_state_test.dart`, `explosion_test.dart`,
  `collision_test.dart`, `randomizer_test.dart`, `falling_piece_test.dart`,
  `piece_test.dart`, `golden_scenario_test.dart`), нашлись ДВА живых потребителя,
  которых в ТЗ нет:
  - `test/game_engine/data/level_playthrough_test.dart` — импортирует
    `game/game_controller.dart`, `game/game_state.dart`, `models/piece.dart`,
    `rules/randomizer.dart`; реально гоняет `GameController.tick` до победы
    (уровни 1 и 6).
  - `test/game_engine/data/level_charge_budget_test.dart` — те же импорты плюс
    вызовы `controller.armExplosive()`/`controller.detonate()` (косвенно тянет
    `rules/explosion.dart` через `GameController`); прогоняет уровни 0/1/2/6.
  Оба файла принадлежат модулю `game_engine/data` (тесты + строка «Как
  проверить» в `lib/game_engine/data/README.md` явно на них ссылается), который
  **не входит** в список «Модули (≤ 3)» этой задачи (`game`/`rules`/`models`).
  Удаление файлов по ТЗ «как есть» ломает компиляцию этих двух тестов →
  `flutter test` красный, DoD п.1 недостижим без правки 4-го модуля
  (`game_engine/data`, тесты + паспорт).
  Это ровно случай из ТЗ/AGENT.md: «Если grep покажет живого потребителя
  удаляемого файла — стоп и эскалация, не додумывай» (плюс «полез 4-й модуль» —
  AGENT.md §3). Не додумываю сам, чья это ошибка (удалить/адаптировать эти два
  теста — решение о содержании покрытия `game_engine/data`, не чисто техническое
  «удалить мёртвый файл»), возвращаю на перенарезку/уточнение ТЗ.
  **Дерево чистое:** ничего не удалено, ничего не закоммичено (проверено
  `git status` — clean на момент остановки).
  **Что не тронуто (для следующего исполнителя):** остальная часть T4 (grep по
  `game`/`rules`/`models` файлам вне этих двух тестов) выглядит бьющейся с ТЗ —
  единственная нестыковка именно в этих двух файлах `game_engine/data`.
  **Варианты для Постановщика (не выбираю сам):** (а) добавить эти два файла в
  список удаления T4 (они — сквозной прогон реальным падением, семантически
  дублируют то, что удаляет T4, эквивалент `golden_scenario_test.dart`, но
  структурные проверки `chargeBudget` в `level_charge_budget_test.dart` полезны
  и без движка); (б) адаптировать их под новое ядро/оставить только
  структурную часть без `GameController`; (в) явно включить `game_engine/data`
  четвёртым модулем в ТЗ T4 с уточнением, что именно с этими тестами делать.
- **Резолюция Постановщика (2026-07-22): вариант (а), ТЗ T4 дополнено (п. 4а).**
  Эскалация корректная — пробел мой (нарезка не учла тесты `data`, гоняющие
  движок). Решение техническое (содержание покрытия удаляемого поведения, §2
  POSTANOVSHCHIK): оба теста снимаются в T4 — `level_playthrough_test` дублирует
  семантику удаляемого `golden_scenario_test` (сквозной прогон падением), а
  «структурная» ценность `level_charge_budget_test` привязана к `chargeBudget` —
  данным взрыва, которые Стори 03 удаляет; сохранять тест обречённых данных —
  зомби-покрытие. Критерий приёмки стори №4 прямо требует снять тесты
  удалённого поведения в этой же стори. Полный список потребителей движка
  перепроверен grep'ом Постановщика: кроме этих двух файлов и уже перечисленных
  в ТЗ — никого; `lib/` чист. Новая содержательная проверка контента
  («каждая деталь нарезается и укладывается новым ядром») — Стори 03, как и
  было нарезано.
