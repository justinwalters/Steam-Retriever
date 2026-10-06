// ===== Steam Retriever art generator: painterly fur parts, brass steampunk gear =====
const S=3; // pixels per unit
function rng(seed){let a=seed>>>0;return()=>{a|=0;a=a+0x6D2B79F5|0;let t=Math.imul(a^a>>>15,1|a);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296;};}
function parse(d){const t=d.trim().split(/\s+/);const ops=[];let i=0;while(i<t.length){const o=t[i++];const n={M:2,L:2,C:6,Q:4,Z:0,E:4}[o];ops.push([o,...t.slice(i,i+n).map(Number)]);i+=n;}return ops;}
function trace(c,ops){c.beginPath();for(const p of ops){const o=p[0];
 if(o=='M')c.moveTo(p[1],p[2]);else if(o=='L')c.lineTo(p[1],p[2]);else if(o=='C')c.bezierCurveTo(p[1],p[2],p[3],p[4],p[5],p[6]);
 else if(o=='Q')c.quadraticCurveTo(p[1],p[2],p[3],p[4]);else if(o=='Z')c.closePath();
 else if(o=='E'){c.moveTo(p[1]+p[3],p[2]);c.ellipse(p[1],p[2],p[3],p[4],0,0,Math.PI*2);}}}
function flatten(ops){ // -> polyline (closed)
 const pts=[];let cx=0,cy=0,sx=0,sy=0;
 for(const p of ops){const o=p[0];
  if(o=='M'){cx=sx=p[1];cy=sy=p[2];pts.push([cx,cy]);}
  else if(o=='L'){cx=p[1];cy=p[2];pts.push([cx,cy]);}
  else if(o=='C'){for(let i=1;i<=24;i++){const t=i/24,u=1-t;pts.push([u*u*u*cx+3*u*u*t*p[1]+3*u*t*t*p[3]+t*t*t*p[5],u*u*u*cy+3*u*u*t*p[2]+3*u*t*t*p[4]+t*t*t*p[6]]);}cx=p[5];cy=p[6];}
  else if(o=='Q'){for(let i=1;i<=16;i++){const t=i/16,u=1-t;pts.push([u*u*cx+2*u*t*p[1]+t*t*p[3],u*u*cy+2*u*t*p[2]+t*t*p[4]]);}cx=p[3];cy=p[4];}
  else if(o=='E'){for(let i=0;i<64;i++){const a=i/64*Math.PI*2;pts.push([p[1]+Math.cos(a)*p[3],p[2]+Math.sin(a)*p[4]]);}}
 }
 return pts;}
function resample(pts,step){const out=[];let acc=0;out.push(pts[0]);for(let i=1;i<=pts.length;i++){let a=pts[i-1];const b=pts[i%pts.length];let d=Math.hypot(b[0]-a[0],b[1]-a[1]);while(acc+d>=step){const f=(step-acc)/d;const nx=a[0]+(b[0]-a[0])*f,ny=a[1]+(b[1]-a[1])*f;out.push([nx,ny]);a=[nx,ny];d=Math.hypot(b[0]-nx,b[1]-ny);acc=0;}acc+=d;}return out;}
function inPoly(pt,poly){let c=false;for(let i=0,j=poly.length-1;i<poly.length;j=i++){const a=poly[i],b=poly[j];if((a[1]>pt[1])!=(b[1]>pt[1])&&pt[0]<(b[0]-a[0])*(pt[1]-a[1])/(b[1]-a[1])+a[0])c=!c;}return c;}
function bbox(pts){let x0=1e9,y0=1e9,x1=-1e9,y1=-1e9;for(const p of pts){x0=Math.min(x0,p[0]);y0=Math.min(y0,p[1]);x1=Math.max(x1,p[0]);y1=Math.max(y1,p[1]);}return{x0,y0,x1,y1};}
function mix(a,b,t){const pa=hex(a),pb=hex(b);return `rgb(${Math.round(pa[0]+(pb[0]-pa[0])*t)},${Math.round(pa[1]+(pb[1]-pa[1])*t)},${Math.round(pa[2]+(pb[2]-pa[2])*t)})`;}
function hex(h){if(h[0]=='#'){h=h.slice(1);return[parseInt(h.slice(0,2),16),parseInt(h.slice(2,4),16),parseInt(h.slice(4,6),16)];}const m=h.match(/\d+/g);return[+m[0],+m[1],+m[2]];}

const FUR={ // palettes: light, base, shade, deep
 gold:{hi:'#FFE3A1',light:'#F9CD70',base:'#EAA43E',shade:'#C47A22',deep:'#8F5415',line:'rgba(104,52,10,.7)'},
 goldFar:{hi:'#D9A857',light:'#C98A34',base:'#AE6C21',shade:'#8E5518',deep:'#5F360C',line:'rgba(70,34,6,.8)'},
 cream:{hi:'#FFF3D0',light:'#FCE6B2',base:'#F3CF86',shade:'#D9A85A',deep:'#B2803A',line:'rgba(120,70,20,.55)'},
 ear:{hi:'#F0B65C',light:'#DE9B3E',base:'#C7822A',shade:'#9E5E1A',deep:'#6E3F0E',line:'rgba(80,38,6,.75)'},
};

