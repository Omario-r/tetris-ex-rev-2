# STORY 03 — Клетка на поле — кусок оригинала

**Эпик:** Ронин-1 — первые модули корабля
**Статус:** на приёмке (Гейт 2) — T1 выполнена 2026-10-08; визуальный критерий за Постановщиком

## Ценность

Игрок может **видеть, как каждая уложенная клетка проступает своим куском
настоящего корабля**, чтобы **собирать не «плитку материала», а фрагмент
«Ронина»: пазл из рисунка, а не раскраска**.

## Критерии приёмки

- [x] Уложенная клетка на поле — **свой кусок оригинала** (канон `el-cell-filled`,
      `docs/design/ukladka-field.html`): кусок рисунка ровно той клетки маски
      детали, которой клетка соответствует, в масштабе детали (`cellOnShip`;
      плита — слой корпуса, предмет — корпус и предметы), плюс `seam` по границе
      клетки. Плоского материала детали на поле больше нет.
      _Доказательство: `flutter test test/presentation/packing_painter_test.dart` —
      на уровне `bridge_c` (через `prepareLevel`, сдвиг `targetX/Y`) центр каждой
      уложенной клетки = `paintPartCell` её клетки маски (±2), ≠ графит, ≠ `boardBg`;
      граница клетки темнее центра и того же пикселя без `seam`. Параметров
      материала у `PackingPainter` нет._
- [x] Незаполненная клетка силуэта (`el-cell-target`, пунктир `ghostTarget`) и
      клетка вне силуэта (`el-cell-void`) — как в мокапе, без изменений канона.
      _Доказательство: тест «незанятая клетка силуэта — ghost, как было» — растр
      клетки (без краевых 2 px) = `boardBg` + `ghostTarget.paint` (±2); код ghost и
      фона не менялся._
- [x] Кусочки в лотке и кусок в руке остаются **сырым графитом**
      (`el-piece-tray` / `el-piece-drag`) — контраст «сырьё → корабль» сохранён.
      _Доказательство: `PackingPainter.paintPiece` и вызовы `GameScreen` с
      `BlockMaterial.graphite` не тронуты (`git diff` — только поле); визуально — Гейт 2._
- [ ] Кадр `el-field-partial` воспроизводится: `seam` только по уложенным клеткам,
      граница уложенного идёт по кускам, а не по плитам рисунка.
      _Детерминированно: клип и `seam` строятся только по `occupiedCellsExcluding`
      (тест: клетки поднятого куска снова ghost). Визуальная сверка — Гейт 2._
- [x] Карта `ShipMaterials` вытеснена из работающего кода: фолбэк
      `PackingPainter.materialForPiece` и временный материал Стори 01 убраны,
      `grep -rn "ship_materials.dart'" lib test` находит только тест
      `test/presentation/theme/ship_materials_test.dart`. **Файл и его тест сносятся в
      Стори 06** (решение PO 2026-07-29). Токены материалов (`BlockMaterial`)
      остаются живыми — они нужны лотку.
      _Доказательство: `grep -rn "ship_materials.dart'" lib test` → одна строка,
      `test/presentation/theme/ship_materials_test.dart:5`._
- [x] `flutter analyze` — 0; `flutter test` — зелёный (в т.ч. обновлённый
      `packing_painter_test`); смоук-команда — зелёная.
      _Доказательство: `flutter analyze` → «No issues found!»; `flutter test` →
      «+584: All tests passed!» (смоук-файлы в составе)._
- [ ] **Гейт 2, визуально:** поле в середине сборки против `el-field-partial` и
      собранная деталь против `el-cell-filled` — скриншот/preview.

## Не входит

- Изменения геометрии поля, топбара, лотка, прогресс-бара — они уже по мокапу
  (Стори 01).
- Поток «деталь собрана», кнопки под полем, офсет под палец — Стори 05.
- Тюнинг форм кусочков — Стори 04.
- Сетка клеток на экране корабля — её нет по канону (`DESIGN.md`: на корабле швы
  даёт сам рисунок).

## Контекст для нарезки

- **Точка входа сэмплинга готова в Стори 02** (`lib/presentation/ship_render/`):
  по клетке сетки корабля отдаёт её кусок рисунка в заданный прямоугольник.
  Клетка детали (`dx, dy` внутри маски) → клетка сетки: `col = origin[0] + dx`,
  `row = origin[1] + dy`.
