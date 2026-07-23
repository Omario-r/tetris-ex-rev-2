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
| models | `lib/game_engine/models/` | Структуры данных ядра (маска мишени, шаблон уровня) | — |
| packing | `lib/game_engine/packing/` | Ядро укладки — основной движок игры: полиомино-кусок, состояние (силуэт+размещённые+лоток), валидация/завершение, нарезка силуэта | models |
| data | `lib/game_engine/data/` | Контент: `ShipParts` (дев-детали) + `LevelMap` (`ShipParts.parts.length` уровней, v1=7) | models |
| application | `lib/application/` | Персист прогресса (`ProgressService`) | data ¹ |
| theme | `lib/presentation/theme/` | Скины блоков и оверлеи (только отрисовка) | models |
| widgets | `lib/presentation/widgets/` | Пейнтеры укладки и корабля | packing, data, theme |
| screens | `lib/presentation/screens/` | Экраны + композиционный корень партии укладки | packing, models, data, application, theme, widgets |

¹ **application → game_engine/data:** `ProgressService._max` берёт `ShipParts.parts.length - 1`
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
        ▼  (ProgressService._max ← ShipParts.parts.length, см. ¹)
   game_engine:  packing ──► models ◄── data
                                        ▲
                                        application
```

- packing ──► models (`TargetMask` как силуэт) — ядро укладки, **основной движок
  игры** (`presentation/screens` и `presentation/widgets` читают его в главном
  потоке). Старое тетрис-ядро — модуль `game`, `rules`-коллизии/взрыв/генератор,
  `models`-падающая фигура — **удалено** (эпик «Укладка», Стори 02 T4).

- `screens` — единственный композиционный корень: тянет ядро укладки, данные и виджеты.
- `application` тонкий: `application/game_loop` — мёртвый стуб (кандидат на удаление, Стори 03).
- `widgets → data`: `ShipPainter` берёт форму деталей из `ShipParts` — тот же источник, что
  и мишени дев-уровней (`LevelMap`), поэтому «собранное на уровне» = «деталь корабля».

## Сквозные соглашения

- **Слои и импорты:** `presentation → application → game_engine`, импорты только вниз.
  В `game_engine/` запрещён `import 'package:flutter/...'` — чистый Dart.
- **Стек:** без Flame. Рендер — `CustomPainter`; анимация (пульс `doneGlow`) —
  `AnimationController` в `screens/game_screen`; персист — `shared_preferences`.
- **API движка (`PackController`):** команды возвращают `void`; невозможное действие = **no-op**,
  исключений не бросаем.
- **Координаты:** `(0,0)` слева сверху, `y` растёт вниз; линейный индекс `i = y*width + x`.
- **Детерминизм:** `slicePolyomino(silhouette, seed)` — детерминированная нарезка; база тестов
  ядра укладки.
- **Именование:** файлы `snake_case`, классы `PascalCase`, `///`-комментарий на публичном API.
  Импорты внутри `lib/` — относительные.
- **Навигация:** захватить `NavigatorState` до `pushReplacement`; `context` из `State` в колбэках
  после ухода с экрана не использовать (проверка `mounted`).
- **Точка входа:** `lib/main.dart` → `ProgressService.getCurrentLevel()` → `GameScreen(levelIndex)`.
- **Тестовая фикстура:** `defaultLevel`/`defaultTargetMask` (крест 6×6, маска `0x30CFFF30C`) —
  НЕ игровой уровень; на нём написаны тесты движка, не удалять при чистке контента.
- **Команды и смоук-тест:** `flutter pub get` / `flutter run` / `flutter test` / `flutter analyze`
  (analyze — ноль ошибок и предупреждений). Смоук/сквозной сценарий:
  `flutter test test/widget_test.dart test/presentation/win_flow_test.dart`
  (`win_flow` — минимальный прогон укладки до победы + мета-финал; полный прогон всего
  контента новым ядром — Стори 03 эпика «Укладка»; `widget_test.dart` — пустая заглушка,
  см. BACKLOG. `golden_scenario_test` удалён вместе со старым ядром, Стори 02 T4).
