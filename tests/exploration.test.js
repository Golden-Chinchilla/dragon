import test from 'node:test';
import assert from 'node:assert/strict';
import {createExploration,encodeProgress,decodeProgress} from '../src/world/exploration.js';
test('initial unknown, reveal stays revealed after player leaves',()=>{const e=createExploration();assert.equal(e.sample(0,0),0);e.reveal(0,0);assert.ok(e.visible(0,0));assert.equal(e.sample(15,15),0);const before=e.cells.slice();e.reveal(12,0);assert.ok(before.every((v,i)=>e.cells[i]>=v));assert.ok(e.visible(0,0));});
test('long movements reveal the trail without skipping ground',()=>{const e=createExploration();e.revealTrail({x:-15,z:0},{x:15,z:0});for(let x=-15;x<=15;x++)assert.ok(e.visible(x,0));assert.equal(e.sample(0,15),0);});
test('stationary reveal does not change revision, boundaries stay bounded',()=>{const e=createExploration();e.reveal(23,23);const revision=e.revision;e.reveal(23,23);assert.equal(e.revision,revision);assert.equal(e.reveal(30,0),false);assert.equal(e.sample(30,0),0);});
test('progress round trips and rejects wrong version or corrupt save',()=>{const e=createExploration();e.reveal(-3,7);const text=encodeProgress(e,{x:-3,z:7}),saved=decodeProgress(text);assert.deepEqual(saved.data,e.cells);assert.deepEqual(saved.position,[-3,7]);assert.equal(decodeProgress('{broken'),null);const record=JSON.parse(text);record.id='old-map';assert.equal(decodeProgress(JSON.stringify(record)),null);});