// flow(x,y)->angle radians for fur strokes
function furFill(c,ops,pal,o){
 o=o||{};const R=rng(o.seed||7);
 const poly=flatten(ops);const bb=bbox(poly);
 const flow=o.flow||((x,y)=>Math.PI/2);
 // base
 trace(c,ops);
 const g=c.createLinearGradient(0,bb.y0,0,bb.y1);
 g.addColorStop(0,pal.light);g.addColorStop(.5,pal.base);g.addColorStop(1,pal.shade);
 c.fillStyle=g;c.fill();
 c.save();trace(c,ops);c.clip();
 c.filter='blur(0.4px)';
 const area=(bb.x1-bb.x0)*(bb.y1-bb.y0);
 const N=Math.floor(area*(o.density||1.5)*1.7);
 c.lineCap='round';
 for(let i=0;i<N;i++){
  const x=bb.x0+R()*(bb.x1-bb.x0),y=bb.y0+R()*(bb.y1-bb.y0);
  if(!inPoly([x,y],poly))continue;
  const ty=(y-bb.y0)/(bb.y1-bb.y0);
  const a=flow(x,y)+(R()-.5)*.7;
  const L=(o.len||7)*.62*(.5+R());
  const r=R();
  let col;
  if(r<.34)col=mix(pal.hi,pal.light,R());else if(r<.62)col=pal.base;else col=mix(pal.base,pal.shade,R()*.9+ty*.3);
  c.strokeStyle=col;c.globalAlpha=.10+R()*.2;c.lineWidth=.3+R()*.45;
  c.beginPath();c.moveTo(x,y);c.quadraticCurveTo(x+Math.cos(a+.3)*L*.5,y+Math.sin(a+.3)*L*.5,x+Math.cos(a)*L,y+Math.sin(a)*L);c.stroke();
 }
 c.globalAlpha=1;c.filter='none';
 // soft shading: bottom shade, top light
 const sh=c.createLinearGradient(0,bb.y0,0,bb.y1);
 sh.addColorStop(0,'rgba(255,240,190,.20)');sh.addColorStop(.35,'rgba(255,240,190,0)');sh.addColorStop(.7,'rgba(110,50,8,0)');sh.addColorStop(1,'rgba(110,50,8,.38)');
 c.fillStyle=sh;c.fillRect(bb.x0-2,bb.y0-2,bb.x1-bb.x0+4,bb.y1-bb.y0+4);
 if(o.shadeSide){ // darker toward one x side
  const sg=c.createLinearGradient(bb.x0,0,bb.x1,0);sg.addColorStop(0,o.shadeSide<0?'rgba(110,50,8,.28)':'rgba(110,50,8,0)');sg.addColorStop(1,o.shadeSide<0?'rgba(110,50,8,0)':'rgba(110,50,8,.28)');
  c.fillStyle=sg;c.fillRect(bb.x0-2,bb.y0-2,bb.x1-bb.x0+4,bb.y1-bb.y0+4);}
 c.restore();
 // outline
 if(o.outline!==false){trace(c,ops);c.strokeStyle=pal.line;c.lineWidth=o.lw||.9;c.lineJoin='round';c.stroke();}
 // edge tufts: small tapered clumps, drooping with gravity
 const edge=resample(poly,o.tuftStep||2.0);
 const tufts=o.tufts===undefined?.3:o.tufts;
 if(tufts>0){
  for(let i=0;i<edge.length;i++){
   if(R()>.8*tufts)continue;
   const p=edge[i],pa=edge[(i+edge.length-1)%edge.length],pb=edge[(i+1)%edge.length];
   let tx=pb[0]-pa[0],ty=pb[1]-pa[1];const tl=Math.hypot(tx,ty)||1;tx/=tl;ty/=tl;
   let nx=ty,ny=-tx; if(inPoly([p[0]+nx*1.2,p[1]+ny*1.2],poly)){nx=-nx;ny=-ny;}
   const gdir=o.tuftDir||[0,1],gw=o.gw===undefined?.55:o.gw;
   let dx=nx*(1-gw)+gdir[0]*gw+(R()-.5)*.5,dy=ny*(1-gw)+gdir[1]*gw+(R()-.5)*.5;const dl=Math.hypot(dx,dy)||1;dx/=dl;dy/=dl;
   const L=(o.tuftLen||2.4)*.62*(.5+R()*.8);
   const bw=.55+R()*.4;
   const bx=p[0]-nx*1.5,by=p[1]-ny*1.5;
   const ex=p[0]+dx*L,ey=p[1]+dy*L;
   const r=R();c.fillStyle=r<.45?pal.base:(r<.75?pal.light:pal.shade);
   c.beginPath();c.moveTo(bx-tx*bw,by-ty*bw);c.quadraticCurveTo((bx+ex)/2-tx*bw*.5+nx*.5,(by+ey)/2-ty*bw*.5+ny*.5,ex,ey);c.quadraticCurveTo((bx+ex)/2+tx*bw*.6+nx*.5,(by+ey)/2+ty*bw*.6+ny*.5,bx+tx*bw,by+ty*bw);c.closePath();c.fill();
  }
 }
}

