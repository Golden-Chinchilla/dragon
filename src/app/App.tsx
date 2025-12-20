import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import * as THREE from "three";
import { Canvas } from "@react-three/fiber";
import { Scroll, ScrollControls, useProgress } from "@react-three/drei";

import { SECTIONS, SectionConfig } from "../config/sections";
import {
  getRandomOneShotClip,
  getSectionLoopClip,
  getSectionSequenceClips,
} from "../state/animationMachine";
import DragonScene from "../scene/DragonScene";
import ScrollDriver from "../scene/scroll/ScrollDriver";
import SectionsOverlay from "./sections/SectionsOverlay";

const ONE_SHOT_COOLDOWN_MS = 1600;

export default function App() {
  const [activeSection, setActiveSection] = useState<SectionConfig>(SECTIONS[0]);
  const [loopClip, setLoopClip] = useState<string | null>(null);
  const [oneShotClip, setOneShotClip] = useState<string | null>(null);
  const oneShotQueueRef = useRef<string[]>([]);
  const lastOneShotAtRef = useRef(0);
  const [modelBounds, setModelBounds] = useState<{
    center: THREE.Vector3;
    radius: number;
  } | null>(null);
  const headTargetRef = useRef<THREE.Vector3 | null>(null);

  const pageCount = useMemo(() => SECTIONS.length, []);

  useEffect(() => {
    const loopClip = getSectionLoopClip(activeSection);
    setLoopClip(loopClip);

    const sequence = getSectionSequenceClips(activeSection);
    if (sequence.length > 0) {
      oneShotQueueRef.current = sequence;
      setOneShotClip(sequence[0]);
      lastOneShotAtRef.current = Date.now();
    } else {
      oneShotQueueRef.current = [];
      setOneShotClip(null);
    }
  }, [activeSection]);

  const triggerOneShot = useCallback(() => {
    const now = Date.now();
    if (oneShotClip) return;
    if (now - lastOneShotAtRef.current < ONE_SHOT_COOLDOWN_MS) return;
    const clip = getRandomOneShotClip(activeSection);
    if (!clip) return;
    lastOneShotAtRef.current = now;
    setOneShotClip(clip);
  }, [activeSection, oneShotClip]);

  const handleOneShotComplete = useCallback(() => {
    const queue = oneShotQueueRef.current;
    if (queue.length > 0) {
      queue.shift();
      const next = queue[0] ?? null;
      setOneShotClip(next);
      if (next) return;
    }
    setOneShotClip(null);
  }, []);

  const handleHeadTarget = useCallback((position: THREE.Vector3 | null) => {
    if (!position) {
      headTargetRef.current = null;
      return;
    }
    if (!headTargetRef.current) {
      headTargetRef.current = position.clone();
      return;
    }
    headTargetRef.current.copy(position);
  }, []);

  return (
    <div className="relative h-screen w-screen bg-slate-950">
      <LoadingOverlay />
      <Canvas
        shadows={{ type: THREE.PCFSoftShadowMap }}
        camera={{ position: [0, 1.5, 3.5], fov: 55, near: 0.1, far: 100 }}
        gl={{
          outputColorSpace: THREE.SRGBColorSpace,
          toneMapping: THREE.ACESFilmicToneMapping,
          toneMappingExposure: 1.7,
        }}
      >
        <ScrollControls pages={pageCount} damping={0.2}>
          <DragonScene
            loopClip={loopClip}
            oneShotClip={oneShotClip}
            onOneShotComplete={handleOneShotComplete}
            onModelPointerDown={triggerOneShot}
            onModelPointerOver={triggerOneShot}
            onModelBounds={setModelBounds}
            onModelHeadTarget={handleHeadTarget}
          />
          <Scroll html>
            <SectionsOverlay />
          </Scroll>
          <ScrollDriver
            onSectionChange={setActiveSection}
            modelBounds={modelBounds}
            headTargetRef={headTargetRef}
          />
        </ScrollControls>
      </Canvas>
    </div>
  );
}

function LoadingOverlay() {
  const { active, progress } = useProgress();

  if (!active) return null;

  return (
    <div className="pointer-events-none absolute inset-0 z-20 flex items-center justify-center bg-slate-950/70 text-white">
      <div className="flex flex-col items-center gap-3">
        <div className="h-10 w-10 animate-spin rounded-full border-4 border-slate-200/20 border-t-slate-200" />
        <div className="text-xs font-semibold uppercase tracking-[0.25em]">
          Loading {Math.round(progress)}%
        </div>
      </div>
    </div>
  );
}
