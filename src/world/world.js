import * as THREE from 'three';
import {createNavigation} from './navigation.js';
import {extendTerrain} from './terrain.js';
import {createExploration,encodeProgress,decodeProgress,MAP_ID} from './exploration.js';
export function createWorld(view,assets) {
 const {scene,camera,center}=view,{courtyard,traveler,metadata}=assets;
 courtyard.traverse(o=>{if(o.isMesh){o.castShadow=true;o.receiveShadow=true;if(o.material.name==='Amber window glass'){o.material.color.set('#5b300c');o.material.emissive.set('#ffb952');o.material.emissiveIntensity=1.8;}}});traveler.traverse(o=>{if(o.isMesh){o.castShadow=true;o.receiveShadow=true;}});
 scene.add(courtyard,traveler);traveler.position.fromArray(metadata.spawn);
 const limbs=['LeftLeg','RightLeg','LeftArm','RightArm'].map(name=>traveler.getObjectByName(name)).filter(Boolean);
 const rest=limbs.map(o=>o.quaternion.clone());
 const terrain=extendTerrain(scene,assets),nav=createNavigation(terrain.bounds,terrain.colliders);
 let saved=null;try{saved=decodeProgress(localStorage.getItem(MAP_ID));}catch{ /* Storage may be unavailable. */ }
 const exploration=createExploration({data:saved?.data});if(saved&&!nav.blocked(...saved.position))traveler.position.set(saved.position[0],0,saved.position[1]);exploration.reveal(traveler.position.x,traveler.position.z);view.follow(traveler.position,0,true);
 let lastReveal=traveler.position.clone(),revealClock=0,saveClock=0,manualCamera=false;
 function save(){try{localStorage.setItem(MAP_ID,encodeProgress(exploration,traveler.position));document.querySelector('#save-state').textContent='探索已保存';}catch{document.querySelector('#save-state').textContent='本次探索仅保存在当前页面';}}
 addEventListener('pagehide',save);addEventListener('visibilitychange',()=>{if(document.hidden)save();});
 const proxies=terrain.colliders.filter(o=>['守灯人的家','药草小屋','水井','林间旅舍'].includes(o.name)).map(o=>{
  const height=o.name==='守灯人的家'?5.5:o.name==='药草小屋'?3.6:2.8;const m=new THREE.Mesh(new THREE.BoxGeometry(o.w,height,o.d),new THREE.MeshBasicMaterial({visible:false}));m.position.set(o.x,height/2,o.z);m.userData.name=o.name;scene.add(m);return m;
 });
 const lamps=[...metadata.lamps,...terrain.lamps].map(([x,y,z])=>{const light=new THREE.PointLight('#ffbd65',12,7,2);light.position.set(x,y,z);scene.add(light);return light;});
 const heroLight=new THREE.PointLight('#ffc780',10,5.5,2);traveler.add(heroLight);heroLight.position.set(.3,.5,0);
 const marker=new THREE.Mesh(new THREE.RingGeometry(.15,.21,24),new THREE.MeshBasicMaterial({color:'#e7c98b',side:THREE.DoubleSide,transparent:true,opacity:.8}));marker.rotation.x=-Math.PI/2;marker.position.y=.16;marker.visible=false;scene.add(marker);
 const particleGeometry=new THREE.BufferGeometry();const positions=new Float32Array(32*3),origins=[];
 for(let i=0;i<32;i++){const x=Math.sin(i*17)*8,z=Math.cos(i*13)*7;origins.push({x,z});positions.set([x,.4,z],i*3);}particleGeometry.setAttribute('position',new THREE.BufferAttribute(positions,3));
 const particles=new THREE.Points(particleGeometry,new THREE.PointsMaterial({color:'#e8d496',size:.04,transparent:true,opacity:.7,depthWrite:false}));scene.add(particles);
 const keys=new Set();let path=[],time=0,paused=false,pointer=null;const ray=new THREE.Raycaster(),plane=new THREE.Plane(new THREE.Vector3(0,1,0),0);
 const descriptions={'守灯人的家':'石墙、旧木窗，炉火正等着晚归的人。','药草小屋':'迷迭香与鼠尾草，沿着窗台慢慢生长。','水井':'石头记得雨水，也记得村庄的每一个夏天。','林间旅舍':'穿过夜色，终于找到另一盏为你亮着的灯。'};
 function goTo(x,z){if(!exploration.visible(x,z)){document.querySelector('#place-note').textContent='这里尚未探索，向雾边走近一些。';return false;}const result=nav.findPath(traveler.position,{x,z},exploration.visible);if(!result.length)return false;manualCamera=false;path=result;marker.position.set(result.at(-1).x,.17,result.at(-1).z);marker.visible=true;return true;}
 const accepted=['ArrowLeft','ArrowRight','ArrowUp','ArrowDown','w','a','s','d'];
 addEventListener('keydown',e=>{const key=e.key.length===1?e.key.toLowerCase():e.key;if(accepted.includes(key)){e.preventDefault();keys.add(key);manualCamera=false;path=[];marker.visible=false;}});addEventListener('keyup',e=>keys.delete(e.key.length===1?e.key.toLowerCase():e.key));addEventListener('blur',()=>keys.clear());
 const canvas=view.renderer.domElement;
 canvas.addEventListener('pointerdown',e=>{pointer={x:e.clientX,y:e.clientY,cx:center.x,cz:center.z,moved:false};canvas.setPointerCapture(e.pointerId);});
 canvas.addEventListener('pointermove',e=>{if(!pointer)return;const dx=(e.clientX-pointer.x)/innerWidth*(camera.right-camera.left),dy=(e.clientY-pointer.y)/innerHeight*(camera.top-camera.bottom);if(Math.hypot(e.clientX-pointer.x,e.clientY-pointer.y)>7)pointer.moved=true;if(pointer.moved){manualCamera=true;center.x=THREE.MathUtils.clamp(pointer.cx-dx*Math.cos(view.angle)-dy*Math.sin(view.angle),-22,22);center.z=THREE.MathUtils.clamp(pointer.cz+dx*Math.sin(view.angle)-dy*Math.cos(view.angle),-22,22);view.position();}});
 canvas.addEventListener('pointerup',e=>{if(pointer&&!pointer.moved){ray.setFromCamera(new THREE.Vector2(e.clientX/innerWidth*2-1,1-e.clientY/innerHeight*2),camera);const hits=ray.intersectObjects(proxies);if(hits.length){const object=hits[0].object;if(!exploration.visible(object.position.x,object.position.z)){document.querySelector('#place-note').textContent='雾中还有未知的地方。';pointer=null;return;}const name=object.userData.name;document.querySelector('#place-title').textContent=name;document.querySelector('#place-note').textContent=descriptions[name];}else{const p=new THREE.Vector3();if(ray.ray.intersectPlane(plane,p))goTo(p.x,p.z);}}pointer=null;});canvas.addEventListener('pointercancel',()=>pointer=null);
 function update(dt){if(paused)return;time+=dt;let dx=0,dz=0;const h=(keys.has('ArrowRight')||keys.has('d')?1:0)-(keys.has('ArrowLeft')||keys.has('a')?1:0),v=(keys.has('ArrowDown')||keys.has('s')?1:0)-(keys.has('ArrowUp')||keys.has('w')?1:0);dx=h*Math.cos(view.angle)+v*Math.sin(view.angle);dz=-h*Math.sin(view.angle)+v*Math.cos(view.angle);
  if(path.length&&!h&&!v){const delta=new THREE.Vector2(path[0].x-traveler.position.x,path[0].z-traveler.position.z);if(delta.length()<.075)path.shift();else{dx=delta.x;dz=delta.y;}}
  const distance=Math.hypot(dx,dz);let moving=false;
  if(distance>.001){const amount=Math.min(dt*2.3,path.length&&!h&&!v?distance:Infinity);dx=dx/distance*amount;dz=dz/distance*amount;const before=traveler.position.clone();if(!nav.blocked(before.x+dx,before.z))traveler.position.x+=dx;if(!nav.blocked(traveler.position.x,before.z+dz))traveler.position.z+=dz;moving=before.distanceToSquared(traveler.position)>1e-8;if(moving){traveler.rotation.y=Math.atan2(dx,dz);manualCamera=false;}}
  limbs.forEach((o,i)=>{o.quaternion.copy(rest[i]);o.rotateX(moving?Math.sin(time*10+i%2*Math.PI)*.36:0);});
  if(!path.length)marker.visible=false;lamps.forEach((l,i)=>l.intensity=exploration.visible(l.position.x,l.position.z)?12+Math.sin(time*1.3+i)*.7:0);
  const data=particleGeometry.attributes.position;origins.forEach((o,i)=>data.setXYZ(i,o.x+Math.sin(time*.4+i)*.16,exploration.visible(o.x,o.z)?.35+Math.sin(time*.7+i)*.18:-100,o.z+Math.cos(time*.3+i)*.15));data.needsUpdate=true;
  revealClock+=dt;saveClock+=dt;if(revealClock>.1){if(lastReveal.distanceToSquared(traveler.position)>.005){exploration.revealTrail(lastReveal,traveler.position);lastReveal.copy(traveler.position);}revealClock=0;document.querySelector('#explored').textContent=exploration.percent.toFixed(1)+'%';document.querySelector('#coordinates').textContent=`${traveler.position.x.toFixed(1)} / ${traveler.position.z.toFixed(1)}`;}if(saveClock>2){save();saveClock=0;}if(!manualCamera)view.follow(traveler.position,dt);
 }
 const waypoints=[{x:0,z:2},{x:-3,z:2},{x:-9,z:0},{x:-12,z:-4},{x:-15,z:-9}];let waypoint=waypoints.reduce((best,p,i)=>Math.hypot(p.x-traveler.position.x,p.z-traveler.position.z)<Math.hypot(waypoints[best].x-traveler.position.x,waypoints[best].z-traveler.position.z)?i:best,0);
 function advance(){while(waypoint<waypoints.length&&Math.hypot(waypoints[waypoint].x-traveler.position.x,waypoints[waypoint].z-traveler.position.z)<.6)waypoint++;if(waypoint===waypoints.length){document.querySelector('#place-note').textContent='你已抵达林间旅舍，可以继续自由探索。';return;}const p=waypoints[waypoint],dx=p.x-traveler.position.x,dz=p.z-traveler.position.z,d=Math.hypot(dx,dz),step=Math.min(d,3.3);goTo(traveler.position.x+dx/d*step,traveler.position.z+dz/d*step);}
 return {update,goTo,advance,exploration,save,position:traveler.position,pause(){paused=!paused;return paused;},reset(){keys.clear();path=[];marker.visible=false;traveler.position.fromArray(metadata.spawn);traveler.rotation.y=0;view.reset();manualCamera=false;view.follow(traveler.position,0,true);document.querySelector('#coordinates').textContent=`${traveler.position.x.toFixed(1)} / ${traveler.position.z.toFixed(1)}`;lastReveal.copy(traveler.position);exploration.reveal(traveler.position.x,traveler.position.z);waypoint=0;save();},restart(){exploration.cells.fill(0);this.reset();},metadata};
}
