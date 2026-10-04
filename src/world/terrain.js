import * as THREE from 'three';
export function extendTerrain(scene,assets){
 const shared=new Map();assets.courtyard.traverse(o=>{if(o.isMesh)shared.set(o.material.name,o.material);});
 const prepare=root=>root.traverse(o=>{if(o.isMesh){o.material=shared.get(o.material.name)||o.material;o.castShadow=true;o.receiveShadow=true;}});
 assets.courtyard.traverse(o=>{if(o.isMesh&&o.material.name==='Earth cut edge')o.visible=false;});
 const groundMat=shared.get('Mossy soil').clone();const ground=new THREE.Mesh(new THREE.PlaneGeometry(48,48),groundMat);ground.rotation.x=-Math.PI/2;ground.position.y=-.06;ground.receiveShadow=true;scene.add(ground);
 const colliders=assets.metadata.colliders.map(o=>({...o}));
 const lodge=assets.lodge.clone();prepare(lodge);lodge.position.set(-15+6.3,0,-12+2.8);scene.add(lodge);colliders.push({name:'林间旅舍',x:-15,z:-12,w:3.7,d:3.7});
 const trail=[[-3,2],[-9,0],[-12,-4],[-15,-10]];
 const nearTrail=(x,z)=>trail.slice(1).some(([bx,bz],i)=>{const [ax,az]=trail[i],dx=bx-ax,dz=bz-az,t=THREE.MathUtils.clamp(((x-ax)*dx+(z-az)*dz)/(dx*dx+dz*dz),0,1);return Math.hypot(x-ax-dx*t,z-az-dz*t)<2.2;});
 const treePositions=[];for(let i=0;i<52;i++){const x=Math.sin(i*42.17)*21,z=Math.cos(i*17.43)*21;if(Math.abs(x)<10&&Math.abs(z)<9)continue;if(Math.abs(x+15)<3&&Math.abs(z+12)<3)continue;if(nearTrail(x,z)||Math.abs(x)<1.6)continue;treePositions.push([x,z]);}
 for(const [x,z] of treePositions){const tree=assets.tree.clone();prepare(tree);tree.position.set(x+7,0,z-6);scene.add(tree);colliders.push({name:'树干',x,z,w:.8,d:.8});}
 // Low-cost instanced stepping stones lead out of the authored courtyard into the woods.
 const stoneMaterial=shared.get('Hand cut sandstone'),stones=[];
 const points=[[0,7],[0,15],[-3,2],[-9,0],[-12,-4],[-15,-10]];
 for(let i=0;i<points.length-1;i++){if(i===1)continue;const [ax,az]=points[i],[bx,bz]=points[i+1],distance=Math.hypot(bx-ax,bz-az),count=Math.ceil(distance/.7);for(let j=0;j<count;j++){const t=j/count;stones.push([ax+(bx-ax)*t,az+(bz-az)*t]);}}
 const instanced=new THREE.InstancedMesh(new THREE.BoxGeometry(.52,.08,.56),stoneMaterial,stones.length*2),dummy=new THREE.Object3D();let index=0;
 for(const [x,z] of stones)for(const side of [-1,1]){dummy.position.set(x+side*.29,.025,z);dummy.rotation.y=Math.sin(index)*.1;dummy.updateMatrix();instanced.setMatrixAt(index++,dummy.matrix);}instanced.receiveShadow=true;scene.add(instanced);
 return {colliders,bounds:{x:24,z:24},landmarks:[{name:'林间旅舍',x:-15,z:-12,w:3.7,d:3.7}],lamps:[[-15,1.3,-9.7]]};
}
