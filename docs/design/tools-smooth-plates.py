# Черновик разметки «Ронина-1» v3 (мокап ronin-seams.html): из ronin-parts.js v2
# убирает язычок носа и одинарные шипы — клетку шириной в одну клетку отдаёт
# соседней плите с наибольшим контактом. Запуск: python3 tools-smooth-plates.py
# из docs/design/; печатает сетки секций и JSON масок (origin в клетках секции).
import re, json
src=open('ronin-parts.js').read()
secs={'prow':(10,6),'bridge':(21,6),'fwd':(36,16)}
parts=[]
for blk in src.split("{ id:")[1:]:
    if "layer:0" not in blk: continue
    pid=re.match(r"'(\w+)'",blk).group(1)
    m=re.search(r"section:'(\w+)', origin:\[(\d+),(\d+)\]",blk)
    mk=re.search(r"mask:\[(.*?)\]",blk,re.S)
    parts.append(dict(id=pid,sec=m.group(1),ox=int(m.group(2)),oy=int(m.group(3)),mask=re.findall(r"'([.#]+)'",mk.group(1))))
grids={}
for sec,(W,H) in secs.items():
    g=[[None]*W for _ in range(H)]
    for p in parts:
        if p['sec']!=sec: continue
        for r,l in enumerate(p['mask']):
            for c,ch in enumerate(l):
                if ch=='#': g[p['oy']+r][p['ox']+c]=p['id']
    grids[sec]=g
# 1. язычок носа -> убрать; дыру мостика под ним -> bridge_c
gp=grids['prow']
for r in (4,5):
    for c in range(10): gp[r][c]=None
gb=grids['bridge']
for r in range(6):
    for c in range(21):
        if gb[r][c] is None: gb[r][c]='bridge_c'
def nb(g,r,c):
    H=len(g);W=len(g[0])
    for dr,dc in ((0,1),(0,-1),(1,0),(-1,0)):
        rr,cc=r+dr,c+dc
        if 0<=rr<H and 0<=cc<W: yield rr,cc
def own(g,r,c):
    H=len(g);W=len(g[0])
    return g[r][c] if 0<=r<H and 0<=c<W else '#OUT'
def connected(g,pid):
    cells=[(r,c) for r in range(len(g)) for c in range(len(g[0])) if g[r][c]==pid]
    if not cells: return False
    seen={cells[0]};st=[cells[0]]
    while st:
        r,c=st.pop()
        for q in nb(g,r,c):
            if g[q[0]][q[1]]==pid and q not in seen: seen.add(q);st.append(q)
    return len(seen)==len(cells)
def thin(g,r,c):
    a=g[r][c]
    if a is None: return False
    h = own(g,r,c-1)!=a and own(g,r,c+1)!=a
    v = own(g,r-1,c)!=a and own(g,r+1,c)!=a
    # край корпуса не считаем шипом: сторона снаружи секции
    if h and (own(g,r,c-1)=='#OUT' or own(g,r,c+1)=='#OUT'): h=False
    if v and (own(g,r-1,c)=='#OUT' or own(g,r+1,c)=='#OUT'): v=False
    return h or v
for sec,g in grids.items():
    for it in range(30):
        changed=False
        for r in range(len(g)):
            for c in range(len(g[0])):
                if not thin(g,r,c): continue
                a=g[r][c]; cnt={}
                for q in nb(g,r,c):
                    b=g[q[0]][q[1]]
                    if b and b!=a: cnt[b]=cnt.get(b,0)+1
                if not cnt: continue
                b=max(cnt,key=cnt.get)
                g[r][c]=b
                if not connected(g,a): g[r][c]=a; continue
                changed=True
        if not changed: break
out={}
for p in parts:
    g=grids[p['sec']]
    cells=[(r,c) for r in range(len(g)) for c in range(len(g[0])) if g[r][c]==p['id']]
    r0=min(r for r,_ in cells);r1=max(r for r,_ in cells);c0=min(c for _,c in cells);c1=max(c for _,c in cells)
    mask=[''.join('#' if g[r][c]==p['id'] else '.' for c in range(c0,c1+1)) for r in range(r0,r1+1)]
    thinleft=sum(1 for r,c in cells if thin(g,r,c))
    out[p['id']]=dict(origin=[c0,r0],mask=mask,cells=len(cells))
    print(f"{p['id']:9} {len(cells):3} кл.  {c1-c0+1}×{r1-r0+1}  тонких={thinleft}")
for sec,g in grids.items():
    print(sec)
    for row in g: print(' '.join(f'{(x or ".").replace("bridge_","b").replace("fwd","")[:4]:>4}' for x in row))
print(json.dumps(out, ensure_ascii=False))