- **Где рисуется:** `lib/presentation/widgets/packing_painter.dart` —
  `PackingPainter` (параметр `partMaterial` уходит; появляется зависимость от
  рендера корабля и от текущей детали). `PackingPainter.paintPiece` (статик) —
  единая точка «как выглядит кусочек», её потребитель `GameScreen` рисует лоток и
  drag-фидбэк: они остаются графитовыми, менять только заливку уложенных клеток.
- **Токен `seam`** — `hsla(220 14% 4% / 55%)` (`docs/DESIGN.md`, пока не
  реализован); ставится **только на поле укладки**.
- **Производительность:** клип-путь объединяет уложенные клетки — один replay
  рисунка на кадр, не по клетке (см. заметку в Стори 02).
- **Смещение силуэта в поле:** силуэт отцентрован в поле 10×14 (Стори 01) —
  сэмплинг должен учитывать это смещение, иначе кусок рисунка «поедет».
- Арх-дельта: `widgets` получает связь на `ship_render`, теряет связь на
  `theme/ship_materials`; правку `docs/ARCHITECTURE.md` пишет Постановщик при
  нарезке задач.

## Затронутые модули

- `lib/presentation/widgets/` — `packing_painter.dart` (заливка уложенных клеток
  из рисунка + `seam`).
- `lib/presentation/screens/` — `game_screen.dart` (прокидывание детали/рендера
  вместо материала).
- `lib/presentation/theme/` — `ship_materials.dart` выводится из употребления
  (файл сносится в Стори 06).

## Открытые вопросы к PO

_нет_

## Вычитка Критика (режим «ТЗ», 2026-10-08)

Принято: явная формула перевода клетки поля в клетку маски; заливка `backdrop` —
`drawPaint` под клипом; `paintPartCell` с `backdrop` вынесен отдельным подпунктом;
`_targetX/_targetY` — поля состояния рядом с `_silhouette`; точки сравнения
пикселей в тестах. Отклонено: «двойная заливка» (точки входа не вызываются на
одной клетке вместе), «двойной расчёт `shipCellRect`» (деталь реализации),
«статус `seam` не в проверке» (он в DoD).

## Задачи

### T1 — Уложенные клетки поля из рисунка корабля + `seam`

- **Статус:** выполнена (2026-10-08, не закоммичена — коммит за Постановщиком)
- **Рекомендованный агент:** Исполнитель (тяжёлая) · Claude (Opus, `ispolnitel-heavy`)
- **Цель:** уложенная клетка поля показывает свой кусок «Ронина» в масштабе детали;
  материал детали на поле убран.
- **Модули (≤ 3):** `lib/presentation/ship_render/` (паспорт `README.md`);
  `lib/presentation/widgets/` — `packing_painter.dart` (паспорт `README.md`);
  `lib/presentation/screens/` — `game_screen.dart`, `ship_screen.dart` (паспорт
  `README.md`).
