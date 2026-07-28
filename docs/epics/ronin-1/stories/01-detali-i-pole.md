# STORY 01 — Детали «Ронина» вместо дев-деталей: 13 деталей на сетке 44×108, поле 10×14

**Эпик:** Ронин-1 — первые модули корабля
**Статус:** в работе (нарезана на 4 задачи 2026-07-29)

## Ценность

Игрок может **собирать настоящие детали носа и мостика «Ронина» — силуэт уровня
есть след детали на корабле 1:1 — на фиксированном поле 10×14**, чтобы
**играть по настоящему контенту, а не по семи дев-кляксам: игра всегда в
«настоящем» состоянии**.

## Критерии приёмки

- [ ] В игре ровно **13 уровней** в порядке поля `order` разметки
      (`docs/design/ronin-parts.js`, 1..13 без пропусков). Уровень N — деталь с
      `order == N`; силуэт уровня = её `mask` **1:1, без масштабирования**.
- [ ] Поле укладки **фиксировано 10×14 клеток** для всех уровней (не зависит от
      размера детали); силуэт отцентрован в поле по обеим осям.
- [ ] Топбар игрового экрана — по мокапу `ukladka-field.html`: «ДЕТАЛЬ N / 13»
      + название детали (`title` из разметки, напр. «НОС, ЛЕВЫЙ БОРТ»).
      Свотча материала детали больше нет.
- [ ] Дев-детали выведены из игры: ни один работающий путь кода их больше не
      читает — `grep -rn 'ShipParts' lib` не находит ссылок вне самого
      `ship_parts.dart`; чит-меню (выбор уровня, состояние корабля) и
      `ProgressService` работают на 13 деталях. **Сами файлы `ship_parts.dart` и
      `ship_parts_test.dart` в этой стори НЕ удаляются** — физический выпил
      собран в Стори 06 (решение PO 2026-07-29: удаления пачкой в конце эпика,
      чтобы не прерывать работу подтверждениями). Тест дев-деталей до тех пор
      остаётся зелёным на осиротевших данных.
- [ ] Тест инвариантов разметки (все 13 деталей): bbox ≤ 10×14; 60 ≤ `cells` ≤ 80;
      маска связна по 4-соседству; `cells` совпадает с числом `#` в маске; детали
      попарно не пересекаются на сетке 44×108; `order` — перестановка 1..13;
      `id` уникальны.
- [ ] Тест проходимости (аналог существующего `content_packing_test`): каждая из
      13 деталей режется генератором и эталонная раскладка укладывается до
      `PackState.isComplete`.
- [ ] `flutter analyze` — 0 ошибок и предупреждений; `flutter test` — зелёный;
      смоук-команда проекта (`flutter test test/widget_test.dart
      test/presentation/win_flow_test.dart`) — зелёная.
- [ ] **Гейт 2, визуально:** на устройстве/preview деталь целиком помещается в
      поле, клетка читаема (канон 34 px, на коротких экранах ужимается), силуэт
      не срезан и не смещён.

## Не входит

- **Клетка = кусок оригинала** (сэмплинг рисунка в уложенные клетки) — Стори 03.
  В этой стори уложенные клетки красятся одним временным плоским материалом.
- **Рисунок «Ронина» и экран корабля-композит** — Стори 02. Здесь экран корабля
  лишь адаптируется к новым маскам минимальной правкой (не переделывается).
- **Тюнинг генератора кусочков и подбор `seed`** — Стори 04. Здесь `seed`
  остаётся тем же механизмом, что сейчас в `GameScreen`.
- **Поток «деталь собрана» и офсет куска под палец** — Стори 05.
- Детали остального борта (~37 штук) — «Ронин-2».

## Контекст для нарезки

- **Источник разметки — `docs/design/ronin-parts.js`** (канон Дизайнера, утв. PO
  2026-07-29). Оттуда переносятся: `grid` (cols 44, rows 108, renderCell 4,
  originCol 2) и 13 деталей (`id`, `order`, `module`, `title`, `origin`, `cells`,
  `seed`, `mask` строками `#`/`.`). HTML-страницы `ronin-*.html` читать не нужно —
  там только вывод.
