import {chromium} from '/opt/node22/lib/node_modules/playwright/index.mjs';import fs from 'fs';import {spawn} from 'child_process';
const [,, dir, mode, out, fpsArg] = process.argv;
const srt = fs.readFileSync(dir+'/'+(process.env.SRT||'script.srt'),'utf8').replace(/\r/g,'').trim().split(/\n\n+/).map(b=>{const l=b.split('\n');const m=l[1].match(/(\d+):(\d+):(\d+),(\d+) --> (\d+):(\d+):(\d+),(\d+)/);const s=(h,mi,se,ms)=>+h*3600+ +mi*60+ +se+ +ms/1000;return {a:s(m[1],m[2],m[3],m[4]),b:s(m[5],m[6],m[7],m[8]),text:l.slice(2).join(' ')}});
const TOTAL = +(process.env.TOTAL||117); const PAGE = process.env.PAGE||'video.html';
const b = await chromium.launch({executablePath:'/opt/pw-browsers/chromium',args:['--allow-file-access-from-files']});
const p = await b.newPage({viewport:{width:1080,height:1920}});
await p.addInitScript(([s,t])=>{window.__SRT=s;window.__TOTAL=t},[srt,TOTAL]);
await p.goto('file://'+dir+'/'+PAGE);await p.waitForTimeout(800);
if (mode==='frames'){ for (const t of out.split(',').map(Number)){ await p.evaluate(t=>render(t),t); await p.screenshot({path:dir+'/f-'+t+'.png'}); } }
else {
  const fps=+fpsArg||30, n=Math.round(TOTAL*fps);
  const ff=spawn('ffmpeg',['-y','-loglevel','error','-f','image2pipe','-framerate',String(fps),'-c:v','mjpeg','-i','-','-c:v','libx264','-preset','medium','-crf','20','-pix_fmt','yuv420p','-movflags','+faststart',out],{stdio:['pipe','inherit','inherit']});
  for(let f=0;f<n;f++){ await p.evaluate(t=>render(t),f/fps); const buf=await p.screenshot({type:'jpeg',quality:92}); if(!ff.stdin.write(buf)) await new Promise(r=>ff.stdin.once('drain',r)); if(f%300===0) console.log('image',f,'/',n); }
  ff.stdin.end(); await new Promise(r=>ff.on('close',r)); console.log('fini');
}
await b.close();
