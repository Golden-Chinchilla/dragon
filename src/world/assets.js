import {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';
export async function loadAssets(onProgress) {
  const loader=new GLTFLoader();
  const metadataResponse=await fetch('/assets/courtyard.json');
  if(!metadataResponse.ok)throw new Error('场景配置加载失败');
  const metadata=await metadataResponse.json();
  const [courtyard,traveler,lodge,tree]=await Promise.all([
    loader.loadAsync('/assets/courtyard.glb',event=>{if(event.total)onProgress(Math.round(event.loaded/event.total*100));}),
    loader.loadAsync('/assets/traveler.glb'),loader.loadAsync('/assets/forest-lodge.glb'),loader.loadAsync('/assets/forest-tree.glb')
  ]);
  return {courtyard:courtyard.scene,traveler:traveler.scene,lodge:lodge.scene,tree:tree.scene,metadata};
}
