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

  Клетка поля (D-016, D-017):
    'build' — во время сборки: плитка с рельефом куска (вариант Б). Вид клетки (cellInfo):
              основа — однотонная (преобладающий цвет рисунка без краски, цветных
              элементов и света; почти чёрное не берётся, если его < 70 %), поверх —
              краска корпуса (слой 'paint', может занимать часть клетки); цветной
              элемент — клетка целиком его цвета; свет — то же с ореолом на соседей,
              краски поверх нет. Элемент берёт клетку, если занимает ≥ 40 % её, или
              ≥ 15 % и ≥ 70 % от соседа поперёк элемента. Заклёпки чёрные 45 %, на
              тёмной клетке (яркость < 0,2) — 85 %.
    'done'  — деталь собрана: настоящий рисунок без рельефа и сетки; кромку детали
              рисует crispEdge в пикселях поля.
*/
window.RONIN_DRAW = (function(){
"use strict";
const SHIP = window.__SHIP, P = window.RONIN_PARTS, O = window.RONIN_OBJECTS;
const C = SHIP.C, RES = SHIP.RES || 2;
const secOf = (part) => P.sections.find(s => s.id === part.section);

/* ---------- варианты рисунка (лениво) ---------- */
const OFF = { lights:false, paint:false, accents:false };
const PICS = {}, PIC_OPT = {
  hull:  { res:RES, layer:'hull' },                               // корабль: обшивка
  obj:   { res:RES, layer:'objects' },                            // корабль и поле: предметы
  done:  { res:RES, layer:'hull', edges:false },                  // поле, собрана
  /* поле, сборка (D-017): основа, + цветные элементы, + свет; краска корпуса отдельно */
  hullBase:  Object.assign({ res:2, layer:'hull', edges:false }, OFF),
  hullAcc:   Object.assign({ res:2, layer:'hull', edges:false }, OFF, { accents:true }),
  hullLight: Object.assign({ res:2, layer:'hull', edges:false }, OFF, { lights:true }),
  objBase:   Object.assign({ res:2, layer:'objects' }, OFF),
  objAcc:    Object.assign({ res:2, layer:'objects' }, OFF, { accents:true }),
  objLight:  Object.assign({ res:2, layer:'objects' }, OFF, { lights:true }),
  paint:     { res:2, layer:'paint' },
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

/* пиксели рисунка (лениво, один раз) */
function pixels(p){ if (!p.img) p.img = p.cv.getContext('2d', { willReadFrequently:true }).getImageData(0, 0, p.cv.width, p.cv.height); return p.img; }
const lumAt = (d, i) => (0.2126*d[i] + 0.7152*d[i+1] + 0.0722*d[i+2]) / 255;
const lum = ([r, g, b]) => (0.2126*r + 0.7152*g + 0.0722*b) / 255;
const rgb = (a, al) => al == null ? `rgb(${a.map(v => v|0).join(',')})` : `rgba(${a.map(v => v|0).join(',')},${al})`;
/* квадрат клетки в пикселях рисунка p */
function box(p, x, y, cs){ const k = p.res; return [Math.round(x*k), Math.round(y*k), Math.max(1, Math.round(cs*k))]; }

/* преобладающий цвет участка рисунка: самая частая корзина квантованного цвета;
   skipDark — почти чёрное (обводка, тень) не берётся, если его меньше 70 % участка */
function domColor(p, x, y, cs, skipDark){
  const im = pixels(p), d = im.data, W = im.width, [x0, y0, n] = box(p, x, y, cs);
  const bins = new Map(); let dark = 0, tot = 0;
  for (let j = 0; j < n; j++) for (let i = 0; i < n; i++){
    const q = ((y0+j)*W + x0+i)*4; if (d[q+3] < 128) continue; tot++;
    const isDark = !!skipDark && lumAt(d, q) < 0.03; if (isDark) dark++;
    const key = (isDark ? 1<<12 : 0) | (d[q]>>4)<<8 | (d[q+1]>>4)<<4 | (d[q+2]>>4), b = bins.get(key) || [0,0,0,0,isDark];
    b[0]+=d[q]; b[1]+=d[q+1]; b[2]+=d[q+2]; b[3]++; bins.set(key, b);
  }
  const skip = tot && dark/tot < 0.7;
  let best = null; for (const b of bins.values()) if (!(skip && b[4]) && (!best || b[3] > best[3])) best = b;
  return best ? [best[0]/best[3], best[1]/best[3], best[2]/best[3]] : [23, 26, 30];
}

/* доля пикселей элемента в клетке и их средний цвет; kind 'light' — ярче основы на 0,25,
   'accent' — отличается от основы (сумма |ΔRGB| > 40) */
function elemShare(part, c, r, kind){
  const [x, y, cs] = cellRect(part, c, r), obj = part.layer === 1;
  const src = pic((obj ? 'obj' : 'hull') + (kind === 'light' ? 'Light' : 'Acc')), base = pic(obj ? 'objBase' : 'hullBase');
  const im = pixels(src), d = im.data, b = pixels(base).data, W = im.width, [x0, y0, n] = box(src, x, y, cs);
  let hit = 0, tot = 0; const sum = [0, 0, 0];
  for (let j = 0; j < n; j++) for (let i = 0; i < n; i++){
    const q = ((y0+j)*W + x0+i)*4; if (d[q+3] < 128) continue; tot++;
    const on = kind === 'light' ? lumAt(d, q) - lumAt(b, q) > 0.25
      : Math.abs(d[q]-b[q]) + Math.abs(d[q+1]-b[q+1]) + Math.abs(d[q+2]-b[q+2]) > 40;
    if (on){ hit++; sum[0] += d[q]; sum[1] += d[q+1]; sum[2] += d[q+2]; }
  }
  return { f: tot ? hit/tot : 0, col: hit ? sum.map(v => v/hit) : null };
}
/* клетки элемента: ≥ 40 % клетки, или ≥ 15 % и ≥ 70 % от соседа поперёк элемента
   (элемент шире, чем выше, — соседи сверху и снизу, иначе — слева и справа) */
function elemCells(part, kind){
  const F = new Map(); eachCell(part, (c, r) => F.set(c+','+r, elemShare(part, c, r, kind)));
  const hot = [...F].filter(([, v]) => v.f >= 0.15).map(([k]) => k.split(',').map(Number));
  const out = new Map(); if (!hot.length) return out;
  const span = i => Math.max(...hot.map(h => h[i])) - Math.min(...hot.map(h => h[i]));
  const across = span(0) >= span(1) ? [[0,1],[0,-1]] : [[1,0],[-1,0]];
  for (const [c, r] of hot){
    const v = F.get(c+','+r), nb = Math.max(0, ...across.map(([a, b]) => (F.get((c+a)+','+(r+b)) || {f:0}).f));
    if (v.f >= 0.4 || v.f >= 0.7*nb) out.set(c+','+r, v.col);
  }
  return out;
}
/* вид и цвет каждой клетки детали (D-017), кеш по id: 'c,r' → { kind, col } */
const INFO = {};
function cellInfo(part){
  if (INFO[part.id]) return INFO[part.id];
  const light = elemCells(part, 'light'), acc = elemCells(part, 'accent'), out = new Map();
  eachCell(part, (c, r) => { const k = c+','+r, [x, y, cs] = cellRect(part, c, r);
    out.set(k, light.has(k) ? { kind:'light', col:light.get(k) }
      : acc.has(k) ? { kind:'accent', col:acc.get(k) }
      : { kind:'base', col:domColor(pic(part.layer === 1 ? 'objBase' : 'hullBase'), x, y, cs, true) }); });
  return INFO[part.id] = out;
}

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
/* ореол световой клетки — на соседей (рисуется до самой клетки) */
function halo(g, col, dx, dy, u){
  g.save(); g.shadowColor = rgb(col, .9); g.shadowBlur = .7*u;
  g.fillStyle = rgb(col); g.fill(rrPath(dx+2, dy+2, u-4, u-4, 3)); g.restore();
}
/* плитка клетки во время сборки, без ореола */
function buildTile(g, part, c, r, dx, dy, u){
  const [x, y, cs] = cellRect(part, c, r), info = cellInfo(part).get(c+','+r);
  const s = u/34, i = s, w = u - 2*i;
  g.save(); g.clip(rrPath(dx+i, dy+i, w, w, 3*s));
  g.fillStyle = rgb(info.col); g.fillRect(dx, dy, u, u);
  if (info.kind === 'base' && part.layer === 0){ const p = pic('paint');
    g.drawImage(p.cv, x*p.res, y*p.res, cs*p.res, cs*p.res, dx, dy, u, u); }
  tileRelief(g, dx+i, dy+i, w, w, s, 1.4);
  g.restore();
  rivets(g, dx+i, dy+i, w, w, s, lum(info.col) < 0.2);
}

/* одна клетка детали в (dx,dy) размером u; phase — 'build' | 'done' (по умолчанию) */
function drawCell(g, part, c, r, dx, dy, u, phase){
  if (phase !== 'build'){
    const [x, y, cs] = cellRect(part, c, r), p = pic(part.layer === 1 ? 'obj' : 'done');
    g.drawImage(p.cv, x*p.res, y*p.res, cs*p.res, cs*p.res, dx, dy, u, u);
    return;
  }
  const info = cellInfo(part).get(c+','+r);
  if (info.kind === 'light') halo(g, info.col, dx, dy, u);
  buildTile(g, part, c, r, dx, dy, u);
}

/* деталь на поле укладки: маска со сдвигом (oc,or) в клетках поля */
function drawField(g, part, u, oc, or, phase){
  if (phase === 'build'){                       /* световые клетки последними — ореол ложится на соседей */
    const info = cellInfo(part), lit = [];
    eachCell(part, (c, r) => info.get(c+','+r).kind === 'light' ? lit.push([c, r]) : buildTile(g, part, c, r, (oc+c)*u, (or+r)*u, u));
    for (const [c, r] of lit) halo(g, info.get(c+','+r).col, (oc+c)*u, (or+r)*u, u);
    for (const [c, r] of lit) buildTile(g, part, c, r, (oc+c)*u, (or+r)*u, u);
    return;
  }
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

return { RES, pic, frame, cellRect, eachCell, dpr, domColor, cellInfo, drawCell, drawField, crispEdge, drawSeams,
         strokeOutline, shipRegion, drawOnShip, strokeOnShip, centerOnShip, shipOutlinePath };
})();
