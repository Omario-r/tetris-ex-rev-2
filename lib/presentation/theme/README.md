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
- `BlockTheme(map)` + `of(material)`, `copyWithMaterial`; статическая `defaultTheme`
  (процедурная) + `ghostTarget`. `haloHighlight` удалён (Стори 02 T3, см. ниже).
- Скины (рендер по каталогу элементов `docs/design/game-field.html`, утверждён PO
  2026-07-18, Стори 01 T5): `ProceduralBlockSkin(material)` — канон `el-block`,
  ОДИН рендер для любого `BlockMaterial` (заливка материалом + фаска + риветы;
  прежние пер-материальные текстуры T1 отменены). `ScrapBlockSkin` (канон
  `el-scrap`, «сырой» вид падающей фигуры вне мишени) удалён — единственный
  потребитель `BoardPainter` (эпик «Укладка» Стори 02 T3).
- `CanisterChargePainter(state, {pulse})` (Стори 02 T1, файл
  `canister_charge_painter.dart`) — иконка канистры-заряда: канон
  `docs/design/game-field.html` `.can`/`.armedcore` (панель «КНОПКА ВЗРЫВА —
  СОСТОЯНИЯ»). `ChargeIconState{ready,armed,empty}` — рисует либо канистру
  (Ready/Empty: графитовый корпус, колпак+индикатор, шов, диагональная
  hazard-полоса; Empty — полоса гаснет в серый), либо горячее ядро (Armed:
  заливка + кольца + искры по углам + пульсирующее свечение, `pulse`
  прокидывается снаружи, свой таймер не заводит). **Оставлен намеренно** (Стори
  02 T3) несмотря на удаление `GameHud` — единственный потребитель теперь не
  в `lib/`, а `tool/generate_app_icon.dart` (генератор иконки приложения для
  `flutter_launcher_icons`, `pubspec.yaml`): grep по `lib/`/`test/` покажет
  файл осиротевшим — ложный сигнал, урок эпика «Готовность» (единый источник
  кнопки И иконки). Заменяет `TntSkin`/`CreeperFacePainter` (удалены,
  Minecraft-остатки).
- `ImageBlockSkin` удалён в Стори 01 T1 (не был подключён, ассетов нет; добавление PNG-набора —
  отдельное продуктовое решение при появлении ассетов).
- `LevelSkin` удалён (Стори 02 T3) — единственный потребитель `materialForLevelIndex`/
  `materialForLevel`/`materialForObjectFragment` был `GameScreen`/`BoardPainter` старого ядра.
- `ShipMaterials` — карта деталь→материал для корабля (новый модуль в T2). Дефолт: 7 материалов
  по секциям корабля (нос/мостик/крылья/двигатель/хвост) из референса «Ронин» v4.
- Оверлеи: `GhostTargetOverlay` (контур мишени — hazard-оранжевый пунктир по токену
  `ghostTarget`, inset+скругление по мокапу `game-field.html`, Стори 01 T4; потребитель —
  `PackingPainter`). `HaloHighlightOverlay` (канон `el-halo`, пульс dirty-halo) удалён
  (Стори 02 T3) — единственный потребитель `BoardPainter`.
- `BlockPaintUtils` — общие хелперы: `baseCellSize` (34px, база размеров каталога
  элементов) + `paintElBlock`/`paintElDrop` (канон `el-block`/`el-piece`/`el-scrap`
  и `el-drop`, размеры масштабируются от `baseCellSize` к фактическому `rect`,
  Стори 01 T5; `paintElBlock` — потребитель `PackingPainter`); `paintElPieceArmed(canvas, rect,
  {required pulse})` — канон `el-piece-armed` (Стори 01 T6): реиспользует
  `paintElBlock` (через опц. хуки `onFillPainted`/`topBandOverlayColor`) для базы
  el-piece + диагональный hazard-хэтч 45° (`armedHatch`) + hazard-подкрас верхней
  фаски + горячее свечение `armedGlow` (пульс от [pulse]) + ембер-ядро
  (`armedEmber`/`armedEmberGlow`); `paintElDropArmed(canvas, rect)` — канон
  `el-drop-armed`: геометрия `paintElDrop`, но сплошной контур + 10% заливка +
  свечение `armedEmberGlow`. Плюс `noise(boardX,boardY,localX,localY)` —
  детерминированный шум (прежде питал `ScrapBlockSkin`, удалён Стори 02 T3;
  сама функция оставлена как часть `BlockPaintUtils`, живого потребителя сейчас
  нет — зачистка вне скоупа Стори 02, см. Стори 03). Низкоуровневые
  `drawTexturedRect`/`drawBevel`/`drawBlockOutline`/`pick`/`paintBlock`
  существовали только для `TntSkin`/`CreeperFacePainter` — удалены вместе с ними
  (Стори 02 T1, Minecraft-остатки).

## Зависит от

- Внешнее: `flutter`, `dart:ui`. `game_engine/models` (`LevelSkin` читал
  `LevelTemplate`) — зависимость снята (Стори 02 T3, `LevelSkin` удалён).

## От него зависят

- `presentation/widgets` — `packing_painter` (`BlockMaterial`, `BlockTheme`,
  `BlockPaintUtils`, `ShipMaterials`, `GhostTargetOverlay`), `ship` (карта материалов).
- `tool/generate_app_icon.dart` — `CanisterChargePainter`/`ChargeIconState`
  (Стори 02 T3, см. выше).

## Инварианты

- Только presentation: никакой игровой логики.
- Процедурный шум детерминирован от `(boardX,boardY,localX,localY)` — стабильная текстура клетки.
- `BlockMaterial` и оверлей `GhostTargetOverlay` — свой воксельно-космический
  стиль (Стори 01 T1, эпик «Готовность»). Палитра — лайтнес-варианты HSL-хью из референса
  «Ронин» v4 (`/Users/omarior/Development/Home/Ideas/Tetris-ex-ideas/ship_ronin_v4.html`,
  константа `M`): графит/графит-тёмный/тёмные ниши/оранжевые hazard-панели/ржавчина/gunmetal/
  матовый чёрный — без осветления сверх диапазона, уже заданного самим референсом (edge-bevel
  ±12 lightness, plate-jitter ±3.5). Один источник палитры для поля и (T2) корабля.
- `ShipMaterials` — единый источник цвета для `ShipPainter` и (T3) перекраски клетки. Не хардкодит
  единственный корабль (адресуемость под #6).
- `GhostTargetOverlay` — цвета строго из токенов DESIGN.md `ghostTarget` (пунктир,
  `hsl(23 62% 55% / 55%)` = `#D37C45`) и `hazardOrange` (лёгкая заливка 5%,
  `#BE642D`) — не своя палитра, Стори 01 T4.

## Как проверить

`flutter test test/presentation/theme/` (block_theme, ship_materials).
