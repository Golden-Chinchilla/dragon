import { useEffect } from "react";
import * as THREE from "three";
import { useTexture } from "@react-three/drei";

import groundDiffuse from "../../public/texture/groundfloor/rock_embedded_floor_diff_1k.jpg";
import groundNormal from "../../public/texture/groundfloor/rock_embedded_floor_nor_gl_1k.png";
import groundRoughness from "../../public/texture/groundfloor/rock_embedded_floor_rough_1k.png";

export default function Ground() {
  const [map, normalMap, roughnessMap] = useTexture([
    groundDiffuse,
    groundNormal,
    groundRoughness,
  ]);

  useEffect(() => {
    [map, normalMap, roughnessMap].forEach((tex, idx) => {
      tex.wrapS = tex.wrapT = THREE.RepeatWrapping;
      tex.repeat.set(6, 6);
      tex.anisotropy = 8;
      if (idx === 0) tex.colorSpace = THREE.SRGBColorSpace;
      tex.needsUpdate = true;
    });
  }, [map, normalMap, roughnessMap]);

  return (
    <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, -0.8, 0]} receiveShadow>
      <planeGeometry args={[30, 30]} />
      <meshStandardMaterial
        map={map}
        normalMap={normalMap}
        roughnessMap={roughnessMap}
        normalScale={new THREE.Vector2(0.8, 0.8)}
        roughness={1}
      />
    </mesh>
  );
}
