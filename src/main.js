import "./style.css";
import { createStudioPipeline } from "./studio.js";
import * as THREE from "three";
import { OrbitControls } from "three/addons/controls/OrbitControls.js";
import { GLTFLoader } from "three/addons/loaders/GLTFLoader.js";
import { RoomEnvironment } from "three/addons/environments/RoomEnvironment.js";
import { wingAngle, clampExpansion, expansionOffset } from "./kinematics.js";

const $ = (selector) => document.querySelector(selector);
const canvas = $("#specimen");
const reducedMotion = window.matchMedia(
  "(prefers-reduced-motion: reduce)",
).matches;
const state = {
  running: !reducedMotion,
  expanded: 0,
  expansion: 0,
  time: 0,
  view: "overview",
  ready: false,
};
const descriptions = {
  overview: [
    "01 / 04",
    "精密，共生。",
    "层叠机芯、密排复眼与薄壳腹甲。旋转、靠近，观察承力、传动与外壳之间的装配关系。",
  ],
  head: [
    "01 / 04",
    "微观之眼。",
    "密排六角透镜覆盖曲面复眼，外圈由螺钉锁紧。中央虹膜镜组与分节触须构成完整的感知组件。",
  ],
  thorax: [
    "02 / 04",
    "力量的起点。",
    "齿冠、桥板和滚珠轴承层层叠置，下方露出连续铜线绕组。翼根叉架与细推杆连接四翼。",
  ],
  wing: [
    "03 / 04",
    "轻，亦有骨。",
    "细薄的前缘梁与分叉主脉，围合不规则的翼膜分区。根部双层叉板、微型紧固件和配重共同构成翼面。",
  ],
  top: [
    "04 / 04",
    "秩序的轮廓。",
    "十节薄壳腹甲沿中轴逐段收束，接缝露出内脊与细拉杆。双杆机械足、波纹护套与分节抓钩位于下方。",
  ],
};