- **Блокирующее ограничение: `TargetMask` держит окно только 8×8**
  (`lib/game_engine/models/target_mask.dart`: битмаска в `int`, 64 бита). Детали —
  до 10×14. Представление маски придётся переделать (рекомендация: хранить строки
  `List<String>` — `const`-able, читается как в разметке; публичный API `width`,
  `height`, `contains`, `cells` сохранить, чтобы `packing` не трогать). Потребители
  конструктора: `ship_parts.dart` и 5 тестовых файлов
  (`target_mask_test`, `pack_slicer_test`, `pack_controller_test`,
  `pack_state_test`, `packing_painter_test`) + фикстура `defaultTargetMask`
  (крест 6×6) — она **не** игровой уровень, её оставить (ARCHITECTURE, «Тестовая
  фикстура»).
- **Что где сейчас:** `LevelMap` строит уровни из `ShipParts.parts` с полем 10×20 и
  floor-anchor (`targetY = boardHeight - height`) — floor-anchor снят вместе с
  гравитацией, теперь центрирование в поле 10×14. `ProgressService._max` берёт
  `ShipParts.parts.length - 1` (единый источник числа уровней — сохранить приём,
  сменив источник). `kShipPartCount` живёт в `lib/presentation/widgets/ship.dart`
  и выводится из `ShipParts.parts.length`. `GameScreen._computeCellSize` считает
  клетку от размера мишени — переводится на фиксированные 10×14 (канон 34 px,
  клампится вниз на коротких экранах).
- **Материал уложенных клеток** сейчас — `ShipMaterials.defaultMaterials
  .materialForPart(fragmentIndex)` (карта на 7 дев-деталей). В этой стори — один
  временный материал (`BlockMaterial.graphite`); последний потребитель карты
  уходит в Стори 03, физический выпил файла — в Стори 06.
- **Экран корабля** (`ShipPainter`, `ship.dart`) сейчас рисует 7 масок в сетке
  `gridSize = 12`. Здесь — минимальная адаптация к 13 маскам на сетке 44×108
  (плоская заливка, как сейчас); полноценный композит из рисунка — Стори 02,
  которая этот пейнтер заменяет. Осознанно временный код — помечать комментарием
  со ссылкой на Стори 02, чтобы не осел зомби.
- **Порядок сборки = `order`** (парами сверху вниз, канон `DESIGN.md`
  § «Разметка деталей»): уровень N ↔ деталь с `order == N`; на корабле первыми
  прирастают половинки носа.
- Персист прогресса совместим: старое сохранённое значение ≤ 6 < 13, миграция не
  нужна.

## Затронутые модули

- `lib/game_engine/models/` — `TargetMask` на произвольный размер окна.
- `lib/game_engine/data/` — новый `ronin_parts.dart` (13 деталей + сетка),
  `level_map.dart` на него; `ship_parts.dart` остаётся осиротевшим до Стори 06.
- `lib/presentation/widgets/` — `ship.dart` (`kShipPartCount`, временная адаптация
  `ShipPainter`).
- `lib/presentation/screens/` — `game_screen.dart` (поле 10×14, топбар-чип),
  `cheat_menu.dart` (13 уровней).
- `lib/application/` — `ProgressService._max` (источник числа уровней).

> Правило трёх модулей — на задачу, не на стори: нарезать так, чтобы каждая
> задача трогала ≤ 3 модуля (модели+тесты → данные+уровни → экраны).

## Открытые вопросы к PO

_нет_

## Задачи

> Нарезка 2026-07-29. Порядок = порядок выполнения; проект рабочий после каждой.

### T1 — `TargetMask` на произвольный размер окна

