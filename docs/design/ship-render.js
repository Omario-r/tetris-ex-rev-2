/*
  ship-render.js — рендер крейсера «Ронин» v4. КАНОН РИСУНКА, утв. PO 2026-07-12
  (подтверждён 2026-07-13). Единственный экземпляр: страницы docs/design/*.html
  подключают этот файл, копий кода рендера в проекте больше нет.

  Рисует корабль в offscreen-канву `off` (2x) и отдаёт её вместе с системой
  координат. Клетка рендера = C px; корпус занимает строки 0..ROWS-1,
  колонки span[y][0]..span[y][1].

  Потребители: ship_ronin_v4.html (референс), ronin-grid.html, ronin-ship.html,
  ronin-parts-catalog.html. Разметка деталей — ronin-parts.js.
*/
window.__SHIP = (function(){
"use strict";
/* ---------- базовые константы ---------- */
const C=24, GW=15, GH=30;
const OX=4*C, OY=1.9*C;
const W=(GW+8)*C, H=(GH+8.6)*C;
const px=x=>OX+x*C, py=y=>OY+y*C;
const cx=px(7.5);

/* детерминированный рандом */
function mulberry32(a){return function(){a|=0;a=a+0x6D2B79F5|0;let t=Math.imul(a^a>>>15,1|a);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296}}
const rnd=mulberry32(20260712);

/* ---------- силуэт: [x0,x1] на строку (центр 7.5, слимнее, больше ступеней) ---------- */
const span=[];
span[0]=[5,9]; span[1]=[5,9];
span[2]=[4,10]; span[3]=[4,10];
for(let y=4;y<=20;y++)span[y]=[3,11];
for(let y=21;y<=24;y++)span[y]=[4,10];
span[25]=[5,9]; span[26]=[5,9];
const ROWS=27; // 0..26 воксельные; ниже — сопло и факел (графика)

/* ---------- секции-пояса ---------- */
const BANDS=[
 {r:[0,1],  kind:'prow'},
 {r:[2,3],  kind:'bridge'},
 {r:[4,7],  kind:'fwd'},
 {r:[8,12], kind:'bandA'},   // главный оранжевый пояс
 {r:[13,17],kind:'mid'},
 {r:[18,20],kind:'bandB'},
 {r:[21,24],kind:'eng'},
 {r:[25,26],kind:'skirt'},
];

/* материалы: [h,s,l] */
const M={
 GRAF:[215,9,31], GRAF2:[215,9,26], DARK:[216,11,17],
 ORAN:[23,62,46], RUST:[19,58,38],
 GUN:[220,10,22], BLACKM:[220,12,13],
};
const hsl=(m,dl=0,da=1)=>`hsla(${m[0]},${m[1]}%,${Math.max(3,Math.min(92,m[2]+dl))}%,${da})`;

/* ---------- нарезка на панели-плиты ---------- */
const plates=[];
for(const b of BANDS){
  let y=b.r[0];
  while(y<=b.r[1]){
    const canPair = y+1<=b.r[1] && span[y][0]===span[y+1][0] && span[y][1]===span[y+1][1];
    const ph = (canPair && rnd()<.8)?2:1;
    const x0=span[y][0], x1=span[y][1];
    const wide=(b.kind==='bandA'||b.kind==='bandB');
    let x=x0, i=0;
    while(x<=x1){
      let pw = wide? 3+Math.floor(rnd()*3) : 2+Math.floor(rnd()*3); // 3..5 / 2..4
      if(x1-x+1-pw===1) pw++;
      pw=Math.min(pw, x1-x+1);
      plates.push({x,y,w:pw,h:ph,kind:b.kind,i:i++,jl:(rnd()*7-3.5),rv:rnd()});
      x+=pw;
    }
    y+=ph;
  }
}
/* материал плиты по поясу */
function plateMat(p){
  const inInset = p.x>=6&&p.x+p.w<=9&&p.y>=9&&p.y+p.h<=12;  // ниша под люк
  const inName  = p.x<=5&&p.y>=8&&p.y<13;                    // поле под маркировку
  switch(p.kind){
    case 'prow':  return M.DARK;
    case 'bridge':return M.GRAF2;
    case 'fwd':   return p.rv<.15?M.DARK:M.GRAF;
    case 'bandA': return inInset?M.DARK:(inName?M.ORAN:(p.rv<.16?M.RUST:M.ORAN));
    case 'mid':   return p.rv<.06?M.DARK:(p.rv>.94?M.ORAN:(p.rv<.72?M.GRAF:M.GRAF2));
    case 'bandB': return p.rv<.46?M.ORAN:(p.rv<.56?M.DARK:M.GRAF2);
    case 'eng':   return p.rv<.3?M.BLACKM:M.GUN;
    case 'skirt': return M.BLACKM;
  }
}

/* ---------- контур корпуса (ступенчатый полигон) ---------- */
function hullPath(g){
  g.beginPath();
  g.moveTo(px(span[0][0]), py(0));
  for(let y=0;y<ROWS;y++){ g.lineTo(px(span[y][0]),py(y)); g.lineTo(px(span[y][0]),py(y+1)); }
  g.lineTo(px(span[ROWS-1][1]+1),py(ROWS));
  for(let y=ROWS-1;y>=0;y--){ g.lineTo(px(span[y][1]+1),py(y+1)); g.lineTo(px(span[y][1]+1),py(y)); }
  g.closePath();
}

/* ---------- вспомогательные ---------- */
function rr(g,x,y,w,h,r){g.beginPath();g.moveTo(x+r,y);g.arcTo(x+w,y,x+w,y+h,r);g.arcTo(x+w,y+h,x,y+h,r);g.arcTo(x,y+h,x,y,r);g.arcTo(x,y,x+w,y,r);g.closePath();}
function glowDot(g,x,y,r,col){const gr=g.createRadialGradient(x,y,0,x,y,r*4);gr.addColorStop(0,col);gr.addColorStop(1,'rgba(0,0,0,0)');g.fillStyle=gr;g.beginPath();g.arc(x,y,r*4,0,7);g.fill();g.fillStyle=col;g.beginPath();g.arc(x,y,r,0,7);g.fill();}

/* ================================================================
   РЕНДЕР ВСЕЙ СЦЕНЫ в offscreen 2x
================================================================ */
const off=document.createElement('canvas'); off.width=W*2; off.height=H*2;
const g=off.getContext('2d'); g.setTransform(2,0,0,2,0,0);

/* --- фон: космос --- */
(function(){
  const bg=g.createLinearGradient(0,0,0,H);
  bg.addColorStop(0,'#05070d'); bg.addColorStop(.6,'#080b13'); bg.addColorStop(1,'#0d0a08');
  g.fillStyle=bg; g.fillRect(0,0,W,H);
  const sr=mulberry32(77);
  for(let i=0;i<110;i++){const x=sr()*W,y=sr()*H*.92,a=.12+sr()*.5,r=sr()<.85?.7:1.3;
    g.fillStyle=`rgba(220,230,255,${a})`;g.beginPath();g.arc(x,y,r,0,7);g.fill();}
})();

/* --- планета (тёплый Марс внизу-справа) --- */
(function(){
  const pcx=W*.74, pcy=H*1.72, pr=H*.95;
  g.save();
  const atm=g.createRadialGradient(pcx,pcy,pr*.92,pcx,pcy,pr*1.06);
  atm.addColorStop(0,'rgba(255,140,60,0)');atm.addColorStop(.8,'rgba(255,140,60,.16)');atm.addColorStop(1,'rgba(255,140,60,0)');
  g.fillStyle=atm;g.beginPath();g.arc(pcx,pcy,pr*1.06,0,7);g.fill();
  const pg=g.createRadialGradient(pcx-pr*.25,pcy-pr*.55,pr*.2,pcx,pcy,pr);
  pg.addColorStop(0,'#96431a');pg.addColorStop(.55,'#5e2810');pg.addColorStop(1,'#170a05');
  g.fillStyle=pg;g.beginPath();g.arc(pcx,pcy,pr,0,7);g.fill();
  const sr=mulberry32(41);
  g.globalAlpha=.14;
  for(let i=0;i<26;i++){const a=Math.PI*(1.05+sr()*.5),rr0=pr*(.55+sr()*.42);
    const sx=pcx+Math.cos(a)*rr0,sy=pcy+Math.sin(a)*rr0;
    if(sy>H)continue;
    g.fillStyle=sr()<.5?'#2a1206':'#b3653a';
    g.beginPath();g.ellipse(sx,sy,14+sr()*30,5+sr()*9,a+1.57,0,7);g.fill();}
  g.globalAlpha=1; g.restore();
})();

/* --- ореол факела за кораблём (до корпуса) --- */
(function(){
  const gy=py(30.8);
  const halo=g.createRadialGradient(cx,gy,0,cx,gy,6.4*C);
  halo.addColorStop(0,'rgba(140,215,255,.34)');halo.addColorStop(.5,'rgba(120,200,255,.13)');halo.addColorStop(1,'rgba(120,200,255,0)');
  g.fillStyle=halo;g.beginPath();g.arc(cx,gy,6.4*C,0,7);g.fill();
})();

/* ================================================================
   КОРПУС
================================================================ */
for(const p of plates){
  const m=plateMat(p);
  const X=px(p.x),Y=py(p.y),Wd=p.w*C,Hd=p.h*C;
  g.fillStyle=hsl(m,p.jl);
  g.fillRect(X,Y,Wd,Hd);
  g.strokeStyle=hsl(m,p.jl+12,.8); g.lineWidth=2;
  g.beginPath();g.moveTo(X+1.2,Y+Hd-1.2);g.lineTo(X+1.2,Y+1.2);g.lineTo(X+Wd-1.2,Y+1.2);g.stroke();
  g.strokeStyle=hsl(m,p.jl-12,.85);
  g.beginPath();g.moveTo(X+Wd-1.2,Y+1.2);g.lineTo(X+Wd-1.2,Y+Hd-1.2);g.lineTo(X+1.2,Y+Hd-1.2);g.stroke();
  g.strokeStyle='rgba(0,0,0,.4)'; g.lineWidth=1.5;
  g.strokeRect(X+.75,Y+.75,Wd-1.5,Hd-1.5);
}
/* лёгкая воксельная сетка */
g.save(); hullPath(g); g.clip();
g.strokeStyle='rgba(255,255,255,.045)'; g.lineWidth=1;
for(let x=0;x<=GW;x++){g.beginPath();g.moveTo(px(x),py(0));g.lineTo(px(x),py(ROWS));g.stroke();}
for(let y=0;y<=ROWS;y++){g.beginPath();g.moveTo(px(0),py(y));g.lineTo(px(GW),py(y));g.stroke();}
g.restore();

/* швы между поясами */
for(const yb of [2,4,8,13,18,21,25]){
  const s0=Math.max(span[yb][0],span[yb-1][0]), s1=Math.min(span[yb][1],span[yb-1][1]);
  g.strokeStyle='rgba(0,0,0,.6)';g.lineWidth=2.5;
  g.beginPath();g.moveTo(px(s0),py(yb));g.lineTo(px(s1+1),py(yb));g.stroke();
  g.strokeStyle='rgba(255,255,255,.12)';g.lineWidth=1;
  g.beginPath();g.moveTo(px(s0),py(yb)-2);g.lineTo(px(s1+1),py(yb)-2);g.stroke();
}

/* --- крупная светотень --- */
g.save(); hullPath(g); g.clip();
let sh=g.createLinearGradient(px(0),0,px(15),0);
sh.addColorStop(0,'rgba(255,255,255,.12)');sh.addColorStop(.4,'rgba(255,255,255,0)');
sh.addColorStop(.62,'rgba(0,0,0,0)');sh.addColorStop(1,'rgba(0,0,0,.20)');
g.fillStyle=sh; g.fillRect(px(-1),py(-1),17*C,29*C);
sh=g.createLinearGradient(0,py(18),0,py(27));
sh.addColorStop(0,'rgba(0,0,0,0)');sh.addColorStop(1,'rgba(0,0,0,.16)');
g.fillStyle=sh; g.fillRect(px(-1),py(18),17*C,10*C);
const warm=g.createRadialGradient(px(13.5),py(28),0,px(13.5),py(28),13*C);
warm.addColorStop(0,'rgba(255,130,50,.14)');warm.addColorStop(1,'rgba(255,130,50,0)');
g.fillStyle=warm; g.fillRect(px(-1),py(10),17*C,18*C);
const wr=mulberry32(9);
for(let i=0;i<9;i++){const wx=px(3+wr()*9),wy=py(4+wr()*20),wl=(.5+wr()*1.4)*C;
  g.fillStyle=`rgba(0,0,0,${.05+wr()*.04})`;g.fillRect(wx,wy,2,wl);}
for(let i=0;i<5;i++){const wx=px(3+wr()*9),wy=py(4+wr()*20);
  g.fillStyle='rgba(255,255,255,.04)';g.fillRect(wx,wy,3.5,.35*C);}
g.restore();

/* ================================================================
   ДЕТАЛИ ПО СЕКЦИЯМ
================================================================ */

/* --- нос: шеврон + датчик-блок + строб --- */
g.save(); g.beginPath();
g.rect(px(span[0][0]),py(0),(span[0][1]-span[0][0]+1)*C,2*C); g.clip();
g.fillStyle=hsl(M.ORAN,0,.95);
g.beginPath();
g.moveTo(cx,py(1.95));g.lineTo(cx-2.1*C,py(.9));g.lineTo(cx-2.1*C,py(.38));
g.lineTo(cx,py(1.38));g.lineTo(cx+2.1*C,py(.38));g.lineTo(cx+2.1*C,py(.9));g.closePath();g.fill();
g.strokeStyle='rgba(255,255,255,.5)';g.lineWidth=2;
g.beginPath();g.moveTo(cx-2.1*C,py(.24));g.lineTo(cx,py(1.22));g.lineTo(cx+2.1*C,py(.24));g.stroke();
g.restore();
/* датчик-блок на носу */
g.fillStyle=hsl(M.DARK,-2);
g.fillRect(cx-.5*C,py(-.55),1*C,.6*C);
g.fillStyle=hsl(M.GUN,6);
g.fillRect(cx-.26*C,py(-.95),.52*C,.42*C);
g.strokeStyle='rgba(0,0,0,.6)';g.lineWidth=1.5;
g.strokeRect(cx-.5*C,py(-.55),1*C,.6*C); g.strokeRect(cx-.26*C,py(-.95),.52*C,.42*C);
g.fillStyle='rgba(180,220,255,.9)'; g.fillRect(cx-.18*C,py(-.78),.36*C,2.2);
glowDot(g,cx,py(-1.06),2.2,'rgba(255,255,255,.95)');

/* --- мостик: визор со щелями --- */
(function(){
  const vx=px(4.65),vy=py(2.62),vw=5.7*C,vh=.58*C;
  rr(g,vx,vy,vw,vh,4); g.fillStyle='#101318'; g.fill();
  g.strokeStyle='rgba(255,255,255,.18)'; g.lineWidth=1.5; g.stroke();
  const sl=[[5.0,1.0],[6.4,1.0],[7.8,1.0],[9.2,.85]];
  g.save(); g.shadowColor='rgba(150,210,255,.9)'; g.shadowBlur=9;
  for(const [sx,sw] of sl){
    const gr=g.createLinearGradient(px(sx),0,px(sx+sw),0);
    gr.addColorStop(0,'#8fc6ee');gr.addColorStop(.5,'#e8f6ff');gr.addColorStop(1,'#79b6e2');
    g.fillStyle=gr; rr(g,px(sx),vy+.16*C,sw*C,.26*C,2.5); g.fill();
  }
  g.restore();
})();
/* номер борта */
g.font='bold 12px "Arial Narrow","DejaVu Sans",sans-serif';
g.textAlign='center'; g.textBaseline='middle';
g.fillStyle='rgba(223,230,236,.85)';
g.fillText('V V - 7 7', cx, py(4.62));
/* торпедные люки на носовой секции */
for(const s of [-1,1]){
  const tx=cx+s*1.45*C-.42*C, ty=py(5.95);
  g.save(); g.shadowColor='rgba(0,0,0,.5)'; g.shadowBlur=5;
  g.fillStyle=hsl(M.DARK,-1); rr(g,tx,ty,.84*C,.66*C,3); g.fill(); g.restore();
  g.strokeStyle='rgba(0,0,0,.65)';g.lineWidth=1.6; rr(g,tx,ty,.84*C,.66*C,3); g.stroke();
  g.strokeStyle='rgba(255,255,255,.14)';g.lineWidth=1;
  g.beginPath();g.moveTo(tx+.42*C,ty+3);g.lineTo(tx+.42*C,ty+.66*C-3);g.stroke();
  g.fillStyle='rgba(224,131,55,.85)'; g.fillRect(tx+2,ty-2.6,.84*C-4,2);
}

/* трафарет «77» на носовой секции (как бортовые надписи референса) */
g.save();
g.font='bold 26px "Arial Narrow","DejaVu Sans",sans-serif';
g.fillStyle='rgba(228,234,240,.78)';
g.fillText('7 7', px(4.85), py(7.28));
g.restore();

/* --- маркировка «РОНИН» --- */
(function(){
  const word='РОНИН';
  g.font='bold 21px "Arial Narrow","DejaVu Sans",sans-serif';
  g.fillStyle='rgba(30,18,8,.92)';
  for(let i=0;i<5;i++) g.fillText(word[i], px(4.5), py(8.55+i));
  g.strokeStyle='rgba(30,18,8,.5)'; g.lineWidth=2;
  g.beginPath();g.moveTo(px(3.4),py(8.25));g.lineTo(px(3.4),py(12.75));g.stroke();
})();

/* --- стыковочный люк-октагон --- */
(function(){
  const ox=cx, oy=py(10.5), R=.9*C;
  g.save(); g.shadowColor='rgba(0,0,0,.6)'; g.shadowBlur=8;
  g.beginPath();
  for(let i=0;i<8;i++){const a=Math.PI/8+i*Math.PI/4;
    const X=ox+Math.cos(a)*R, Y=oy+Math.sin(a)*R;
    i?g.lineTo(X,Y):g.moveTo(X,Y);}
  g.closePath();
  g.fillStyle='#0e1114'; g.fill(); g.restore();
  g.strokeStyle=hsl(M.GUN,18); g.lineWidth=3;
  g.beginPath();
  for(let i=0;i<8;i++){const a=Math.PI/8+i*Math.PI/4;
    const X=ox+Math.cos(a)*R, Y=oy+Math.sin(a)*R;
    i?g.lineTo(X,Y):g.moveTo(X,Y);}
  g.closePath(); g.stroke();
  g.beginPath();
  for(let i=0;i<8;i++){const a=Math.PI/8+i*Math.PI/4;
    const X=ox+Math.cos(a)*R*.6, Y=oy+Math.sin(a)*R*.6;
    i?g.lineTo(X,Y):g.moveTo(X,Y);}
  g.closePath(); g.strokeStyle='rgba(255,255,255,.16)'; g.lineWidth=1.5; g.stroke();
  for(let i=0;i<4;i++){const a=i*Math.PI/2+Math.PI/4;
    g.fillStyle='#79828c';g.beginPath();g.arc(ox+Math.cos(a)*R*.8,oy+Math.sin(a)*R*.8,2.4,0,7);g.fill();}
  g.strokeStyle='rgba(255,255,255,.22)';g.lineWidth=1.2;
  g.beginPath();g.moveTo(ox-R*.35,oy);g.lineTo(ox+R*.35,oy);g.stroke();
})();

/* --- бортовые огни-иллюминаторы (щели) --- */
(function(){
  const ws=[[4.0,5.45,'c'],[10.2,5.45,'c'],[3.6,10.42,'w'],[9.9,9.42,'w'],[3.7,13.42,'c'],[10.5,13.42,'c'],[3.6,19.42,'w'],[9.9,19.42,'w']];
  for(const [x,y,k] of ws){
    g.save(); g.shadowBlur=7;
    g.shadowColor=k==='w'?'rgba(255,205,140,.85)':'rgba(160,215,255,.85)';
    g.fillStyle=k==='w'?'#ffd9a0':'#cfeaff';
    rr(g,px(x),py(y),.8*C,.16*C,2); g.fill(); g.restore();
  }
})();

/* --- манёвровые гондолы на миделе (объёмы, без «стволов») --- */
function pod(side){
  const bw=1.06*C, bh=2.9*C, byt=py(13.55);
  const bx = side<0 ? px(3)-bw+2 : px(12)-2;
  // кронштейны к корпусу
  g.fillStyle=hsl(M.DARK,-2);
  const hx = side<0 ? bx+bw-3 : bx+3-8;
  g.fillRect(side<0?bx+bw-4:bx-6, py(14.15), 10, 5.5);
  g.fillRect(side<0?bx+bw-4:bx-6, py(15.6), 10, 5.5);
  // корпус гондолы
  g.save(); g.shadowColor='rgba(0,0,0,.55)'; g.shadowBlur=7;
  const grd=g.createLinearGradient(bx,byt,bx,byt+bh);
  grd.addColorStop(0,hsl(M.GRAF,8));grd.addColorStop(1,hsl(M.GRAF,-10));
  rr(g,bx,byt,bw,bh,7); g.fillStyle=grd; g.fill(); g.restore();
  g.strokeStyle='rgba(0,0,0,.65)'; g.lineWidth=2; rr(g,bx,byt,bw,bh,7); g.stroke();
  g.strokeStyle='rgba(255,255,255,.16)'; g.lineWidth=1.2;
  g.beginPath();g.moveTo(bx+2.5,byt+bh-4);g.lineTo(bx+2.5,byt+4);g.lineTo(bx+bw-2.5,byt+4);g.stroke();
  // сопла-чашки вверх и вниз
  for(const dir of [-1,1]){
    const ny = dir<0 ? byt : byt+bh;
    g.fillStyle='#101215';
    g.beginPath();
    g.moveTo(bx+bw*.26,ny); g.lineTo(bx+bw*.74,ny);
    g.lineTo(bx+bw*.88,ny+dir*9); g.lineTo(bx+bw*.12,ny+dir*9);
    g.closePath(); g.fill();
    g.strokeStyle='rgba(0,0,0,.7)'; g.lineWidth=1.4; g.stroke();
    g.fillStyle='#04060a';
    g.beginPath();g.ellipse(bx+bw/2,ny+dir*9,bw*.37,2.6,0,0,7);g.fill();
    g.strokeStyle='rgba(255,255,255,.2)';g.lineWidth=1;
    g.beginPath();g.ellipse(bx+bw/2,ny+dir*9,bw*.37,2.6,0,0,7);g.stroke();
  }
  // оранжевый пояс + жалюзи
  g.fillStyle=hsl(M.ORAN); g.fillRect(bx+2,byt+bh*.46,bw-4,.3*C);
  g.fillStyle='rgba(0,0,0,.42)';
  for(let i=0;i<2;i++) g.fillRect(bx+bw*.2,byt+.5*C+i*7,bw*.6,2.6);
  g.fillStyle='rgba(0,0,0,.42)';
  for(let i=0;i<2;i++) g.fillRect(bx+bw*.2,byt+bh-.72*C+i*7,bw*.6,2.6);
  // навигационный огонь на внешней скуле
  glowDot(g,side<0?bx+3.5:bx+bw-3.5,byt+.5*C,2.4,side<0?'rgba(255,80,70,.95)':'rgba(90,255,140,.95)');
}
pod(-1); pod(1);

/* --- RCS-квады --- */
function rcs(X,Y,flip){
  g.fillStyle=hsl(M.GUN,10);
  rr(g,X-.3*C,Y-.3*C,.6*C,.6*C,3); g.fill();
  g.strokeStyle='rgba(0,0,0,.6)';g.lineWidth=1.5;g.stroke();
  const noz=(a)=>{
    g.save(); g.translate(X,Y); g.rotate(a);
    g.fillStyle='#101215';
    g.beginPath();g.moveTo(-3.4,-.3*C);g.lineTo(3.4,-.3*C);g.lineTo(5.2,-.56*C);g.lineTo(-5.2,-.56*C);g.closePath();g.fill();
    g.strokeStyle='rgba(255,255,255,.18)';g.lineWidth=1;g.stroke();
    g.restore();
  };
  noz(0); noz(flip*Math.PI/2); noz(Math.PI);
}
rcs(px(3),py(4.5),-1); rcs(px(12),py(4.5),1);
rcs(px(3),py(20.5),-1); rcs(px(12),py(20.5),1);

/* --- грузовой люк (лево) и шлюз (право) --- */
(function(){
  const X=px(3.55),Y=py(14.15),Wd=1.9*C,Hd=1.6*C;
  g.save(); g.shadowColor='rgba(0,0,0,.5)'; g.shadowBlur=6;
  g.fillStyle=hsl(M.DARK,1); rr(g,X,Y,Wd,Hd,4); g.fill(); g.restore();
  g.strokeStyle='rgba(0,0,0,.7)';g.lineWidth=2; rr(g,X,Y,Wd,Hd,4); g.stroke();
  g.strokeStyle='rgba(255,255,255,.12)';g.lineWidth=1;
  for(let i=1;i<4;i++){g.beginPath();g.moveTo(X+3,Y+Hd*i/4);g.lineTo(X+Wd-3,Y+Hd*i/4);g.stroke();}
  g.fillStyle=hsl(M.ORAN,0,.9); g.fillRect(X,Y-3,Wd,2.4);
  for(const [bx,by] of [[X+4,Y+4],[X+Wd-4,Y+4],[X+4,Y+Hd-4],[X+Wd-4,Y+Hd-4]]){
    g.fillStyle='#666e78';g.beginPath();g.arc(bx,by,1.8,0,7);g.fill();}
  const ax=px(9.35),ay=py(14.1),aw=1.4*C,ah=1.7*C;
  g.save(); g.shadowColor='rgba(0,0,0,.5)'; g.shadowBlur=6;
  rr(g,ax,ay,aw,ah,5); g.fillStyle=hsl(M.DARK,3); g.fill(); g.restore();
  g.strokeStyle='rgba(0,0,0,.7)';g.lineWidth=2; rr(g,ax,ay,aw,ah,5); g.stroke();
  g.save(); g.beginPath(); g.rect(ax-6,ay,5,ah); g.clip();
  for(let i=0;i<8;i++){g.fillStyle=i%2?'#191a1c':'#d7a323';
    g.save();g.translate(ax-6,ay+i*ah/7);g.rotate(-.6);g.fillRect(-4,0,16,4);g.restore();}
  g.restore();
  g.save();g.shadowColor='rgba(255,205,140,.8)';g.shadowBlur=6;
  g.fillStyle='#ffd9a0'; rr(g,ax+aw*.28,ay+.2*C,aw*.44,.15*C,2); g.fill(); g.restore();
  g.strokeStyle='#8d959e';g.lineWidth=2.4;
  g.beginPath();g.moveTo(ax+aw*.3,ay+ah*.62);g.lineTo(ax+aw*.7,ay+ah*.62);g.stroke();
})();

/* --- решётка-радиатор поперёк миделя --- */
(function(){
  const X=px(4.5),Y=py(16.35),Wd=6.0*C,Hd=.5*C;
  g.fillStyle='#0f1215'; rr(g,X,Y,Wd,Hd,3); g.fill();
  g.strokeStyle='rgba(255,255,255,.14)';g.lineWidth=1.2;g.stroke();
  for(let i=1;i<9;i++){g.strokeStyle='rgba(255,255,255,.16)';
    g.beginPath();g.moveTo(X+Wd*i/9,Y+2);g.lineTo(X+Wd*i/9,Y+Hd-2);g.stroke();}
  const gr=g.createLinearGradient(X,Y,X+Wd,Y);
  gr.addColorStop(0,'rgba(255,120,40,0)');gr.addColorStop(.5,'rgba(255,120,40,.25)');gr.addColorStop(1,'rgba(255,120,40,0)');
  g.fillStyle=gr; g.fillRect(X,Y+Hd*.3,Wd,Hd*.4);
})();

/* ================================================================
   КОРМА: машинное отделение → юбка → сопло
================================================================ */
function pipeV(X,y0,y1){
  const gr=g.createLinearGradient(X-4,0,X+4,0);
  gr.addColorStop(0,'#5e3b1e');gr.addColorStop(.35,'#96683a');gr.addColorStop(.6,'#7d5028');gr.addColorStop(1,'#4a2e17');
  g.fillStyle=gr; g.fillRect(X-3.8,py(y0),7.6,(y1-y0)*C);
  g.strokeStyle='rgba(0,0,0,.55)';g.lineWidth=1.2;g.strokeRect(X-3.8,py(y0),7.6,(y1-y0)*C);
  for(const yj of [y0+.7,y0+1.8,y0+2.9]){
    if(yj>y1)break;
    g.fillStyle='#33383f'; g.fillRect(X-5.2,py(yj),10.4,4.2);
    g.strokeStyle='rgba(0,0,0,.6)';g.strokeRect(X-5.2,py(yj),10.4,4.2);
  }
}
pipeV(px(4.6),21.15,24.8); pipeV(px(10.4),21.15,24.8);
(function(){
  const Y=py(21.4);
  const gr=g.createLinearGradient(0,Y-3.5,0,Y+3.5);
  gr.addColorStop(0,'#96683a');gr.addColorStop(1,'#4a2e17');
  g.fillStyle=gr; g.fillRect(px(4.6),Y-3.4,5.8*C,6.8);
  g.strokeStyle='rgba(0,0,0,.5)';g.lineWidth=1.2;g.strokeRect(px(4.6),Y-3.4,5.8*C,6.8);
})();
/* сферические полубаки */
for(const X of [px(6.0),px(9.0)]){
  const Y=py(21.05);
  const gr=g.createRadialGradient(X-3,Y+3,1,X,Y+5,12);
  gr.addColorStop(0,'#8b939d');gr.addColorStop(.5,'#4b5158');gr.addColorStop(1,'#23262b');
  g.fillStyle=gr;g.beginPath();g.arc(X,Y+5,10,Math.PI,0);g.closePath();g.fill();
  g.strokeStyle='rgba(0,0,0,.6)';g.lineWidth=1.4;g.stroke();
}
/* большой горизонтальный бак */
(function(){
  const X=px(5.7),Y=py(22.25),Wd=3.6*C,Hd=.95*C,R=Hd/2;
  g.save(); g.shadowColor='rgba(0,0,0,.55)'; g.shadowBlur=7;
  const gr=g.createLinearGradient(0,Y,0,Y+Hd);
  gr.addColorStop(0,'#767e88');gr.addColorStop(.35,'#4d535b');gr.addColorStop(1,'#1e2126');
  rr(g,X,Y,Wd,Hd,R); g.fillStyle=gr; g.fill(); g.restore();
  g.strokeStyle='rgba(0,0,0,.7)';g.lineWidth=2; rr(g,X,Y,Wd,Hd,R); g.stroke();
  for(const fx of [.28,.5,.72]){
    g.strokeStyle='rgba(0,0,0,.4)';g.lineWidth=2;
    g.beginPath();g.moveTo(X+Wd*fx,Y+1.5);g.lineTo(X+Wd*fx,Y+Hd-1.5);g.stroke();
    g.strokeStyle='rgba(255,255,255,.15)';g.lineWidth=1;
    g.beginPath();g.moveTo(X+Wd*fx+2,Y+1.5);g.lineTo(X+Wd*fx+2,Y+Hd-1.5);g.stroke();
  }
  g.fillStyle='rgba(255,255,255,.25)'; rr(g,X+R*.5,Y+2.5,Wd-R,3,1.5); g.fill();
})();
/* вентиляция с огнём внутри */
for(const X of [px(4.35),px(9.85)]){
  for(let i=0;i<3;i++){
    const Y=py(23.35)+i*7.5;
    g.fillStyle='#050607'; rr(g,X,Y,18,3.4,1.5); g.fill();
    g.fillStyle='rgba(255,122,51,.85)'; g.fillRect(X+3,Y+1,12,1.4);
  }
}
/* гофра-переход над юбкой */
(function(){
  const Y=py(24.55),Hd=.42*C, X0=px(4.15),X1=px(10.85);
  g.save(); g.beginPath(); g.rect(X0,Y,X1-X0,Hd); g.clip();
  for(let x=X0,i=0;x<X1;x+=6,i++){
    g.fillStyle=i%2?'#d7a323':'#141518';
    g.save();g.translate(x,Y);g.rotate(.66);g.fillRect(0,-6,4.2,Hd+14);g.restore();
  }
  g.restore();
  g.strokeStyle='rgba(0,0,0,.6)';g.lineWidth=1.5;g.strokeRect(X0,Y,X1-X0,Hd);
})();

/* --- юбка: рёбра + гидроштоки --- */
(function(){
  const Y0=py(25),Y1=py(27),X0=px(5),X1=px(10);
  g.save(); g.beginPath(); g.rect(X0,Y0,X1-X0,Y1-Y0); g.clip();
  for(let x=X0,i=0;x<X1;x+=C*.5,i++){
    g.fillStyle=i%2?'rgba(255,255,255,.06)':'rgba(0,0,0,.28)';
    g.fillRect(x,Y0,C*.5,Y1-Y0);
  }
  g.restore();
  g.strokeStyle=hsl(M.ORAN,4,.9); g.lineWidth=3;
  g.beginPath();g.moveTo(X0+2,Y0+3);g.lineTo(X1-2,Y0+3);g.stroke();
  for(const X of [px(5.6),px(9.4)]){
    const gr=g.createLinearGradient(X-3,0,X+3,0);
    gr.addColorStop(0,'#20232a');gr.addColorStop(.4,'#aab3bd');gr.addColorStop(.6,'#78818b');gr.addColorStop(1,'#1c1f24');
    g.fillStyle=gr; g.fillRect(X-2.8,Y0+.2*C,5.6,Y1-Y0-.3*C);
    g.strokeStyle='rgba(0,0,0,.7)';g.lineWidth=1.2;g.strokeRect(X-2.8,Y0+.2*C,5.6,Y1-Y0-.3*C);
    g.fillStyle='#2c3037'; g.fillRect(X-4.4,Y0+.12*C,8.8,5); g.fillRect(X-4.4,Y1-.34*C,8.8,5);
  }
  for(let i=0;i<5;i++){
    g.fillStyle='#5c646d';
    g.beginPath();g.arc(X0+ (i+.5)*(X1-X0)/5, Y1-.3*C, 1.9,0,7);g.fill();
  }
})();

/* --- вернье-сопла на ступени машинного отделения --- */
for(const s of [-1,1]){
  const vx=cx+s*3.05*C, vt=py(25.06), ve=py(26.35);
  g.beginPath();
  g.moveTo(vx-.32*C,vt);g.quadraticCurveTo(vx-.48*C,ve-.25*C,vx-.6*C,ve);
  g.lineTo(vx+.6*C,ve);g.quadraticCurveTo(vx+.48*C,ve-.25*C,vx+.32*C,vt);g.closePath();
  const vg=g.createLinearGradient(vx-.6*C,0,vx+.6*C,0);
  vg.addColorStop(0,'#0d0f12');vg.addColorStop(.45,'#3c424a');vg.addColorStop(1,'#0d0f12');
  g.fillStyle=vg;g.fill();g.strokeStyle='#06070a';g.lineWidth=1.6;g.stroke();
  g.fillStyle='#04060a';g.beginPath();g.ellipse(vx,ve,.56*C,.14*C,0,0,7);g.fill();
  g.strokeStyle='rgba(180,230,255,.8)';g.lineWidth=1.4;
  g.beginPath();g.ellipse(vx,ve,.56*C,.14*C,0,Math.PI*.1,Math.PI*.9);g.stroke();
  const mp=g.createLinearGradient(0,ve,0,ve+1.5*C);
  mp.addColorStop(0,'rgba(220,245,255,.85)');mp.addColorStop(.4,'rgba(140,210,255,.35)');mp.addColorStop(1,'rgba(140,210,255,0)');
  g.fillStyle=mp;
  g.beginPath();g.moveTo(vx-.38*C,ve);g.lineTo(vx+.38*C,ve);g.lineTo(vx+.1*C,ve+1.55*C);g.lineTo(vx-.1*C,ve+1.55*C);g.closePath();g.fill();
}

/* --- сопло-колокол (шире юбки, как у референса) --- */
(function(){
  const throatW=1.75*C, exitW=4.2*C;
  const yT=py(27.0), yE=py(29.9);
  g.fillStyle='#15171b'; g.fillRect(cx-2.15*C,yT-4,4.3*C,8);
  g.strokeStyle=hsl(M.ORAN,6,.85); g.lineWidth=2.2;
  g.beginPath();g.moveTo(cx-2.1*C,yT-4);g.lineTo(cx+2.1*C,yT-4);g.stroke();
  const bell=()=>{
    g.beginPath();
    g.moveTo(cx-throatW,yT);
    g.quadraticCurveTo(cx-throatW-5, yT+(yE-yT)*.62, cx-exitW, yE);
    g.lineTo(cx+exitW,yE);
    g.quadraticCurveTo(cx+throatW+5, yT+(yE-yT)*.62, cx+throatW, yT);
    g.closePath();
  };
  bell();
  const bg=g.createLinearGradient(cx-exitW,0,cx+exitW,0);
  bg.addColorStop(0,'#0c0e11');bg.addColorStop(.18,'#3a3f47');bg.addColorStop(.34,'#14161a');
  bg.addColorStop(.5,'#454b54');bg.addColorStop(.66,'#14161a');bg.addColorStop(.82,'#333840');bg.addColorStop(1,'#0a0c0f');
  g.fillStyle=bg; g.fill();
  g.strokeStyle='#06070a'; g.lineWidth=2; g.stroke();
  g.save(); bell(); g.clip();
  for(const f of [.3,.58,.82]){
    const yy=yT+(yE-yT)*f;
    g.strokeStyle='rgba(0,0,0,.5)';g.lineWidth=2;
    g.beginPath();g.moveTo(cx-exitW,yy);g.lineTo(cx+exitW,yy);g.stroke();
    g.strokeStyle='rgba(255,255,255,.10)';g.lineWidth=1;
    g.beginPath();g.moveTo(cx-exitW,yy-2);g.lineTo(cx+exitW,yy-2);g.stroke();
  }
  const ug=g.createLinearGradient(0,yE-14,0,yE);
  ug.addColorStop(0,'rgba(140,215,255,0)');ug.addColorStop(1,'rgba(160,225,255,.5)');
  g.fillStyle=ug; g.fillRect(cx-exitW,yE-14,exitW*2,14);
  g.restore();
  g.fillStyle='#04060a';
  g.beginPath();g.ellipse(cx,yE,exitW*.97,.32*C,0,0,7);g.fill();
  g.save(); g.shadowColor='rgba(160,225,255,.95)'; g.shadowBlur=10;
  g.strokeStyle='rgba(190,235,255,.95)'; g.lineWidth=2.6;
  g.beginPath();g.ellipse(cx,yE,exitW*.97,.32*C,0,Math.PI*.06,Math.PI*.94);g.stroke();
  g.restore();
})();

/* --- главный факел --- */
(function(){
  const yE=py(29.9), pw=3.9*C, len=5.1*C;
  const pg=g.createLinearGradient(0,yE,0,yE+len);
  pg.addColorStop(0,'rgba(235,250,255,.95)');
  pg.addColorStop(.25,'rgba(170,225,255,.7)');
  pg.addColorStop(.6,'rgba(120,195,255,.28)');
  pg.addColorStop(1,'rgba(110,185,255,0)');
  g.fillStyle=pg;
  g.beginPath();
  g.moveTo(cx-pw,yE);
  g.quadraticCurveTo(cx-pw*.55,yE+len*.55,cx-pw*.22,yE+len);
  g.lineTo(cx+pw*.22,yE+len);
  g.quadraticCurveTo(cx+pw*.55,yE+len*.55,cx+pw,yE);
  g.closePath(); g.fill();
  const cg=g.createLinearGradient(0,yE,0,yE+len*.7);
  cg.addColorStop(0,'rgba(255,255,255,.95)');cg.addColorStop(1,'rgba(200,240,255,0)');
  g.fillStyle=cg;
  g.beginPath();
  g.moveTo(cx-pw*.42,yE);
  g.quadraticCurveTo(cx-pw*.18,yE+len*.4,cx,yE+len*.66);
  g.quadraticCurveTo(cx+pw*.18,yE+len*.4,cx+pw*.42,yE);
  g.closePath(); g.fill();
  g.fillStyle='rgba(230,247,255,.4)';
  g.beginPath();g.ellipse(cx,yE+1.6*C,.85*C,.36*C,0,0,7);g.fill();
  g.fillStyle='rgba(230,247,255,.26)';
  g.beginPath();g.ellipse(cx,yE+2.8*C,.55*C,.28*C,0,0,7);g.fill();
})();

/* --- контур корпуса --- */
hullPath(g); g.strokeStyle='#07090c'; g.lineWidth=2.4; g.stroke();

return {off, W, H, C, OX, OY, px, py, cx, span, ROWS, M, hsl};
})();
