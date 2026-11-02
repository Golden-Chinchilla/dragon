// Full-resolution finish drawn over the cards: film grain only. Darkening and
// vignette live in the quarter-resolution background pass.

struct U {
    time: f32,
    width: f32,
    height: f32,
    grain: f32,
};
@group(0) @binding(0) var<uniform> u: U;

struct VOut { @builtin(position) position: vec4<f32> };

@vertex
fn vs_main(@builtin(vertex_index) idx: u32) -> VOut {
    var out: VOut;
    let x = f32(i32(idx) - 1) * 3.0;
    let y = f32(i32(idx & 1u) * 2 - 1) * 3.0;
    out.position = vec4<f32>(x, y, 0.0, 1.0);
    return out;
}

fn ph(p: vec2<f32>) -> f32 {
    let h = dot(p, vec2<f32>(127.1, 311.7));
    return fract(sin(h) * 43758.5453123);
}

@fragment
fn fs_main(in: VOut) -> @location(0) vec4<f32> {
    let frame = floor(u.time * 24.0);
    let g = ph(in.position.xy + vec2<f32>(frame * 13.7, frame * 7.3)) - 0.5;
    let lift = max(g, 0.0) * u.grain;
    let drop = max(-g, 0.0) * u.grain;
    // premultiplied: a touch of white, or a touch of black
    return vec4<f32>(vec3<f32>(lift), lift + drop);
}
