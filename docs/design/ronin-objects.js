/*
  ronin-objects.js — ФОРМЫ ПРЕДМЕТОВ «Ронина» (слой 1, D-011) и растеризация в
  поле укладки. Владеет Дизайнер. Форма предмета = контур того, что рисует
  ship-render.js (та же геометрия, те же константы), в px рисунка до RES.

  Маски предметов в ronin-parts.js посчитаны отсюда (rasterize) и лежат в
  каноне готовыми — реализации Path2D не нужен. Файл нужен страницам
  docs/design/ (вырез предмета на корабле) и при новой разметке (Ронин-2).

  Требует подключённого ship-render.js (window.__SHIP).
*/
window.RONIN_OBJECTS = (function(){
"use strict";
const SHIP = window.__SHIP, C = SHIP.C, px = SHIP.px, py = SHIP.py, cx = SHIP.cx;

const poly = (pts) => { const p = new Path2D(); pts.forEach(([x, y], i) => i ? p.lineTo(x, y) : p.moveTo(x, y)); p.closePath(); return p; };
function rect(x, y, w, h){ const p = new Path2D(); p.rect(x, y, w, h); return p; }
function rrect(x, y, w, h, r){ const p = new Path2D(); p.moveTo(x+r,y); p.arcTo(x+w,y,x+w,y+h,r); p.arcTo(x+w,y+h,x,y+h,r); p.arcTo(x,y+h,x,y,r); p.arcTo(x,y,x+w,y,r); p.closePath(); return p; }
function circle(x, y, r){ const p = new Path2D(); p.arc(x, y, r, 0, 7); return p; }

/* Форма = список Path2D (объединение). kind + параметры — как в ronin-parts.js. */
const SHAPES = {
  /* датчик-блок над носом: корпус, головка, огонёк */
  sensor: () => [
    rect(cx - .5*C, py(-.55), 1*C, .6*C),
    rect(cx - .26*C, py(-.95), .52*C, .42*C),
    circle(cx, py(-1.06), 2.2),
  ],
  /* RCS-квад: блок и три сопла (вверх, вбок наружу, вниз). at — центр в клетках рисунка */
  rcs: ({at:[x, y], flip}) => {
    const X = px(x), Y = py(y);
    const up = [[-5.2,-.56*C],[5.2,-.56*C],[3.4,-.3*C],[-3.4,-.3*C]];
    const rot = (a) => poly(up.map(([u, v]) => [X + u*Math.cos(a) - v*Math.sin(a), Y + u*Math.sin(a) + v*Math.cos(a)]));
    return [rrect(X-.3*C, Y-.3*C, .6*C, .6*C, 3), rot(0), rot(flip*Math.PI/2), rot(Math.PI)];
  },
};
const shape = (obj) => SHAPES[obj.kind](obj);

/*
  Растеризация в масштабе s (клеток поля на клетку рисунка): клетка входит в
  маску, если предмет покрывает больше половины клетки (6×6 проб). Сетка клеток
  центрирована на bbox предмета. Возвращает { mask, origin:[x,y] } — origin в
  клетках рисунка, левый-верх маски.
*/
const probe = document.createElement('canvas').getContext('2d');
function rasterize(paths, s){
  const inside = (x, y) => paths.some(p => probe.isPointInPath(p, x, y));
  let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9;
  for (let y = -3*C; y < SHIP.H; y += 3) for (let x = 0; x < SHIP.W; x += 3)
    if (inside(x, y)) { x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x); y1 = Math.max(y1, y); }
  const X0 = x0 - 4, Y0 = y0 - 4, X1 = x1 + 4, Y1 = y1 + 4;
  x0 = 1e9; y0 = 1e9; x1 = -1e9; y1 = -1e9;
  for (let y = Y0; y <= Y1; y += .5) for (let x = X0; x <= X1; x += .5)
    if (inside(x, y)) { x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x); y1 = Math.max(y1, y); }
  const cs = C / s, bw = x1 - x0, bh = y1 - y0;
  const cols = Math.ceil(bw / cs), rows = Math.ceil(bh / cs);
  let gx = x0 - (cols*cs - bw) / 2, gy = y0 - (rows*cs - bh) / 2;
  const N = 6;
  let mask = [];
  for (let r = 0; r < rows; r++){
    let line = '';
    for (let c = 0; c < cols; c++){
      let hit = 0;
      for (let i = 0; i < N; i++) for (let j = 0; j < N; j++)
        if (inside(gx + (c + (i+.5)/N)*cs, gy + (r + (j+.5)/N)*cs)) hit++;
      line += hit * 2 > N*N ? '#' : '.';
    }
    mask.push(line);
  }
  while (!mask[0].includes('#')) { mask.shift(); gy += cs; }
  while (!mask[mask.length-1].includes('#')) mask.pop();
  while (mask.every(l => l[0] === '.')) { mask = mask.map(l => l.slice(1)); gx += cs; }
  while (mask.every(l => l[l.length-1] === '.')) mask = mask.map(l => l.slice(0, -1));
  const r3 = v => Math.round(v * 1000) / 1000;
  return { mask, origin: [r3((gx - SHIP.OX) / C), r3((gy - SHIP.OY) / C)] };
}

return { shape, rasterize };
})();
