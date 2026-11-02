// App card: a thin box. Front face samples the app's print texture; sides are
// dark glass. A glossy sweep crosses the face when selected, with a rim glow
// in the palette colour. Reflections are the box turned over, fading with
// height. Output premultiplied alpha into a transparent canvas.

struct U {
    mvp: mat4x4<f32>,
    model: mat4x4<f32>,
    glow: vec4<f32>,     // rgb, card height
    params: vec4<f32>,   // selected 0..1, reflection 0/1, sweep 0..2.2, floorY
};
@group(0) @binding(0) var<uniform> u: U;
@group(1) @binding(0) var tex: texture_2d<f32>;
@group(1) @binding(1) var samp: sampler;

struct VIn {
    @location(0) pos: vec3<f32>,
    @location(1) nrm: vec3<f32>,
    @location(2) uv: vec2<f32>,
};

struct VOut {
    @builtin(position) position: vec4<f32>,
    @location(0) nrm: vec3<f32>,
    @location(1) uv: vec2<f32>,
    @location(2) local: vec3<f32>,
    @location(3) worldY: f32,
};

@vertex
fn vs_main(v: VIn) -> VOut {
    var out: VOut;
    out.position = u.mvp * vec4<f32>(v.pos, 1.0);
    out.nrm = normalize((u.model * vec4<f32>(v.nrm, 0.0)).xyz);
    out.uv = v.uv;
    out.local = v.pos;
    out.worldY = (u.model * vec4<f32>(v.pos, 1.0)).y;
    return out;
}

@fragment
fn fs_main(in: VOut) -> @location(0) vec4<f32> {
    let sel = u.params.x;
    let refl = u.params.y;
    let sweep = u.params.z;
    let floorY = u.params.w;
    let n = normalize(in.nrm);
    let L = normalize(vec3<f32>(-0.4, 0.7, 0.6));
    let V = vec3<f32>(0.0, 0.0, 1.0);
    let diff = max(dot(n, L), 0.0);
    let H = normalize(L + V);
    let spec = pow(max(dot(n, H), 0.0), 40.0);

    var col: vec3<f32>;
    let faceZ = select(0.03, -0.03, refl > 0.5);
    let front = step(0.029, in.local.z * sign(faceZ));
    // sample before branching: textureSample must stay in uniform control flow
    var uv = in.uv;
    if (refl > 0.5) {
        uv.x = 1.0 - uv.x;
    }
    let pr = textureSample(tex, samp, uv * vec2<f32>(0.62, 0.62) + vec2<f32>(0.2, 0.2)).rgb;
    if (front > 0.5) {
        let edge = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
        let bevel = smoothstep(0.0, 0.035, edge);
        col = mix(vec3<f32>(0.05, 0.05, 0.06), pr, bevel);
        let s = uv.x * 0.8 + (1.0 - uv.y) * 0.6;
        let gloss = exp(-pow((s - (sweep - 0.4)) * 6.0, 2.0)) * 0.55
                  + smoothstep(0.55, 1.1, s) * 0.10;
        col = col + vec3<f32>(gloss);
        col = col * (0.75 + 0.35 * diff) + spec * 0.15;
        let rim = (1.0 - smoothstep(0.0, 0.06, edge)) * sel;
        col = mix(col, u.glow.rgb, rim * 0.8);
    } else {
        col = vec3<f32>(0.06, 0.065, 0.075) * (0.5 + diff) + spec * 0.25;
        col = col + u.glow.rgb * sel * 0.25 * (0.3 + diff);
    }
    col = col * (0.9 + 0.25 * sel);

    var alpha = 1.0;
    if (refl > 0.5) {
        let height = max(u.glow.w, 0.01);
        let below = clamp((floorY - in.worldY) / height, 0.0, 1.0);
        alpha = 0.32 * pow(1.0 - below, 2.2);
        col = col * 0.75;
    }
    return vec4<f32>(col * alpha, alpha);
}
