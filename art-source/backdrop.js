function drawBackdrop(c,W,H){
 const R=rng(99);const hz=H*0.5;
 // sky
 let g=c.createLinearGradient(0,0,0,hz);g.addColorStop(0,'#050813');g.addColorStop(.55,'#0E1730');g.addColorStop(.85,'#1B3150');g.addColorStop(1,'#2C5667');
 c.fillStyle=g;c.fillRect(0,0,W,hz+2);
 for(let i=0;i<220;i++){const x=R()*W,y=R()*hz*.8;c.fillStyle=`rgba(200,225,255,${.15+R()*.5})`;c.beginPath();c.arc(x,y,.5+R()*1.1,0,7);c.fill();}
 // gear moon
 const mx=W*.78,my=H*.2,mr=H*.17;
 let rg=c.createRadialGradient(mx,my,mr*.3,mx,my,mr*2.4);rg.addColorStop(0,'rgba(255,200,110,.28)');rg.addColorStop(1,'rgba(255,200,110,0)');c.fillStyle=rg;c.fillRect(mx-mr*3,my-mr*3,mr*6,mr*6);
 c.save();c.translate(mx,my);gearPath(c,0,0,mr,22,mr*.12);c.fillStyle='rgba(200,150,70,.22)';c.fill();c.strokeStyle='rgba(255,205,120,.35)';c.lineWidth=3;c.stroke();
 c.beginPath();c.arc(0,0,mr*.72,0,7);c.strokeStyle='rgba(255,205,120,.3)';c.lineWidth=2;c.stroke();
 for(let i=0;i<12;i++){const a=i/12*Math.PI*2;c.beginPath();c.moveTo(Math.cos(a)*mr*.62,Math.sin(a)*mr*.62);c.lineTo(Math.cos(a)*mr*.7,Math.sin(a)*mr*.7);c.stroke();}
 c.beginPath();c.moveTo(0,0);c.lineTo(0,-mr*.5);c.moveTo(0,0);c.lineTo(mr*.34,mr*.12);c.lineWidth=4;c.strokeStyle='rgba(255,215,140,.45)';c.stroke();c.restore();
 // far skyline layers
 function skyline(base,col,hmin,hmax,seed,windows){const r=rng(seed);c.fillStyle=col;let x=-20;while(x<W+20){const w=40+r()*90,h=hmin+r()*(hmax-hmin);c.fillRect(x,base-h,w,h+4);
   if(r()<.35){c.beginPath();c.moveTo(x,base-h);c.quadraticCurveTo(x+w/2,base-h-30-r()*30,x+w,base-h);c.fill();}
   if(r()<.3){c.fillRect(x+w*.6,base-h-30-r()*40,6,40);}
   if(windows){for(let k=0;k<w/14;k++)for(let j=0;j<h/20;j++)if(r()<.12){c.fillStyle='rgba(255,196,100,.7)';c.fillRect(x+6+k*14,base-h+8+j*20,4,6);c.fillStyle=col;}}
   x+=w+r()*8;}}
 skyline(hz+6,'#14243C',60,150,5,false);
 // clock tower
 c.fillStyle='#0E1A2E';c.fillRect(W*.26,hz-250,70,260);c.beginPath();c.moveTo(W*.26-8,hz-250);c.lineTo(W*.26+35,hz-320);c.lineTo(W*.26+78,hz-250);c.fill();
 c.beginPath();c.arc(W*.26+35,hz-205,22,0,7);c.fillStyle='rgba(255,205,120,.85)';c.fill();c.strokeStyle='#0E1A2E';c.lineWidth=2;c.beginPath();c.moveTo(W*.26+35,hz-205);c.lineTo(W*.26+35,hz-220);c.moveTo(W*.26+35,hz-205);c.lineTo(W*.26+46,hz-200);c.stroke();
 skyline(hz+8,'#0B1527',40,110,6,true);
 // airship
 c.save();c.translate(W*.12,H*.17);c.fillStyle='#16233A';c.beginPath();c.ellipse(0,0,95,32,-.05,0,7);c.fill();c.fillRect(-26,30,52,12);
 c.strokeStyle='rgba(255,196,100,.5)';c.lineWidth=2;c.beginPath();c.ellipse(0,0,95,32,-.05,0,7);c.stroke();
 for(let i=-3;i<=3;i++){c.fillStyle='rgba(255,196,100,.8)';c.fillRect(i*14-2,34,4,5);}c.restore();
 // chimney steam
 for(let i=0;i<6;i++){const x=W*(.1+i*.17)+R()*40,y=hz-40-R()*30;for(let k=0;k<7;k++){const rr=22+k*13;const gg=c.createRadialGradient(x+k*10,y-k*34,0,x+k*10,y-k*34,rr);gg.addColorStop(0,`rgba(190,215,235,${.09-k*.01})`);gg.addColorStop(1,'rgba(190,215,235,0)');c.fillStyle=gg;c.fillRect(x+k*10-rr,y-k*34-rr,rr*2,rr*2);}}
 // horizon glow
 let hg=c.createLinearGradient(0,hz-90,0,hz+40);hg.addColorStop(0,'rgba(80,170,180,0)');hg.addColorStop(.7,'rgba(90,190,190,.25)');hg.addColorStop(1,'rgba(90,190,190,0)');c.fillStyle=hg;c.fillRect(0,hz-90,W,130);
 // ground
 g=c.createLinearGradient(0,hz,0,H);g.addColorStop(0,'#1B3A3C');g.addColorStop(.35,'#14292C');g.addColorStop(1,'#08151A');c.fillStyle=g;c.fillRect(0,hz,W,H-hz);
 // lawn strokes (perspective: denser/smaller far)
 for(let i=0;i<5200;i++){const u=Math.pow(R(),1.7);const y=hz+u*(H-hz);const sc=.25+u*1.4;const x=R()*W;const len=(5+R()*10)*sc;
  c.strokeStyle=`rgba(${40+R()*40|0},${95+R()*70|0},${80+R()*40|0},${.10+R()*.22})`;c.lineWidth=.6+sc*.9;c.beginPath();c.moveTo(x,y);c.lineTo(x+(R()-.5)*len*.6,y-len);c.stroke();}
 // brick path converging to horizon
 c.save();c.beginPath();c.moveTo(W*.46,hz);c.lineTo(W*.54,hz);c.lineTo(W*.86,H);c.lineTo(W*.14,H);c.closePath();c.clip();
 let pg=c.createLinearGradient(0,hz,0,H);pg.addColorStop(0,'rgba(120,100,80,.18)');pg.addColorStop(1,'rgba(150,120,90,.34)');c.fillStyle=pg;c.fillRect(0,hz,W,H-hz);
 c.strokeStyle='rgba(20,12,6,.55)';
 for(let row=0;row<26;row++){const u=Math.pow(row/26,1.9);const y=hz+u*(H-hz);c.lineWidth=.5+u*3;c.beginPath();c.moveTo(0,y);c.lineTo(W,y);c.stroke();
  const n=8+Math.floor(u*16);const x0=W*(.5-.04-.36*u),x1=W*(.5+.04+.36*u);for(let k=0;k<=n;k++){const x=x0+(x1-x0)*k/n+((row%2)?(x1-x0)/n/2:0);const yy=hz+Math.pow((row+1)/26,1.9)*(H-hz);c.lineWidth=.5+u*2.4;c.beginPath();c.moveTo(x,y);c.lineTo(x+(x-W/2)*.012*(row+1),yy);c.stroke();}}
 c.restore();
 // lamp posts
 function lamp(x,base,s){c.save();c.translate(x,base);c.scale(s,s);
  const gl=c.createRadialGradient(0,-200,5,0,-200,170);gl.addColorStop(0,'rgba(255,196,100,.55)');gl.addColorStop(.4,'rgba(255,170,80,.16)');gl.addColorStop(1,'rgba(255,170,80,0)');c.fillStyle=gl;c.fillRect(-180,-380,360,360);
  c.fillStyle='#0A0F18';c.fillRect(-5,-200,10,200);c.fillRect(-14,-14,28,14);c.fillRect(-9,-60,18,8);
  c.beginPath();c.moveTo(-18,-212);c.lineTo(18,-212);c.lineTo(13,-246);c.lineTo(-13,-246);c.closePath();c.fill();c.beginPath();c.moveTo(-18,-246);c.lineTo(0,-262);c.lineTo(18,-246);c.fill();
  c.fillStyle='#FFD58A';c.beginPath();c.moveTo(-12,-216);c.lineTo(12,-216);c.lineTo(9,-242);c.lineTo(-9,-242);c.closePath();c.fill();
  c.strokeStyle='#0A0F18';c.lineWidth=2;c.beginPath();c.moveTo(0,-216);c.lineTo(0,-242);c.stroke();c.restore();}
 lamp(W*.16,H*.66,.75);lamp(W*.86,H*.62,.68);lamp(W*.34,H*.56,.42);lamp(W*.68,H*.55,.4);
 // fence far
 c.strokeStyle='rgba(8,14,24,.9)';c.lineWidth=3;for(let x=0;x<W;x+=22){c.beginPath();c.moveTo(x,hz+16);c.lineTo(x,hz-6);c.stroke();}c.beginPath();c.moveTo(0,hz+2);c.lineTo(W,hz+2);c.stroke();
 // vignette
 const vg=c.createRadialGradient(W/2,H*.55,H*.35,W/2,H*.55,H*.95);vg.addColorStop(0,'rgba(0,0,0,0)');vg.addColorStop(1,'rgba(0,0,0,.55)');c.fillStyle=vg;c.fillRect(0,0,W,H);
}