- **Статус:** не начата
- **Рекомендованный агент:** Исполнитель · Claude (Sonnet, `ispolnitel`)
- **Цель:** снять потолок 8×8 у маски силуэта — детали «Ронина» до 10×14 клеток
  (100+ бит не влезают в `int`). Без этого Стори 01 не сдвинется.
- **Модули (≤ 3):** `lib/game_engine/models/` (паспорт:
  `lib/game_engine/models/README.md`) — сама маска;
  `lib/game_engine/data/` (паспорт: `lib/game_engine/data/README.md`) —
  конвертация 7 дев-масок, чтобы файл продолжал компилироваться.
- **Что сделать:**
  1. `lib/game_engine/models/target_mask.dart`: заменить битовое представление
     на строковое.
     ```dart
     class TargetMask {
       /// Строки окна сверху вниз: '#' — клетка силуэта, любой другой символ —
       /// пустая. Все строки одной длины, список непуст.
       final List<String> rows;
       const TargetMask({required this.rows}) : assert(rows.length > 0);

       int get height => rows.length;
       int get width => rows.first.length;

       /// Вне окна — честный false, без исключения (поведение сохраняется).
       bool contains(int localX, int localY);

       /// Все локальные координаты клеток силуэта, обход сверху вниз,
       /// слева направо (порядок сохраняется — на нём стоят тесты движка).
       List<({int x, int y})> get cells;

       /// Новая маска размера [width]×[height], в которую эта вложена со
       /// сдвигом ([dx], [dy]); клетки вне исходной — пустые. Нужна для
       /// центрирования детали в фиксированном поле (T3).
       TargetMask padTo({
         required int width,
         required int height,
         required int dx,
         required int dy,
       });
     }
     ```
     Именованные параметры `width`/`height` и поле `mask` из конструктора
     уходят — `width`/`height` теперь геттеры.
  2. `defaultTargetMask` (крест 6×6, был `0x30CFFF30C`) переписать строками —
     значение то же:
     `['..##..', '..##..', '######', '######', '..##..', '..##..']`.
  3. `lib/game_engine/data/ship_parts.dart`: перевести 7 масок на строки.
     Картинки клеток уже есть в комментариях над каждой деталью (`.##. / ####`
     и т.д.) — они и есть строки. Файл дев-деталей **не удалять** (выпил — Стори 06),
     он обязан компилироваться и держать свой тест зелёным.
  4. Перевести на строковый конструктор тестовые фикстуры:
     `test/game_engine/models/target_mask_test.dart`,
     `test/game_engine/packing/pack_state_test.dart`,
     `test/game_engine/packing/pack_controller_test.dart`,
     `test/presentation/packing_painter_test.dart`
     (`TargetMask(width: 2, height: 2, mask: 0xF)` → `TargetMask(rows: ['##', '##'])`
     и т.п. — множество клеток должно совпасть с прежним).
  5. В `target_mask_test.dart` добавить тесты: строки разной длины /пустой список —
     ловятся (assert или явная проверка); `padTo` кладёт исходные клетки со
     сдвигом и не добавляет чужих.
- **Арх-дельта:** в `docs/ARCHITECTURE.md`, «Сквозные соглашения», строку
  «**Тестовая фикстура:** `defaultLevel`/`defaultTargetMask` (крест 6×6, маска
  `0x30CFFF30C`) — …» заменить на: «**Тестовая фикстура:** `defaultLevel`/
  `defaultTargetMask` (крест 6×6, строки `..##..`/`######`) — НЕ игровой уровень;
  на нём написаны тесты движка, не удалять при чистке контента.» Остальное в
  строке без изменений. Связи между модулями не меняются.
- **Дизайн-референс:** нет (видимого не трогает).
- **Результат (как проверить):** `flutter analyze` — «No issues found!»;
  `flutter test` — зелёный целиком (маска — фундамент движка, падать не должно
  ничего).
- **DoD задачи:** обновить паспорт `lib/game_engine/models/README.md`
  (представление маски, отсутствие потолка 8×8, `padTo`); применить арх-дельту;
  общий чек-лист — `system/AGENT.md` п. 5.
