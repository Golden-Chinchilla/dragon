import { Vector3 } from "three";

export type CameraPreset = {
  direction: Vector3;
  targetOffset: Vector3;
  fov?: number;
  distanceFactor?: number;
};

const PRESETS: Record<string, CameraPreset> = {
  "section-01": {
    direction: new Vector3(0.0, 0.01, 2.5),
    targetOffset: new Vector3(0, 0.05, 0),
    fov: 52,
    distanceFactor: 1.25,
  },
  "section-02": {
    direction: new Vector3(0.5, 0.35, 1.0),
    targetOffset: new Vector3(0.1, 0.1, 0),
    fov: 52,
    distanceFactor: 1.3,
  },
  "section-03": {
    direction: new Vector3(-0.6, 0.3, 1.0),
    targetOffset: new Vector3(-0.1, 0.2, 0),
    fov: 50,
    distanceFactor: 1.35,
  },
  "section-04": {
    direction: new Vector3(0.0, 0.01, 1.0),
    targetOffset: new Vector3(0, 0.05, 0),
    fov: 48,
    distanceFactor: 1.4,
  },
  "section-05": {
    direction: new Vector3(0.3, 0.6, 1.0),
    targetOffset: new Vector3(0.1, 0.5, 0),
    fov: 60,
    distanceFactor: 1.6,
  },
  "section-06": {
    direction: new Vector3(-0.35, 0.75, 0.85),
    targetOffset: new Vector3(0.0, 0.3, 0.0),
    fov: 58,
    distanceFactor: 1.6,
  },
};

export function getCameraPreset(sectionId: string): CameraPreset {
  return PRESETS[sectionId] ?? PRESETS["section-01"];
}
