# STORY 06 — Чистка: выпил осиротевшего кода одной пачкой

**Эпик:** Ронин-1 — первые модули корабля
**Статус:** закрыта 2026-10-09 (Гейт 2 пройден — раздел «Гейт 2»)

> Стори существует по решению PO 2026-07-29: удаления файлов прерывают работу
> подтверждениями, поэтому они не размазаны по стори «где заменили — там и
> снесли», а собраны в один заход в конце эпика. Цена решения принята осознанно:
> между 01 и 06 в дереве живут осиротевшие файлы. Задача этой стори — вернуть
> проекту состояние «в коде ровно то, что участвует в игре», чтобы эпик уходил
> на Гейт 3 чистым.

## Ценность

PO может **закрывать эпик на дереве, где нет мёртвого кода прошлого ядра**,
чтобы **следующий заход («Ронин-2», плейтест) читал проект как есть, а не
угадывал, какой из двух источников контента настоящий**.

## Критерии приёмки

- [x] Удалены осиротевшие файлы (все — `git rm`, одним заходом; список сверить
      по факту на момент старта стори, он определяется тем, что реально осталось
      после 01–05):
      - `lib/game_engine/data/ship_parts.dart` + `test/game_engine/data/ship_parts_test.dart`
        (дев-детали, вытеснены Стори 01);
      - `lib/presentation/theme/ship_materials.dart` +
        `test/presentation/theme/ship_materials_test.dart` (карта материалов,
        вытеснена Стори 03);
      - `ShipPainter` в `lib/presentation/widgets/ship.dart` (вытеснен Стори 02;
        файл целиком — только если `kShipPartCount` к этому моменту переехал,
        иначе удаляется лишь пейнтер);
      - любые прочие хвосты, оставшиеся от 01–05 (временный плоский материал,
        `ShipScreen.reveal`, дев-фикстуры под 7 деталей).
- [x] Снят вариант «Колючие куски» (D-013, PO отклонил на A/B):
      `SliceConfig.spikyPieces`, параметр `spiky` в `mergeAdjacentPieces`, их
      тесты и эталоны, кнопка в чит-меню; `SliceConfig` остаётся с одним
      значением или сворачивается — решение при нарезке.
- [x] **Ничего живого не снесено:** `grep -rn '<имя каждого удаляемого символа>'
      lib test` до удаления не находит ссылок из работающего кода — доказательство
      по каждой позиции списка приложено к стори (grep-вывод).
- [x] Документы приведены в соответствие: `docs/ARCHITECTURE.md` (карта модулей и
      схема связей), паспорта затронутых модулей (`lib/*/README.md`),
      `docs/DESIGN.md` (строка про карту «деталь → материал», которая после
      Ронина-1 не существует).
- [x] `flutter analyze` — 0 ошибок и предупреждений; `flutter test` — зелёный;
      смоук-команда (`flutter test test/widget_test.dart
      test/presentation/win_flow_test.dart`) — зелёная.
- [x] Контрольный grep по проекту не находит зомби-ссылок на удалённое
      (`ShipParts`, `ShipMaterials`, `materialForPart`, `materialForPiece`,
      `ShipPainter`, `reveal`) — кроме исторических упоминаний в `docs/`.

## Не входит

- Любые изменения поведения игры: стори не правит ни визуал, ни логику — только
  сносит то, что уже не исполняется. Всплыло поведенческое расхождение — это
  возврат в соответствующую стори, а не правка здесь.
- Рефакторинг «заодно» (переименования, разбиение файлов, уборка чужих хвостов
  вроде `widget_test.dart`-заглушки) — в `docs/BACKLOG.md`, скоуп не расширяется.
- `CanisterChargePainter` — выглядит осиротевшим по grep'у `lib`/`test`, но его
  потребитель `tool/generate_app_icon.dart` (генератор иконки приложения).
  **Не удалять** — известный ложный сигнал, урок эпика «Готовность».
- Фикстура `defaultTargetMask`/`defaultLevel` (крест 6×6) — база тестов движка,
  не игровой контент (`ARCHITECTURE.md`, «Тестовая фикстура»). Не удалять.

## Контекст для нарезки

- **Точный список к удалению фиксируется в начале стори**, а не сейчас: стори
  01–05 могут по ходу снести часть хвостов сами (например, если файл мешал
  компиляции). Первое действие — grep по кандидатам и сверка с фактом.
- **Удалять через `git rm`** (в allowlist проекта с 2026-07-23, `PROJECT.md`
  § «Синхронизация») — меньше прерываний на подтверждения, чем `rm`.
