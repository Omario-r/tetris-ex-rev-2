# LEGACY — выжимка из документации прототипа

> Временный документ-мост: всё нужное из удалённых `old_docs/` (полные версии —
> в git-истории до 2026-07-07). Источник истины — код `lib/`. На инвентаризации:
> сверить с кодом, растащить по ARCHITECTURE.md и паспортам модулей, затем
> удалить этот файл.

## Соглашения и инварианты → в ARCHITECTURE «Сквозные соглашения»

- Слои: `presentation → application → game_engine`, импорты только вниз.
  В `game_engine/` запрещён `import 'package:flutter/...'` — чистый Dart.
- Стек: без Flame; рендер `CustomPainter`, цикл `Ticker`, персист `shared_preferences`.
- Публичное API движка: void-команды; невозможное действие = **no-op**, исключений не бросаем.
- Координаты: `(0,0)` слева сверху, `y` растёт вниз; индекс `i = y*width + x`.
- Детерминизм: `SevenBagGenerator(seed)` / `FixedSequenceGenerator` — база всех тестов.
- Именование: файлы `snake_case`, классы `PascalCase`, `///`-комментарий на публичное API.
- Команды: `flutter pub get / run / test / analyze` (ноль ошибок и предупреждений).
- Навигация: захватить `NavigatorState` до `pushReplacement`; `context` из State
  в колбэках после ухода с экрана не использовать (unmounted).

## Правила движка (истина — код и тесты)

- Поле 10×20, 7 тетромино, 7-bag. Вращение только CW, без wall kicks; коллизия при повороте → no-op.
- **Target (S)** — клетки, которые надо заполнить. **Halo (H)** — 8-соседи S вне S
  в пределах поля. Победа: S заполнено И H пусто (H за краем поля игнорируется).
  Проверка — после каждого lock и взрыва. **Clutter** — занятая клетка вне S.
- **Explosive:** `armExplosive()` ровно один раз на фигуру (Normal → Explosive,
  обратно нельзя); летит сквозь блоки (коллизии только с границами);
  `detonate()` вручную или авто у пола; взрыв убирает только клетки под
  footprint фигуры. Гравитации после взрыва НЕТ — по дизайну.
- Поражение: переполнение спавна (spawn занят).
- `tick(dt)`: фазы spawning / falling / won / lost; ручные команды — вне tick, немедленно.

## Форматы данных

- `TargetMask`: MSB-first битмаска, бит `b = (w*h−1) − (y*w + x)`, окна до 8×8 (64 бита Dart int).
- `LevelTemplate`: маска + `targetX/Y` + `moveLimit?` + `objectId`/`fragmentIndex`;
  S и H вычисляются при создании.
- Тестовая фикстура: крест 6×6, маска `0x30CFFF30C` (`defaultLevel`) — НЕ игровой
  уровень; на нём написаны тесты движка, не удалять при чистке контента.

## Мета прототипа — касается эпика «Мета-каркас корабля»

- Уже есть `LevelMap`: 4 объекта × 4 фрагмента = 16 линейных уровней. Объект 0 —
  «Дом» (две крыши-ступеньки + две стены, окна 5×5), объекты 1–3 — заглушки-квадраты.
- Уже есть экраны: `LevelCompleteScreen` (сетка фрагментов объекта, текущий
  анимированно встаёт на место), `ObjectCompleteScreen` (объект целиком);
  навигация Game → LevelComplete → (ObjectComplete) → Game.
- Уже есть `ProgressService`: shared_preferences, ключ `current_level` (0..15);
  провал уровня = повтор.
- Для Voxel Voyager «объект» — прообраз «корабля»: каркас переиспользуем,
  содержание меняем (один корабль, свои детали, свой масштаб).
- ⚠ Старые мишени НЕ соответствуют новому правилу VISION «площадь кратна 4»
  (стены 25 клеток, крыши 15) — контент заменяется в эпике «Контент».

## Карта модулей по старым докам (сверить с кодом на инвентаризации)

- `lib/game_engine/` — models (board, piece, falling_piece, level_template,
  target_mask, object_template, fragment_def), rules (collision, rotation,
  explosion, halo, randomizer), game (game_state, game_controller), data (level_map).
- `lib/application/` — game_loop (Ticker → tick(dt) → ValueNotifier), progress_service.
- `lib/presentation/` — theme (скины блоков в Minecraft-стиле — под замену по
  VISION, включая tnt_skin и крипер-оверлеи), widgets (board_painter, hud,
  object_full_painter, object_fragment_grid_painter), screens (game_screen,
  level_complete_screen, object_complete_screen).
- `main.dart` — вход: ProgressService → GameScreen(levelIndex).
- Известный мусор: `explosion.dart` содержит неиспользуемый `applyLimitedGravity()` —
  кандидат на удаление.

## Сознательно отброшено (post-MVP идеи старого DESIGN — в git-истории)

Скоринг/звёзды, Pure Path, комбо-метр, экономика взрывов, дейлики, ачивки,
коллекция, монетизация. По VISION возвращаемся к ним только после релиза v1.
