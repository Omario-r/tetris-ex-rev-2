/*
  ronin-draw.js — общий вывод разметки v3 для страниц docs/design/ronin-*.html и
  ukladka-field.html: клетка детали на поле укладки (фазы «сборка» / «готово»),
  деталь на корабле по слоям. НЕ канон и не спека — канон это ronin-parts.js
  (разметка), ronin-objects.js (формы предметов), ship-render.js (рисунок) и
  docs/DESIGN.md (правила, D-016).

  Подключение (порядок важен):
    <script src="ronin-parts.js"></script>
    <script>window.__SHIP_RES = 4;</script>
    <script src="ship-render.js"></script>
    <script src="ronin-objects.js"></script>
    <script src="ronin-draw.js"></script>
  Нужные варианты рисунка ronin-draw заказывает сам через __SHIP.render (лениво).

  Клетка поля (D-016):
    'build' — во время сборки: плитка с рельефом куска (вариант Б). Плита — рисунок
              без кромок деталей и щелей-огней; предмет — преобладающий цвет клетки.
              Заклёпки чёрные 45 %, на тёмной клетке (яркость < 0,2) — 85 %.
    'done'  — деталь собрана: настоящий рисунок без рельефа и сетки; кромку детали
              рисует crispEdge в пикселях поля.
*/
window.RONIN_DRAW = (function(){
"use strict";
const SHIP = window.__SHIP, P = window.RONIN_PARTS, O = window.RONIN_OBJECTS;
const C = SHIP.C, RES = SHIP.RES || 2;
const secOf = (part) => P.sections.find(s => s.id === part.section);

/* ---------- варианты рисунка (лениво) ---------- */
const PICS = {}, PIC_OPT = {
  hull:  { res:RES, layer:'hull' },                               // корабль: обшивка
  obj:   { res:RES, layer:'objects' },                            // корабль и поле: предметы
  build: { res:2,   layer:'hull', edges:false, lights:false },    // поле, сборка
  done:  { res:RES, layer:'hull', edges:false },                  // поле, собрана
};
function pic(k){ if (!PICS[k]) PICS[k] = { cv: SHIP.render(PIC_OPT[k]), res: PIC_OPT[k].res }; return PICS[k]; }

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
function eachCell(part, cb){
  part.mask.forEach((line, r) => { for (let c = 0; c < line.length; c++) if (line[c] === '#') cb(c, r); });
}
const on = (part, c, r) => r >= 0 && r < part.mask.length && c >= 0 && part.mask[r][c] === '#';

function dpr(cv, w, h){
  const k = window.devicePixelRatio || 1;
  cv.width = w*k; cv.height = h*k;
  cv.style.width = w+'px'; cv.style.height = h+'px';
  const g = cv.getContext('2d'); g.scale(k,k);
  g.imageSmoothingEnabled = true; g.imageSmoothingQuality = 'high';
  return g;
}

/* преобладающий цвет участка рисунка: самая частая корзина квантованного цвета */
function domColor(p, x, y, cs){
  const k = p.res, d = p.cv.getContext('2d', { willReadFrequently:true })
    .getImageData(Math.round(x*k), Math.round(y*k), Math.max(1, Math.round(cs*k)), Math.max(1, Math.round(cs*k))).data;
  const bins = new Map();
  for (let i = 0; i < d.length; i += 4){ if (d[i+3] < 128) continue;
    const key = (d[i]>>4)<<8 | (d[i+1]>>4)<<4 | (d[i+2]>>4), b = bins.get(key) || [0,0,0,0];
    b[0]+=d[i]; b[1]+=d[i+1]; b[2]+=d[i+2]; b[3]++; bins.set(key, b); }
  let best = null; for (const b of bins.values()) if (!best || b[3] > best[3]) best = b;
  return best ? [best[0]/best[3], best[1]/best[3], best[2]/best[3]] : [23, 26, 30];
}
const lum = ([r, g, b]) => (0.2126*r + 0.7152*g + 0.0722*b) / 255;

function rrPath(x, y, w, h, r){ const p = new Path2D(); p.moveTo(x+r,y); p.arcTo(x+w,y,x+w,y+h,r);
  p.arcTo(x+w,y+h,x,y+h,r); p.arcTo(x,y+h,x,y,r); p.arcTo(x,y,x+w,y,r); p.closePath(); return p; }

/* рельеф плитки — как el-block (paintElBlock), s = u/34, k — сила (Б: 1.4) */
function tileRelief(g, x, y, w, h, s, k){
  const b = 3*s;
  g.fillStyle = `rgba(255,255,255,${.09*k})`; g.fillRect(x, y, w, b);
  g.fillStyle = `rgba(0,0,0,${.35*k})`;       g.fillRect(x, y+h-b, w, b);
  g.fillStyle = `rgba(255,255,255,${.04*k})`; g.fillRect(x, y, b, h);
  g.fillStyle = `rgba(0,0,0,${.18*k})`;       g.fillRect(x+w-b, y, b, h);
}
function rivets(g, x, y, w, h, s, dark){
  g.fillStyle = dark ? 'rgba(0,0,0,.85)' : 'rgba(0,0,0,.45)';
  for (const [a, b] of [[x+4*s,y+4*s],[x+w-4*s,y+4*s],[x+4*s,y+h-4*s],[x+w-4*s,y+h-4*s]]){
    g.beginPath(); g.arc(a, b, 1.5*s, 0, 7); g.fill(); }
}

/* одна клетка детали в (dx,dy) размером u; phase — 'build' | 'done' (по умолчанию) */
function drawCell(g, part, c, r, dx, dy, u, phase){
  const [x, y, cs] = cellRect(part, c, r), obj = part.layer === 1;
  if (phase !== 'build'){
    const p = pic(obj ? 'obj' : 'done');
    g.drawImage(p.cv, x*p.res, y*p.res, cs*p.res, cs*p.res, dx, dy, u, u);
    return;
  }
  const p = pic(obj ? 'obj' : 'build'), dom = domColor(p, x, y, cs);
  const s = u/34, i = s, w = u - 2*i;
  g.save(); g.clip(rrPath(dx+i, dy+i, w, w, 3*s));
  if (obj){ g.fillStyle = `rgb(${dom.map(v => v|0).join(',')})`; g.fillRect(dx, dy, u, u); }
  else g.drawImage(p.cv, x*p.res, y*p.res, cs*p.res, cs*p.res, dx, dy, u, u);
  tileRelief(g, dx+i, dy+i, w, w, s, 1.4);
  g.restore();
  rivets(g, dx+i, dy+i, w, w, s, lum(dom) < 0.2);
}

/* деталь на поле укладки: маска со сдвигом (oc,or) в клетках поля */
function drawField(g, part, u, oc, or, phase){
  eachCell(part, (c, r) => drawCell(g, part, c, r, (oc+c)*u, (or+r)*u, u, phase));
  if (phase !== 'build' && part.layer === 0) crispEdge(g, part, u, oc, or);
}

/* чёткая кромка собранной плиты — в пикселях поля, не растянутым рисунком (D-016) */
function crispEdge(g, part, u, oc, or){
  const seg = (x1,y1,x2,y2,col,w) => { g.strokeStyle=col; g.lineWidth=w; g.beginPath(); g.moveTo(x1,y1); g.lineTo(x2,y2); g.stroke(); };
  eachCell(part, (c, r) => {
    const X = (oc+c)*u, Y = (or+r)*u;
    if (!on(part,c,r-1)) { seg(X,Y+1.5,X+u,Y+1.5,'rgba(255,255,255,.14)',2); seg(X,Y+.5,X+u,Y+.5,'rgba(0,0,0,.55)',1); }
    if (!on(part,c-1,r)) { seg(X+1.5,Y,X+1.5,Y+u,'rgba(255,255,255,.07)',2); seg(X+.5,Y,X+.5,Y+u,'rgba(0,0,0,.55)',1); }
    if (!on(part,c,r+1)) { seg(X,Y+u-1.5,X+u,Y+u-1.5,'rgba(0,0,0,.35)',2);   seg(X,Y+u-.5,X+u,Y+u-.5,'rgba(0,0,0,.55)',1); }
    if (!on(part,c+1,r)) { seg(X+u-1.5,Y,X+u-1.5,Y+u,'rgba(0,0,0,.22)',2);   seg(X+u-.5,Y,X+u-.5,Y+u,'rgba(0,0,0,.55)',1); }
  });
}

/* разделители клеток (seam) — поле укладки без рельефа (v2; на v3 плитки делит рельеф) */
function drawSeams(g, part, u, oc, or, color){
  g.strokeStyle = color; g.lineWidth = 1;
  eachCell(part, (c, r) => g.strokeRect(Math.round((oc+c)*u)+.5, Math.round((or+r)*u)+.5, u, u));
}

/* контур силуэта на поле (ghostTarget): внешние рёбра маски */
function strokeOutline(g, part, u, oc, or, color, width){
  g.strokeStyle = color; g.lineWidth = width || 1.5; g.beginPath();
  eachCell(part, (c, r) => {
    const x = (oc+c)*u, y = (or+r)*u;
    if (!on(part, c, r-1)) { g.moveTo(x, y);   g.lineTo(x+u, y); }
    if (!on(part, c, r+1)) { g.moveTo(x, y+u); g.lineTo(x+u, y+u); }
    if (!on(part, c-1, r)) { g.moveTo(x, y);   g.lineTo(x, y+u); }
    if (!on(part, c+1, r)) { g.moveTo(x+u, y); g.lineTo(x+u, y+u); }
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

/* деталь на корабле: плита — слой обшивки, предмет — слой предметов.
   g уже в координатах px рисунка (g.scale/translate снаружи) */
function drawOnShip(g, part){
  const p = pic(part.layer === 1 ? 'obj' : 'hull');
  g.save(); g.clip(shipRegion(part));
  g.drawImage(p.cv, 0, 0, SHIP.W*p.res, SHIP.H*p.res, 0, 0, SHIP.W, SHIP.H);
  g.restore();
}
function strokeOnShip(g, part, color, width){
  g.strokeStyle = color; g.lineWidth = width;
  if (part.layer === 1) { O.shape(part.object).forEach(q => g.stroke(q)); return; }
  g.beginPath();
  eachCell(part, (c, r) => {
    const [x, y, cs] = cellRect(part, c, r);
    if (!on(part, c, r-1)) { g.moveTo(x, y);    g.lineTo(x+cs, y); }
    if (!on(part, c, r+1)) { g.moveTo(x, y+cs); g.lineTo(x+cs, y+cs); }
    if (!on(part, c-1, r)) { g.moveTo(x, y);    g.lineTo(x, y+cs); }
    if (!on(part, c+1, r)) { g.moveTo(x+cs, y); g.lineTo(x+cs, y+cs); }
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

return { RES, pic, frame, cellRect, eachCell, dpr, domColor, drawCell, drawField, crispEdge, drawSeams,
         strokeOutline, shipRegion, drawOnShip, strokeOnShip, centerOnShip, shipOutlinePath };
})();
