// Grade overlay: vignette, a faint haze band, animated film grain.
// Drawn on top of everything with srcOver; output is premultiplied.

struct U {
    time: f32,
    width: f32,
    height: f32,
    grain: f32,
    vignette: f32,
    pad0: f32,
    pad1: f32,
    pad2: f32,
};
@group(0) @binding(0) var<uniform> u: U;

struct VOut {
    @builtin(position) position: vec4<f32>,
};

@vertex
fn vs_main(@builtin(vertex_index) idx: u32) -> VOut {
    var out: VOut;
    let x = f32(i32(idx) - 1) * 3.0;
    let y = f32(i32(idx & 1u) * 2 - 1) * 3.0;
    out.position = vec4<f32>(x, y, 0.0, 1.0);
    return out;
}

fn hash(p: vec2<f32>) -> f32 {
    let h = dot(p, vec2<f32>(127.1, 311.7));
    return fract(sin(h) * 43758.5453123);
}

@fragment
fn fs_main(in: VOut) -> @location(0) vec4<f32> {
    let res = vec2<f32>(u.width, u.height);
    let p = in.position.xy / res;

    // vignette: dark towards the corners
    let d = distance(p, vec2<f32>(0.5, 0.5)) * 1.25;
    let vig = smoothstep(0.45, 1.15, d) * u.vignette;

    // grain: per-pixel, re-rolled every frame; brighten or darken
    let frame = floor(u.time * 24.0);
    let g = hash(in.position.xy + vec2<f32>(frame * 13.7, frame * 7.3)) - 0.5;
    let lift = max(g, 0.0) * u.grain;
    let drop = max(-g, 0.0) * u.grain;

    // faint cool haze in the upper half
    let haze = (1.0 - smoothstep(0.0, 0.6, p.y)) * 0.05;

    let dark = clamp(vig + drop, 0.0, 1.0);
    let lightA = clamp(lift + haze, 0.0, 1.0);
    // premultiplied: dark pixels contribute (0,0,0,a); light ones (c*a, a)
    let lightC = vec3<f32>(0.75, 0.9, 1.0) * lightA;
    let a = dark + lightA * (1.0 - dark);
    return vec4<f32>(lightC * (1.0 - dark), a);
}
