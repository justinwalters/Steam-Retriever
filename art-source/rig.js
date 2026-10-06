const D2R=Math.PI/180;
function build(){const I={};for(const n of Object.keys(PARTS)){const P=PARTS[n];const [x0,y0,x1,y1]=P.box;const cv=document.createElement('canvas');cv.width=Math.ceil((x1-x0)*3);cv.height=Math.ceil((y1-y0)*3);const c=cv.getContext('2d');c.scale(3,3);c.translate(-x0,-y0);P.draw(c);I[n]={cv,ox:x0,oy:y0,w:x1-x0,h:y1-y0};}return I;}
function img(c,I,n){const m=I[n];c.drawImage(m.cv,m.ox,m.oy,m.w,m.h);}
function leg(c,I,x,y,a1,a2,far,front){c.save();c.translate(x,y);c.rotate(-a1*D2R);c.scale(1,1.12);
 img(c,I,(front?'front_up':'hind_up')+(far?'_far':''));c.translate(0,11);c.rotate(a2*D2R);img(c,I,(front?'front_low':'hind_low')+(far?'_far':''));if(front&&!far){c.save();c.translate(0,7);c.scale(.8,.8);img(c,I,'wrist');c.restore();}c.restore();}
// pose: phase,gait,sit,lift,bodyRot,tail,ear,headRot,mouth,tongue,eyes(0 open,1 happy,2 X,3 cross),gear,pawFront,dig,sy,squash,ballMouth,boneMouth,bflyNose,t
function drawPup(c,I,p){
 const ph=p.phase||0,g=p.gait||0,sit=p.sit||0,t=p.t||0,pf=p.pawFront||0,dg=p.dig||0;
 const sw=(o,a)=>Math.sin(ph+o)*a*g,kn=(o,a)=>Math.max(0,Math.sin(ph+o+1.3))*a*g;
 let fa=[sw(0,44),sw(.6,44)],ha=[sw(Math.PI*.95,40),sw(Math.PI*.95+.6,40)];
 let fk=[-kn(0,50),-kn(.6,50)],hk=[kn(Math.PI*.95,55),kn(Math.PI*.95+.6,55)];
 const bodyRot=-sit*24+(p.bodyRot||0);
 let frontA=fa.map(a=>a*(1-sit)+sit*bodyRot);
 if(pf>0){frontA[0]=frontA[0]*(1-pf)+(66+Math.sin(t*13)*16)*pf;fk[0]=fk[0]*(1-pf)-35*pf;}
 if(dg>0){const s=Math.sin(t*20);frontA=[-30+s*40,-30-s*40];fk=[40+s*20,40-s*20];}
 const sy=(p.sy===undefined)?1:p.sy, sq=p.squash||1;
 c.save();
 // flip about body centre, resting on ground when upside down
 c.translate(0,-(p.lift||0)+((1-sy)/2)*11);
 c.translate(-5,-40);c.rotate((p.spin||0)*D2R);c.translate(5,40);
 c.translate(0,-34);c.scale(1,sy*sq);c.translate(0,34);
 c.translate(-30,0);c.rotate(bodyRot*D2R);c.translate(30,0);
 c.translate(0,-3);
 if(sit<.5)leg(c,I,-26,-30,ha[1],hk[1],true,false);
 leg(c,I,16,-30,frontA[1],fk[1],true,true);
 c.save();c.translate(-37,-40);c.rotate(((p.tail||0)-6)*D2R);c.scale(.8,.8);img(c,I,'tail');c.restore();
 img(c,I,'body');
 if(sit>=.5){c.save();c.translate(-22,-18);img(c,I,'haunch');c.restore();c.save();c.translate(-4,-3);img(c,I,'hpaw');c.restore();}
 else leg(c,I,-26,-30,ha[0],hk[0],false,false);
 leg(c,I,16,-30,frontA[0],fk[0],false,true);
 c.save();c.translate(-16,-49);c.scale(.55,.55);img(c,I,'pack');c.restore();
 c.save();c.translate(19,-43);img(c,I,'collar');c.restore();
 c.save();c.translate(21,-43);c.rotate((Math.sin(ph)*8*g+(p.swing||0)+(p.bodyRot||0)*-.5)*D2R);c.scale(.55,.55);img(c,I,'badge');c.restore();
 c.save();c.translate(31,-35);c.rotate(Math.sin(ph+1)*10*g*D2R);c.scale(.85,.85);img(c,I,'cap');c.restore();
 c.save();c.translate(19,-43);c.rotate((p.headRot||0)*D2R);c.scale(.8,.8);
 c.save();c.translate(34,-46);c.rotate(((p.ear||0)+8)*D2R);img(c,I,'ear_far');c.restore();
 c.save();c.translate(26,-6);c.rotate((p.mouth||0)*28*D2R);
  if((p.tongue||0)>0){c.save();c.translate(19,-5);c.rotate(.1);c.scale(1,p.tongue);img(c,I,'tongue');c.restore();}
  c.scale(.6,.6);img(c,I,'jaw');c.restore();
 img(c,I,'head');
 if(p.ballMouth){c.save();c.translate(48,-8+(p.mouth||0)*4);c.scale(.95,.95);img(c,I,'ball');c.restore();}
 if(p.boneMouth){c.save();c.translate(46,-6);c.rotate(-.25);c.scale(1.1,1.1);img(c,I,'bone');c.restore();}
 const ey=p.eyes||0;
 function eye(x,y,rx,ry,dx){ if(ey==0||ey==3){const px=ey==3?dx:0;c.fillStyle='#1b100c';c.beginPath();c.ellipse(x,y,rx,ry,0,0,7);c.fill();c.fillStyle='#fff';c.beginPath();c.arc(x+rx*.35+px*.3,y-ry*.38,rx*.42,0,7);c.fill();c.beginPath();c.arc(x-rx*.4,y+ry*.4,rx*.2,0,7);c.fill();}
  else if(ey==1){c.strokeStyle='#1b100c';c.lineWidth=1.9;c.lineCap='round';c.beginPath();c.moveTo(x-rx,y+1);c.quadraticCurveTo(x,y-ry*.9,x+rx,y+1);c.stroke();}
  else{c.strokeStyle='#1b100c';c.lineWidth=1.8;c.lineCap='round';c.beginPath();c.moveTo(x-rx*.9,y-rx*.9);c.lineTo(x+rx*.9,y+rx*.9);c.moveTo(x+rx*.9,y-rx*.9);c.lineTo(x-rx*.9,y+rx*.9);c.stroke();}}
 eye(22,-27,6,7.4,4);eye(38,-29,4.6,6.2,-2);
 c.save();c.translate(16,-47);c.rotate(-.2);img(c,I,'goggles');c.restore();
 c.save();c.translate(-1,-41);c.rotate(((p.ear||0)+6)*D2R);img(c,I,'ear');c.restore();
 if(p.bflyNose){c.save();c.translate(52,-30+Math.sin(t*5)*1.2);c.scale(.8*(0.6+0.4*Math.abs(Math.sin(t*14))),.8);img(c,I,'bfly');c.restore();}
 c.restore();
 c.restore();
}