- **Порядок безопасного выпила:** сначала тесты удаляемого кода, потом сам код,
  потом документы; после каждого шага — `flutter analyze` (он же и есть детектор
  «снесли живое»).
- Урок эпика «Укладка» (выпил взрыва и старого ядра): резать честно, до конца —
  полуудалённый модуль хуже неудалённого, потому что выглядит рабочим.

## Затронутые модули

- `lib/game_engine/data/` — `ship_parts.dart`.
- `lib/presentation/theme/` — `ship_materials.dart`.
- `lib/presentation/widgets/` — `ship.dart` (`ShipPainter`).
- Документы: `docs/ARCHITECTURE.md`, паспорта модулей, `docs/DESIGN.md`.

## Открытые вопросы к PO

_нет_

## Сверка списка с фактом (Продюсер за Постановщика, 2026-10-09, HEAD b8c169e)

Число импортёров каждого файла `lib/` (вне самого файла; `lib` / `lib+test+tool`):

| Файл | lib | всего | Кто держит |
|---|---|---|---|
| `game_engine/data/ship_parts.dart` | 0 | 4 | свой тест, `content_packing_test` (проверяет дев-детали), `pack_slicer_test` (три маски 4×3 / 4×2 как фикстуры) |
| `presentation/theme/ship_materials.dart` | 0 | 1 | только свой тест |
| `presentation/widgets/ship.dart` | 1 | 3 | `cheat_menu.dart` и два теста — ради `kShipPartCount` (= `RoninParts.parts.length`); `ShipPainter` не зовёт никто |
| `game_engine/packing/start_metric.dart` | 0 | 1 | тест рампа D-009 — **живое**, инструмент метрики, оставить |
| `presentation/theme/canister_charge_painter.dart` | 0 | 1 | `tool/generate_app_icon.dart` — **живое**, оставить |

Колючие куски (D-013): `SliceConfig.spikyPieces`, `spiky` в `mergeAdjacentPieces`,
секция чит-меню «Нарезка: калибровка», `GameScreen.sliceConfig`, тесты в
`slice_config_test`, `cheat_menu_test`, `game_screen_test`, `win_flow_test`,
`packing_painter_test`, `start_metric_test`.

**Решение [Продюсер]:** без колючих у `SliceConfig` остаётся одно значение —
перечисление сносится целиком: `prepareLevel(partMask, {required seed})` всегда
режет «Крупными кусками», секция чит-меню «Нарезка: калибровка» уходит вместе с
устаревшей подписью. Имя файла `slice_config.dart` не
трогаем (переименование — рефакторинг «заодно»).

## Гейт 2 (Продюсер за Постановщика, 2026-10-09)

Перепрогон: `flutter analyze` — 0; `flutter test` — «+471: All tests passed!»
(было 598: ушли параметризованные тесты колючей конфигурации, дев-деталей и
карты материалов; эталоны нарезки «Крупных кусков» не менялись и зелёные).
Симулятор: деталь 1 режется теми же пятью кусками, что до чистки; чит-меню без
секции «Нарезка: калибровка» — стало короче и больше не заезжает под статус-бар
(`06-cheat-menu.png`). Поведение игры не изменилось.

**Вердикт:** проходимость, отклик, читаемость — как до чистки; мокап — не
затрагивается; «интересно» — н/п (служебная стори).

## Задачи

### T1 — Снос осиротевшего кода и колючих кусков

- **Статус:** выполнена, принята (коммит c4eb647)
- **Рекомендованный агент:** Исполнитель · Claude (`ispolnitel`)
- **Цель:** в коде остаётся только то, что участвует в игре; поведение не меняется.
- **Модули:** `lib/game_engine/data/`, `lib/game_engine/packing/`,
  `lib/presentation/` (`screens/`, `theme/`, `widgets/`) — удаления и правки
  ссылок; паспорта `README.md` каждого.