- **Заметки по выполнению:**

### T2 — Разметка «Ронина»: 13 деталей и сетка 44×108

- **Статус:** не начата
- **Рекомендованный агент:** Исполнитель · Claude (Sonnet, `ispolnitel`)
- **Цель:** перенести канон разметки Дизайнера в код как адресуемую единицу —
  под неё встают уровни, корабль и нарезка.
- **Модули (≤ 3):** `lib/game_engine/data/` (паспорт:
  `lib/game_engine/data/README.md`) — новая разметка;
  `lib/game_engine/packing/` (паспорт: `lib/game_engine/packing/README.md`) —
  только чтение, для теста проходимости.
- **Что сделать:**
  1. Новый файл `lib/game_engine/data/ronin_parts.dart`. Источник данных —
     **`docs/design/ronin-parts.js`** (канон Дизайнера, утв. PO 2026-07-29):
     переносится ровно то, что там лежит, без правок формы. HTML-страницы
     `docs/design/ronin-*.html` читать не нужно.
     ```dart
     /// Сетка корабля: клетка рендера = 4×4 клетки сетки, сетка сдвинута
     /// относительно рендера на originCol (см. docs/design/ronin-parts.js).
     class RoninGrid {
       static const int cols = 44;
       static const int rows = 108;
       static const int renderCell = 4;
       static const int originCol = 2;
     }

     class RoninPartDef {
       final String id;        // 'prow_l' …
       final int order;        // 1..13, порядок сборки
       final String module;    // 'prow' | 'bridge' | 'fwd'
       final String title;     // 'Нос, левый борт'
       final int originCol;    // левый-верх bbox маски в координатах сетки
       final int originRow;
       final int cells;        // число клеток детали (бюджет уровня)
       final int? seed;        // фиксированный seed нарезки; пока null (Стори 04)
       final TargetMask mask;  // bbox-маска детали, '#' = клетка детали
       const RoninPartDef({...});
     }

     class RoninParts {
       /// 13 деталей, отсортированы по order по возрастанию: индекс == order-1.
       static const List<RoninPartDef> parts = [...];
       /// Деталь по порядку сборки (order 1..13).
       static RoninPartDef partAtOrder(int order);
       /// Деталь по id; неизвестный id — ArgumentError.
       static RoninPartDef byId(String id);
     }
     ```
     `origin` в JS — пара `[col, row]`; `seed: null` переносится как есть.
  2. Новый тест `test/game_engine/data/ronin_parts_test.dart` — инварианты
     разметки (это же и страховка от опечатки при переносе масок):
     - деталей ровно 13; `id` уникальны; `order` — перестановка 1..13;
       список отсортирован по `order` (индекс == `order - 1`);
     - у каждой детали `mask.width ≤ 10` и `mask.height ≤ 14` (поле укладки);
     - `cells` == числу клеток в маске; `60 ≤ cells ≤ 80`;
     - маска связна по 4-соседству; в маске нет полностью пустых строк/столбцов
       по краям bbox (origin описывает именно bbox);
     - деталь целиком внутри сетки: `originCol + width ≤ RoninGrid.cols`,
       `originRow + height ≤ RoninGrid.rows`;
     - детали **попарно не пересекаются** на сетке (перевести маски в абсолютные
       клетки сетки и сравнить множества);
     - суммарно 960 клеток, объединение всех деталей связно по 4-соседству.
  3. Новый тест `test/game_engine/data/ronin_packing_test.dart` — проходимость
     (аналог существующего `content_packing_test.dart` для дев-деталей): для
     каждой из 13 деталей `slicePolyomino(part.mask, seed: s)` при `s` из
     `[0, 1, 2]` даёт валидную нарезку (куски 3..5 клеток, покрытие без дыр и
     пересечений), а раскладка по `PackSlice.solution` доводит `PackState` до
     `isComplete`. Образец структуры — `test/game_engine/data/content_packing_test.dart`.
