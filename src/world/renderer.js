import * as THREE from 'three';
export function createRenderer(canvas) {
 const renderer=new THREE.WebGLRenderer({canvas,antialias:true});
 renderer.setPixelRatio(Math.min(devicePixelRatio,1.75));renderer.shadowMap.enabled=true;renderer.shadowMap.type=THREE.PCFShadowMap;
 renderer.outputColorSpace=THREE.SRGBColorSpace;renderer.toneMapping=THREE.ACESFilmicToneMapping;renderer.toneMappingExposure=1.05;
 const scene=new THREE.Scene();scene.background=new THREE.Color('#0b1829');scene.fog=new THREE.FogExp2('#0b1829',.009);
 const camera=new THREE.OrthographicCamera(-15,15,15,-15,.1,120);
 const center=new THREE.Vector3(0,.7,0);let angle=Math.PI/4;
 function position(){camera.position.set(center.x+Math.sin(angle)*26,25,center.z+Math.cos(angle)*26);camera.lookAt(center);}
 function resize(){const aspect=innerWidth/innerHeight;const vertical=Math.max(7,8/aspect);camera.left=-vertical*aspect;camera.right=vertical*aspect;camera.top=vertical;camera.bottom=-vertical;camera.updateProjectionMatrix();renderer.setSize(innerWidth,innerHeight);position();}
 resize();addEventListener('resize',resize);
 scene.add(new THREE.HemisphereLight('#8db3d1','#09111d',.45));
 const sun=new THREE.DirectionalLight('#8aaad4',.65);sun.position.set(-8,16,5);sun.castShadow=true;sun.shadow.mapSize.set(2048,2048);Object.assign(sun.shadow.camera,{left:-15,right:15,top:15,bottom:-15,near:1,far:50});sun.shadow.normalBias=.035;sun.shadow.bias=-.0002;sun.shadow.radius=3;scene.add(sun);
 return {renderer,scene,camera,center,resize,position,get angle(){return angle;},rotate(){angle+=Math.PI/2;position();},follow(player,dt,snap=false){const factor=snap?1:1-Math.exp(-dt*5);center.x+=(player.x-center.x)*factor;center.z+=(player.z-center.z)*factor;position();},reset(){angle=Math.PI/4;position();}};
}
