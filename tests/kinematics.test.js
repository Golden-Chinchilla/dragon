import test from "node:test";
import assert from "node:assert/strict";
import {
  wingAngle,
  clampExpansion,
  expansionOffset,
} from "../src/kinematics.js";

test("opposite wings mirror and stay within the mechanical display envelope", () => {
  for (let time = 0; time < 30; time += 0.017) {
    for (const hind of [false, true]) {
      const right = wingAngle(time, 1, hind);
      assert.equal(wingAngle(time, -1, hind), -right);
      assert.ok(right >= -0.081 && right <= 0.261);
    }
  }
});
test("front and rear wings have a quarter-cycle phase separation", () => {
  const quarterCycle = Math.PI / (2 * 2.4);
  for (const t of [0, 0.7, 2.1, 10])
    assert.ok(
      Math.abs(wingAngle(t, 1, true) - wingAngle(t + quarterCycle, 1, false)) <
        1e-12,
    );
});
test("expansion input is bounded and rejects nonfinite values", () => {
  for (const [input, expected] of [
    [-40, 0],
    [1000, 1],
    ["50", 0.5],
    ["x", 0],
    [Infinity, 0],
  ])
    assert.equal(clampExpansion(input), expected);
});
test("assembly expansion is reversible and mirrors wings without moving the thorax", () => {
  for (const name of [
    "Head",
    "Wing_L_Fore",
    "Wing_R_Hind",
    "Abdomen_05",
    "Leg_R_1",
    "Thorax",
  ]) {
    assert.ok(expansionOffset(name, 0).every((v) => v === 0));
    assert.ok(expansionOffset(name, 1).every(Number.isFinite));
  }
  assert.equal(
    expansionOffset("Wing_L_Fore", 1)[0],
    -expansionOffset("Wing_R_Fore", 1)[0],
  );
  assert.deepEqual(expansionOffset("Thorax", 1), [0, 0, 0]);
  assert.ok(expansionOffset("Head", 1)[2] > 0);
  assert.ok(expansionOffset("Abdomen_00", 1)[2] < 0);
});
