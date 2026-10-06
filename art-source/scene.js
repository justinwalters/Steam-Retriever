function toScreen(W,H,x,z){const k=H/1080;return{sx:W/2+x*W*.5,sy:lerp(.92*H,.54*H,z),sc:lerp(3.3,.9,z)*k};}
function hash(i){let h=Math.imul(i+1,2654435761)>>>0;h^=h>>>15;h=Math.imul(h,2246822519)>>>0;h^=h>>>13;return(h>>>0)/4294967296;}
function drawScene(c,W,H,name,t,D,I,bd,steam){
 c.drawImage(bd,0,0,W,H);
 const S=state(name,t,D);const {sx,sy,sc}=toScreen(W,H,S.x,S.z);const p=S.pose,pr=S.props,u=t/D;const face=S.face;
 // hole
 if(pr.hole>0){const hx=sx+face*68*sc,hy=sy+1*sc;const g=c.createRadialGradient(hx,hy,2,hx,hy,34*sc*pr.hole);g.addColorStop(0,'#05080a');g.addColorStop(.7,'#0c1210');g.addColorStop(1,'rgba(30,22,12,.0)');c.fillStyle=g;c.beginPath();c.ellipse(hx,hy,36*sc*pr.hole,10*sc*pr.hole,0,0,7);c.fill();
  c.strokeStyle='rgba(70,45,22,.8)';c.lineWidth=2*sc;c.beginPath();c.ellipse(hx,hy,36*sc*pr.hole,10*sc*pr.hole,0,0,7);c.stroke();}
 // shadow
 const lift=(p.lift||0)*sc;c.save();c.globalAlpha=.4*(1-cl(lift/(120*sc),0,.7));c.fillStyle='#000';c.beginPath();c.ellipse(sx,sy+2*sc,56*sc,9*sc,0,0,7);c.fill();c.restore();
 // steam puffs (world trail)
 if(steam){for(let i=0;i<7;i++){const age=((t*.8+i/7)%1);const tp=Math.max(0,t-age*1.2);const s2=state(name,tp,D);const q=toScreen(W,H,s2.x,s2.z);
   const cx=q.sx+(-20.4*s2.face)*q.sc,cy=q.sy-66*q.sc-age*70*sc;const r=(5+age*20)*sc;const gg=c.createRadialGradient(cx+age*10*sc,cy,0,cx+age*10*sc,cy,r);gg.addColorStop(0,`rgba(215,230,240,${.5*(1-age)})`);gg.addColorStop(1,'rgba(215,230,240,0)');c.fillStyle=gg;c.beginPath();c.arc(cx+age*10*sc,cy,r,0,7);c.fill();}}
 // bone from hole
 if(pr.bone){const hx=sx+face*68*sc;const k=pr.bone.k;const by=sy-(pr.bone.ground?0:(k*34+Math.sin(t*3)*2))*sc;c.save();c.translate(pr.bone.ground?sx+face*58*sc:hx,by);c.rotate(-.3+(pr.bone.ground?0:Math.sin(t*3)*.1));const s=1.5*sc*(pr.bone.ground?1:k);c.scale(s,s);img(c,I,'bone');c.restore();
   if(!pr.bone.ground&&k>0.3){c.save();c.globalAlpha=.8*(1-k*.4);const gg=c.createRadialGradient(hx,by,0,hx,by,40*sc);gg.addColorStop(0,'rgba(255,230,150,.55)');gg.addColorStop(1,'rgba(255,230,150,0)');c.fillStyle=gg;c.beginPath();c.arc(hx,by,40*sc,0,7);c.fill();c.restore();}}
 // pad
 if(pr.pad){const q={x:sx+62*sc,y:sy-4*sc};c.save();c.translate(q.x,q.y);c.rotate(pr.pad.wob*.04);c.scale(1.5*sc,1.5*sc);img(c,I,'pad');c.restore();}
 // pup
 c.save();c.translate(sx,sy);c.scale(sc*face,sc);drawPup(c,I,p);c.restore();
 // dirt
 if(pr.digging){for(let k=0;k<14;k++){const id=Math.floor(t/.05)-k;const age=(t-id*.05);if(age<0||age>.8)continue;const r=hash(id),r2=hash(id+999);
   const sxp=sx+face*62*sc,syp=sy-2*sc;const X=sxp+(-face)*(40+r*130)*age*sc;
   const Y=syp-(160+r2*120)*age*sc+260*age*age*sc;c.fillStyle=r2<.5?'#4a3320':'#6b4a2c';c.globalAlpha=1-age/.8;c.beginPath();c.arc(X,Y,(2.6+r*3)*sc,0,7);c.fill();c.globalAlpha=1;}}
 // text/hearts/stars/bang/bfly/ball
 if(pr.ball){const q=toScreen(W,H,pr.ball.x,pr.ball.z);c.save();c.fillStyle='rgba(0,0,0,.35)';c.beginPath();c.ellipse(q.sx,q.sy+2*q.sc,10*q.sc,3*q.sc,0,0,7);c.fill();c.translate(q.sx,q.sy-(pr.ball.h)*q.sc*.45-8*q.sc);c.rotate(t*6);c.scale(1.3*q.sc,1.3*q.sc);img(c,I,'ball');c.restore();}
 if(pr.text){const k=pr.text.k;c.save();c.font=`800 ${17*sc}px monospace`;c.textAlign='center';const a=Math.min(1,k*6)*Math.min(1,(1-k)*5);c.globalAlpha=a;const ty=sy-(125+k*70)*sc;c.lineWidth=6*sc;c.strokeStyle='#04210f';c.strokeText(pr.text.s,sx+40*sc,ty);c.fillStyle='#6BFFA8';c.fillText(pr.text.s,sx+40*sc,ty);c.restore();}
 if(pr.hearts){for(let i=0;i<3;i++){const k=cl(pr.hearts*1.3-i*.15,0,1);if(k<=0||k>=1)continue;const hx=sx+(20+i*22+Math.sin(k*6+i)*8)*sc,hy=sy-(100+k*90)*sc;c.save();c.globalAlpha=1-k;c.fillStyle='#FF5C7A';c.translate(hx,hy);c.scale(sc*(.8+.4*i%2),sc*(.8));c.beginPath();c.moveTo(0,5);c.bezierCurveTo(-12,-4,-6,-12,0,-5);c.bezierCurveTo(6,-12,12,-4,0,5);c.fill();c.restore();}}
 if(pr.stars){for(let i=0;i<4;i++){const a=t*6+i*Math.PI/2;const stx=sx+(face>0?1:1)*(34+Math.cos(a)*26)*sc,sty=sy-(92+Math.sin(a)*8)*sc;c.save();c.translate(stx,sty);c.rotate(t*5);c.fillStyle='#FFD34A';c.globalAlpha=pr.stars;c.beginPath();for(let j=0;j<10;j++){const r=j%2?3:7;const aa=j/10*Math.PI*2;c.lineTo(Math.cos(aa)*r*sc,Math.sin(aa)*r*sc);}c.fill();c.restore();}}
 if(pr.bang){const k=pr.bang;const sc2=sc*(.6+.5*sm(seg(k,0,.2)))*(1-sm(seg(k,.7,1)));c.save();c.translate(sx+70*sc,sy-110*sc);c.scale(sc2,sc2);c.fillStyle='#FFD34A';c.strokeStyle='#8a3a10';c.lineWidth=3;c.beginPath();for(let j=0;j<16;j++){const r=j%2?26:44;const aa=j/16*Math.PI*2;c.lineTo(Math.cos(aa)*r,Math.sin(aa)*r);}c.closePath();c.fill();c.stroke();c.fillStyle='#B3261E';c.font='900 20px monospace';c.textAlign='center';c.fillText('BANG!',0,7);c.restore();}
 if(pr.bfly){const b=pr.bfly;const q=toScreen(W,H,b.x,b.z);c.save();c.translate(q.sx,q.sy-b.h*q.sc*.5);c.rotate(Math.sin(t*3)*.3);c.scale(1.7*q.sc*(.5+.5*Math.abs(Math.sin(t*16))),1.7*q.sc);const glow=c.createRadialGradient(0,0,0,0,0,26);glow.addColorStop(0,'rgba(120,255,230,.35)');glow.addColorStop(1,'rgba(120,255,230,0)');c.fillStyle=glow;c.fillRect(-26,-26,52,52);img(c,I,'bfly');c.restore();}
}
