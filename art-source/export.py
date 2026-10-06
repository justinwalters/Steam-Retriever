import sys,json,base64,os
from playwright.sync_api import sync_playwright
out=sys.argv[1]; os.makedirs(out,exist_ok=True)
with sync_playwright() as p:
    b=p.chromium.launch(); pg=b.new_page(viewport={'width':1100,'height':1100})
    pg.on('pageerror',lambda e:print('ERR',e))
    pg.goto('file://'+os.path.dirname(os.path.abspath(__file__))+'/bd.html'); pg.wait_for_timeout(500)
    names=pg.evaluate("Object.keys(PARTS)")
    table=[]
    for n in names:
        r=pg.evaluate("n=>renderPart(n)",n)
        open(f"{out}/{n}.png","wb").write(base64.b64decode(r['dataURL'].split(',')[1]))
        table.append((n,r['ox'],r['oy'],r['w'],r['h']))
    d=pg.evaluate("document.getElementById('o').toDataURL('image/jpeg',0.9)")
    open(f"{out}/backdrop.jpg","wb").write(base64.b64decode(d.split(',')[1]))
    pg.goto('file://'+os.path.dirname(os.path.abspath(__file__))+'/icon.html'); pg.wait_for_timeout(1200)
    d=pg.evaluate("document.getElementById('o').toDataURL('image/png')")
    open(f"{out}/icon1024.png","wb").write(base64.b64decode(d.split(',')[1]))
    b.close()
with open(f"{out}/table.txt","w") as f:
    for t in table: f.write("        \"%s\": Sprite(ox: %g, oy: %g, w: %g, h: %g),\n"%t)
print(len(table))
