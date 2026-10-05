import { HalfFloatType, WebGLRenderTarget } from "three";
import { EffectComposer } from "three/addons/postprocessing/EffectComposer.js";
import { RenderPass } from "three/addons/postprocessing/RenderPass.js";
import { GTAOPass } from "three/addons/postprocessing/GTAOPass.js";
import { OutputPass } from "three/addons/postprocessing/OutputPass.js";

// Layer 1 contains opaque specimen parts. Transparent wing film and the shadow
// floor must not become opaque occluders in the normal/depth pass.
class MechanicalAOPass extends GTAOPass {
  render(renderer, writeBuffer, readBuffer) {
    const mask = this.camera.layers.mask;
    const shadowAutoUpdate = renderer.shadowMap.autoUpdate;
    this.camera.layers.set(1);
    renderer.shadowMap.autoUpdate = false;
    try {
      super.render(renderer, writeBuffer, readBuffer);
    } finally {
      this.camera.layers.mask = mask;
      renderer.shadowMap.autoUpdate = shadowAutoUpdate;
    }
  }
}

export function createStudioPipeline(renderer, scene, camera) {
  const target = new WebGLRenderTarget(1, 1, {
    type: HalfFloatType,
    samples: 4,
  });
  const composer = new EffectComposer(renderer, target);
  composer.addPass(new RenderPass(scene, camera));
  const ao = new MechanicalAOPass(scene, camera, 1, 1);
  ao.updateGtaoMaterial({
    radius: 0.17,
    thickness: 0.16,
    distanceExponent: 1.5,
    distanceFallOff: 1,
    scale: 1,
    samples: 16,
  });
  ao.updatePdMaterial({ radius: 3, samples: 8 });
  ao.blendIntensity = 0.7;
  composer.addPass(ao);
  composer.addPass(new OutputPass());
  return {
    render: (dt) => composer.render(dt),
    resize(width, height) {
      composer.setSize(width, height);
      // Contact shading does not need full device-pixel resolution.
      ao.setSize(width, height);
    },
  };
}