- **Что сделать (порядок — тесты → код → документы, `flutter analyze` после каждого шага):**
  1. **Доказательство до удаления:** для каждого символа (`ShipParts`,
     `ShipMaterials`, `materialForPart`, `ShipPainter`, `kShipPartCount`,
     `SliceConfig`, `spikyPieces`, `spiky`, `sliceConfig`, `onSetSliceConfig`)
     выполнить `grep -rn '<символ>' lib test tool` и вписать вывод в «Заметки по
     выполнению» (кратко: файл:строка). Живыми потребителями считаются только
     перечисленные выше — если найдётся ещё кто-то из работающего кода, стоп и
     эскалация.
  2. **Тесты-фикстуры:** `test/game_engine/packing/pack_slicer_test.dart` — три
     маски из `ShipParts.parts[0/1/5]` вписать локальными константами
     `TargetMask` (те же клетки), импорт `ship_parts.dart` убрать;
     `test/game_engine/data/content_packing_test.dart` — проверяет только
     дев-детали → `git rm` (покрытие «каждая деталь режется» для Ронина уже в
     `ronin_packing_test`; проверить, что он есть и зелёный).
  3. **`kShipPartCount`** → `RoninParts.parts.length` во всех потребителях
     (`cheat_menu.dart`, `cheat_menu_test.dart`, `game_screen_test.dart`).
  4. **`git rm`:** `lib/game_engine/data/ship_parts.dart`,
     `test/game_engine/data/ship_parts_test.dart`,
     `lib/presentation/theme/ship_materials.dart`,
     `test/presentation/theme/ship_materials_test.dart`,
     `lib/presentation/widgets/ship.dart` (целиком).
  5. **Колючие и `SliceConfig`:** в `slice_config.dart` удалить `enum SliceConfig`
     и параметр `spiky` с его веткой; `prepareLevel(TargetMask partMask,
     {required int seed})` — нарезка + `mergeAdjacentPieces(silhouette, slice)`.
     В `game_screen.dart` — `GameScreen.sliceConfig`, `_cheatSetSliceConfig` и
     передачу в чит-меню убрать; в `cheat_menu.dart` — параметры `sliceConfig` /
     `onSetSliceConfig`, секцию «Нарезка: калибровка», `_sliceConfigLabel`.
     Тесты: убрать группу `spikyPieces` и `_compactShare` из
     `slice_config_test`, тесты кнопок нарезки из `cheat_menu_test`, тесты
     переключения конфигурации из `game_screen_test`, `tearDown`-сбросы
     `GameScreen.sliceConfig`; вызовы `prepareLevel(..., SliceConfig.bigPieces,
     seed: …)` → `prepareLevel(..., seed: …)`. Эталоны нарезки «Крупных кусков»
     (`_bigPiecesReference`, `_referenceSlices`) — **не менять**: нарезка должна
     остаться побитово прежней, это и есть проверка «поведение не изменилось».
  6. **Комментарии-зомби** в живом коде: `block_material.dart`,
     `procedural_block_skin.dart`, `progress_service.dart` (+ тест) — упоминания
     `ShipMaterials` / `ShipPainter` / `ShipParts` переписать под текущее
     состояние или убрать.
  7. **Документы:** `docs/ARCHITECTURE.md` (таблица модулей и схема связей:
     `ship_parts`, `ship_materials`, `widgets/ship.dart`, `SliceConfig`),
     паспорта `lib/game_engine/data/README.md`, `lib/game_engine/packing/README.md`,
     `lib/presentation/{screens,theme,widgets}/README.md`, `lib/application/README.md`;
     `docs/DESIGN.md` — строка про карту «деталь → материал» и про A/B колючих
     (если есть) приводятся к факту. `docs/BACKLOG.md` не трогать.
- **Арх-дельта:** удаление строк `ship_parts`, `ship_materials`, `widgets/ship.dart`
  и связи `screens → widgets/ship`; `SliceConfig` из описания `packing`.
- **Результат (как проверить):** `flutter analyze` — 0; `flutter test` — зелёный;
  смоук `flutter test test/widget_test.dart test/presentation/win_flow_test.dart`
  — зелёный; `grep -rn 'ShipParts\|ShipMaterials\|materialForPart\|materialForPiece\|ShipPainter\|kShipPartCount\|SliceConfig\|spiky' lib test tool`
  — пусто (кроме README с историческими пометками, если они явно помечены как
  история).
