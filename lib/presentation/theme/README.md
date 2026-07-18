# MODULE — presentation/theme

> Паспорт модуля. 30–50 строк. Единственное, что другие агенты знают о модуле,
> не читая код. Обновляется в сессии, где менялся интерфейс/зависимости/инварианты.

## Назначение

Визуальные скины блоков и оверлеи: как выглядит клетка на поле. Только отрисовка
(`Canvas`), без игровой логики.

## Публичный интерфейс

- `BlockMaterial{graphite,graphiteDark,darkNiche,hazardOrange,rust,gunmetal,matteBlack}` —
  свой воксельно-космический набор (палитра по референсу «Ронин» v4, см. Инварианты).
  Цвет материала — через `color` (extension).
- `BlockSkin` (abstract): `paint(canvas, rect, {boardX, boardY})`.
- `BlockTheme(map)` + `of(material)`, `copyWithMaterial`; статические `defaultTheme`
  (процедурная), `tnt`, `ghostTarget`, `haloHighlight`.
- Скины (все — рендер по каталогу элементов `docs/design/game-field.html`,
  утверждён PO 2026-07-18, Стори 01 T5): `ProceduralBlockSkin(material)` — канон
  `el-block`, ОДИН рендер для любого `BlockMaterial` (заливка материалом + фаска
  + риветы; прежние пер-материальные текстуры T1 отменены); `ScrapBlockSkin` —
  канон `el-scrap` (заливка `graphiteDark`, слабая фаска без боковых граней, без
  риветов, детерминированный питтинг rust-пятен от `(boardX,boardY)`); `TntSkin`
  (взведённый заряд, ⚠ ждёт Стори 02 «взрыв» — не трогать вне неё).
- `ImageBlockSkin` удалён в Стори 01 T1 (не был подключён, ассетов нет; добавление PNG-набора —
  отдельное продуктовое решение при появлении ассетов).
- `LevelSkin.materialForLevelIndex/materialForLevel/materialForObjectFragment` — уровень → материал.
- `ShipMaterials` — карта деталь→материал для корабля (новый модуль в T2). Дефолт: 7 материалов
  по секциям корабля (нос/мостик/крылья/двигатель/хвост) из референса «Ронин» v4.
- Оверлеи: `GhostTargetOverlay` (контур мишени — hazard-оранжевый пунктир по токену
  `ghostTarget`, inset+скругление по мокапу `game-field.html`, Стори 01 T4),
  `HaloHighlightOverlay` — канон `el-halo` (рамка `ghostTarget`-тона @ 55% + лёгкое
  свечение, без плоской заливки; пульс альфы — прежний период T1, Стори 01 T5),
  `CreeperFacePainter` (⚠ ждёт Стори 02 «взрыв» — не трогать вне неё).
- `BlockPaintUtils` — общие хелперы: `baseCellSize` (34px, база размеров каталога
  элементов) + `paintElBlock`/`paintElDrop` (канон `el-block`/`el-piece`/`el-scrap`
  и `el-drop`, размеры масштабируются от `baseCellSize` к фактическому `rect`,
  Стори 01 T5), плюс низкоуровневые `noise/pick/drawTexturedRect/drawBevel/
  drawBlockOutline/paintBlock` — только для `TntSkin`/`CreeperFacePainter`
  (Стори 02, не трогать вне неё).

## Зависит от

- `game_engine/models` — `LevelSkin` читает `LevelTemplate` (`objectId`/`fragmentIndex`).
- Внешнее: `flutter`, `dart:ui`.

## От него зависят

- `presentation/widgets` — `board_painter`, `hud`, `ship` (карта материалов).
- `presentation/screens` — `game_screen` (тема, `LevelSkin`).

## Инварианты

- Только presentation: никакой игровой логики, из ядра — лишь чтение `LevelTemplate`.
- Процедурный шум детерминирован от `(boardX,boardY,localX,localY)` — стабильная текстура клетки.
- `BlockMaterial` и оверлеи `GhostTargetOverlay`/`HaloHighlightOverlay` — свой воксельно-космический
  стиль (Стори 01 T1, эпик «Готовность»). Палитра — лайтнес-варианты HSL-хью из референса
  «Ронин» v4 (`/Users/omarior/Development/Home/Ideas/Tetris-ex-ideas/ship_ronin_v4.html`,
  константа `M`): графит/графит-тёмный/тёмные ниши/оранжевые hazard-панели/ржавчина/gunmetal/
  матовый чёрный — без осветления сверх диапазона, уже заданного самим референсом (edge-bevel
  ±12 lightness, plate-jitter ±3.5). Один источник палитры для поля и (T2) корабля.
- ⚠ `TntSkin`/`CreeperFacePainter` — ещё Minecraft-подобные (TNT/creeper); переработка —
  Стори 02 эпика «Готовность» (взрыв), не трогать раньше.
- `ShipMaterials` — единый источник цвета для `ShipPainter` и (T3) перекраски клетки. Не хардкодит
  единственный корабль (адресуемость под #6).
- `GhostTargetOverlay` — цвета строго из токенов DESIGN.md `ghostTarget` (пунктир,
  `hsl(23 62% 55% / 55%)` = `#D37C45`) и `hazardOrange` (лёгкая заливка 5%,
  `#BE642D`) — не своя палитра, Стори 01 T4.

## Как проверить

`flutter test test/presentation/theme/` (block_theme, level_skin, scrap_block_skin).
