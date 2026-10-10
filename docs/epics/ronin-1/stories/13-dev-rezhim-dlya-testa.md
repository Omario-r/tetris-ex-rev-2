# STORY 13 — Дев-режим для теста: чит-меню в любой сборке, версия, понятные читы

**Эпик:** Ронин-1 — первые модули корабля
**Статус:** закрыта 2026-10-10 (Гейт 2 — раздел «Гейт 2»)

## Ценность

PO может **ставить игру с иконки (release) и при этом пользоваться чит-меню,
видеть, какая сборка стоит, и переключаться понятными кнопками**, чтобы **вести
плейтест без отдельной debug-сессии и без путаницы, что установлено** (PO
2026-10-10, D-018). Попутно — без переполнения экрана игры при крупном системном
шрифте (на телефоне PO: «bottom overflowed by 3 pixels»).

## Критерии приёмки

- [x] Чит-меню и дев-кнопки видны в любой сборке, пока флаг `DEV_TOOLS` включён (по
      умолчанию — да); `--dart-define=DEV_TOOLS=false` их прячет.
- [x] В чит-меню — строка сборки: короткий хеш коммита и время сборки (из
      `--dart-define`; без них — «dev»).
- [x] Чит-меню: «Уровень» 1…N — открывает деталь N, корабль собран до неё (детали
      1…N−1); кнопки «Сбросить на начало» (прогресс 0, деталь 1) и «Закончить
      уровень» (все куски укладываются, дальше обычная пауза «деталь собрана»).
      «Победить», «Состояние корабля», «Пересобрать нарезку», «Решить» — сняты.
- [x] Экран игры и экран корабля без переполнения при системном шрифте до ×1,5 на
      экранах 375×667 … 430×932.
- [x] Ранбук: команды сборки передают хеш и время.
- [x] `flutter analyze` — 0; `flutter test` — зелёный.
- [x] **Гейт 2:** в симуляторе сборка с хешем и временем, чит-меню, строка сборки,
      «Закончить уровень» (release на симуляторе Flutter не собирает — флаг `DEV_TOOLS`
      от режима не зависит, закрыт тестами).

## Гейт 2 (Продюсер за Постановщика, 2026-10-10, симулятор iPhone 17)

| Что | Итог |
|---|---|
| Чит-меню (`13-cheat-menu.png`) | «Сборка: 35f26fc · 10.10 20:35»; «Уровень» 1–19; «Сбросить на начало», «Закончить уровень»; старых кнопок нет |
| «Закончить уровень» (`13-finish-level.png`) | куски уложены, пауза «деталь собрана», кнопки «К кораблю» / «Следующая деталь» |
| Выбор уровня, сброс | закрыты тестами `game_screen_test` (прогресс = N, деталь N; прогресс 0, деталь 1) |
| Крупный шрифт | `text_scale_overflow_test`: ×1,0/1,2/1,5 на 375×667, 402×874, 430×932 — без переполнения (экран игры и корабля) |

Проверки: `flutter analyze` — 0; `flutter test` — 613 зелёных (перепрогон Продюсера).

**Вердикт:** проходимость — да; отклик — да; читаемость — меню понятное, сборку видно;
мокап — дев-экран, мокапа нет; «интересно» — н/п.

## Не входит

- Номер версии из `pubspec` (нужна новая зависимость — не нужно, PO 2026-10-10).
- Выключение флага перед публикацией — BACKLOG (D-018).

## Задачи

### T1 — флаг дев-инструментов, строка сборки, новое чит-меню, без переполнения

- **Статус:** готова (не закоммичена — коммит делает Постановщик)
- **Рекомендованный агент:** Исполнитель · Claude (`ispolnitel`)
- **Модули (≤ 3):** `lib/application/` (новый `build_info.dart`, паспорт),
  `lib/presentation/screens/` (`game_screen.dart`, `cheat_menu.dart`,
  `ship_screen.dart`, паспорт); тесты `test/`.