- **Что сделать:**
  1. `ship_render`:
     - `ShipArt` — новый геттер `Color get backdrop` (подложка под рисунком в
       клетке, где рисунка нет: клетки предмета вне его формы и вне корпуса). В
       `RoninArt` — `Color(0xFF070A11)` (середина градиента фона `ship-render.js`,
       `#05070d → #080b13`; звёзды не переносим) [Постановщик: мокап сэмплирует
       полный рендер с космосом, у нас фона в рисунке нет].
     - `RoninArt.shared` — `static final RoninArt shared = RoninArt();` (картинки
       слоёв пишутся один раз на запуск). `ship_screen.dart`: приватный
       `_roninArt` заменить на `RoninArt.shared`.
     - `ship_cell_sampler.dart` — новая функция:
       ```dart
       /// Клетки [cells] маски [part] (координаты маски) — куски рисунка в
       /// масштабе детали; клетка (c, r) ложится в
       /// `Rect.fromLTWH(origin.dx + c * cellSize, origin.dy + r * cellSize, cellSize, cellSize)`.
       /// Один clip (объединение прямоугольников клеток) и один replay на слой.
       void paintPartCells(Canvas canvas, ShipArt art, RoninPartDef part,
           Iterable<({int x, int y})> cells, {required Offset origin, required double cellSize});
       ```
       Порядок: `save` → `clipPath(union)` → `canvas.drawPaint(Paint()..color =
       art.backdrop)` (заливка ровно клипа) →
       преобразование «px рисунка → поле» (клетка маски (0, 0) =
       `shipCellRect(art, part, 0, 0)` → `origin`, масштаб `cellSize /
       shipCellRect(...).width`) → `drawPicture(hullPicture)` → у предмета
       (`!part.isPlate`) ещё `drawPicture(objectsPicture)` → `restore`. Пустой
       `cells` — ничего не рисует.
     - `paintPartCell` — после `clipRect(dst)` тоже `drawPaint(backdrop)` под
       рисунком (иначе две точки входа дадут разный вид).
  2. `PackingPainter` (`widgets/packing_painter.dart`):
     - убрать `shipMaterials`, `partMaterial`, `materialForPiece`, импорты
       `ship_materials.dart` и `ship.dart` (`kShipPartCount`);
     - добавить обязательные `ShipArt art`, `RoninPartDef part`, `int targetX`,
       `int targetY` (сдвиг bbox маски детали в поле — `PreparedLevel.targetX/Y`);
     - порядок отрисовки: фон `boardBg` → ghost незанятых клеток силуэта (как
       сейчас) → уложенные клетки (`occupiedCellsExcluding(state,
       excludePieceId)`, координаты поля) одним вызовом
       `paintPartCells(canvas, art, part, [for (f in occupied) (x: f.x - targetX,
       y: f.y - targetY)], origin: Offset(targetX * cellSize, targetY * cellSize),
       cellSize: cellSize)` — клетка поля (x, y) ↔ клетка маски (x − targetX,
       y − targetY) и ложится ровно в свой прямоугольник поля →
       `seam` по каждой уложенной клетке: `strokeRect` 1 px, цвет `seam`
       `hsla(220 14% 4% / 55%)` (константа `PackingPainter.seam`), прямоугольник
       клетки со сдвигом +0.5 (как `strokeRect(c*CELL+.5, r*CELL+.5, CELL, CELL)`
       в мокапе) → снап-превью (как сейчас);
     - `paintPiece` (лоток, кусок в руке) не трогать — графит;
     - `shouldRepaint` — по `art`, `part`, `targetX/Y` вместо материалов.
  3. `game_screen.dart`: поля состояния `late int _targetX, _targetY;` рядом с
     `_silhouette`, присваиваются в `_rebuild` из `prepared.targetX/targetY`;
     `_partMaterial` и импорт `ship_materials.dart` убрать; в `PackingPainter`
     передать `art: RoninArt.shared`, `part: RoninParts.parts[_fragmentIndex]`,
     `targetX/targetY`. Лоток и drag-фидбэк — `BlockMaterial.graphite`, как сейчас.
  4. Тесты:
     - `test/presentation/ship_render/ship_cell_sampler_test.dart` — для
       `paintPartCells`: растр клетки совпадает с `paintPartCell` в той же клетке
       (плита `bridge_c` и предмет `sensor`, по 2–3 клетки; холст 1×, клетка
       `cellSize = 32`; сравнение пикселей в точках `(c + 0.5, r + 0.5) * 32` и
       `(c + 0.2, r + 0.2) * 32` с допуском ±2 на канал); вне клеток — пусто
       (прозрачно); пустой список — пустой растр.
     - `test/presentation/packing_painter_test.dart` — снести тесты `partMaterial`
       и `materialForPiece`; новые: уложенная клетка ≠ цвет графита и ≠ `boardBg`
       и совпадает с `paintPartCell` этой клетки маски (центр клетки, допуск);
       незанятая клетка силуэта — ghost (как было); граница уложенной клетки
       темнее её центра (`seam`); `excludePieceId` — клетки поднятого куска снова
       ghost; `shouldRepaint` по `part`.
     - Остальные тесты, где строится `PackingPainter` или проверяется материал
       поля, — под новый конструктор.
- **Арх-дельта** (`docs/ARCHITECTURE.md`): `widgets` → `ship_render` и
  `game_engine/data` (новые связи); связь `widgets` → `theme/ship_materials`
  убрать; в строке `ship_render` — «`paintPartCells` (поле укладки)».
- **Дизайн-референс:** `docs/design/ukladka-field.html` — `el-cell-filled`,
  `el-field-partial`, функция `renderPlaced` (кусок оригинала + `seam`),
  `docs/design/ronin-draw.js` `drawCell` (слой 0 — корпус без предметов, слой 1 —
  полный рисунок). Токены (DESIGN.md): `seam` `hsla(220 14% 4% / 55%)` (статус в
  таблице токенов — «реализован (Ронин-1/03)»), `ghostTarget`, `boardBg` — как
  есть.
- **Результат (как проверить):** `flutter analyze` — 0; `flutter test` — зелёный;
  `grep -rn "ship_materials.dart'" lib test` — только
  `test/presentation/theme/ship_materials_test.dart`. Визуально — Гейт 2.