- **Арх-дельта:** нет (модуль `data` уже есть, новых связей между модулями
  задача не добавляет — `data → models` существует). Строку модуля `data` в
  `docs/ARCHITECTURE.md` правит T3, когда `LevelMap` переедет на новую разметку.
- **Дизайн-референс:** данные разметки — канон Дизайнера
  `docs/design/ronin-parts.js` (утв. PO 2026-07-29); правила разметки —
  `docs/DESIGN.md` § «Модель модулей Ронин-1» → «Разметка деталей». Видимого
  задача не трогает (только данные).
- **Результат (как проверить):** `flutter analyze` — 0;
  `flutter test test/game_engine/data/` — зелёный (в т.ч. два новых файла);
  `flutter test` — зелёный целиком.
- **DoD задачи:** обновить паспорт `lib/game_engine/data/README.md` (добавить
  `RoninParts`/`RoninGrid` в публичный интерфейс и инварианты разметки; дев-детали
  пометить как вытесняемые, выпил — Стори 06); тесты из п. 2–3; общий чек-лист —
  `system/AGENT.md` п. 5.
- **Заметки по выполнению:**

### T3 — Уровни на деталях «Ронина»: поле 10×14, число уровней, корабль

- **Статус:** не начата
- **Рекомендованный агент:** Исполнитель · Claude (Sonnet, `ispolnitel`)
- **Цель:** уровень N становится деталью «Ронина» с `order == N` на фиксированном
  поле 10×14; число уровней и прогресс корабля идут от новой разметки.
- **Модули (≤ 3):** `lib/game_engine/data/` (`level_map.dart`),
  `lib/application/` (паспорт: `lib/application/README.md` — `ProgressService`),
  `lib/presentation/widgets/` (паспорт: `lib/presentation/widgets/README.md` —
  `ship.dart`).
- **Что сделать:**
  1. `lib/game_engine/data/level_map.dart` — уровни строятся из
     `RoninParts.parts` (индекс == `order - 1`):
     ```dart
     class LevelMap {
       /// Поле укладки фиксировано (docs/DESIGN.md § «Разметка деталей»).
       static const int fieldWidth = 10;
       static const int fieldHeight = 14;
       static LevelTemplate levelAt(int levelIndex); // 0..RoninParts.parts.length-1
     }
     ```
     Для уровня `i`: `part = RoninParts.parts[i]`;
     `targetX = (fieldWidth - part.mask.width) ~/ 2`,
     `targetY = (fieldHeight - part.mask.height) ~/ 2`;
     **`targetMask = part.mask.padTo(width: fieldWidth, height: fieldHeight,
     dx: targetX, dy: targetY)`** — маска уже размера поля, деталь в ней
     отцентрована; `boardWidth = fieldWidth`, `boardHeight = fieldHeight`,
     `fragmentIndex = i`. Прежний floor-anchor (`targetY = boardHeight - height`)
     снят — гравитации нет, деталь центрируется.
     В doc-комментарии зафиксировать: `targetMask` теперь **размера поля**, а
     `targetX`/`targetY` говорят, где внутри него сидит деталь (это понадобится
     Стори 03 для сэмплинга рисунка).
  2. `lib/application/progress_service.dart` — `_max` считать от
     `RoninParts.parts.length - 1` (приём «единый источник числа уровней»
     сохраняется, меняется только источник). Импорт `ship_parts.dart` убрать.
  3. `lib/presentation/widgets/ship.dart` — `kShipPartCount` выводить из
     `RoninParts.parts.length`; `ShipPainter` перевести на `RoninParts`:
     сетка `RoninGrid.cols × RoninGrid.rows` вместо `ShipParts.gridSize`, якорь
     детали — `originCol`/`originRow`, собранные детали (`i < collectedCount`) —
     плоская заливка, остальные — контур (как сейчас). Масштаб/центрирование
     считать по `RoninGrid` с сохранением пропорций (сетка теперь не квадратная:
     44×108 — вписывать по меньшей из сторон, не растягивать).
     **Отрисовка временная:** пометить комментарием «плоская заливка — временно,
     заменяется композитом из рисунка в Стори 02 эпика Ронин-1», чтобы код не
     осел зомби. Материал заливки — из `ShipMaterials` по индексу, как сейчас
     (карта уходит в Стори 03).
  4. Обновить тесты, которые ходят через эти точки:
     `test/game_engine/data/level_map_test.dart` (мишень == маска детали, но
     теперь маска уровня — размера поля: сверять с `padTo`-ожиданием; число
     уровней == `RoninParts.parts.length`; каждая мишень внутри поля),
     `test/application/progress_service_test.dart` (`_maxLevel` от `RoninParts`).
     `test/game_engine/data/ship_parts_test.dart` и
     `test/game_engine/data/content_packing_test.dart` (дев-детали) —
     **оставить зелёными как есть**, они тестируют осиротевшие данные до Стори 06.
