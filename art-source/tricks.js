// ===== choreography (mirrors Swift Choreo) =====
const cl=(x,a,b)=>Math.min(Math.max(x,a),b);
const sm=x=>{x=cl(x,0,1);return x*x*(3-2*x);};
const seg=(u,a,b)=>cl((u-a)/(b-a),0,1);
const lerp=(a,b,t)=>a+(b-a)*t;
const X0=0,Z0=.14;
const TRICKS=['fetch','zoomies','gamer','roll','dig','spin','dead','flip','fly'];
const CAPTION={fetch:"Sprocket is fetching the brass ball",zoomies:"Sprocket has the zoomies",gamer:"Sprocket is speedrunning a level",roll:"Sprocket is rolling over",dig:"Sprocket is digging for treasure",spin:"Sprocket is chasing his tail",dead:"Sprocket is playing dead",flip:"Sprocket is practising backflips",fly:"Sprocket spotted a clockwork butterfly"};
// path(t,D)-> {x,z}, face(t,D)
function path(n,t,D){const u=t/D;
 switch(n){
 case 'fetch':{ if(u<.12)return[X0,Z0]; if(u<.40){const k=sm(seg(u,.12,.40));return[lerp(0,.6,k),lerp(Z0,.7,k)];} if(u<.48)return[.6,.7]; if(u<.80){const k=sm(seg(u,.48,.80));return[lerp(.6,-.02,k),lerp(.7,Z0,k)];} return[-.02,Z0];}
 case 'zoomies':{const env=sm(seg(u,0,.08))*sm(seg(1-u,0,.08));const x=1.38*env*Math.sin(4*Math.PI*u);const z=Z0+env*.4*(1-Math.cos(8*Math.PI*u))*.5*1.0;return[x,Math.min(z,.8)];}
 case 'dig':{ if(u<.14){const k=sm(seg(u,0,.14));return[lerp(0,-.42,k),lerp(Z0,.3,k)];} if(u<.86)return[-.42,.3]; const k=sm(seg(u,.86,1));return[lerp(-.42,0,k),lerp(.3,Z0,k)];}
 case 'spin':{const th=spinTheta(u);return[.04*Math.sin(th),.16+.03*Math.cos(th)];}
 case 'fly':{ if(u<.52)return[0,Z0]; if(u<.66){const k=sm(seg(u,.52,.66));return[lerp(0,.62,k),lerp(Z0,.8,k)];} if(u<.86)return[.62,.8]; const k=sm(seg(u,.86,.98));return[lerp(.62,0,k),lerp(.8,Z0,k)];}
 default:return[X0,Z0];}}
function spinTheta(u){return 2*Math.PI*4*sm(seg(u,.08,.62));}
function faceOf(n,t,D,vx){const u=t/D;
 switch(n){
 case 'fetch':return u<.44?1:(u<.5?lerp(1,-1,sm(seg(u,.44,.5))):(u<.80?-1:lerp(-1,1,sm(seg(u,.80,.86)))));
 case 'zoomies':return cl(vx/.25,-1,1)||1;
 case 'dig':return u<.02?lerp(1,-1,sm(seg(u,0,.02))):(u<.88?-1:lerp(-1,1,sm(seg(u,.88,.92))));
 case 'spin':{const c=Math.cos(spinTheta(u));return(Math.abs(c)<.16?(c<0?-.16:.16):c);}
 case 'fly':return u<.5?1:(u<.54?1:(u<.7?1:(u<.86?lerp(1,-1,sm(seg(u,.72,.78))):(u<.96?-1:lerp(-1,1,sm(seg(u,.96,1)))))));
 default:return 1;}}
function speedAt(n,t,D){const a=path(n,Math.max(0,t-.05),D),b=path(n,Math.min(D,t+.05),D);return Math.hypot((b[0]-a[0])*1.0,(b[1]-a[1])*.5)/.1;}
function phaseAt(n,t,D){let ph=0;for(let s=0;s<t;s+=.1){const sp=speedAt(n,s,D);ph+=.1*(sp>.05?cl(8+sp*9,8,19):0);}return ph;}
function jump(u,a,b,h){const k=seg(u,a,b);return k>0&&k<1?Math.sin(Math.PI*k)*h:0;}