- **Что сделать:**
  1. `lib/application/build_info.dart`:
     `const bool kDevTools = bool.fromEnvironment('DEV_TOOLS', defaultValue: true);`
     `const String kBuildCommit = String.fromEnvironment('BUILD_COMMIT');`
     `const String kBuildTime = String.fromEnvironment('BUILD_TIME');`
     и `String buildLabel()` — «`<commit> · <time>`», пустые части опускаются, обе
     пустые — «dev». Комментарий: D-018, до публикации флаг выключить.
  2. Все `kDebugMode`-гейты дев-инструментов (`GameScreen` — кнопка чит-меню,
     `ShipScreen` — «Сброс прогресса (dev)») → `kDevTools`.
  3. `CheatMenu` / `showCheatMenu` — новый состав:
     - заголовок «Чит-меню», под ним строка сборки `Key('cheat_build')`
       («Сборка: …»);
     - «Уровень» — кнопки 1…N (`Key('cheat_level_$i')`, `i` — 0-based) →
       `onSelectLevel(i)`;
     - кнопки `Key('cheat_reset')` «Сбросить на начало» → `onResetGame` и
       `Key('cheat_finish_level')` «Закончить уровень» → `onFinishLevel`.
     Колбэки `onInstantWin`, `onSetShipParts`, `onReshuffle`, `onSolve` — убрать.
  4. `GameScreen`:
     - `onSelectLevel(i)`: `ProgressService().setCollectedCount(i)`, затем
       `pushReplacement(GameScreen(levelIndex: i))`;
     - `onResetGame`: `ProgressService().reset()`, затем `GameScreen(levelIndex: 0)`;
     - `onFinishLevel`: закрыть меню и `_solveAll()` (укладка → `isComplete` →
       обычная пауза и засчёт детали, как после ручной сборки);
     - снять `_cheatInstantWin`, `_cheatSetShipParts`, `_cheatReshuffle` и всё, что
       осталось только ради них (`_reshuffle`, `_seedOffset` — если больше нигде не
       нужны; seed детали по умолчанию не меняется). `_solveAll` остаётся (им
       пользуются тесты).
  5. Переполнение: при системном шрифте > 1 переполняется блок прогресса над полем
     (`_buildProgress`, `Column` в зоне фиксированной высоты `_progZoneHeight`;
     ×1,1 — 1 px, ×1,3 — 4 px). Зоны фиксированной высоты экрана игры (топбар,
     прогресс, кнопки паузы) — `MediaQuery.withClampedTextScaling(maxScaleFactor:
     1.0)`; лоток и поле — без текста. Экран корабля — проверить тем же тестом и
     поправить так же, если переполняется.
  6. Тесты:
     - `build_info`: `buildLabel` для пустых/частичных/полных значений (вынести
       сборку строки в функцию с параметрами, чтобы тестировать без
       `--dart-define`);
     - `cheat_menu_test` — под новый состав (строка сборки, N кнопок уровня, две
       кнопки, старых ключей нет);
     - `game_screen_test`: выбор уровня `i` → `getCollectedCount() == i` и открыта
       деталь `i`; «Сбросить на начало» → прогресс 0, деталь 1; «Закончить уровень»
       → пауза «деталь собрана», деталь засчитана; кнопка чит-меню есть
       (`kDevTools` по умолчанию `true`);
     - новый тест переполнения: `GameScreen` на деталях 1, 13, 17 (и на паузе) и
       `ShipScreen` при `textScaler` 1.0 / 1.2 / 1.5 и размерах 375×667, 402×874,
       430×932 — без `FlutterError` о переполнении;
     - остальные тесты, где были старые читы, — под новый состав (в «Заметках» —
       что поменялось).
- **Арх-дельта:** новый файл в модуле `application` (паспорт).
- **Результат:** `flutter analyze` — 0; `flutter test` — зелёный.
- **DoD:** паспорта `application`, `screens`; `system/AGENT.md` п. 5. Не коммитить.
- **Заметки по выполнению:**
  - Сделано: `lib/application/build_info.dart` (`kDevTools`, `kBuildCommit`, `kBuildTime`,
    `buildLabel()` + `composeBuildLabel(commit, time)` для тестов). `kDebugMode` заменён на
    `kDevTools` в `GameScreen` (кнопка читов) и `ShipScreen` («Сброс прогресса (dev)»).
    `CheatMenu`/`showCheatMenu`: «Чит-меню», `cheat_build` «Сборка: …», «Уровень» 1…N
    (`cheat_level_$i`), `cheat_reset`, `cheat_finish_level`; колбэки `onSelectLevel`,
    `onResetGame`, `onFinishLevel`. `GameScreen`: `_cheatSelectLevel` (pop → `setCollectedCount(i)`
    → `pushReplacement(GameScreen(i))`), `_cheatResetGame` (pop → `reset()` → `GameScreen(0)`),
    `_cheatFinishLevel` (pop → `_solveAll()`). Сняты `_cheatInstantWin`, `_cheatSetShipParts`,
    `_cheatReshuffle`, `_cheatSolve`, `_reshuffle`, `_restartLevel`, `_seedOffset`; `_markDone`
    и `_solveAll` остались.
  - Переполнение: `_fixedText` (`MediaQuery.withClampedTextScaling(maxScaleFactor: 1.0)`) на
    топбаре, строке прогресса и кнопках паузы `GameScreen`. `ShipScreen` на ×1,5 переполнялся
    (шапка `_Header` высотой 38, 9 px по низу) — решение внутри ТЗ п. 5 «поправить так же»:
    шапка в таком же clamp.
  - Тесты: новые `test/application/build_info_test.dart` и
    `test/presentation/text_scale_overflow_test.dart` (3 размера × 3 шрифта; GameScreen — детали
    1/13/17 + пауза через чит-меню, ShipScreen — три режима). `cheat_menu_test` переписан под
    новый состав (строка сборки, N кнопок, две кнопки, старых ключей нет, нет overflow на
    390×844). В `game_screen_test`: `cheat_solve` → `cheat_finish_level` (3 места), удалён тест
    «Пересобрать» (чит снят), добавлена группа «чит-меню» (уровень i → собрано i и деталь i,
    понижение прогресса, сброс, «Закончить уровень»). `win_flow_test`: `cheat_solve` →
    `cheat_finish_level`. `ship_screen_test`: правка комментария.
  - Паспорта `application` и `presentation/screens` обновлены. Ранбук и `STATUS.md` не трогал
    (по указанию Постановщика).
  - Итог: `flutter analyze` — No issues found; `flutter test` — 613 тестов, All tests passed.
  - Развилок нет.
