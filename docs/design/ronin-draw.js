/*
  ronin-draw.js — общий вывод разметки для страниц docs/design/ronin-*.html:
  сэмплинг рисунка корабля по маске детали. НЕ канон и не спека — канон это
  ronin-parts.js (разметка) и docs/DESIGN.md (правила). Файл существует только
  затем, чтобы три страницы не держали три копии одного кода.

  Требует подключённых ship-render.js и ronin-parts.js.
*/
window.RONIN_DRAW = (function(){
"use strict";
const SHIP = window.__SHIP, P = window.RONIN_PARTS;
const SC = 2;                                  // offscreen отрисован в 2x
const K  = 1 / P.grid.renderCell;              // клетка сетки -> клетка рендера

/* координаты клетки сетки в px рисунка (до SC) */
const rx = col => SHIP.px(P.grid.originCol + col * K);
const ry = row => SHIP.py(row * K);

function dpr(cv, w, h){
  const k = window.devicePixelRatio || 1;
  cv.width = w*k; cv.height = h*k;
  cv.style.width = w+'px'; cv.style.height = h+'px';
  const g = cv.getContext('2d'); g.scale(k,k);
  g.imageSmoothingEnabled = true; g.imageSmoothingQuality = 'high';
  return g;
}

/* обход клеток маски: cb(col, row) в координатах СЕТКИ */
function eachCell(part, cb){
  const [c0, r0] = part.origin;
  part.mask.forEach((line, dr) => {
    for (let dc = 0; dc < line.length; dc++)
      if (line[dc] === '#') cb(c0 + dc, r0 + dr);
  });
}

/* путь по клеткам детали; map(col,row) -> [x,y] в целевых координатах, u — размер клетки */
function maskPath(g, part, map, u){
  g.beginPath();
  eachCell(part, (col, row) => { const [x, y] = map(col, row); g.rect(x, y, u, u); });
}

/*
  Деталь «из оригинала»: клип по маске + блит куска рисунка.
  map(col,row) -> [x,y] целевые координаты левого верхнего угла клетки, u — её размер.
*/
function drawPart(g, part, map, u){
  const [c0, r0] = part.origin;
  const w = part.mask[0].length, h = part.mask.length;
  const [X, Y] = map(c0, r0);
  g.save();
  maskPath(g, part, map, u); g.clip();
  g.drawImage(SHIP.off,
    rx(c0)*SC, ry(r0)*SC, (rx(c0+w)-rx(c0))*SC, (ry(r0+h)-ry(r0))*SC,
    X, Y, w*u, h*u);
  g.restore();
}

/*
  Разделители клеток (токен seam). ТОЛЬКО поле укладки: на экране корабля
  сетку клеток не рисуем — там швы даёт сам рисунок (DESIGN.md, решение PO
  2026-07-28). Каждая четвёртая линия совпадает со швом плиты рисунка.
*/
function drawCellSeams(g, part, map, u, color){
  g.strokeStyle = color; g.lineWidth = 1;
  eachCell(part, (col, row) => {
    const [x, y] = map(col, row);
    g.strokeRect(Math.round(x)+.5, Math.round(y)+.5, u, u);
  });
}

/* контур силуэта детали: та же маска, но обводим только внешние рёбра */
function strokeOutline(g, part, map, u, color, width){
  const on = new Set();
  eachCell(part, (col, row) => on.add(col+','+row));
  g.strokeStyle = color; g.lineWidth = width || 1.5;
  g.beginPath();
  eachCell(part, (col, row) => {
    const [x, y] = map(col, row);
    if (!on.has(col+','+(row-1))) { g.moveTo(x, y);     g.lineTo(x+u, y); }
    if (!on.has(col+','+(row+1))) { g.moveTo(x, y+u);   g.lineTo(x+u, y+u); }
    if (!on.has((col-1)+','+row)) { g.moveTo(x, y);     g.lineTo(x, y+u); }
    if (!on.has((col+1)+','+row)) { g.moveTo(x+u, y);   g.lineTo(x+u, y+u); }
  });
  g.stroke();
}

/* контур всего борта «сюда дорастёт», включая гондолы; T(x,y) — px рисунка -> целевые */
function shipOutlinePath(g, T){
  const {span, ROWS, C, px, py} = SHIP;
  const L = (x, y) => { const [a,b] = T(x, y); g.lineTo(a, b); };
  g.beginPath();
  const [sx0, sy0] = T(px(span[0][0]), py(0)); g.moveTo(sx0, sy0);
  for (let y = 0; y < ROWS; y++){ L(px(span[y][0]), py(y)); L(px(span[y][0]), py(y+1)); }
  L(px(span[ROWS-1][1]+1), py(ROWS));
  for (let y = ROWS-1; y >= 0; y--){ L(px(span[y][1]+1), py(y+1)); L(px(span[y][1]+1), py(y)); }
  g.closePath(); g.stroke();
  /* гондолы по бортам — часть силуэта */
  const bw = 1.06*C, bh = 2.9*C, byt = py(13.55);
  for (const bx of [px(3)-bw+2, px(12)-2]){
    const [x, y] = T(bx, byt), [x2, y2] = T(bx+bw, byt+bh), r = 5;
    g.beginPath(); g.moveTo(x+r, y);
    g.arcTo(x2, y, x2, y2, r); g.arcTo(x2, y2, x, y2, r);
    g.arcTo(x, y2, x, y, r);   g.arcTo(x, y, x2, y, r);
    g.closePath(); g.stroke();
  }
}

return { SC, rx, ry, dpr, eachCell, maskPath, drawPart, drawCellSeams, strokeOutline, shipOutlinePath };
})();
