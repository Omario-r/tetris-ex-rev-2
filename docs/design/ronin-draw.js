/*
  ronin-draw.js — общий вывод разметки v2 для страниц docs/design/ronin-*.html и
  ukladka-field.html: сэмплинг рисунка корабля по маске детали в её масштабе,
  деталь на корабле по слоям. НЕ канон и не спека — канон это ronin-parts.js
  (разметка), ronin-objects.js (формы предметов) и docs/DESIGN.md (правила).

  Подключение (корпус без предметов + полный рисунок — для слоёв D-011):
    <script>window.__SHIP_RES=4; window.__SHIP_NO_OBJECTS=true;</script>
    <script src="ship-render.js"></script>
    <script>window.__SHIP_HULL=window.__SHIP; window.__SHIP_NO_OBJECTS=false;</script>
    <script src="ship-render.js?full"></script>
    <script src="ronin-parts.js"></script> <script src="ronin-objects.js"></script>
    <script src="ronin-draw.js"></script>
  Без __SHIP_HULL плиты сэмплируют полный рисунок (предметы проступят на плитах).
*/
window.RONIN_DRAW = (function(){
"use strict";
const SHIP = window.__SHIP, HULL = window.__SHIP_HULL || SHIP, P = window.RONIN_PARTS, O = window.RONIN_OBJECTS;
const C = SHIP.C, RES = SHIP.RES || 2;
const secOf = (part) => P.sections.find(s => s.id === part.section);

/* масштаб детали и левый-верх её маски на корабле, в клетках рисунка */
function frame(part){
  if (part.layer === 1) return { s: part.s, x0: part.origin[0], y0: part.origin[1] };
  const sec = secOf(part);
  return { s: sec.s, x0: sec.origin[0] + part.origin[0] / sec.s, y0: sec.origin[1] + part.origin[1] / sec.s };
}

/* клетка (c,r) маски детали → прямоугольник на корабле, px рисунка (до RES) */
function cellRect(part, c, r){
  const f = frame(part), cs = C / f.s;
  return [SHIP.px(f.x0) + c*cs, SHIP.py(f.y0) + r*cs, cs];
}

/* слой 0 сэмплирует корпус без предметов, слой 1 — полный рисунок */
const imgOf = (part) => (part.layer === 1 ? SHIP : HULL).off;

function eachCell(part, cb){
  part.mask.forEach((line, r) => { for (let c = 0; c < line.length; c++) if (line[c] === '#') cb(c, r); });
}

function dpr(cv, w, h){
  const k = window.devicePixelRatio || 1;
  cv.width = w*k; cv.height = h*k;
  cv.style.width = w+'px'; cv.style.height = h+'px';
  const g = cv.getContext('2d'); g.scale(k,k);
  g.imageSmoothingEnabled = true; g.imageSmoothingQuality = 'high';
  return g;
}

/* одна клетка детали — кусок оригинала в её масштабе — в (dx,dy) размером u */
function drawCell(g, part, c, r, dx, dy, u){
  const [x, y, cs] = cellRect(part, c, r);
  g.drawImage(imgOf(part), x*RES, y*RES, cs*RES, cs*RES, dx, dy, u, u);
}

/* деталь на поле укладки: маска со сдвигом (oc,or) в клетках поля */
function drawField(g, part, u, oc, or){ eachCell(part, (c, r) => drawCell(g, part, c, r, (oc+c)*u, (or+r)*u, u)); }

/* разделители клеток (seam) — только поле укладки */
function drawSeams(g, part, u, oc, or, color){
  g.strokeStyle = color; g.lineWidth = 1;
  eachCell(part, (c, r) => g.strokeRect(Math.round((oc+c)*u)+.5, Math.round((or+r)*u)+.5, u, u));
}

/* контур силуэта на поле (ghostTarget): внешние рёбра маски */
function strokeOutline(g, part, u, oc, or, color, width){
  const on = (c, r) => r >= 0 && r < part.mask.length && c >= 0 && part.mask[r][c] === '#';
  g.strokeStyle = color; g.lineWidth = width || 1.5; g.beginPath();
  eachCell(part, (c, r) => {
    const x = (oc+c)*u, y = (or+r)*u;
    if (!on(c, r-1)) { g.moveTo(x, y);   g.lineTo(x+u, y); }
    if (!on(c, r+1)) { g.moveTo(x, y+u); g.lineTo(x+u, y+u); }
    if (!on(c-1, r)) { g.moveTo(x, y);   g.lineTo(x, y+u); }
    if (!on(c+1, r)) { g.moveTo(x+u, y); g.lineTo(x+u, y+u); }
  });
  g.stroke();
}

/* область детали на корабле: плита — объединение её клеток, предмет — его форма */
function shipRegion(part){
  const p = new Path2D();
  if (part.layer === 1) { O.shape(part.object).forEach(q => p.addPath(q)); return p; }
  eachCell(part, (c, r) => { const [x, y, cs] = cellRect(part, c, r); p.rect(x, y, cs, cs); });
  return p;
}

/* деталь на корабле. g уже в координатах px рисунка (g.scale/translate снаружи) */
function drawOnShip(g, part){
  g.save(); g.clip(shipRegion(part));
  g.drawImage(imgOf(part), 0, 0, SHIP.W*RES, SHIP.H*RES, 0, 0, SHIP.W, SHIP.H);
  g.restore();
}
function strokeOnShip(g, part, color, width){
  g.strokeStyle = color; g.lineWidth = width;
  if (part.layer === 1) { O.shape(part.object).forEach(q => g.stroke(q)); return; }
  const on = (c, r) => r >= 0 && r < part.mask.length && c >= 0 && part.mask[r][c] === '#';
  g.beginPath();
  eachCell(part, (c, r) => {
    const [x, y, cs] = cellRect(part, c, r);
    if (!on(c, r-1)) { g.moveTo(x, y);    g.lineTo(x+cs, y); }
    if (!on(c, r+1)) { g.moveTo(x, y+cs); g.lineTo(x+cs, y+cs); }
    if (!on(c-1, r)) { g.moveTo(x, y);    g.lineTo(x, y+cs); }
    if (!on(c+1, r)) { g.moveTo(x+cs, y); g.lineTo(x+cs, y+cs); }
  });
  g.stroke();
}
/* центр детали на корабле, px рисунка — для номера порядка */
function centerOnShip(part){
  let sx = 0, sy = 0, n = 0;
  eachCell(part, (c, r) => { const [x, y, cs] = cellRect(part, c, r); sx += x + cs/2; sy += y + cs/2; n++; });
  return [sx / n, sy / n];
}

/* контур всего борта «сюда дорастёт», включая гондолы; T(x,y) — px рисунка -> целевые */
function shipOutlinePath(g, T){
  const {span, ROWS, px, py} = SHIP;
  const L = (x, y) => { const [a,b] = T(x, y); g.lineTo(a, b); };
  g.beginPath();
  const [sx0, sy0] = T(px(span[0][0]), py(0)); g.moveTo(sx0, sy0);
  for (let y = 0; y < ROWS; y++){ L(px(span[y][0]), py(y)); L(px(span[y][0]), py(y+1)); }
  L(px(span[ROWS-1][1]+1), py(ROWS));
  for (let y = ROWS-1; y >= 0; y--){ L(px(span[y][1]+1), py(y+1)); L(px(span[y][1]+1), py(y)); }
  g.closePath(); g.stroke();
  const bw = 1.06*C, bh = 2.9*C, byt = py(13.55);
  for (const bx of [px(3)-bw+2, px(12)-2]){
    const [x, y] = T(bx, byt), [x2, y2] = T(bx+bw, byt+bh), r = 5;
    g.beginPath(); g.moveTo(x+r, y);
    g.arcTo(x2, y, x2, y2, r); g.arcTo(x2, y2, x, y2, r);
    g.arcTo(x, y2, x, y, r);   g.arcTo(x, y, x2, y, r);
    g.closePath(); g.stroke();
  }
}

return { RES, frame, cellRect, eachCell, dpr, drawCell, drawField, drawSeams, strokeOutline,
         shipRegion, drawOnShip, strokeOnShip, centerOnShip, shipOutlinePath };
})();
