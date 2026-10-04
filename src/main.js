import './style.css';
import {loadAssets} from './world/assets.js';
import {createRenderer} from './world/renderer.js';
import {createWorld} from './world/world.js';
import {createFogOfWar} from './world/fog-of-war.js';
const status=document.querySelector('#loading');
async function start(){
 const view=createRenderer(document.querySelector('#world'));
 const assets=await loadAssets(progress=>status.textContent=`夜色中的雾谷 · ${progress}%`);
 const world=createWorld(view,assets),fog=createFogOfWar(view,world.exploration);status.classList.add('loaded');status.setAttribute('aria-hidden','true');
 document.querySelectorAll('button').forEach(b=>b.disabled=false);
 let previous=performance.now();
 function frame(now){const dt=Math.min((now-previous)/1000,.05);previous=now;world.update(dt);fog.render(dt);requestAnimationFrame(frame);}requestAnimationFrame(frame);
 document.querySelector('#advance').addEventListener('click',()=>world.advance());
 document.querySelector('#angle').addEventListener('click',()=>view.rotate());
 document.querySelector('#reset').addEventListener('click',()=>world.reset());
 document.querySelector('#restart').addEventListener('click',()=>{world.restart();document.querySelector('#place-title').textContent='夜色中的雾谷';document.querySelector('#place-note').textContent='沿着石径向前，寻找雾里的下一盏灯。';});
 document.querySelector('#pause').addEventListener('click',e=>{const paused=world.pause();e.currentTarget.textContent=paused?'▷':'Ⅱ';e.currentTarget.setAttribute('aria-label',paused?'继续动画':'暂停动画');});
}
start().catch(error=>{console.error(error);status.textContent='世界暂时无法打开，请刷新重试。';status.classList.add('failed');});