// brass helpers
function brassGrad(c,x0,y0,x1,y1){const g=c.createLinearGradient(x0,y0,x1,y1);g.addColorStop(0,'#FFE5A0');g.addColorStop(.25,'#E8B04A');g.addColorStop(.55,'#B8791F');g.addColorStop(.8,'#8A5512');g.addColorStop(1,'#D4973A');return g;}
function rivet(c,x,y,r){const g=c.createRadialGradient(x-r*.3,y-r*.3,0,x,y,r);g.addColorStop(0,'#FFF0B8');g.addColorStop(1,'#8A5512');c.fillStyle=g;c.beginPath();c.arc(x,y,r,0,7);c.fill();c.strokeStyle='rgba(50,25,4,.6)';c.lineWidth=.3;c.stroke();}
function gearPath(c,cx,cy,r,teeth,depth){c.beginPath();const n=teeth*2;for(let i=0;i<n;i++){const a=i/n*Math.PI*2;const rr=(i%2==0)?r:r-depth;const a2=a+Math.PI/n*.5;c.lineTo(cx+Math.cos(a-Math.PI/n*.5)*rr,cy+Math.sin(a-Math.PI/n*.5)*rr);c.lineTo(cx+Math.cos(a2)*rr,cy+Math.sin(a2)*rr);}c.closePath();}
function leather(c,x0,y0,x1,y1){const g=c.createLinearGradient(x0,y0,x1,y1);g.addColorStop(0,'#6B4226');g.addColorStop(.5,'#4A2B15');g.addColorStop(1,'#2E1A0C');return g;}

// ===== parts =====
const PARTS={}; // name -> {box:[x0,y0,x1,y1], draw(c)}
function part(name,box,draw){PARTS[name]={box,draw};}
const M=10;
function legUp(name,pal,ops,seed){part(name,[-16,-8,16,18],c=>furFill(c,parse(ops),pal,{seed,flow:()=>Math.PI/2,len:6,tuftLen:4,tufts:.7,density:1.8,outline:false}));}
function legLow(name,pal,seed){
 const ops="M -6.5 -1 L -6.5 6 C -11 8.5 -11.5 14 -9.5 17 C -7 19.5 -2 19.5 0 19.5 C 3 19.5 8 19.5 10 17 C 12 14 11.5 8.5 6.5 6 L 6.5 -1 Z";
 part(name,[-18,-6,18,26],c=>{furFill(c,parse(ops),pal,{seed,flow:()=>Math.PI/2,len:5,tuftLen:3.5,tufts:.8,density:2,outline:false});
  c.strokeStyle='rgba(70,32,4,.65)';c.lineWidth=.8;c.lineCap='round';c.beginPath();c.moveTo(-3,19);c.lineTo(-3,14.5);c.moveTo(2.5,19.2);c.lineTo(2.5,14.5);c.stroke();});}
const FUP="M -8 -2 C -10 4 -9 9 -8 12 L 8 12 C 9 9 10 4 8 -2 C 5 -5 -5 -5 -8 -2 Z";
const HUP="M -11 -2 C -16 5 -14 13 -9 16 L 9 16 C 11 12 12 5 8 -2 C 4 -6 -6 -6 -11 -2 Z";
legUp('front_up',FUR.gold,FUP,11);legUp('front_up_far',FUR.goldFar,FUP,12);
legUp('hind_up',FUR.gold,HUP,13);legUp('hind_up_far',FUR.goldFar,HUP,14);
legLow('front_low',FUR.gold,15);legLow('front_low_far',FUR.goldFar,16);
legLow('hind_low',FUR.gold,17);legLow('hind_low_far',FUR.goldFar,18);

