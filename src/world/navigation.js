export function createNavigation(bounds, obstacles, step = .4) {
  const blocked = (x, z) => Math.abs(x) > bounds.x - .25 || Math.abs(z) > bounds.z - .25 || obstacles.some(o => Math.abs(x - o.x) < o.w / 2 + .2 && Math.abs(z - o.z) < o.d / 2 + .2);
  function findPath(start, destination, allowed = () => true) {
    const startCell = [Math.round(start.x / step), Math.round(start.z / step)];
    const endCell = [Math.round(destination.x / step), Math.round(destination.z / step)];
    if (blocked(endCell[0] * step, endCell[1] * step) || !allowed(endCell[0]*step,endCell[1]*step)) return [];
    const id = ([x,z]) => `${x},${z}`;
    const queue = [startCell], parents = new Map([[id(startCell), null]]);
    let found = false;
    for (let i = 0; i < queue.length; i++) {
      const current = queue[i];
      if (id(current) === id(endCell)) { found = true; break; }
      for (const [dx,dz] of [[1,0],[-1,0],[0,1],[0,-1]]) {
        const next = [current[0]+dx,current[1]+dz];
        if (parents.has(id(next)) || blocked(next[0]*step,next[1]*step) || !allowed(next[0]*step,next[1]*step)) continue;
        parents.set(id(next),current); queue.push(next);
      }
    }
    if (!found) return [];
    const path = [];
    for (let cell = endCell; cell && id(cell) !== id(startCell); cell = parents.get(id(cell))) path.push({x:cell[0]*step,z:cell[1]*step});
    return path.reverse();
  }
  return {blocked,findPath};
}
