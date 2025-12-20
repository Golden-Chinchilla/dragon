import * as THREE from "three";
import { Suspense } from "react";
import { useGLTF } from "@react-three/drei";

import { DEFAULT_MODEL_PATH, MODEL_PATHS } from "../config/models";
import DragonModel from "./DragonModel";
import Ground from "./Ground";
import Lights from "./Lights";

type DragonSceneProps = {
  loopClip: string | null;
  oneShotClip: string | null;
  modelPath?: string;
  onAnimationsLoaded?: (names: string[]) => void;
  onOneShotComplete?: () => void;
  onModelBounds?: (bounds: { center: THREE.Vector3; radius: number }) => void;
  onModelHeadTarget?: (position: THREE.Vector3 | null) => void;
  onModelPointerDown?: () => void;
  onModelPointerOver?: () => void;
};

export default function DragonScene({
  loopClip,
  oneShotClip,
  modelPath = DEFAULT_MODEL_PATH,
  onAnimationsLoaded,
  onOneShotComplete,
  onModelBounds,
  onModelHeadTarget,
  onModelPointerDown,
  onModelPointerOver,
}: DragonSceneProps) {
  return (
    <Suspense
      fallback={
        <mesh>
          <boxGeometry args={[1, 1, 1]} />
          <meshStandardMaterial color="#38bdf8" />
        </mesh>
      }
    >
      <color attach="background" args={["#0b1323"]} />
      <Lights />
      <DragonModel
        modelPath={modelPath}
        loopClip={loopClip}
        oneShotClip={oneShotClip}
        onAnimationsLoaded={onAnimationsLoaded}
        onOneShotComplete={onOneShotComplete}
        onBoundsReady={onModelBounds}
        onHeadTarget={onModelHeadTarget}
        onPointerDown={onModelPointerDown}
        onPointerOver={onModelPointerOver}
      />
      <Ground />
    </Suspense>
  );
}

useGLTF.preload(MODEL_PATHS.primary);
useGLTF.preload(MODEL_PATHS.secondary);
