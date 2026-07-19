# STORY 03 — Иконка/имя приложения + ранбук и смоук на устройствах

> Заполняет Постановщик при декомпозиции. PO утверждает на Гейте 1 и принимает
> на Гейте 2.

**Эпик:** Готовность к плейтесту
**Статус:** T1–T3 закрыты 2026-07-19 (T1 отображаемое имя «Voxel Voyager»,
T2 своя иконка iOS+Android через `flutter_launcher_icons`, T3
`docs/RUNBOOK-devices.md` + локальный смоук 301/301). **Гейт 2 — device-gated:
ждёт прогона PO** на его iOS+Android по ранбуку (агент устройства не трогает).
Зависимость `flutter_launcher_icons` одобрена PO 2026-07-19 (dev-dep).

## Ценность

PO может **установить игру на свои iOS + Android под своим именем и иконкой** и
**пройти весь контент от старта до собранного корабля без падений**, чтобы был
готовый носитель для раннего плейтеста своими силами (VISION, эпик #5 позже).

## Критерии приёмки

- [ ] Имя приложения (отображаемое; `pubspec.yaml` + платформенные конфиги) — своё,
  без отсылок к Minecraft.
- [ ] Иконка на iOS и на Android — своя (не дефолтная Flutter-заглушка, не Minecraft).
- [ ] Агент написал **ранбук**: пошаговая установка на iOS (free-signing Xcode) и
  Android + чек-лист смоука (весь контент от старта до собранного корабля без падений).
- [ ] PO по ранбуку прогнал на ≥1 iOS и ≥1 Android — «без падений» подтверждено
  (результат по устройствам — в «Заметках по выполнению»).
- [ ] `flutter analyze` — 0; локальный смоук (`win_flow_test` + `golden_scenario` +
  `widget_test`) зелёный перед сборкой под устройства.

## Не входит

- Раздаваемая сборка для внешних тестеров (TestFlight/APK-раздача) — только свои
  устройства (решение PO).
- Публикация в стор, платные аккаунты — product-режим, после плейтеста.
- Визуальный полиш — **Стори 01**.
- Изменения ядра/правил/контента — заморожено VISION.

## Дизайн-референс

> Канон — `docs/DESIGN.md` + утверждённый мокап `docs/design/app-icon.html`
> (вариант «Заряд», утверждён PO 2026-07-18; варианты «деталь-нос» и «корабль»
> отклонены). Сверка с мокапом — на Гейте 2.

**Иконка = канистра-заряд** — тот же объект языка, что кнопка взрыва (стори 02):
- корпус `graphite` `hsl(215 9% 31%)`, колпак `graphite-dark` `hsl(215 9% 26%)` +
  индикатор `#CFD6DD`, вертикальный шов, диагональная hazard-полоса
  (repeating-linear 45°, `hazard-orange` `hsl(23 62% 46%)` / `#17191D`);
- фон иконки — `matte-black` `hsl(220 12% 13%)`; исходник — **квадрат** с
  центрированной канистрой и полем-отступом, **без запечённых скруглённых углов**
  (обе ОС маскируют сами: iOS — суперэллипс, Android — adaptive icon);
- **Android** отдать слоями: foreground (канистра) + background (matte-black).

**Имя приложения — «Voxel Voyager»** (из VISION). В сплэше/маркетинге акцент —
«VOYAGER» в `hazard-orange`; отображаемое имя ОС — просто «Voxel Voyager».
Проверить на устройстве (стори 03), влезает ли имя под иконкой на обеих ОС.

## Контекст для нарезки

- Платформенные каталоги `android/` и `ios/` уже есть (прототип запускается) —
  меняем иконку/имя, новую платформу не заводим. `pubspec.yaml` — имя.
- Смоук: `win_flow_test` — сквозной прогон контента (основа смоука); агент держит
  его зелёным. На устройстве прогоняет **PO по ранбуку агента** — у агента в CLI нет
  доступа к устройствам (решено на консультации: PO ставит, агент инструктирует).

## Затронутые модули

- `android/`, `ios/`, `pubspec.yaml` — платформенная упаковка (не `lib/`-модуль,
  паспорт не требуется).
- `test/` — прогон существующих смоук-тестов (без новых).

## Открытые вопросы к PO

_нет_

## Задачи

> Нарезал Постановщик 2026-07-19. Порядок = зависимости: имя → иконка → ранбук.
> T1 и T2 обе трогают платформенные каталоги, но разные файлы (T1 — label/
> DisplayName, T2 — иконки/pubspec) — конфликтов нет, порядок для чистоты.
> Приёмка стори (Гейт 2) — device-gated: закрывает PO прогоном ранбука (T3) на
> своих iOS+Android; агент устройства не трогает.

### T1 — Отображаемое имя приложения «Voxel Voyager»
- **Статус:** выполнено (2026-07-19)
- **Рекомендованный агент:** Исполнитель · Claude/Sonnet (`ispolnitel`) — правка
  двух платформенных конфигов, не «тяжёлая».
- **Цель:** на домашнем экране обеих ОС приложение подписано «Voxel Voyager»
  (не «Explosive Tetris», не Minecraft-отсылки).
- **Модули (≤3):** `android/` (`app/src/main/AndroidManifest.xml`), `ios/`
  (`Runner/Info.plist`). Не `lib/`-модули — паспорт не требуется. `test/` — нет
  (платформенный конфиг тестами не покрывается).
- **Что сделать:**
  1. `android/app/src/main/AndroidManifest.xml:3` — `android:label="explosive_tetris"`
     → `android:label="Voxel Voyager"`.
  2. `ios/Runner/Info.plist` — `CFBundleDisplayName` (сейчас `Explosive Tetris`) →
     `Voxel Voyager`. `CFBundleName` (`explosive_tetris`) НЕ трогать — это короткое
     служебное имя; `applicationId`/`PRODUCT_BUNDLE_IDENTIFIER`
     (`com.example.explosive_tetris`) НЕ трогать (смена ломает подпись/установку).
  3. Пакетное имя в `pubspec.yaml` (`name: explosive_tetris`) НЕ трогать — это
     Dart-пакет, смена ломает все импорты `package:explosive_tetris/...`.
- **Границы (строго):** только `android:label` и `CFBundleDisplayName`. Bundle id,
  applicationId, Dart-имя пакета, версии — не трогать.
- **Арх-дельта:** нет.
- **Результат (как проверить):** `flutter analyze` = 0; `flutter test` зелёные
  (ничего не должно измениться — конфиг не в тестовом покрытии). Визуально имя
  под иконкой — на устройстве (T3, PO). `grep -rn "Voxel Voyager" android/ ios/`
  показывает обе правки.
- **DoD задачи:** статус задачи в стори; `docs/STATUS.md`; один коммит
  `gotovnost/03-ikonka-imya-i-smouk T1: <суть>`.
- **Заметки по выполнению:** правка ровно двух строк: `android/app/src/main/AndroidManifest.xml:3`
  `android:label="explosive_tetris"` → `"Voxel Voyager"`; `ios/Runner/Info.plist`
  `CFBundleDisplayName` `Explosive Tetris` → `Voxel Voyager`. `CFBundleName`,
  `applicationId`/`PRODUCT_BUNDLE_IDENTIFIER`, `pubspec.yaml` `name:` — не тронуты.
  `flutter analyze` = 0 ошибок/предупреждений. `flutter test` — 301/301 зелёных
  (не изменилось, как и ожидалось — конфиг вне тестового покрытия). `grep -rn
  "Voxel Voyager" android/ ios/` подтверждает обе правки. Визуальная проверка
  имени под иконкой на устройстве — T3/Гейт 2 (PO).

### T2 — Своя иконка (iOS + Android) из канона канистры-заряда
- **Статус:** выполнено (2026-07-19)
- **Рекомендованный агент:** Исполнитель · Claude/Sonnet (`ispolnitel`). ТЗ
  детальное; домен хрупкий (платформенная упаковка, первый заход). **Критик
  (режим «ТЗ») отработал 2026-07-19** — критические пробелы закрыты в разделе
  «Уточнения» ниже (алгоритм вписания, структура генератора, версия/команда
  пакета, safe-zone, регистрация исходников). ТЗ готово к запуску.
- **Цель:** на iOS и Android — своя иконка «канистра-заряд» (не дефолтная
  Flutter-заглушка, не Minecraft), в каноне мокапа `docs/design/app-icon.html`.
- **Модули (≤3):** `pubspec.yaml` (dev-dep + конфиг `flutter_launcher_icons`);
  `theme` (переиспользование `CanisterChargePainter` для рендера исходника — файл
  `lib/presentation/theme/canister_charge_painter.dart`, паспорт
  `lib/presentation/theme/README.md` если добавляется публичный хелпер);
  генератор пишет в `android/`/`ios/` (артефакты, не модуль). + инструмент
  рендера исходника в `test/` или `tool/`.
- **Дизайн-референс:** мокап `docs/design/app-icon.html` (вариант «Заряд»,
  утверждён PO 2026-07-18). Пропорции с эталона `.appicon.l` = 180×180:
  канистра `.can` 74×100 (≈0.411×0.556 от стороны иконки), `margin-top` 14
  (≈0.078), центрирована по горизонтали, колпак/индикатор над корпусом. Фон —
  `matteBlack` `#1D2025`. Токены канистры уже в `CanisterChargePainter`
  (`_graphite #484E56`, `_graphiteDark #3C4148`, `_hazardOrange #BE642D` и т.д.).
  **Исходник — квадрат БЕЗ запечённых скруглённых углов** (обе ОС маскируют
  сами); Android — **слоями**: foreground = канистра (прозрачный фон),
  background = сплошной `matteBlack`.
- **Что сделать:**
  1. Сгенерировать исходники PNG из канона (переиспользовать
     `CanisterChargePainter(state: ChargeIconState.ready)` — тот же объект, что
     кнопка взрыва, единый источник правды). Инструмент: Flutter-тест или
     `tool/`-скрипт, который через `PictureRecorder`→`picture.toImage`→
     `toByteData(png)` рисует на 1024×1024:
     - `assets/icon/app_icon.png` — matteBlack-квадрат + канистра по центру
       (масштаб/сдвиг по пропорциям выше; учесть, что painter рисует колпак в
       отрицательном `y` относительно корпуса — вписать полные габариты
       канистры с полем-отступом);
     - `assets/icon/app_icon_foreground.png` — та же канистра на ПРОЗРАЧНОМ фоне
       (для Android adaptive foreground), с safe-zone запасом (adaptive-иконка
       обрезается маской — канистра в центральных ~66%).
  2. `pubspec.yaml`: добавить `flutter_launcher_icons` в `dev_dependencies` +
     блок конфига (`android: true`, `ios: true`, `image_path: assets/icon/app_icon.png`,
     `adaptive_icon_foreground: assets/icon/app_icon_foreground.png`,
     `adaptive_icon_background: "#1D2025"`, `remove_alpha_ios: true`). `flutter pub get`.
  3. Запустить `dart run flutter_launcher_icons` (или `flutter pub run
     flutter_launcher_icons`) — сгенерит `ios/Runner/Assets.xcassets/AppIcon.appiconset`
     и `android/app/src/main/res/mipmap-*` + adaptive XML в `mipmap-anydpi-v26`.
     Убедиться, что дефолтная Flutter-иконка заменена (файлы перезаписаны).
- **Уточнения (по холодной вычитке Критиком 2026-07-19 — закрыть до кода):**
  1. **Вписание канистры (колпак в −y) — точные числа.** Полные габариты
     `_paintCanister` в локали пейнтера (до масштаба): x∈[0,34], y∈[−8,46]
     (колпак сверху −8, корпус до 46, индикатор ≈−6 внутри) → ширина 34, высота
     54. Пейнтер масштабирует по `size.width/34` (height параметра не использует).
     - `app_icon.png` (1024²): ширина канистры `canW=421` (≈0.411·1024 из мокапа
       `.can` 74/180). `s=421/34≈12.38`, полная высота `54·s≈669`. Отрисовка:
       `canvas.drawRect(0,0,1024,1024, matteBlack #1D2025)`; затем
       `canvas.translate(301.5, 276.5)` (dx=(1024−421)/2; ty так, что полный верх
       на (1024−669)/2≈177.5, т.е. ty=177.5+8·s); затем
       `CanisterChargePainter(state: ChargeIconState.ready).paint(canvas, Size(421,421))`.
     - `app_icon_foreground.png` (1024², ПРОЗРАЧНЫЙ фон — фон НЕ заливать):
       `canW=360` (запас под adaptive-маску), `s≈10.59`, полная высота ≈572;
       `canvas.translate(332, 310.7)` (dx=(1024−360)/2; ty=(1024−572)/2+8·s);
       `paint(canvas, Size(360,360))`. Канистра ложится в центральные ~66%
       (safe-zone adaptive), маска её не режет.
  2. **Пайплайн — где код.** Генератор — Flutter-**тест-файл** `tool/generate_app_icon.dart`
     (НЕ в `test/`, чтобы не попал в дефолтный `flutter test`, который берёт
     `test/**_test.dart`). Внутри: `TestWidgetsFlutterBinding.ensureInitialized()`,
     `PictureRecorder`→`Canvas`→заливка/трансформ/`painter.paint`→
     `final img = await recorder.endRecording().toImage(1024,1024)`→
     `final png = await img.toByteData(format: ui.ImageByteFormat.png)`→
     `File('assets/icon/app_icon.png').writeAsBytesSync(png!.buffer.asUint8List())`
     (и второй файл). Запуск разово: `flutter test tool/generate_app_icon.dart`.
     Идемпотентен (детерминированный рендер), в обычный прогон тестов не входит.
  3. **Пакет — версия/команда.** Добавить через `flutter pub add dev:flutter_launcher_icons`
     (подберёт совместимую версию — не хардкодить constraint). Генерация:
     `dart run flutter_launcher_icons`. Если README установленной версии диктует
     иную команду — следовать ей.
  4. **`assets/icon/` создать в корне, НЕ регистрировать в `flutter: assets:`** —
     исходники PNG это вход генератора, не ресурсы приложения (иначе зря
     раздуют APK/IPA).
  5. **minSdk не менять**, `monochrome`/доп-теги не нужны — стандартный конфиг.
     Web-таргет `flutter_launcher_icons` не трогает (это норма, вне скоупа).
- **Границы (строго):** только иконка. Игровую логику, `lib/` вне
  `canister_charge_painter.dart`, имя (T1) — не трогать. Новую платформу не
  заводить. Единственная новая зависимость — `flutter_launcher_icons` (одобрена
  PO); других не добавлять.
- **Арх-дельта:** нет (если публичный хелпер рендера иконки добавляется в
  `theme` — отметить в паспорте `theme/README.md`, связи модулей не меняются).
- **Результат (как проверить):** `flutter analyze` = 0; `flutter test` (дефолтный
  набор, БЕЗ `tool/`) зелёные — число тестов не растёт (генератор вне суита).
  Иконки сгенерированы: `ls ios/Runner/Assets.xcassets/AppIcon.appiconset` — PNG
  перезаписаны (>1KB, не дефолт-Flutter); `android/app/src/main/res/mipmap-anydpi-v26/`
  содержит `ic_launcher.xml` (adaptive) + foreground/background drawables.
  Исходники `assets/icon/app_icon.png` и `app_icon_foreground.png` существуют.
  Визуал иконки на домашнем экране — Гейт 2 (PO на устройстве, T3).
- **DoD задачи:** паспорт `theme` (если добавлен хелпер рендера иконки); статус
  задачи в стори; `docs/STATUS.md`; ОДИН коммит `gotovnost/03-ikonka-imya-i-smouk
  T2: <суть>`, включающий: исходники `assets/icon/*`, генератор
  `tool/generate_app_icon.dart`, сгенерированные ассеты (`android/`, `ios/`),
  `pubspec.yaml`.
- **Заметки по выполнению:** Генератор `tool/generate_app_icon.dart`
  (Flutter-тест-файл, не в `test/` — не попадает в дефолтный `flutter test`)
  рендерит `CanisterChargePainter(state: ChargeIconState.ready)` через
  `PictureRecorder`→`Canvas`→`toImage(1024,1024)`→`toByteData(png)` в
  `assets/icon/app_icon.png` (matteBlack `#1D2025` фон, `canW=421`,
  `translate(301.5, 276.5)`, `paint(Size(421,421))`) и
  `assets/icon/app_icon_foreground.png` (прозрачный фон, `canW=360`,
  `translate(332, 310.7)`, `paint(Size(360,360))`) — числа по уточнению ТЗ,
  визуально сверено (иконка = канистра-заряд, канон мокапа). Запуск разово:
  `flutter test tool/generate_app_icon.dart` — прошёл. Пакет добавлен
  `flutter pub add dev:flutter_launcher_icons` → `flutter_launcher_icons: ^0.14.4`
  (без хардкода версии). Конфиг в `pubspec.yaml` (`flutter_launcher_icons:`
  верхнего уровня): `android: true`, `ios: true`, `remove_alpha_ios: true`,
  `image_path`, `adaptive_icon_background: "#1D2025"`,
  `adaptive_icon_foreground`. `assets/icon/` НЕ зарегистрирован в
  `flutter: assets:` (вход генератора, не ресурс приложения). Генерация:
  `dart run flutter_launcher_icons` → `AppIcon.appiconset` перезаписан (25
  файлов, PNG 402Б–14002Б, включая 1024×1024), новые idiom-размеры (50/57/72)
  добавлены пакетом (стандартное поведение); Android получил
  `mipmap-anydpi-v26/ic_launcher.xml` (adaptive, background=`@color/
  ic_launcher_background` из нового `values/colors.xml` `#1D2025`,
  foreground=`drawable-*/ic_launcher_foreground.png` с inset 16%) + легаси
  `mipmap-*/ic_launcher.png` перезаписаны. `ios/Runner.xcodeproj/project.pbxproj`
  получил 2-строчную правку `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS`
  `YES`→`AppIcon` — штатный побочный эффект генератора пакета, не трогал руками.
  minSdk не менялся (`android/app/build.gradle.kts` — `minSdk = flutter.minSdkVersion`,
  без диффа). `flutter analyze` = 0 ошибок/предупреждений. Дефолтный `flutter
  test` (БЕЗ `tool/`) — 301/301 зелёных (не изменилось, как и ожидалось —
  генератор вне суита). Паспорт `theme/README.md` не тронут — публичный хелпер
  рендера НЕ добавлялся, `CanisterChargePainter` переиспользован как есть
  (уже публичный конструктор), новый интерфейс модуля не появился. Визуал
  иконки на домашнем экране — T3/Гейт 2 (PO).
  **Побочная находка/фикс:** `.gitignore` строка `Icon` (правило для macOS
  custom-folder-icon, литерального файла, оканчивающегося двумя CR-байтами)
  без anchoring совпадала регистронезависимо (macOS `core.ignorecase`) с ЛЮБЫМ
  путём, содержащим компонент `icon`/`Icon` — включая новый каталог
  `assets/icon/`, из-за чего исходники не попадали под git-трекинг
  (`git status` их не видел, `git check-ignore` подтвердил совпадение с
  правилом `Icon`). Минимальный фикс: заменил `Icon` на `Icon\r\r`
  (два литеральных CR-байта — канонический macOS-gitignore идиом из
  github/gitignore), теперь совпадает только с настоящим артефактом Finder, не
  с нашим каталогом. Проверено: `git check-ignore assets/icon
  assets/icon/app_icon.png assets/icon/app_icon_foreground.png` → exit 1
  (не игнорируется); `git status --short assets/` → `?? assets/icon/`. Диф
  `.gitignore` — только эта строка (комментарий + замена).

### T3 — Ранбук установки на устройства + локальный смоук
- **Статус:** выполнено (2026-07-19)
- **Рекомендованный агент:** Исполнитель · Claude/Sonnet (`ispolnitel`) —
  техпис + прогон существующих смоук-тестов, не «тяжёлая».
- **Цель:** у PO есть пошаговый ранбук, по которому он ставит игру на свои
  iOS + Android и прогоняет весь контент от старта до собранного корабля;
  локальный смоук зелёный перед сборкой под устройства.
- **Модули (≤3):** `docs/` (новый ранбук, напр. `docs/RUNBOOK-devices.md`);
  `test/` (прогон существующих смоук-тестов, без новых). Не `lib/`-модуль.
- **Что сделать:**
  1. Написать ранбук `docs/RUNBOOK-devices.md`:
     - **iOS (free-signing):** открыть `ios/Runner.xcworkspace` в Xcode, выбрать
       свою личную Team в Signing & Capabilities (бесплатная учётка Apple ID),
       поменять bundle id на уникальный при конфликте, подключить iPhone,
       Trust, `flutter run --release -d <device>` или Run из Xcode; типовые
       грабли (untrusted developer → Settings→General→VPN & Device Management).
     - **Android:** включить USB-debugging, `flutter run --release -d <device>`
       (или `flutter build apk --release` + установка `app-release.apk`);
       типовые грабли (драйвер/автоподтверждение).
     - **Чек-лист смоука:** пройти весь контент от старта до собранного корабля
       (все `kShipPartCount` деталей), проверить: запуск без падения, кнопка
       взрыва (Готов/Взведён/детонация), сборка N/N → «Начать заново», нет
       overflow HUD на своём экране, имя/иконка на домашнем экране.
     - Место для отметки PO по устройствам (модель iOS/Android → «без падений»).
  2. Прогнать локальный смоук: `flutter test test/presentation/win_flow_test.dart
     test/integration/golden_scenario_test.dart test/widget_test.dart` (сквозной
     смоук из PROJECT.md) — зелёный. Полный `flutter test` — тоже зелёный.
- **Границы (строго):** только документ + прогон существующих тестов. Код игры,
  конфиги, иконку/имя — не трогать (сделаны в T1/T2).
- **Арх-дельта:** нет.
- **Результат (как проверить):** `flutter analyze` = 0; сквозной смоук-набор и
  полный `flutter test` зелёные (числа в заметках); `docs/RUNBOOK-devices.md`
  существует и покрывает обе ОС + чек-лист. Прогон на физических устройствах —
  **PO** (критерий приёмки стори, не агент).
- **DoD задачи:** статус задачи в стори; `docs/STATUS.md`; один коммит
  `gotovnost/03-ikonka-imya-i-smouk T3: <суть>`.
- **Заметки по выполнению:** Написан `docs/RUNBOOK-devices.md`: раздел iOS
  (free-signing через `Runner.xcworkspace` → личная Team в Signing &
  Capabilities → уникальный bundle id при конфликте → `flutter run --release
  -d <device>` или Run из Xcode → Trust в Настройки→Основные→VPN и управление
  устройством; грабли — 7-дневный сертификат, лимит App ID free-tier);
  раздел Android (USB-debugging → `flutter run --release -d <device>` или
  `flutter build apk --release` + установка `app-release.apk`; грабли —
  драйвер/режим USB, «Установка из неизвестных источников», конфликт подписи
  при апдейте); чек-лист смоука (запуск без падения, имя/иконка «Voxel
  Voyager» на домашнем экране, кнопка взрыва Готов/Взведён/детонация, все
  `kShipPartCount`=7 уровней подряд без падений, N/N + «Начать заново» →
  сброс, нет overflow HUD); таблица отметок PO по устройствам (модель →
  результат, пусто — заполняет PO). Реальные пути смоук-тестов сверены перед
  записью в ранбук (`ls test/presentation/win_flow_test.dart
  test/integration/golden_scenario_test.dart test/widget_test.dart` — все три
  существуют, совпадают с PROJECT.md). Прогон: `flutter analyze` = 0
  ошибок/предупреждений. Сквозной смоук-набор (`win_flow_test` +
  `golden_scenario_test` + `widget_test`) — 7/7 зелёных. Полный `flutter
  test` — 301/301 зелёных (не изменилось — только новый doc, код/тесты не
  трогал). Только новый документ создан, код игры/конфиги/иконка/имя не
  тронуты (T1/T2 не трогал). Прогон на физических устройствах — за PO
  (Гейт 2).