// returns {x,z,face,pose,props}
function state(n,t,D){
 const u=t/D;const [x,z]=path(n,t,D);const sp=speedAt(n,t,D);
 const vx=(path(n,Math.min(D,t+.05),D)[0]-path(n,Math.max(0,t-.05),D)[0])/.1;
 const face=faceOf(n,t,D,vx);
 const g=cl(sp/.18,0,1);
 const p={phase:phaseAt(n,t,D),gait:g,t:t,gear:t*40,tail:Math.sin(t*9)*10,ear:Math.sin(t*3)*3,tongue:0,eyes:0,mouth:0};
 if(g>.05){p.lift=Math.abs(Math.sin(p.phase))*3.5*g;p.tongue=1;p.mouth=.5;p.tail=Math.sin(t*16)*14+8;p.ear=-18*g+Math.sin(p.phase*2)*6;p.bodyRot=Math.sin(p.phase*2)*2;}
 const pr={};
 switch(n){
 case 'fetch':{
  const k=seg(u,.05,.2);
  if(u>=.05&&u<.42){const bx=lerp(.05,.6,k),bz=lerp(Z0,.7,k);pr.ball={x:bx,z:bz,h:Math.sin(Math.PI*k)*260*(k<1?1:0)+ (u>=.2&&u<.24? Math.sin(Math.PI*seg(u,.2,.24))*40:0)};}
  if(u>=.05&&u<.12)p.eyes=0;
  p.headRot=u>.38&&u<.5?24*Math.sin(Math.PI*seg(u,.38,.5)):0;
  p.ballMouth=u>=.46&&u<.82;
  if(p.ballMouth){p.tongue=0;p.mouth=0;}
  const sitK=sm(seg(u,.84,.9));p.sit=sitK;
  if(u>=.82){pr.ball={x:-.02+.13,z:Z0,h:Math.abs(Math.sin(seg(u,.82,.88)*Math.PI*2))*30*(1-seg(u,.82,.9))};p.tongue=1;p.mouth=.5;p.eyes=1;p.tail=Math.sin(t*16)*18;}
  break;}
 case 'zoomies':{p.tail=Math.sin(t*20)*22;break;}
 case 'gamer':{
  const sitK=sm(seg(u,.06,.16))*sm(seg(1-u,0,.1));p.sit=sitK;
  if(u>.18&&u<.94)pr.pad={x:.15,z:Z0,wob:Math.sin(t*14)};
  const play=sm(seg(u,.2,.26))*sm(seg(.74,.68,.74));
  p.pawFront=play*(.5+.5*Math.sin(t*9));p.headRot=8*play;p.tongue=play;p.mouth=.3*play;
  p.eyes=u>.78?1:0;
  if(u>.46&&u<.64)pr.text={s:"LEVEL UP!",k:seg(u,.46,.64),x:.07,z:Z0};
  if(u>.74&&u<.9)pr.hearts=seg(u,.74,.9);
  break;}
 case 'roll':{
  const down=sm(seg(u,.06,.16))*sm(seg(.2,.14,.2)) ;
  const th=2*Math.PI*2*sm(seg(u,.2,.72));
  const rolling=u>.2&&u<.72;
  p.sy=rolling?Math.cos(th):1;
  p.squash=1-.12*sm(seg(u,.06,.18))*(1-sm(seg(u,.72,.8)));
  p.headRot=10*sm(seg(u,.06,.18))*(1-sm(seg(u,.2,.24)));
  if(rolling){const back=cl(-p.sy+.35,0,1);p.gait=.8*back;p.phase=t*13;p.eyes=back>.3?1:0;p.tongue=1;p.mouth=.5;p.bodyRot=Math.sin(th)*6;p.lift=0;}
  if(u>.8&&u<.92){const e=sm(seg(u,.8,.83))*sm(seg(.92,.86,.92));p.bodyRot=Math.sin(t*34)*7*e;p.ear=Math.sin(t*30)*25*e;}
  if(u>.72){p.eyes=1;p.tongue=1;p.mouth=.4;}
  break;}
 case 'dig':{
  const digK=sm(seg(u,.16,.2))*sm(seg(.62,.56,.62));
  p.dig=digK>.5?1:0;p.headRot=28*digK+(u>.62&&u<.7?-12*sm(seg(u,.62,.66)):0);
  if(g<.1)p.tail=Math.sin(t*14)*16;
  pr.digging=digK>.5;
  pr.hole=sm(seg(u,.16,.5))*(1-sm(seg(u,.9,.97)));
  if(u>.54&&u<.97)pr.bone={k:sm(seg(u,.54,.7)),mouthUp:u>.7};
  p.boneMouth=u>=.72&&u<.93;
  if(p.boneMouth){p.tongue=0;p.mouth=0;}
  if(u>.62){p.eyes=1;p.lift=(p.lift||0)+jump(u,.64,.7,14)+jump(u,.7,.76,10);}
  if(u>=.93&&u<.99)pr.bone={k:1,ground:true};
  break;}
 case 'spin':{
  const th=spinTheta(u);
  p.tail=Math.sin(t*22)*34;p.mouth=.4;p.tongue=1;p.headRot=14*Math.sin(th*1);
  p.bodyRot=Math.sin(th)*5;
  const dz=sm(seg(u,.62,.7))*(1-sm(seg(u,.9,.97)));
  if(dz>0){p.bodyRot=Math.sin(t*7)*14*dz;p.eyes=3;p.headRot=Math.sin(t*5)*12*dz;pr.stars=dz;}
  if(u>.95)p.eyes=1;
  break;}
 case 'dead':{
  if(u>=.1&&u<.3)pr.bang=seg(u,.1,.3);
  const fall=sm(seg(u,.2,.3));const wake=sm(seg(u,.72,.78));
  p.sy=Math.cos(Math.PI*cl(fall-wake,0,1));
  const down=fall*(1-wake);
  p.lift=(u>.3&&u<.34?Math.sin(seg(u,.3,.34)*Math.PI)*8:0)+jump(u,.78,.9,34);
  p.eyes=down>.5?(u>.6&&u<.66?0:2):(u>.78?1:0);
  p.tongue=down>.4?1:p.tongue;p.mouth=down*.5;
  p.gait=0;p.ear=down*30;p.tail=down>.4?0:p.tail;
  if(down>.9){p.gait=u>.48&&u<.54?.6:0;p.phase=t*16;}
  if(u>.78)p.eyes=1;
  break;}
 case 'flip':{
  const c1=sm(seg(u,.06,.14))*(1-sm(seg(u,.14,.16)));
  const k1=seg(u,.14,.32),k2=seg(u,.46,.68);
  let spin=0,lift=0;
  if(k1>0&&k1<1){spin=-360*sm(k1);lift=Math.sin(Math.PI*k1)*70;}
  if(k2>0&&k2<1){spin=-360*sm(k2);lift=Math.sin(Math.PI*k2)*110;}
  p.spin=spin;p.lift=lift;
  const c2=sm(seg(u,.38,.46))*(1-sm(seg(u,.46,.48)));
  const land=(u>.32&&u<.4?sm(seg(u,.32,.34))*(1-sm(seg(u,.36,.42))):0)+(u>.68&&u<.76?sm(seg(u,.68,.7))*(1-sm(seg(u,.72,.78))):0);
  p.squash=1-.22*Math.max(c1,c2,land);
  p.sit=0;
  const bow=sm(seg(u,.76,.82))*(1-sm(seg(u,.9,.95)));
  p.bodyRot=bow*16;p.headRot=bow*14;p.tail=Math.sin(t*20)*24;p.tongue=1;p.mouth=.5;
  p.eyes=bow>.3?1:0;
  if(u>.14&&u<.32)p.mouth=.7;
  break;}
 case 'fly':{
  // butterfly world pos
  let b={x:0,z:0,h:0,on:false};
  if(u<.5){const a=2*Math.PI*2.2*u;b={x:.14*Math.cos(a)+.04,z:Z0+.03*Math.sin(a*1.3),h:150+55*Math.sin(a*1.7)};
   p.headRot=-16*Math.sin(a+1)*sm(seg(u,.02,.1));p.mouth=.3;p.tongue=1;p.eyes=0;
   p.lift=(p.lift||0)+jump(u,.28,.34,18)+jump(u,.36,.42,22)+jump(u,.44,.5,26);}
  else if(u<.66){const k=sm(seg(u,.5,.64));b={x:lerp(.04,.78,k),z:lerp(Z0,.86,k),h:lerp(120,60,k)+20*Math.sin(t*5)};}
  else if(u<.72){b={x:.78+.03*Math.sin(t*3),z:.86,h:60+10*Math.sin(t*5)};p.headRot=-10;}
  else if(u<.84){const k=sm(seg(u,.72,.84));b={x:lerp(.78,.66,k),z:lerp(.86,.82,k),h:lerp(60,50,k)+8*Math.sin(t*6)};p.headRot=-10*(1-k);}
  else {b.on=true;}
  if(u<.84)pr.bfly=b;
  if(u>=.84&&u<.985){p.bflyNose=true;p.eyes=3;p.tongue=0;p.mouth=0;p.headRot=6;}
  if(u>=.985){pr.bfly={x:x+.02,z:z,h:60+(u-.985)/.015*160,flyaway:true};}
  p.ear=p.ear||0;
  break;}
 }
 return{x,z,face,pose:p,props:pr};
}