- **DoD задачи:** паспорта трёх модулей; арх-дельта; статус токена `seam` в
  DESIGN.md; `system/AGENT.md` п. 5. Не коммитить.
- **Заметки по выполнению:** (Исполнитель, 2026-10-08)
  - **Сделано по пунктам ТЗ.** `ShipArt.backdrop` (+ `RoninArt` `0xFF070A11`),
    `RoninArt.shared` (`ship_screen` взял его вместо приватного `_roninArt`),
    `paintPartCells` в `ship_cell_sampler.dart` (порядок save → clipPath → drawPaint
    `backdrop` → «px рисунка → поле» → hull → objects у предмета → restore; пустой
    `cells` — ранний выход), `paintPartCell` — `drawPaint(backdrop)` после `clipRect`.
    `PackingPainter`: убраны `shipMaterials`/`partMaterial`/`materialForPiece` и импорты
    `ship_materials.dart`/`ship.dart`; добавлены обязательные `art`, `part`,
    `targetX`, `targetY`; константа `PackingPainter.seam`; `shouldRepaint` по новым
    полям. `GameScreen`: `late int _targetX, _targetY` из `prepared`, `_partMaterial` и
    импорт `ship_materials.dart` убраны. Тесты — `ship_cell_sampler_test` (+5:
    совпадение с `paintPartCell` для `bridge_c` и `sensor`, вне клеток прозрачно,
    сдвиг `origin`, пустой список) и переписанный `packing_painter_test`.
  - **Решения внутри ТЗ.**
    1. `seam` — все прямоугольники клеток одним `Path` и одним `drawPath`
       (геометрия ТЗ: +0.5, 1 px, сторона `cellSize`). Общая граница соседних клеток
       ложится одной линией 55 %, не двумя наложенными (~80 %). Так выглядит и
       мокап: в `renderPlaced` `drawCell` следующей клетки перекрывает правый/нижний
       `seam` предыдущей, после чего клетка рисует свой.
    2. Значение `seam` = `Color(0x8C090A0C)` — перевод `hsla(220 14% 4% / 55%)` с тем же
       округлением, что у `boardBg`.
    3. Клип `paintPartCells` — `Path.addRect` по клеткам (ненулевая обмотка, смежные
       прямоугольники дают объединение) без `Path.combine`.
    4. Тест `seam` сверяет пиксель границы и с центром клетки (по ТЗ), и с тем же
       пикселем без `seam` (эталон `paintPartCell`): это не зависит от того, тёмный ли
       рисунок в центре клетки.
    5. `dart format` переформатировал чужой код в `ronin_art.dart` и
       `game_screen.dart` (длинные строки прошлых задач). Эти файлы восстановлены из
       HEAD, правки ТЗ внесены заново без чужого переформатирования, чтобы дифф был
       только по задаче.
    6. `DESIGN.md`: у `shipOutline` в колонке «где» стояло «там же», то есть ссылка
       на строку `seam`. После смены статуса `seam` ссылка повела бы на
       `packing_painter.dart`, поэтому вписан фактический файл
       `ship_render/ship_composite_painter.dart`.
  - **Сверка с мокапом** (`ukladka-field.html`, `ronin-draw.js`; по коду, глазами — Гейт 2):
    - `el-cell-filled` — кусок рисунка своей клетки маски в масштабе детали
      (`cellOnShip` → `shipCellRect`); плита — слой корпуса, предмет — корпус +
      предметы (как `imgOf`: слой 1 → полный рисунок); `seam` 1 px по границе, как
      в `renderPlaced` (в каталоге `elFilled` линия 2 px — это увеличенная
      витрина 68 px). Отличие, заданное ТЗ: вместо космоса со звёздами под рисунком
      ровный `backdrop` `#070A11`. Ещё одно: мокап сэмплирует растр (RES 6,
      сглаживание), у нас векторный replay, поэтому кусок резче.
    - `el-field-partial` — клип и `seam` строятся только по уложенным клеткам
      (`occupiedCellsExcluding`); у незанятых клеток силуэта остаётся пунктир
      `ghostTarget`, фон поля сеткой не расчерчен. Граница уложенного идёт по кускам:
      клип — клетки, плиты рисунка его не задают.
    - Лоток / кусок в руке — графит: `paintPiece` и вызовы `GameScreen` с
      `BlockMaterial.graphite` не тронуты.
  - **Стори → «на приёмке (Гейт 2)»** (T1 — единственная задача стори; стори +
    `EPIC.md`). Визуальный критерий и `el-field-partial` глазами — за Постановщиком.