part('body',[-56,-76,52,-4],c=>{
 const b=parse("M -40 -38 C -42 -52 -26 -58 -8 -57 C 10 -57 28 -54 33 -40 C 37 -27 26 -14 6 -14 C -14 -13 -30 -14 -36 -21 C -41 -26 -40 -33 -40 -38 Z");
 furFill(c,b,FUR.gold,{seed:21,flow:(x,y)=>Math.PI*.5-(x>0?.5:-.1)+(x<-10?-.4:0),len:9,tuftLen:5,density:1.6,tuftDir:[0,.9]});
 const ch=parse("M 18 -50 C 31 -44 37 -31 30 -20 C 25 -14 14 -12 6 -14 C 16 -20 22 -34 18 -50 Z");
 furFill(c,ch,FUR.cream,{seed:22,flow:()=>Math.PI*.55,len:8,tuftLen:4,tufts:.7,density:2,outline:false,tuftDir:[0,1],tuftStep:2});
 // soft top rim light
 c.strokeStyle='rgba(255,236,170,.55)';c.lineWidth=1.6;c.lineCap='round';c.beginPath();c.moveTo(-28,-52);c.bezierCurveTo(-14,-57,6,-57,22,-52);c.stroke();
});
part('haunch',[-34,-30,34,30],c=>furFill(c,parse("E 0 0 21 19"),FUR.gold,{seed:31,flow:()=>Math.PI*.6,len:8,tuftLen:5,density:1.7}));
part('hpaw',[-24,-12,24,12],c=>furFill(c,parse("E 0 0 14 6.2"),FUR.gold,{seed:32,flow:()=>0,len:5,tuftLen:3,density:2.2}));
part('tail',[-60,-56,16,16],c=>{
 const t=parse("M 0 4 C -14 6 -30 -4 -36 -22 C -39 -34 -32 -44 -27 -38 C -24 -34 -26 -28 -22 -24 C -18 -16 -8 -10 6 -6 Z");
 furFill(c,t,FUR.gold,{seed:41,flow:(x,y)=>Math.atan2(-(y+4),x-4)+Math.PI,len:9,tuftLen:4.5,tufts:.55,tuftStep:1.9,density:1.8,tuftDir:[-.2,.8]});
});
// head
const HEAD="M -10 -12 C -17 -24 -9 -43 11 -49 C 29 -53 41 -46 44 -36 C 51 -36 54 -27 53 -17 C 52 -7 45 1 37 2 C 30 3 25 1 21 1 C 12 5 -3 4 -10 -12 Z";
part('head',[-28,-70,76,16],c=>{
 furFill(c,parse(HEAD),FUR.gold,{seed:51,flow:(x,y)=>x>30?0.1:Math.atan2(y+22,x-8)+Math.PI/2*0.2,len:7,tuftLen:5,density:2});
 // muzzle lighter
 furFill(c,parse("M 28 -24 C 33 -34 49 -35 53 -24 C 55 -13 49 -3 39 1 C 32 3 25 -4 28 -24 Z"),FUR.cream,{seed:52,flow:()=>0.15,len:5,density:2.4,outline:false,tuftLen:3,tuftStep:2.6,tufts:.5});
 // forehead blaze highlight
 c.save();trace(c,parse(HEAD));c.clip();const rg=c.createRadialGradient(14,-42,1,14,-40,22);rg.addColorStop(0,'rgba(255,238,180,.5)');rg.addColorStop(1,'rgba(255,238,180,0)');c.fillStyle=rg;c.fillRect(-30,-70,100,90);c.restore();
 // brow tufts
 c.fillStyle='rgba(255,236,170,.9)';c.beginPath();c.ellipse(22,-39.5,4.2,2.2,-.18,0,7);c.fill();c.beginPath();c.ellipse(37,-38.5,3.2,1.8,-.1,0,7);c.fill();
 // nose
 const ng=c.createRadialGradient(49,-26,.5,51,-23,8);ng.addColorStop(0,'#5a4036');ng.addColorStop(.35,'#241510');ng.addColorStop(1,'#120a07');
 c.fillStyle=ng;c.beginPath();c.ellipse(51,-22.5,5.4,4.5,.25,0,7);c.fill();
 c.fillStyle='rgba(255,255,255,.7)';c.beginPath();c.ellipse(49.6,-24.5,2.1,1.1,-.45,0,7);c.fill();
 // mouth
 c.strokeStyle='rgba(60,25,10,.85)';c.lineWidth=1.1;c.lineCap='round';c.beginPath();c.moveTo(51,-18);c.quadraticCurveTo(50,-9,43,-7);c.quadraticCurveTo(36,-5.5,30,-9);c.stroke();
 // whisker dots
 c.fillStyle='rgba(80,35,10,.55)';for(const[ x,y]of[[44,-14],[40,-15],[46,-10],[38,-11]]){c.beginPath();c.arc(x,y,.55,0,7);c.fill();}
 // cheek blush
 c.fillStyle='rgba(240,110,100,.28)';c.beginPath();c.ellipse(29,-10,5,3,0,0,7);c.fill();
});
part('ear',[-34,-8,26,60],c=>furFill(c,parse("M -2 -2 C -12 -2 -20 10 -19 24 C -18 38 -8 47 1 44 C 11 41 14 26 13 12 C 12 3 8 -2 -2 -2 Z"),FUR.ear,{seed:61,flow:()=>Math.PI*.5,len:9,tuftLen:4.5,tufts:.55,tuftStep:1.9,density:1.9,tuftDir:[0,1]}));
part('ear_far',[-34,-8,26,60],c=>furFill(c,parse("M -2 -2 C -11 -2 -17 9 -16 22 C -15 34 -7 42 1 40 C 9 37 12 24 11 12 C 10 4 7 -2 -2 -2 Z"),{hi:'#B87A2E',light:'#9E6420',base:'#85501A',shade:'#68390F',deep:'#40220A',line:'rgba(40,18,4,.85)'},{seed:62,flow:()=>Math.PI*.5,len:8,tuftLen:6,density:1.7}));
part('jaw',[-8,-16,56,22],c=>{
 c.fillStyle='#4A1820';c.beginPath();c.moveTo(2,-5);c.lineTo(44,-9);c.bezierCurveTo(42,0,22,4,6,0);c.closePath();c.fill();
 furFill(c,parse("M 0 -3 C 4 7 20 11 34 8 C 43 6 45 -3 41 -8 L 0 -6 Z"),FUR.cream,{seed:71,flow:()=>0,len:5,density:2,tuftLen:3,tufts:.6,lw:.8});});
