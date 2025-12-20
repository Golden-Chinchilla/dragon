import { useEffect, useRef } from "react";
import * as THREE from "three";
import { useAnimations, useGLTF } from "@react-three/drei";
import { useFrame } from "@react-three/fiber";

type DragonModelProps = {
  modelPath: string;
  loopClip: string | null;
  oneShotClip: string | null;
  onAnimationsLoaded?: (names: string[]) => void;
  onOneShotComplete?: () => void;
  onBoundsReady?: (bounds: { center: THREE.Vector3; radius: number }) => void;
  onHeadTarget?: (position: THREE.Vector3 | null) => void;
  onPointerDown?: () => void;
  onPointerOver?: () => void;
};

export default function DragonModel({
  modelPath,
  loopClip,
  oneShotClip,
  onAnimationsLoaded,
  onOneShotComplete,
  onBoundsReady,
  onHeadTarget,
  onPointerDown,
  onPointerOver,
}: DragonModelProps) {
  const gltf = useGLTF(modelPath);
  const { actions, names, mixer } = useAnimations(gltf.animations, gltf.scene);
  const activeActionRef = useRef<THREE.AnimationAction | null>(null);
  const headNodeRef = useRef<THREE.Object3D | null>(null);
  const headPositionRef = useRef(new THREE.Vector3());

  useEffect(() => {
    onAnimationsLoaded?.(names);
  }, [names, onAnimationsLoaded]);

  useEffect(() => {
    if (oneShotClip) return;
    if (!loopClip) return;
    const nextAction = actions[loopClip];
    if (!nextAction) return;
    nextAction.setLoop(THREE.LoopRepeat, Infinity);
    const previousAction = activeActionRef.current;
    if (previousAction && previousAction !== nextAction) {
      previousAction.crossFadeTo(nextAction.reset().play(), 0.4, false);
    } else {
      nextAction.reset().fadeIn(0.4).play();
    }
    activeActionRef.current = nextAction;
  }, [actions, loopClip, oneShotClip]);

  useEffect(() => {
    if (!oneShotClip) return;
    const nextAction = actions[oneShotClip];
    if (!nextAction) return;
    const previousAction = activeActionRef.current;
    if (previousAction && previousAction !== nextAction) {
      previousAction.crossFadeTo(nextAction.reset().play(), 0.25, false);
    } else {
      nextAction.reset().fadeIn(0.25).play();
    }
    nextAction.setLoop(THREE.LoopOnce, 1);
    nextAction.clampWhenFinished = true;
    activeActionRef.current = nextAction;

    const handleFinished = (event: THREE.Event) => {
      if ((event as any).action === nextAction) {
        onOneShotComplete?.();
      }
    };

    mixer.addEventListener("finished", handleFinished);
    return () => {
      mixer.removeEventListener("finished", handleFinished);
    };
  }, [actions, mixer, oneShotClip, onOneShotComplete]);

  useEffect(() => {
    console.log("@@@", gltf);

    gltf.scene.traverse((obj) => {
      const mesh = obj as THREE.Mesh;
      if ((mesh as any).isMesh || (mesh as any).isSkinnedMesh) {
        mesh.castShadow = true;
        mesh.receiveShadow = true;
      }
    });
  }, [gltf.scene]);

  useEffect(() => {
    const box = new THREE.Box3().setFromObject(gltf.scene);
    const center = new THREE.Vector3();
    const size = new THREE.Vector3();
    box.getCenter(center);
    box.getSize(size);
    const radius = size.length() * 0.5;
    onBoundsReady?.({ center, radius });
  }, [gltf.scene, onBoundsReady]);

  useEffect(() => {
    let node: THREE.Object3D | null = null;
    const nodes = (gltf as any).nodes as Record<string, THREE.Object3D>;
    if (nodes) {
      const keys = Object.keys(nodes);
      const headKey =
        keys.find((key) => /head/i.test(key)) ??
        keys.find((key) => /neck/i.test(key));
      if (headKey) node = nodes[headKey] ?? null;
    }
    if (!node) {
      node =
        gltf.scene.getObjectByName("Bip001-Head") ??
        gltf.scene.getObjectByName("Head") ??
        gltf.scene.getObjectByName("Bip001-Neck") ??
        gltf.scene.getObjectByName("Neck") ??
        null;
    }
    headNodeRef.current = node;
  }, [gltf.scene]);

  useFrame(() => {
    if (!onHeadTarget) return;
    const headNode = headNodeRef.current;
    if (!headNode) {
      onHeadTarget(null);
      return;
    }
    headNode.getWorldPosition(headPositionRef.current);
    onHeadTarget(headPositionRef.current);
  });

  return (
    <primitive
      object={gltf.scene}
      position={[0, -0.5, 0]}
      onPointerDown={onPointerDown}
      onPointerOver={onPointerOver}
    />
  );
}
