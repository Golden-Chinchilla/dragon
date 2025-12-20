export default function Lights() {
  return (
    <>
      <hemisphereLight color="#9ab7ff" groundColor="#4b4135" intensity={0.8} />
      <ambientLight intensity={0.3} />
      <spotLight
        position={[0, 8, 0]}
        angle={0.7}
        penumbra={0.5}
        intensity={3}
        color="#ffd9a1"
        castShadow
        shadow-mapSize={[1024, 1024]}
        shadow-bias={-0.0015}
        shadow-camera-near={1}
        shadow-camera-far={20}
        shadow-camera-fov={35}
      />
      <directionalLight
        position={[4, 6, 5]}
        intensity={1.5}
        color="#ffbb73"
        castShadow
      />
      <directionalLight
        position={[-3, 2, -2]}
        intensity={0.8}
        color="#9cbcff"
      />
      <pointLight position={[0, 3, 2]} intensity={0.6} color="#ffd9a1" />
    </>
  );
}
