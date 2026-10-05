export const TAU = Math.PI * 2;

// Artistic slow-motion four-wing cycle. Front and rear pairs are quarter-cycle
// offset. Opposite wings mirror around the longitudinal axis.
export function wingAngle(time, side, hind = false) {
  return side * (0.09 + Math.sin(time * 2.4 + (hind ? Math.PI / 2 : 0)) * 0.17);
}

export function clampExpansion(value) {
  const number = Number(value);
  return Number.isFinite(number) ? Math.min(1, Math.max(0, number / 100)) : 0;
}

export function expansionOffset(name, amount) {
  const side = name.includes("_L") ? -1 : 1;
  if (name.startsWith("Wing_"))
    return [
      side * amount * 1.05,
      amount * 0.65,
      name.includes("Fore") ? amount * 0.3 : -amount * 0.3,
    ];
  if (name === "Head") return [0, amount * 0.18, amount * 0.75];
  if (name.startsWith("Abdomen_")) return [0, 0, -amount * 0.16];
  if (name.startsWith("Leg_")) return [side * amount * 0.24, -amount * 0.22, 0];
  return [0, 0, 0];
}