part('tongue',[-14,-4,14,26],c=>{
 const g=c.createLinearGradient(0,0,0,18);g.addColorStop(0,'#F37A8C');g.addColorStop(1,'#E4566E');
 c.fillStyle=g;trace(c,parse("M -7 0 C -9 10 -6 18 0 18 C 6 18 9 10 7 0 Z"));c.fill();c.strokeStyle='rgba(120,30,50,.6)';c.lineWidth=.7;c.stroke();
 c.strokeStyle='rgba(150,40,60,.55)';c.beginPath();c.moveTo(0,2);c.lineTo(0,13);c.stroke();});
// steampunk gear
part('goggles',[-30,-22,40,22],c=>{
 // strap (leather) running back
 c.fillStyle=leather(c,0,-7,0,7);c.beginPath();c.moveTo(-28,-4);c.lineTo(-8,-6);c.lineTo(-8,6);c.lineTo(-28,5);c.closePath();c.fill();
 c.strokeStyle='rgba(210,160,90,.5)';c.lineWidth=.5;c.setLineDash([1.4,1.2]);c.beginPath();c.moveTo(-27,-2.5);c.lineTo(-9,-4);c.moveTo(-27,3);c.lineTo(-9,4);c.stroke();c.setLineDash([]);
 // far lens
 function lens(cx,cy,r,rot){c.save();c.translate(cx,cy);c.rotate(rot);
  c.fillStyle=brassGrad(c,-r,-r,r,r);c.beginPath();c.arc(0,0,r+2.2,0,7);c.fill();c.strokeStyle='rgba(50,25,4,.8)';c.lineWidth=.6;c.stroke();
  const g=c.createRadialGradient(-r*.3,-r*.3,0,0,0,r);g.addColorStop(0,'#BFFCF1');g.addColorStop(.45,'#35B8B4');g.addColorStop(1,'#0B4C5A');
  c.fillStyle=g;c.beginPath();c.arc(0,0,r,0,7);c.fill();
  c.strokeStyle='rgba(20,10,2,.6)';c.lineWidth=.5;c.stroke();
  c.fillStyle='rgba(255,255,255,.65)';c.beginPath();c.ellipse(-r*.38,-r*.42,r*.34,r*.18,-.7,0,7);c.fill();
  for(let i=0;i<8;i++){const a=i/8*7;rivet(c,Math.cos(a)*(r+1.2),Math.sin(a)*(r+1.2),.5);}
  c.restore();}
 lens(21,-1,6.6,.15);lens(0,0,8.6,0);
 c.fillStyle=brassGrad(c,6,-2,16,2);c.fillRect(8.5,-2.2,6,3.4);
});
part('collar',[-16,-8,26,26],c=>{
 c.fillStyle=leather(c,0,0,0,18);trace(c,parse("M -4 -4 C 8 -2 14 8 13 20 L 3 20 C 4 10 0 4 -9 3 Z"));c.fill();
 c.strokeStyle='rgba(0,0,0,.55)';c.lineWidth=.6;c.stroke();
 c.strokeStyle='rgba(230,180,100,.55)';c.lineWidth=.45;c.setLineDash([1.2,1.1]);c.beginPath();c.moveTo(-5,0);c.bezierCurveTo(6,1,10,8,9.5,19);c.stroke();c.setLineDash([]);
 c.fillStyle=brassGrad(c,2,6,10,14);c.fillRect(3.6,8,6.4,6);c.strokeStyle='rgba(40,20,4,.8)';c.lineWidth=.5;c.strokeRect(3.6,8,6.4,6);c.fillStyle='#2a160a';c.fillRect(5.6,10,2.4,2.2);
 rivet(c,1.5,3,.8);rivet(c,9.5,19,.8);
});
part('gear',[-9,-9,9,9],c=>{
 gearPath(c,0,0,7.6,9,1.9);c.fillStyle=brassGrad(c,-7,-7,7,7);c.fill();c.strokeStyle='rgba(50,25,4,.85)';c.lineWidth=.55;c.stroke();
 c.fillStyle='#4a2c0c';c.beginPath();c.arc(0,0,3.1,0,7);c.fill();
 const g=c.createRadialGradient(0,0,0,0,0,2.7);g.addColorStop(0,'#FFFBD0');g.addColorStop(.5,'#FFC552');g.addColorStop(1,'#E8822A');c.fillStyle=g;c.beginPath();c.arc(0,0,2.5,0,7);c.fill();
});
part('pack',[-30,-34,30,18],c=>{
 // chimney & pipe
 c.fillStyle=brassGrad(c,-10,-30,-4,-30);c.fillRect(-11,-30,6,16);c.strokeStyle='rgba(40,20,4,.8)';c.lineWidth=.5;c.strokeRect(-11,-30,6,16);
 c.fillStyle='#3a2a1c';c.fillRect(-12.5,-32,9,3.4);
 // tank
 const tg=c.createLinearGradient(0,-16,0,12);tg.addColorStop(0,'#F0C060');tg.addColorStop(.3,'#C4882C');tg.addColorStop(.7,'#8E5A16');tg.addColorStop(1,'#5C3608');
 c.fillStyle=tg;trace(c,parse("M -22 -4 C -22 -14 -14 -17 0 -17 C 14 -17 22 -14 22 -4 C 22 6 14 11 0 11 C -14 11 -22 6 -22 -4 Z"));c.fill();c.strokeStyle='rgba(40,20,4,.85)';c.lineWidth=.7;c.stroke();
 c.strokeStyle='rgba(40,20,4,.6)';c.lineWidth=.7;for(const x of[-10,10]){c.beginPath();c.moveTo(x,-16.5);c.lineTo(x,10.5);c.stroke();}
 for(const x of[-10,10])for(const y of[-12,-4,4])rivet(c,x+(x<0?-2.4:2.4),y,.6);
 // highlight
 c.strokeStyle='rgba(255,240,180,.55)';c.lineWidth=1.2;c.lineCap='round';c.beginPath();c.moveTo(-16,-13);c.quadraticCurveTo(0,-16,16,-13);c.stroke();
 // gauge
 c.fillStyle=brassGrad(c,-5,-6,5,6);c.beginPath();c.arc(1,-3,6,0,7);c.fill();c.strokeStyle='rgba(40,20,4,.9)';c.lineWidth=.5;c.stroke();
 c.fillStyle='#F6EBD0';c.beginPath();c.arc(1,-3,4.6,0,7);c.fill();
 c.strokeStyle='#8a1f1a';c.lineWidth=.8;c.beginPath();c.moveTo(1,-3);c.lineTo(3.6,-5.2);c.stroke();c.fillStyle='#222';c.beginPath();c.arc(1,-3,.8,0,7);c.fill();
 // enamel pins
 c.fillStyle='#ff5a6e';c.beginPath();c.arc(-15,5,2.1,0,7);c.arc(-12,5,2.1,0,7);c.fill();c.beginPath();c.moveTo(-17.6,6);c.lineTo(-13.5,10);c.lineTo(-9.4,6);c.fill();
 c.fillStyle='#ffd34a';gearPath(c,14,5,3.2,5,1.4);c.fill();
 // strap down the side
 c.fillStyle=leather(c,0,8,0,18);c.beginPath();c.moveTo(-6,9);c.lineTo(4,9);c.lineTo(5,18);c.lineTo(-7,18);c.closePath();c.fill();
});
part('ball',[-12,-12,12,12],c=>{
 const g=c.createRadialGradient(-3,-4,1,0,0,10);g.addColorStop(0,'#FFE7A8');g.addColorStop(.35,'#D9923A');g.addColorStop(1,'#6B3A0E');
 c.fillStyle=g;c.beginPath();c.arc(0,0,8.5,0,7);c.fill();c.strokeStyle='rgba(40,20,4,.8)';c.lineWidth=.6;c.stroke();
 c.strokeStyle='rgba(60,30,6,.75)';c.lineWidth=.6;c.beginPath();c.ellipse(0,0,8.5,3.2,.5,0,7);c.stroke();c.beginPath();c.ellipse(0,0,3.2,8.5,.5,0,7);c.stroke();
 rivet(c,-5.5,-1.5,.7);rivet(c,5,3,.7);rivet(c,1,-6.2,.7);
 const t=c.createRadialGradient(0,0,0,0,0,3.2);t.addColorStop(0,'#BFFCF1');t.addColorStop(1,'#1C8C93');c.fillStyle=t;c.beginPath();c.arc(.8,.8,1.8,0,7);c.fill();
});
part('bone',[-18,-9,18,9],c=>{
 const g=c.createLinearGradient(0,-7,0,7);g.addColorStop(0,'#FFF6DE');g.addColorStop(1,'#D9BE88');
 c.fillStyle=g;trace(c,parse("M -10 -3 C -12 -8 -17 -6 -16 -2 C -19 0 -17 6 -13 5 C -12 8 -7 7 -8 3 L 8 3 C 7 7 12 8 13 5 C 17 6 19 0 16 -2 C 17 -6 12 -8 10 -3 Z"));c.fill();
 c.strokeStyle='rgba(120,80,30,.8)';c.lineWidth=.6;c.stroke();});
