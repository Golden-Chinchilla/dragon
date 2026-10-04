import test from 'node:test';
import assert from 'node:assert/strict';
import {createNavigation} from '../src/world/navigation.js';
const bounds={x:5,z:5};
test('path goes around a building footprint and reaches destination',()=>{
 const nav=createNavigation(bounds,[{x:0,z:0,w:2,d:2}]);
 const path=nav.findPath({x:0,z:3},{x:0,z:-3.2});
 assert.ok(path.length>0);
 assert.deepEqual(path.at(-1),{x:0,z:-3.2});
 assert.ok(path.every(p=>!nav.blocked(p.x,p.z)));
 assert.ok(path.some(p=>Math.abs(p.x)>1.2));
});
test('rejects destination within a building or outside the map',()=>{
 const nav=createNavigation(bounds,[{x:0,z:0,w:2,d:2}]);
 assert.deepEqual(nav.findPath({x:0,z:3},{x:0,z:0}),[]);
 assert.deepEqual(nav.findPath({x:0,z:3},{x:10,z:0}),[]);
});
test('unreachable destination does not create a path through a wall',()=>{
 const nav=createNavigation(bounds,[{x:0,z:0,w:12,d:.5}]);
 assert.deepEqual(nav.findPath({x:0,z:3},{x:0,z:-3}),[]);
});
test('click navigation cannot route through unexplored ground',()=>{
 const nav=createNavigation(bounds,[]);
 const explored=(x,z)=>Math.abs(x)<1&&z>0;
 assert.ok(nav.findPath({x:0,z:3},{x:0,z:1.2},explored).length>0);
 assert.deepEqual(nav.findPath({x:0,z:3},{x:0,z:-2},explored),[]);
});
