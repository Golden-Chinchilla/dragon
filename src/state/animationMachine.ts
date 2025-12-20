import { SectionConfig } from "../config/sections";
import { getClipNameByLabel } from "./animationMap";

export function getSectionLoopClip(section: SectionConfig): string | null {
  if (!section.animation.loopLabel) return null;
  return getClipNameByLabel(section.animation.loopLabel);
}

export function getSectionSequenceClips(section: SectionConfig): string[] {
  if (!section.animation.sequenceLabels) return [];
  return section.animation.sequenceLabels
    .map((label) => getClipNameByLabel(label))
    .filter((clip): clip is string => Boolean(clip));
}

export function getRandomOneShotClip(section: SectionConfig): string | null {
  const labels = section.animation.oneShotLabels;
  if (!labels || labels.length === 0) return null;
  const label = labels[Math.floor(Math.random() * labels.length)];
  return getClipNameByLabel(label);
}