- **Арх-дельта:** в `docs/ARCHITECTURE.md`:
  - строку модуля `data` заменить на: `| data | lib/game_engine/data/ |
    Контент: разметка «Ронина» (`RoninParts` — 13 деталей на сетке 44×108,
    маска = след детали на корабле) + `LevelMap` (уровень i ↔ деталь с order i+1,
    поле 10×14); `ShipParts` — осиротевшие дев-детали, выпил в Стори 06 |
    models |`;
  - сноску ¹ («`ProgressService._max` берёт `ShipParts.parts.length - 1`») —
    источник заменить на `RoninParts.parts.length - 1`, остальной текст сноски
    (почему импорт вниз по слоям разрешён, hotfix 2026-07-11) сохранить;
  - в строке связи `widgets → data` заменить «`ShipPainter` берёт форму деталей
    из `ShipParts`» на «`ShipPainter` берёт форму деталей из `RoninParts` (тот же
    источник, что и мишени уровней)».
- **Дизайн-референс:** экран корабля — `docs/design/ronin-ship.html` (канон,
  утв. PO 2026-07-29): порядок прироста деталей по `order`, пропорции сетки
  44×108. **Плоская заливка деталей в этой задаче — заведомо не канон**
  (канон — собранное из рисунка + контур `shipOutline`), она держит экран рабочим
  до Стори 02; визуальный критерий здесь один: экран открывается, показывает 13
  деталей в правильных местах сетки, ничего не срезано.
- **Результат (как проверить):** `flutter analyze` — 0; `flutter test` — зелёный;
  смоук `flutter test test/widget_test.dart test/presentation/win_flow_test.dart` —
  зелёный.
- **DoD задачи:** применить арх-дельту; обновить паспорта
  `lib/game_engine/data/README.md` (уровни и поле 10×14),
  `lib/application/README.md` (источник `_max`),
  `lib/presentation/widgets/README.md` (`ShipPainter` на `RoninParts`, временность);
  общий чек-лист — `system/AGENT.md` п. 5.
- **Заметки по выполнению:**

### T4 — Игровой экран и чит-меню на 13 деталей

- **Статус:** не начата
- **Рекомендованный агент:** Исполнитель · Claude (Sonnet, `ispolnitel`)
- **Цель:** игрок видит и играет 13 настоящих деталей на поле 10×14 — топбар,
  размер клетки и читы соответствуют новому контенту.
- **Модули (≤ 3):** `lib/presentation/screens/` (паспорт:
  `lib/presentation/screens/README.md`) — `game_screen.dart`, `cheat_menu.dart`;
  `lib/game_engine/data/` — только чтение (`RoninParts` для названия детали).
