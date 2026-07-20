# ARCHITECTURE — карта модулей

> Ведёт агент. Обновляется при добавлении/удалении модуля или связи между модулями
> (пункт Definition of Done). Это оглавление проекта: отсюда агент узнаёт, какие
> паспорта читать. Детали — только в паспортах модулей, здесь не дублировать.

Модуль = каталог-лист в `lib/` со своим `README.md`-паспортом. Слои
(`game_engine`, `application`, `presentation`) — это группы модулей, а не модули
(см. `docs/DECISIONS.md`, D-001). Точка входа `lib/main.dart` — не модуль.

## Модули

| Модуль | Путь | Назначение (1 строка) | Зависит от |
|--------|------|----------------------|------------|
| models | `lib/game_engine/models/` | Структуры данных ядра (поле, фигура, маска, шаблоны уровня/объекта) | rules ¹ |
| rules | `lib/game_engine/rules/` | Чистые правила: коллизии, halo/победа, взрыв, генерация фигур | models ¹ |
| packing | `lib/game_engine/packing/` | Ядро укладки (новое): полиомино-кусок, состояние (силуэт+размещённые+лоток), валидация/завершение; нарезка силуэта (T2) | models |
| game | `lib/game_engine/game/` | Состояние партии + оркестрация (`tick`, команды игрока) | models, rules |
| data | `lib/game_engine/data/` | Контент: `ShipParts` (дев-детали) + `LevelMap` (`ShipParts.parts.length` уровней, v1=7) | models |
| application | `lib/application/` | Персист прогресса (`ProgressService`) | data ² |
| theme | `lib/presentation/theme/` | Скины блоков и оверлеи (только отрисовка) | models |
| widgets | `lib/presentation/widgets/` | Пейнтеры поля и корабля, HUD | game, models, data, theme |
| screens | `lib/presentation/screens/` | Экраны + игровой цикл (композиционный корень партии) | game, models, data, rules, application, theme, widgets |

¹ **models ↔ rules — взаимная зависимость:** `models/level_template` при создании зовёт
`rules/halo` (`computeHalo8`), а `rules/*` работают над `models` (`Board`, `FallingPiece`).
Цикл на уровне модулей; допустим в Dart, но держать в уме при рефакторинге (см. BACKLOG).

² **application → game_engine/data:** `ProgressService._max` берёт `ShipParts.parts.length - 1`
(единый источник истины числа уровней) вместо хардкода — импорт строго вниз по слоям, разрешён
(hotfix 2026-07-11: хардкод `15` разошёлся с реальным числом уровней после эпика «Контент» и
ронял приложение на холодном старте с устаревшим persist-значением).

## Схема связей

Слои и направление импортов (только вниз):

```
lib/main.dart (вход)
        │
   presentation:  screens ──► widgets ──► theme
        │            │           │          │
        │            └──────────────────────┼──► game_engine
        ▼                                    │
   application  ◄────────────────────────────┘ (screens → ProgressService)
        │
        ▼  (ProgressService._max ← ShipParts.parts.length, см. ²)
   game_engine:  game ──► rules ◄──► models
                  │                    ▲
                  └──► data ◄──────────┴─── application
```

- packing ──► models (TargetMask как силуэт); новое ядро укладки, параллельно
  game/rules (старое тетрис-ядро выпиливается в Стори 02 эпика «Укладка»).
- `presentation/screens` и `presentation/widgets` теперь читают также
  `game_engine/packing` (прототип укладки, Стори 01 эпика «Укладка»). Новых
  модулей нет; связь `presentation → game_engine` уже была, здесь уточняется
  охват.

- `screens` — единственный композиционный корень: тянет ядро, данные и виджеты.
- `application` тонкий: игровой цикл фактически в `screens/game_screen`, не в `application/game_loop` (стуб).
- `widgets → data`: `ShipPainter` берёт форму деталей из `ShipParts` — тот же источник, что
  и мишени дев-уровней (`LevelMap`), поэтому «собранное на уровне» = «деталь корабля».

## Сквозные соглашения

- **Слои и импорты:** `presentation → application → game_engine`, импорты только вниз.
  В `game_engine/` запрещён `import 'package:flutter/...'` — чистый Dart.
- **Стек:** без Flame. Рендер — `CustomPainter`; игровой цикл — `AnimationController`/`Ticker`
  в `screens/game_screen`; персист — `shared_preferences`.
- **API движка (`GameController`):** команды возвращают `void`; невозможное действие = **no-op**,
  исключений не бросаем.
- **Координаты:** `(0,0)` слева сверху, `y` растёт вниз; линейный индекс `i = y*width + x`.
- **Детерминизм:** `SevenBagGenerator(seed)` / `FixedSequenceGenerator` — база тестов движка.
- **Именование:** файлы `snake_case`, классы `PascalCase`, `///`-комментарий на публичном API.
  Импорты внутри `lib/` — относительные (единственное исключение — `rules/randomizer.dart` через `package:`).
- **Навигация:** захватить `NavigatorState` до `pushReplacement`; `context` из `State` в колбэках
  после ухода с экрана не использовать (проверка `mounted`).
- **Точка входа:** `lib/main.dart` → `ProgressService.getCurrentLevel()` → `GameScreen(levelIndex)`.
- **Тестовая фикстура:** `defaultLevel` (крест 6×6, маска `0x30CFFF30C`) — НЕ игровой уровень;
  на нём написаны тесты движка, не удалять при чистке контента.
- **Команды и смоук-тест:** `flutter pub get` / `flutter run` / `flutter test` / `flutter analyze`
  (analyze — ноль ошибок и предупреждений). Смоук/сквозной сценарий:
  `flutter test test/widget_test.dart test/integration/golden_scenario_test.dart
  test/presentation/win_flow_test.dart` (последний — полный прогон всех уровней контента
  до собранного корабля, эпик «Контент» Стори 03; `widget_test.dart` — пустая заглушка, см. BACKLOG).
