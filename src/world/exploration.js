export const MAP_ID='hollow-night-v1';
export function createExploration({size=48,resolution=256,radius=5.5,data}={}){
 const cells=new Uint8Array(resolution*resolution);
 if(data&&data.length===cells.length)cells.set(data);
 const pixel=size/resolution;let revision=0;
 function sample(x,z){if(Math.abs(x)>size/2||Math.abs(z)>size/2)return 0;const col=Math.min(resolution-1,Math.max(0,Math.floor((x+size/2)/pixel))),row=Math.min(resolution-1,Math.max(0,Math.floor((z+size/2)/pixel)));return cells[row*resolution+col]/255;}
 function reveal(x,z){if(!Number.isFinite(x)||!Number.isFinite(z)||Math.abs(x)>size/2||Math.abs(z)>size/2)return false;let changed=false;
  const left=Math.max(0,Math.floor((x-radius+size/2)/pixel)),right=Math.min(resolution-1,Math.ceil((x+radius+size/2)/pixel)),top=Math.max(0,Math.floor((z-radius+size/2)/pixel)),bottom=Math.min(resolution-1,Math.ceil((z+radius+size/2)/pixel));
  for(let row=top;row<=bottom;row++)for(let col=left;col<=right;col++){const distance=Math.hypot((col+.5)*pixel-size/2-x,(row+.5)*pixel-size/2-z);const strength=Math.max(0,Math.min(1,(radius-distance)/1.15));const value=Math.round(strength*255),index=row*resolution+col;if(value>cells[index]){cells[index]=value;changed=true;}}
  if(changed)revision++;return changed;
 }
 function revealTrail(from,to){const count=Math.max(1,Math.ceil(Math.hypot(to.x-from.x,to.z-from.z)/(radius/3)));for(let i=0;i<=count;i++)reveal(from.x+(to.x-from.x)*i/count,from.z+(to.z-from.z)*i/count);}
 return {cells,size,resolution,reveal,revealTrail,sample,visible:(x,z)=>sample(x,z)>.65,get revision(){return revision;},get percent(){let sum=0;for(const value of cells)if(value>165)sum++;return sum/cells.length*100;}};
}
export function encodeProgress(exploration,position){let binary='';for(let i=0;i<exploration.cells.length;i+=8192)binary+=String.fromCharCode(...exploration.cells.subarray(i,i+8192));return JSON.stringify({id:MAP_ID,size:exploration.size,resolution:exploration.resolution,cells:btoa(binary),position:[position.x,position.z]});}
export function decodeProgress(text,size=48,resolution=256){try{const record=JSON.parse(text);if(record.id!==MAP_ID||record.size!==size||record.resolution!==resolution||!Array.isArray(record.position)||record.position.length!==2||!record.position.every(Number.isFinite))return null;const binary=atob(record.cells);if(binary.length!==resolution*resolution)return null;return {data:Uint8Array.from(binary,c=>c.charCodeAt(0)),position:record.position};}catch{return null;}}