part('bfly',[-14,-12,14,12],c=>{
 function wing(sx){c.save();c.scale(sx,1);const g=c.createLinearGradient(0,-10,10,6);g.addColorStop(0,'#7FF0E0');g.addColorStop(1,'#1D8F9C');
  c.fillStyle=g;c.globalAlpha=.88;trace(c,parse("M 1 -1 C 4 -11 12 -12 12 -6 C 12 -2 7 0 1 0 Z"));c.fill();trace(c,parse("M 1 0 C 7 1 11 5 8 9 C 5 11 1 7 1 1 Z"));c.fill();c.globalAlpha=1;
  c.strokeStyle='rgba(30,70,70,.85)';c.lineWidth=.5;trace(c,parse("M 1 -1 C 4 -11 12 -12 12 -6 C 12 -2 7 0 1 0 Z"));c.stroke();trace(c,parse("M 1 0 C 7 1 11 5 8 9 C 5 11 1 7 1 1 Z"));c.stroke();
  gearPath(c,7,-5,2.6,6,.8);c.fillStyle='rgba(255,215,120,.95)';c.fill();c.restore();}
 wing(1);wing(-1);
 c.fillStyle=brassGrad(c,-1,-5,1,6);c.beginPath();c.ellipse(0,0,1.4,6,0,0,7);c.fill();
 c.strokeStyle='#8A5512';c.lineWidth=.5;c.beginPath();c.moveTo(0,-5);c.quadraticCurveTo(-2,-9,-4,-9);c.moveTo(0,-5);c.quadraticCurveTo(2,-9,4,-9);c.stroke();
});


