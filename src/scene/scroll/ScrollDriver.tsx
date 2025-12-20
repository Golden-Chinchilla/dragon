import { useRef } from "react";
import * as THREE from "three";
import { useFrame, useThree } from "@react-three/fiber";
import { useScroll } from "@react-three/drei";

import { SECTIONS, SectionConfig } from "../../config/sections";
import { CameraPreset, getCameraPreset } from "../cameraPresets";

type ScrollDriverProps = {
  onSectionChange: (section: SectionConfig) => void;
  modelBounds?: { center: THREE.Vector3; radius: number } | null;
  headTargetRef?: { current: THREE.Vector3 | null };
};

const DEFAULT_BOUNDS = {
  center: new THREE.Vector3(0, 0.6, 0),
  radius: 3,
};

export default function ScrollDriver({
  onSectionChange,
  modelBounds,
  headTargetRef,
}: ScrollDriverProps) {
  const scroll = useScroll();
  const lastSectionId = useRef<string | null>(null);
  const cameraTarget = useRef(new THREE.Vector3());
  const targetPresetRef = useRef<CameraPreset>(getCameraPreset(SECTIONS[0].id));
  const { camera } = useThree();

  useFrame(() => {
    const progress = scroll.offset;
    const current =
      SECTIONS.find(
        (section) => progress >= section.start && progress < section.end
      ) ?? SECTIONS[SECTIONS.length - 1];

    if (current.id !== lastSectionId.current) {
      lastSectionId.current = current.id;
      onSectionChange(current);
      targetPresetRef.current = getCameraPreset(current.id);
    }

    const preset = targetPresetRef.current;
    const bounds = modelBounds ?? DEFAULT_BOUNDS;
    const isPerspective = (camera as THREE.PerspectiveCamera)
      .isPerspectiveCamera;
    const baseFov = isPerspective
      ? (camera as THREE.PerspectiveCamera).fov
      : 50;
    const fov = preset.fov ?? baseFov;
    const radius = Math.max(bounds.radius, 0.01);
    const fitDistance = radius / Math.sin(THREE.MathUtils.degToRad(fov / 2));
    const distance = fitDistance * (preset.distanceFactor ?? 1.3) * 0.3;
    const direction = preset.direction.clone().normalize();
    const baseTarget = headTargetRef?.current ?? bounds.center;
    const target = baseTarget
      .clone()
      .add(preset.targetOffset.clone().multiplyScalar(radius));
    const desiredPosition = target
      .clone()
      .add(direction.multiplyScalar(distance));
    camera.position.lerp(desiredPosition, 0.08);
    cameraTarget.current.lerp(target, 0.08);
    camera.lookAt(cameraTarget.current);
    if (isPerspective && preset.fov) {
      const perspectiveCamera = camera as THREE.PerspectiveCamera;
      if (Math.abs(perspectiveCamera.fov - preset.fov) > 0.1) {
        perspectiveCamera.fov = THREE.MathUtils.lerp(
          perspectiveCamera.fov,
          preset.fov,
          0.08
        );
        perspectiveCamera.updateProjectionMatrix();
      }
    }
  });

  return null;
}