async function start() {
  const renderer = new THREE.WebGLRenderer({
    canvas,
    antialias: true,
    alpha: true,
    powerPreference: "high-performance",
  });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 1.8));
  renderer.setClearColor(0x000000, 0);
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 0.95;
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFShadowMap;
  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(34, 1, 0.1, 120);
  const pipeline = createStudioPipeline(renderer, scene, camera);
  const controls = new OrbitControls(camera, canvas);
  controls.enableDamping = true;
  controls.dampingFactor = 0.07;
  controls.minDistance = 2;
  controls.maxDistance = 60;
  controls.maxPolarAngle = Math.PI * 0.85;
  controls.enablePan = true;
  controls.autoRotateSpeed = 0.45;

  const pmrem = new THREE.PMREMGenerator(renderer);
  const room = new RoomEnvironment();
  const environment = pmrem.fromScene(room, 0.04);
  scene.environment = environment.texture;
  scene.environmentIntensity = 0.85;
  room.dispose();
  pmrem.dispose();
  scene.add(new THREE.HemisphereLight(0xd7e9f1, 0x30333a, 0.75));
  function light(color, intensity, p) {
    const l = new THREE.DirectionalLight(color, intensity);
    l.position.set(...p);
    scene.add(l);
    return l;
  }
  const key = light(0xe8efff, 2.6, [-3, 7, 5]);
  key.castShadow = true;
  key.shadow.mapSize.set(2048, 2048);
  Object.assign(key.shadow.camera, { left: -8, right: 8, top: 8, bottom: -8 });
  key.shadow.bias = -0.001;
  key.shadow.normalBias = 0.025;
  light(0xa3ccd9, 1.4, [5, 3, -5]);
  light(0xffd4a1, 1.8, [-6, 2, -2]);
  const floor = new THREE.Mesh(
    new THREE.PlaneGeometry(100, 100),
    new THREE.ShadowMaterial({ opacity: 0.055 }),
  );
  floor.rotation.x = -Math.PI / 2;
  floor.position.y = -1.72;
  floor.receiveShadow = true;
  scene.add(floor);

  const [asset, report] = await Promise.all([
    new GLTFLoader().loadAsync("/assets/dragonfly.glb", (event) => {
      if (event.total)
        $("#load-message").textContent =
          `正在装配机械生命 · ${Math.round((event.loaded / event.total) * 100)}%`;
    }),
    fetch("/assets/dragonfly.json").then((r) => {
      if (!r.ok) throw new Error("资产信息加载失败");
      return r.json();
    }),
  ]);
  const model = asset.scene;
  scene.add(model);
  const root = model.getObjectByName("Dragonfly");
  const nodes = {};
  const moving = [];
  model.traverse((object) => {
    nodes[object.name] = object;
    if (/^(Wing_|Head$|Abdomen_|Leg_)/.test(object.name) && !object.isMesh) {
      object.userData.rest = object.position.clone();
      object.userData.baseRotation = object.quaternion.clone();
      moving.push(object);
    }
    if (object.isMesh) {
      object.castShadow = true;
      object.receiveShadow = true;
      const material = object.material;
      if (!material.transparent) object.layers.enable(1);
      material.envMapIntensity = 1.15;
      if (material.name.startsWith("07")) {
        material.side = THREE.DoubleSide;
        material.depthWrite = false;
        object.castShadow = false;
      }
      if (material.name.startsWith("01")) material.side = THREE.DoubleSide;
    }
  });
  $("#part-count").textContent = report.sourceParts.toLocaleString("en-US");

  const views = {
    overview: { p: [7.0, 9.4, 11.5], t: [0, -0.7, -0.95] },
    thorax: { p: [2.7, 3.5, 3.5], t: [0, 0.1, 0] },
    head: { p: [1.8, 2.4, 4.8], t: [0, 0.1, 1.5] },
    wing: { p: [2.8, 6.2, 3.3], t: [2.1, 0.15, 0] },
    top: { p: [0, 15.3, -0.85], t: [0, 0, -0.85] },
  };
  let transition = null;
  const goalPosition = new THREE.Vector3();
  const goalTarget = new THREE.Vector3();
  const mobile = () => canvas.clientWidth < 700;
  function setView(name, immediate = false) {
    state.view = name;
    $("#app").classList.toggle("inspecting", name !== "overview");
    const view = views[name];
    goalTarget.set(...view.t);
    goalPosition.set(...view.p);
    if (mobile() && (name === "overview" || name === "top")) {
      const width = name === "top" ? 10.7 : 11.0;
      const distance =
        width /
        (2 *
          Math.tan(THREE.MathUtils.degToRad(camera.fov / 2)) *
          camera.aspect);
      goalPosition
        .sub(goalTarget)
        .normalize()
        .multiplyScalar(distance)
        .add(goalTarget);
      if (name === "overview") {
        goalPosition.x -= 0.5;
        goalTarget.x -= 0.5;
      }
    }
    if (name === "overview" || name === "top") {
      goalPosition
        .sub(goalTarget)
        .multiplyScalar(1 + state.expanded * 0.23)
        .add(goalTarget);
    }
    transition = {
      p: camera.position.clone(),
      t: controls.target.clone(),
      elapsed: 0,
    };
    if (immediate) {
      camera.position.copy(goalPosition);
      controls.target.copy(goalTarget);
      transition = null;
    }
    controls.autoRotate = false;
    $("#rotate").setAttribute("aria-pressed", "false");
    for (const button of document.querySelectorAll("[data-view]")) {
      const active = button.dataset.view === name;
      button.classList.toggle("active", active);
      button.setAttribute("aria-pressed", String(active));
    }
    const description = descriptions[name];
    $("#detail-index").textContent = description[0];
    $("#detail-title").textContent = description[1];
    $("#detail-copy").textContent = description[2];
    controls.update();
  }
  controls.addEventListener("start", () => {
    transition = null;
    controls.autoRotate = false;
    $("#rotate").setAttribute("aria-pressed", "false");
  });
  document
    .querySelectorAll("[data-view]")
    .forEach((button) =>
      button.addEventListener("click", () => setView(button.dataset.view)),
    );
  document
    .querySelectorAll("[data-focus]")
    .forEach((button) =>
      button.addEventListener("click", () => setView(button.dataset.focus)),
    );
  $("#explode").addEventListener("input", (event) => {
    state.expanded = clampExpansion(event.target.value);
    $("#explode-value").textContent = `${Math.round(state.expanded * 100)}%`;
    if (state.view === "overview" || state.view === "top") setView(state.view);
  });
  function updateMotionLabel() {
    $("#pause").setAttribute("aria-pressed", String(!state.running));
    $("#pause-label").textContent = state.running ? "暂停运转" : "继续运转";
    $("#pause-icon").textContent = state.running ? "Ⅱ" : "▷";
    $("#motion-status").textContent = state.running ? "低速运转" : "静态观察";
  }
  $("#pause").addEventListener("click", () => {
    state.running = !state.running;
    updateMotionLabel();
  });
  $("#rotate").addEventListener("click", () => {
    transition = null;
    controls.autoRotate = !controls.autoRotate;
    $("#rotate").setAttribute("aria-pressed", String(controls.autoRotate));
  });
  canvas.addEventListener("keydown", (event) => {
    if (
      ![
        "ArrowLeft",
        "ArrowRight",
        "ArrowUp",
        "ArrowDown",
        "+",
        "=",
        "-",
      ].includes(event.key)
    )
      return;
    event.preventDefault();
    transition = null;
    const delta = camera.position.clone().sub(controls.target);
    const spherical = new THREE.Spherical().setFromVector3(delta);
    if (event.key === "ArrowLeft") spherical.theta -= 0.1;
    if (event.key === "ArrowRight") spherical.theta += 0.1;
    if (event.key === "ArrowUp") spherical.phi -= 0.1;
    if (event.key === "ArrowDown") spherical.phi += 0.1;
    if (event.key === "+" || event.key === "=") spherical.radius *= 0.9;
    if (event.key === "-") spherical.radius *= 1.1;
    spherical.phi = THREE.MathUtils.clamp(
      spherical.phi,
      0.05,
      controls.maxPolarAngle,
    );
    spherical.radius = THREE.MathUtils.clamp(
      spherical.radius,
      controls.minDistance,
      controls.maxDistance,
    );
    camera.position
      .copy(controls.target)
      .add(delta.setFromSpherical(spherical));
    controls.update();
  });
  let wasMobile = mobile();
  function resize() {
    const width = canvas.parentElement.clientWidth;
    const height = canvas.parentElement.clientHeight;
    renderer.setSize(width, height, false);
    pipeline.resize(width, height);
    camera.aspect = width / height;
    camera.updateProjectionMatrix();
    $(".view-hint > span").innerHTML = mobile()
      ? '单指旋转<span class="hint-divider">/</span>双指缩放'
      : '拖动旋转<span class="hint-divider">/</span>滚轮靠近';
    if (wasMobile !== mobile()) {
      wasMobile = mobile();
      setView(state.view, true);
    }
  }
  window.addEventListener("resize", resize);
  resize();
  setView("overview", true);
  updateMotionLabel();
  const hotspots = [...document.querySelectorAll("[data-focus]")].map(
    (element) => ({
      element,
      node: nodes[
        element.dataset.focus === "head"
          ? "Head"
          : element.dataset.focus === "thorax"
            ? "Thorax"
            : "Wing_R_Fore"
      ],
      offset:
        element.dataset.focus === "wing"
          ? new THREE.Vector3(2.5, 0.05, 0.35)
          : new THREE.Vector3(0, 0.7, 0),
    }),
  );
  const point = new THREE.Vector3();
  const rotationAxis = new THREE.Vector3(0, 0, 1);
  const axisY = new THREE.Vector3(0, 1, 0);
  const linkStart = new THREE.Vector3();
  const linkEnd = new THREE.Vector3();
  const linkDirection = new THREE.Vector3();
  const q = new THREE.Quaternion();
  let previous = performance.now();
  let hidden = false;
  document.addEventListener("visibilitychange", () => {
    hidden = document.hidden;
    previous = performance.now();
  });
  renderer.setAnimationLoop((now) => {
    const dt = Math.min((now - previous) / 1000, 0.05);
    previous = now;
    if (hidden) return;
    if (state.running) state.time += dt;
    state.expansion +=
      (state.expanded - state.expansion) * (1 - Math.exp(-dt * 8));
    const t = state.time;
    for (const node of moving) {
      const offset = expansionOffset(node.name, state.expansion);
      node.position.copy(node.userData.rest).add(point.set(...offset));
      node.quaternion.copy(node.userData.baseRotation);
      if (node.name.startsWith("Wing_")) {
        const side = node.name.includes("_L") ? -1 : 1;
        q.setFromAxisAngle(
          rotationAxis,
          wingAngle(t, side, node.name.includes("Hind")) *
            (1 - state.expansion * 0.8),
        );
        node.quaternion.premultiply(q);
      }
      if (node.name.startsWith("Abdomen_")) {
        const index = Number(node.name.slice(-2));
        q.setFromAxisAngle(
          axisY,
          Math.sin(t * 0.75 - index * 0.3) * 0.018 * (1 - state.expansion),
        );
        node.quaternion.premultiply(q);
      }
    }
    // glTF empty transforms are already converted to Y-up; gears rotate in XZ.
    for (const [name, speed] of [
      ["Gear_A", 0.65],
      ["Gear_B", (-0.65 * 36) / 32],
      ["Gear_C", (-0.65 * 36) / 30],
    ]) {
      const gear = nodes[name];
      if (!gear.userData.base) gear.userData.base = gear.quaternion.clone();
      gear.quaternion
        .copy(gear.userData.base)
        .premultiply(q.setFromAxisAngle(axisY, t * speed));
    }
    root.position.y = Math.sin(t * 0.7) * 0.025;
    for (const side of [-1, 1]) {
      for (const row of ["Fore", "Hind"]) {
        const label = `${side < 0 ? "L" : "R"}_${row}`;
        const wing = nodes[`Wing_${label}`];
        const link = nodes[`DriveRod_${label}`];
        if (!link) continue;
        const yy = row === "Fore" ? -0.46 : 0.43;
        linkStart.set(side * 0.24, 0.46, -yy);
        // Keep the pushrod beside the drive assembly during exploded inspection.
        linkEnd
          .set(side * 0.16, -0.03, 0)
          .applyQuaternion(wing.quaternion)
          .add(wing.userData.rest);
        linkDirection.subVectors(linkEnd, linkStart);
        link.position.copy(linkStart);
        const length = linkDirection.length();
        link.quaternion.setFromUnitVectors(axisY, linkDirection.normalize());
        link.scale.set(1, length, 1);
      }
    }
    if (transition) {
      transition.elapsed += dt;
      const k = Math.min(1, transition.elapsed / 0.85);
      const ease = 1 - (1 - k) ** 3;
      camera.position.lerpVectors(transition.p, goalPosition, ease);
      controls.target.lerpVectors(transition.t, goalTarget, ease);
      if (k === 1) transition = null;
    }
    controls.update(dt);
    scene.updateMatrixWorld();
    for (const hotspot of hotspots) {
      point.copy(hotspot.offset);
      hotspot.node.localToWorld(point);
      point.project(camera);
      const x = (point.x * 0.5 + 0.5) * canvas.clientWidth;
      const y = (-point.y * 0.5 + 0.5) * canvas.clientHeight;
      const visible =
        state.view === "overview" &&
        state.expansion < 0.05 &&
        point.z < 1 &&
        x > 20 &&
        x < canvas.clientWidth - 20 &&
        y > 100 &&
        y < canvas.clientHeight - 200;
      hotspot.element.style.left = `${x}px`;
      hotspot.element.style.top = `${y}px`;
      hotspot.element.style.opacity = visible ? "1" : "0";
      hotspot.element.style.pointerEvents = visible ? "auto" : "none";
      hotspot.element.tabIndex = visible ? 0 : -1;
      hotspot.element.setAttribute("aria-hidden", String(!visible));
    }
    pipeline.render(dt);
  });
  state.ready = true;
  document
    .querySelectorAll("button[disabled], input[disabled]")
    .forEach((el) => {
      el.disabled = false;
    });
  $("#loading").classList.add("loaded");
  // Small read-only QA surface for checking actual loaded geometry and motion.
  window.__odonata = {
    state,
    report,
    renderer,
    scene,
    camera,
    controls,
    nodes,
  };
  canvas.addEventListener("webglcontextlost", (event) => {
    event.preventDefault();
    $("#loading").classList.remove("loaded");
    $("#load-message").textContent = "图形上下文已中断，请重新加载。";
    $("#retry").hidden = false;
  });
}
$("#retry").addEventListener("click", () => window.location.reload());
start().catch((error) => {
  console.error(error);
  $("#load-message").textContent = "模型加载未完成，请检查连接后重试。";
  $("#retry").hidden = false;
});
