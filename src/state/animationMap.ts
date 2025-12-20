import { ANIMATION_LABELS } from "../animationMap";

const LABEL_TO_CLIP = new Map(
  ANIMATION_LABELS.map((item) => [item.label, item.name])
);

export function getClipNameByLabel(label: string): string | null {
  return LABEL_TO_CLIP.get(label) ?? null;
}