part('wrist',[-11,-9,11,9],c=>{
 c.fillStyle='#6B4226';trace(c,parse('M -8.5 -6 C -8.5 -8 8.5 -8 8.5 -6 L 8.5 6 C 8.5 8 -8.5 8 -8.5 6 Z'));c.fill();
 c.strokeStyle='rgba(230,180,100,.5)';c.lineWidth=.4;c.setLineDash([1,1]);c.beginPath();c.moveTo(-9,-5.5);c.lineTo(9,-5.5);c.moveTo(-9,5.5);c.lineTo(9,5.5);c.stroke();c.setLineDash([]);
 const bg=c.createLinearGradient(-8,-6,8,6);bg.addColorStop(0,'#8E8C5A');bg.addColorStop(.5,'#5E6038');bg.addColorStop(1,'#3A3C22');
 c.fillStyle=bg;trace(c,parse("M -8 -5 C -8 -7 8 -7 8 -5 L 8 5 C 8 7 -8 7 -8 5 Z"));c.fill();c.strokeStyle='rgba(15,18,6,.9)';c.lineWidth=.6;c.stroke();
 const sg=c.createRadialGradient(-1,-1,0,0,0,7);sg.addColorStop(0,'#9BFFC0');sg.addColorStop(.6,'#1EE08A');sg.addColorStop(1,'#0B6B42');
 c.fillStyle=sg;trace(c,parse("M -6 -3.6 C -6 -4.8 4 -4.8 4 -3.6 L 4 3.6 C 4 4.8 -6 4.8 -6 3.6 Z"));c.fill();c.strokeStyle='rgba(5,40,20,.9)';c.lineWidth=.4;c.stroke();
 c.fillStyle='rgba(4,70,40,.75)';for(const[x,y]of[[-3,-1.6],[-1,-1.6],[-4,-.6],[0,-.6],[-3,.4],[-1,.4],[-2,1.4]]){c.fillRect(x-.5,y-.5,1,1);}
 c.strokeStyle='rgba(0,60,30,.35)';c.lineWidth=.3;for(let y=-3.4;y<4;y+=1.1){c.beginPath();c.moveTo(-6,y);c.lineTo(4,y);c.stroke();}
 c.fillStyle='rgba(255,255,255,.4)';c.beginPath();c.ellipse(-3.5,-3,2,.8,-.3,0,7);c.fill();
 rivet(c,6.3,-2.5,.9);rivet(c,6.3,2.5,.9);
});
part('badge',[-14,-4,16,44],c=>{
 c.fillStyle='#17828F';c.beginPath();c.moveTo(-9,-3);c.lineTo(-5,-3);c.lineTo(2,22);c.lineTo(-1,22);c.closePath();c.fill();
 c.beginPath();c.moveTo(12,-3);c.lineTo(8,-3);c.lineTo(1,22);c.lineTo(4,22);c.closePath();c.fill();
 c.fillStyle='rgba(255,255,255,.75)';for(const[x,y]of[[-5,3],[-2,12],[9,3],[5,12]]){c.beginPath();c.arc(x,y,.7,0,7);c.fill();}
 c.fillStyle=brassGrad(c,-2,20,5,25);c.fillRect(-1.2,21,4.8,3.4);
 c.fillStyle='#F4EEDC';trace(c,parse("M -6 24 L 8 24 L 8 40 C 8 41.5 6.5 42 5 42 L -3 42 C -5 42 -6 41.5 -6 40 Z"));c.fill();c.strokeStyle='rgba(60,40,20,.7)';c.lineWidth=.5;c.stroke();
 c.fillStyle='#E8662A';c.fillRect(-6,26,14,5);c.fillStyle='#fff';c.fillRect(-4,27.4,2,1.8);c.fillRect(-1,27.4,2,1.8);c.fillRect(2,27.4,2,1.8);c.fillRect(5,27.4,1.4,1.8);
 c.fillStyle='#E34B63';for(const[x,y]of[[-2,34],[0,34],[2,34],[-3,35],[-2,35],[-1,35],[0,35],[1,35],[2,35],[3,35],[-2,36],[-1,36],[0,36],[1,36],[2,36],[-1,37],[0,37],[1,37],[0,38]]){c.fillRect(x+.4-.5,y-.5,1,1);}
 c.fillStyle='rgba(60,40,20,.6)';c.fillRect(-4.5,39.6,9,.6);
});
part('cap',[-8,-8,8,8],c=>{
 c.fillStyle=brassGrad(c,-6,-6,6,6);c.beginPath();for(let i=0;i<24;i++){const a=i/24*Math.PI*2;const r=i%2?5.1:5.9;c.lineTo(Math.cos(a)*r,Math.sin(a)*r);}c.closePath();c.fill();c.strokeStyle='rgba(40,20,4,.8)';c.lineWidth=.5;c.stroke();
 const g=c.createRadialGradient(-1,-1,0,0,0,4);g.addColorStop(0,'#FF8A8A');g.addColorStop(1,'#B21F2B');c.fillStyle=g;c.beginPath();c.arc(0,0,3.9,0,7);c.fill();
 c.fillStyle='#fff';c.fillRect(-.7,-2.6,1.4,5.2);c.fillRect(-2.6,-.7,5.2,1.4);
});
part('pad',[-18,-11,18,11],c=>{
 const bg=c.createLinearGradient(0,-8,0,9);bg.addColorStop(0,'#5A4A3A');bg.addColorStop(1,'#2A2018');
 c.fillStyle=bg;trace(c,parse("M -14 -3 C -14 -9 -8 -9 -5 -8 L 5 -8 C 8 -9 14 -9 14 -3 C 15 3 14 9 10 9 C 7 9 6 5 3 4 L -3 4 C -6 5 -7 9 -10 9 C -14 9 -15 3 -14 -3 Z"));c.fill();c.strokeStyle='rgba(15,8,2,.9)';c.lineWidth=.7;c.stroke();
 c.fillStyle=brassGrad(c,-14,-8,-6,0);c.fillRect(-10.5,-3.4,6,1.8);c.fillRect(-8.4,-5.6,1.8,6.2);
 c.fillStyle='#E34B5A';c.beginPath();c.arc(8.5,-2.5,2,0,7);c.fill();c.fillStyle='#31C3C0';c.beginPath();c.arc(5,.2,2,0,7);c.fill();
 c.fillStyle='rgba(255,255,255,.4)';c.beginPath();c.arc(8,-3.2,.7,0,7);c.fill();c.beginPath();c.arc(4.5,-.5,.7,0,7);c.fill();
 rivet(c,-12,5,.8);rivet(c,12,5,.8);
});

function renderPart(name){
 const P=PARTS[name];const [x0,y0,x1,y1]=P.box;
 const cv=document.createElement('canvas');cv.width=Math.ceil((x1-x0)*S);cv.height=Math.ceil((y1-y0)*S);
 const c=cv.getContext('2d');c.scale(S,S);c.translate(-x0,-y0);P.draw(c);
 return{dataURL:cv.toDataURL('image/png'),ox:x0,oy:y0,w:x1-x0,h:y1-y0};
}
window.renderPart=renderPart;window.PARTS=PARTS;
