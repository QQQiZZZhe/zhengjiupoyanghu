// Run with Playwright installed, while the project-root HTTP server is running.
const { chromium } = require('playwright');
const fs = require('node:fs');
const path = require('node:path');
(async()=>{
  const output=process.argv[2] || process.cwd();
  fs.mkdirSync(output,{recursive:true});
  const launch={headless:true};
  if(process.env.MOTION_BROWSER_PATH) launch.executablePath=process.env.MOTION_BROWSER_PATH;
  else if(process.platform==='win32') launch.channel='msedge';
  const browser=await chromium.launch(launch);
  const page=await browser.newPage({viewport:{width:1280,height:960},deviceScaleFactor:1});
  const errors=[];page.on('pageerror',e=>errors.push(e.message));
  const checks=[];const check=(ok,name)=>{checks.push({name,ok});if(!ok)throw new Error(name);};
  try{
    await page.goto('http://127.0.0.1:8765/tools/motion_preview/');
    await page.waitForFunction(()=>window.__motionReady || window.__motionError);
    check(await page.evaluate(()=>window.__motionReady===true),'Preview assets and shared profiles load');
    check(await page.evaluate(()=>window.__meta.gsapVersion==='3.15.0'),'Real pinned GSAP executes');
    for(const t of [0,.7,1.6,2.4,3.7,4.2,5.6,7.9]){
      const a=await page.evaluate(t=>window.__seek(t),t);
      const rawA=await page.evaluate(()=>document.querySelector('canvas').toDataURL());
      const shot=await page.locator('canvas').screenshot();
      await page.evaluate(()=>window.__seek(8.0));
      const b=await page.evaluate(t=>window.__seek(t),t);
      const rawB=await page.evaluate(()=>document.querySelector('canvas').toDataURL());
      const repeated=await page.locator('canvas').screenshot();
	  if(JSON.stringify(a)!==JSON.stringify(b) || !shot.equals(repeated)){
	    fs.writeFileSync(path.join(output,'seek-expected.png'),shot);fs.writeFileSync(path.join(output,'seek-actual.png'),repeated);
	    fs.writeFileSync(path.join(output,'seek-difference.json'),JSON.stringify({t,a,b,rawSame:rawA===rawB},null,2));
	  }
      check(JSON.stringify(a)===JSON.stringify(b) && shot.equals(repeated),`Deterministic geometry and pixels at ${t}s`);
      const subject=a.find(c=>c.id==='card-1');
      check(subject.x>=0&&subject.y>=0&&subject.x+subject.w<=1280&&subject.y+subject.h<=720,`Carried card stays framed at ${t}s`);
      fs.writeFileSync(path.join(output,`frame-${t.toFixed(1)}.png`),shot);
    }
    await page.evaluate(()=>window.__seek(1.8));const hold=await page.locator('canvas').screenshot();
    await page.evaluate(()=>window.__seek(2.3));check(hold.equals(await page.locator('canvas').screenshot()),'Reading hold is still');
    await page.click('#play');await page.waitForTimeout(150);await page.click('#play');
    const pause=await page.evaluate(()=>window.__timeline.time());await page.waitForTimeout(100);
    check(await page.evaluate(t=>window.__timeline.time()===t,pause),'Pause freezes the complete GSAP timeline');
    await page.locator('#speed').selectOption('2');check(await page.evaluate(()=>window.__timeline.timeScale()===2),'Speed control applies to the timeline');
    await page.locator('#speed').selectOption('1');
    await page.evaluate(()=>window.__seek(1.6));await page.screenshot({path:path.join(output,'preview.png'),fullPage:true});
    check(errors.length===0,'No browser script errors');
    fs.writeFileSync(path.join(output,'preview-checks.json'),JSON.stringify(checks,null,2));
    console.log(`MOTION_PREVIEW: ${checks.length} checks, 0 failures`);
  }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
