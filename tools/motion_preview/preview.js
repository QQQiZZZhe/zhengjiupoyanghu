/* Developer preview, never loaded by the Godot game or included in exports. */
"use strict";
(async () => {
  // A CPU-backed canvas keeps pixel-art sampling stable for arbitrary seeks.
  const canvas = document.querySelector("#film"), ctx = canvas.getContext("2d",{willReadFrequently:true});
  const slider = document.querySelector("#time"), play = document.querySelector("#play");
  try {
    const response = await fetch("../../assets/motion/profiles.json");
    if (!response.ok) throw new Error("无法读取公共动效配置");
    const profiles = await response.json();
    const image = async path => { const im = new Image(); im.src = path; await im.decode(); return im; };
    const [face, lake] = await Promise.all([image("../../assets/art/card-suits/ecology.png"), image("../../assets/art/poyang-wetland.png")]);
    const names = ["滨湖缓冲带与生态沟渠", "人工鱼巢投放", "生态水位联合调度"];
    const home = [{x:370,y:505,r:-.1},{x:570,y:493,r:0},{x:770,y:505,r:.1}];
    const cards = home.map((p,i)=>({...p,s:1,a:1,id:i}));
    const state = {zoom:1,detail:0,water:60,delta:0};
    const tl = gsap.timeline({paused:true,defaults:{lazy:false},onUpdate:()=>render(tl.time()),onComplete:()=>{play.textContent="播放";}});
    const cfg = (name, extra={}) => ({duration:profiles[name].duration,ease:profiles[name].ease,...extra});
    tl.to(state,cfg("camera",{zoom:1.04}),.2)
      .to(cards[1],cfg("response",{y:470,s:1.06}),.45)
      .to(cards[1],cfg("carry",{x:275,y:245,r:0,s:1.8}),.9)
      .to(state,cfg("enter",{detail:1}),1.0)
      .to(cards[1],cfg("return",{...home[1],s:1}),2.8)
      .to(state,cfg("exit",{detail:0}),2.8);
    cards.forEach((card,i)=>{
      tl.to(card,cfg("gather",{x:570,y:475+i*3,r:0,s:.92}),3.4+i*profiles.gather.stagger);
      tl.to(card,cfg("deal",{...home[(i+1)%3],s:1}),3.9+i*profiles.deal.stagger);
    });
    tl.to(cards[1],cfg("carry",{x:570,y:240,r:0,s:1.12}),4.7);
    [0,2].forEach((i,n)=>tl.to(cards[i],cfg("exit",{y:790,a:0}),4.7+n*.04));
    tl.to(state,{water:68,duration:.35,ease:profiles.response.ease},5.5)
      .to(state,cfg("arrival",{delta:1}),5.5)
      .to(state,{delta:0,duration:.3,ease:profiles.exit.ease},6.35);
    cards.forEach((card,i)=>tl.to(card,cfg("carry",{...home[i],s:1,a:1}),6.9+i*.03));
    tl.to(state,cfg("camera",{zoom:1}),6.9).to({}, {duration:.5},7.7);
    const beats = [[0,"静止 · 等待操作"],[.45,"选择 · 输入先引起反应"],[.9,"详情 · 同一张卡成为阅读主体"],[1.4,"阅读 · 保留静止段落"],[2.8,"返回 · 卡片回到原位"],[3.4,"排序 · 收拢后按新顺序发出"],[4.7,"出牌 · 卡片承接下一段动作"],[5.5,"结算 · 卡片效果传递给湖区指标"],[6.9,"归位 · 镜头与手牌一起落定"],[7.7,"静止 · 等待下一次操作"]];
    function rect(x,y,w,h,r,color){ctx.fillStyle=color;ctx.beginPath();ctx.roundRect(x,y,w,h,r);ctx.fill();}
    function text(str,x,y,size=20,color="#f5ecd8"){ctx.fillStyle=color;ctx.font=`${size}px "Microsoft YaHei", sans-serif`;ctx.fillText(str,x,y);}
    function render(t){
      ctx.reset();ctx.imageSmoothingEnabled=false;ctx.fillStyle="#b8c66d";ctx.fillRect(0,0,1280,720);
      ctx.save();ctx.translate(640,360);ctx.scale(state.zoom,state.zoom);ctx.translate(-640,-360);
      ctx.globalAlpha=.9;ctx.imageSmoothingEnabled=false;ctx.drawImage(lake,90,30,1090,600);ctx.globalAlpha=1;ctx.restore();
      rect(28,24,250,92,8,"#303e49ed");text("鄱阳湖 · 春季",48,59,24);text("第一年 / 第一回合",48,89,15,"#acc9ce");
      rect(995,24,257,103,8,"#303e49ed");text("水质",1015,58,20);text(Math.round(state.water).toString(),1200,58,22,"#c7dcae");rect(1015,76,215,12,3,"#526e86");rect(1015,76,215*state.water/100,12,3,"#c7dcae");
      if(state.detail>0){ctx.save();ctx.globalAlpha=state.detail;rect(470,138,390,238,10,"#303e49ed");text(names[1],495,184,28,"#edc68a");text("恢复鱼类，带动水质改善",495,229,21);text("先保留卡片，再展开说明。",495,271,17,"#acc9ce");text("点击背景后回到手牌",495,332,16,"#91a397");ctx.restore();}
      const order = cards.filter(c=>c.id!==1).concat(cards[1]);
      order.forEach(card=>{ctx.save();ctx.globalAlpha=card.a;ctx.translate(card.x,card.y);ctx.rotate(card.r);let press=1;if(card.id===1){for(const hit of [.45,5.5]){if(t>=hit&&t<hit+.6)press*=OM.press(t,hit,{depth:hit===.45?.035:.025}).s;}}ctx.scale(card.s*press,card.s*press);ctx.shadowColor="#182a2f66";ctx.shadowBlur=10;ctx.shadowOffsetY=5;ctx.drawImage(face,-70,-94,140,188);ctx.shadowBlur=0;ctx.shadowOffsetY=0;ctx.textAlign="center";const title=Array.from(names[card.id]);for(let i=0;i<title.length;i+=6)text(title.slice(i,i+6).join(""),0,-20+Math.floor(i/6)*20,14,"#303e49");text(card.id===1?"20":"30",-10,53,16,"#303e49");ctx.restore();});
      if(state.delta>0){ctx.save();ctx.globalAlpha=Math.min(1,state.delta);text("水质 +8",550,130-(state.delta-1)*8,28,"#303e49");ctx.restore();}
      // Deterministic onetake contact rings: no random particles or camera drift.
      if(t>=5.5 && t<6.5){const rings=OM.ripple(t,5.5,{n:2,stagger:.12,dur:.75,rMax:65});ctx.save();ctx.strokeStyle="#f5ecd8";ctx.lineWidth=2;ctx.globalAlpha=Math.max(0,1-(t-5.5));rings.r.forEach(r=>{ctx.beginPath();ctx.arc(640,328,r,0,Math.PI*2);ctx.stroke();});ctx.restore();}
      slider.value=t;document.querySelector("#clock").value=`${t.toFixed(2)} s`;document.querySelector("#beat").textContent=beats.filter(b=>b[0]<=t).at(-1)[1];
    }
    window.__seek=t=>{tl.pause().time(Math.max(0,Math.min(8.2,t)),true);render(tl.time());return window.__track();};
    window.__track=()=>cards.map(c=>({id:`card-${c.id}`,x:c.x-70*c.s,y:c.y-94*c.s,w:140*c.s,h:188*c.s,rotation:c.r,opacity:c.a}));
    window.__meta={duration:8.2,gsapVersion:gsap.version,inFrame:["card-1"],profiles};
    window.__timeline=tl;
    play.onclick=()=>{if(tl.isActive()){tl.pause();play.textContent="播放";}else{if(tl.progress()===1)tl.restart();else tl.play();play.textContent="暂停";}};
    document.querySelector("#reset").onclick=()=>{tl.restart();play.textContent="暂停";};
    document.querySelector("#speed").onchange=e=>tl.timeScale(+e.target.value);
    slider.oninput=e=>{window.__seek(+e.target.value);play.textContent="播放";};
    document.addEventListener("visibilitychange",()=>{if(document.hidden){tl.pause();play.textContent="播放";}});
    // Resolve all from-values before the first arbitrary seek. Lazy first renders
    // must not make a frame depend on which beat the reviewer visited first.
    tl.totalTime(tl.duration(),true).totalTime(0,true);
    render(0);window.__ready=Promise.resolve(true);window.__motionReady=true;
  }catch(error){const el=document.querySelector("#error");el.hidden=false;el.textContent=`预览加载失败：${error.message}。请在项目根目录运行 python -m http.server 8765 后访问 /tools/motion_preview/。`;window.__motionError=error.message;}
})();
