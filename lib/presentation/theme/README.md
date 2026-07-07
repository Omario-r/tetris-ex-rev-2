# MODULE — presentation/theme

> Паспорт модуля. 30–50 строк. Единственное, что другие агенты знают о модуле,
> не читая код. Обновляется в сессии, где менялся интерфейс/зависимости/инварианты.

## Назначение

Визуальные скины блоков и оверлеи: как выглядит клетка на поле. Только отрисовка
(`Canvas`), без игровой логики.

## Публичный интерфейс

- `BlockMaterial{grass,cobble,planks,bricks,sand,stone,dirt}`.
- `BlockSkin` (abstract): `paint(canvas, rect, {boardX, boardY})`.
- `BlockTheme(map)` + `of(material)`, `copyWithMaterial`; статические `defaultTheme`
  (процедурная), `tnt`, `ghostTarget`, `haloHighlight`.
- Скины: `ProceduralBlockSkin(material)` (текстуры в коде), `TntSkin` (взведённый заряд),
  `ImageBlockSkin(image)` (PNG — НЕ подключён, ассетов нет; кандидат в BACKLOG).
- `LevelSkin.materialForLevelIndex/materialForLevel/materialForObjectFragment` — уровень → материал.
- Оверлеи: `GhostTargetOverlay`, `HaloHighlightOverlay`, `CreeperFacePainter`.
- `BlockPaintUtils` — общие хелперы: `noise/pick/drawTexturedRect/drawBevel/paintBlock`.

## Зависит от

- `game_engine/models` — `LevelSkin` читает `LevelTemplate` (`objectId`/`fragmentIndex`).
- Внешнее: `flutter`, `dart:ui`.

## От него зависят

- `presentation/widgets` — `board_painter`, `hud`.
- `presentation/screens` — `game_screen` (тема, `LevelSkin`).

## Инварианты

- Только presentation: никакой игровой логики, из ядра — лишь чтение `LevelTemplate`.
- Процедурный шум детерминирован от `(boardX,boardY,localX,localY)` — стабильная текстура клетки.
- ⚠ Стиль намеренно Minecraft-подобный (grass/cobble/TNT/creeper) — ЧУЖОЙ IP. По VISION
  заменяется на свой воксельный стиль (эпик «Плейтест-сборка»); в контент/публикацию как есть не тащить.

## Как проверить

`flutter test test/presentation/theme/` (block_theme, level_skin).