- **DoD задачи:** паспорта; арх-дельта; `system/AGENT.md` п. 5. Не коммитить.
- **Заметки по выполнению:**
  - **Grep-доказательства до удаления** (`grep -rn '<символ>' lib test tool`, HEAD b8c169e,
    только `.dart`; README-упоминания — документы):
    - `ShipParts`: определение `lib/game_engine/data/ship_parts.dart:32` (+ doc-ссылки в
      нём); потребители: `test/game_engine/data/ship_parts_test.dart`,
      `test/game_engine/data/content_packing_test.dart:13-14`,
      `test/game_engine/packing/pack_slicer_test.dart:11-13`, `test/presentation/theme/ship_materials_test.dart:11,15`;
      в `lib/` вне самого файла — только комментарии (`progress_service.dart:17`).
    - `ShipMaterials`/`materialForPart`: определение `lib/presentation/theme/ship_materials.dart:8,20,33`;
      потребитель один — `test/presentation/theme/ship_materials_test.dart:8-32`; в `lib/` вне файла — только
      комментарии (`procedural_block_skin.dart:11`, `block_material.dart:8`, `widgets/ship.dart:27,30`).
      `materialForPiece` — в `.dart` нет (только README).
    - `ShipPainter`: определение `lib/presentation/widgets/ship.dart:36,46,129`; вне файла —
      только комментарии (`block_material.dart:9,33`); пейнтер не зовёт никто.
    - `kShipPartCount`: определение `ship.dart:15`; потребители `lib/presentation/screens/cheat_menu.dart:75,90`,
      `test/presentation/cheat_menu_test.dart` (57-156), `test/presentation/game_screen_test.dart:69,229` — как в таблице сверки.
    - `SliceConfig`/`spikyPieces`/`spiky`/`sliceConfig`/`onSetSliceConfig`: `lib/game_engine/packing/slice_config.dart:11-84,121-189`,
      `lib/presentation/screens/game_screen.dart:48,188,289-290,328-330`, `cheat_menu.dart:35-187`;
      тесты — `slice_config_test`, `cheat_menu_test`, `game_screen_test`, `win_flow_test:40`, `packing_painter_test:104`,
      `start_metric_test:44` — ровно перечень из «Сверки списка с фактом». `tool/` — ни одного вхождения.
    - Живых потребителей сверх перечисленных нет, эскалации не потребовалось. Побочно проверено:
      `reveal` в `ship_screen.dart`/`ship_composite_painter.dart` — живой код экрана корабля
      (`revealPartIndex`/`revealProgress`), не хвост; не тронут. `start_metric.dart` и
      `CanisterChargePainter` (`tool/generate_app_icon.dart`), `defaultTargetMask` не тронуты.
  - **Выполнено:** `pack_slicer_test` — три маски (корпус 4×3, нос 4×2, двигатель 4×2) вписаны
    локальными `const TargetMask` (клетки те же); `content_packing_test` удалён (покрытие «каждая деталь
    режется и укладывается» — `ronin_packing_test`, 15 деталей, зелёный); `kShipPartCount` →
    `RoninParts.parts.length` (в `cheat_menu.dart` и в тестах через локальную `_partCount`);
    `git rm` 5 файлов (`ship_parts`+тест, `ship_materials`+тест, `widgets/ship.dart` целиком);
    `enum SliceConfig`, `spiky`/`mergedFill`, `GameScreen.sliceConfig`, `_cheatSetSliceConfig`,
    секция «Нарезка: калибровка», `_sliceConfigLabel` сняты; `prepareLevel(partMask, {required seed})`;
    из тестов убраны группа `spikyPieces`, `_compactShare`/`_isCompact`, группа кнопок нарезки,
    `pickSliceConfig`, `tearDown`-сбросы. Эталоны `_bigPiecesReference`/`_referenceSlices` **не менялись**
    (изменён только doc-комментарий над `_bigPiecesReference`, данные нетронуты) — `slice_config_test`
    «канонные нарезки 15 деталей» зелёный, нарезка побитово прежняя.
  - Тесты упрощены без потери проверки: «лоток не выше 160 px» остался (по одной конфигурации),
    «Пересобрать сдвигает seed» остался (без шага выбора конфигурации). Названия кейсов `pack_slicer_test`
    изменились (ярлыки масок без `parts[i]`).
  - Комментарии-зомби переписаны: `block_material.dart`, `procedural_block_skin.dart`,
    `progress_service.dart`, `progress_service_test.dart`. Паспорта: `application`, `game_engine/{data,models,packing}`,
    `presentation/{screens,theme,widgets}`; `docs/ARCHITECTURE.md` (таблица, схема, связи), `docs/DESIGN.md`
    (карта «деталь → материал», строка про scrap/материал по карте; запись про отклонение «Колючих» (D-013) оставлена как решение).
  - **Результат:** `flutter analyze` — No issues found; `flutter test` — `+471: All tests passed!`;
    смоук (`widget_test` + `win_flow_test`) — `+1: All tests passed!`. Контрольный grep
    `ShipParts|ShipMaterials|materialForPart|materialForPiece|ShipPainter|kShipPartCount|SliceConfig|spiky` по `lib test tool`
    — единственные совпадения подстрокой в других именах: `onSetShipParts`/`_cheatSetShipParts`
    (колбэк чита «Состояние корабля», живой, не переименован — рефакторинг «заодно»).
  - `dart format` на тронутых файлах не прогонялся: файлы исходно не отформатированы
    (прогон переформатировал бы чужие строки).