- **Что сделать:**
  1. `game_screen.dart`, размер клетки: `_canonicalCellSize` `40.0 → 34.0`
     (канон `docs/DESIGN.md`: поле 10×14 при клетке 34 px). Адаптивный расчёт
     `_computeCellSize` и нижний порог 8.0 оставить как есть — на коротких
     экранах клетка ужимается. Поле само становится 10×14: `_silhouette` теперь
     приходит из `LevelMap` уже размера поля (T3), геометрию править не нужно.
  2. `game_screen.dart`, топбар (канон мокапа `docs/design/ukladka-field.html`,
     блок `.topbar` → `.title`): вместо чипа со свотчем — две строки:
     `.kick` = «ДЕТАЛЬ N / 13» (N = `fragmentIndex + 1`, 13 = `kShipPartCount`)
     и `.name` = название детали заглавными (`RoninParts.parts[fragmentIndex]
     .title.toUpperCase()`, напр. «НОС, ЛЕВЫЙ БОРТ»). Виджет `_Swatch` и свотч
     материала из топбара **убрать вместе с классом** (иначе `analyze` поймает
     неиспользуемый приватный класс). Кнопки справа (`Key('cheat_button')` под
     `kDebugMode`, `Key('ship_button')`) — без изменений.
  3. `game_screen.dart`, материал уложенных клеток: `_partMaterial` перестаёт
     браться из `ShipMaterials` — ставится один временный
     `BlockMaterial.graphite`; импорт `ship_materials.dart` из экрана убрать.
     Пометить комментарием «временно: клетка станет куском рисунка в Стори 03
     эпика Ронин-1». Передача `partMaterial` в `PackingPainter` сохраняется.
  4. `cheat_menu.dart`: секции «выбор уровня» и «состояние корабля» работают на
     13 (они уже считают от `kShipPartCount`/`levelCount` — проверить, что нигде
     не осталось семёрки и что список уровней 1..13 скроллится в sheet;
     `CheatMenu` уже внутри `SingleChildScrollView`).
  5. Тексты вида «ДЕТАЛЬ N/7» в коде и тестах — вычистить; число берётся из
     `kShipPartCount`, не хардкодом.
  6. Обновить тесты под новый контент и топбар:
     `test/presentation/game_screen_test.dart`,
     `test/presentation/cheat_menu_test.dart`,
     `test/presentation/win_flow_test.dart` (сквозной прогон теперь по 13
     уровням — гонять solve-хуком `Key('cheat_solve')`/programmatic, как сейчас),
     `test/navigation_test.dart`, `test/presentation/ship_screen_test.dart`.
     Финал на последнем уровне («Начать заново») в этой стори **менять не надо** —
     он переезжает в Стори 05.
- **Арх-дельта:** нет (модули и связи те же).
- **Дизайн-референс:** мокап `docs/design/ukladka-field.html` (утв. PO 2026-07-29).
  Элементы: `.topbar`/`.title`/`.kick`/`.name` (топбар: «ДЕТАЛЬ 1 / 13» +
  «НОС, ЛЕВЫЙ БОРТ», свотча нет), `.board` (панель поля), `el-cell-target`
  (пунктир `ghostTarget`), `el-cell-void`, `el-cell-filled` (в этой стори —
  временная плоская заливка, канон куска рисунка приходит Стори 03),
  `el-piece-tray`, `el-piece-drag`. Токены (`docs/DESIGN.md`): клетка поля
  **34 px**, клетка лотка 32 px, `boardBg` `hsl(219 13% 10%)`,
  `spaceBg` `hsl(220 14% 7%)`, `graphite` `#484E56`, `ghostTarget`
  `hsl(23 62% 55% / 55%)`.
- **Результат (как проверить):** `flutter analyze` — 0; `flutter test` — зелёный;
  смоук `flutter test test/widget_test.dart test/presentation/win_flow_test.dart` —
  зелёный.
- **DoD задачи:** обновить паспорт `lib/presentation/screens/README.md` (поле
  10×14 и клетка 34, топбар с названием детали, временный материал, 13 уровней);
  обновить `docs/STATUS.md`; общий чек-лист — `system/AGENT.md` п. 5.
- **Заметки по выполнению:**
