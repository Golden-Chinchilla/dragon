// Background, rendered at a quarter of the screen: the current print blown
// up, folded like cloth and defocused, darkened for legibility, lit by the
// selected card. A selection change burns the next print through the old one
// along a noisy edge with a bright band, like a light leak.

struct U {
    time: f32,
    t: f32,          // burn progress 0..1
    dir: f32,        // +1 enters from the right, -1 from the left
    seed: f32,       // burn pattern seed
    width: f32,
    height: f32,
    glowX: f32,      // selected card centre, 0..1
    glowY: f32,
    glow: vec4<f32>,
};
@group(0) @binding(0) var<uniform> u: U;
@group(1) @binding(0) var texA: texture_2d<f32>;   // outgoing print
@group(1) @binding(1) var texB: texture_2d<f32>;   // incoming print
@group(1) @binding(2) var samp: sampler;

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

fn pnoise(p: vec2<f32>) -> f32 {
    let i = floor(p);
    let f = fract(p);
    let s = f * f * (3.0 - 2.0 * f);
    let a = ph(i);
    let b = ph(i + vec2<f32>(1.0, 0.0));
    let c = ph(i + vec2<f32>(0.0, 1.0));
    let d = ph(i + vec2<f32>(1.0, 1.0));
    return mix(mix(a, b, s.x), mix(c, d, s.x), s.y);
}

fn fbm3(p: vec2<f32>) -> f32 {
    var v = 0.0;
    var a = 0.5;
    var q = p;
    for (var i = 0; i < 3; i = i + 1) {
        v = v + a * pnoise(q);
        q = q * 2.07 + vec2<f32>(13.0, 7.0);
        a = a * 0.5;
    }
    return v;
}

fn blurred(tex: texture_2d<f32>, uv: vec2<f32>, r: f32) -> vec3<f32> {
    var c = textureSample(tex, samp, uv).rgb * 2.0;
    c = c + textureSample(tex, samp, uv + vec2<f32>(r, 0.0)).rgb;
    c = c + textureSample(tex, samp, uv - vec2<f32>(r, 0.0)).rgb;
    c = c + textureSample(tex, samp, uv + vec2<f32>(0.0, r)).rgb;
    c = c + textureSample(tex, samp, uv - vec2<f32>(0.0, r)).rgb;
    c = c + textureSample(tex, samp, uv + vec2<f32>(r, r) * 0.7).rgb;
    c = c + textureSample(tex, samp, uv - vec2<f32>(r, r) * 0.7).rgb;
    return c / 8.0;
}

@fragment
fn fs_main(in: VOut) -> @location(0) vec4<f32> {
    let res = vec2<f32>(u.width, u.height);
    let p = in.position.xy / res;
    let aspect = u.width / u.height;
    let t = u.time;

    // cloth folds: slow low-frequency displacement
    let pa = vec2<f32>(p.x * aspect, p.y);
    let n1 = fbm3(pa * 1.4 + vec2<f32>(t * 0.03, 0.0));
    let n2 = fbm3(pa * 1.4 + vec2<f32>(7.0, t * 0.02));
    let fold = vec2<f32>(n1 - 0.5, n2 - 0.5) * 0.16;
    let uv = p * vec2<f32>(0.62, 0.62) + fold + vec2<f32>(0.18, 0.16);

    // the burn: a noisy threshold moving across, extra blur while it moves
    let moving = 1.0 - abs(2.0 * u.t - 1.0);
    let r = 0.012 + 0.014 * moving;
    let a = blurred(texA, uv, r);
    let b = blurred(texB, uv + vec2<f32>(0.21, 0.07), r);
    let ramp = select(1.0 - p.x, p.x, u.dir < 0.0);          // 0 at the entering side
    let n = fbm3(pa * 2.6 + vec2<f32>(u.seed * 7.0, u.seed * 3.0));
    let m = ramp * 0.55 + n * 0.9;                            // ~0 .. 1.45
    let edge = u.t * 1.75 - 0.15;
    let keepOld = smoothstep(edge - 0.07, edge + 0.07, m);
    var col = mix(b, a, keepOld);
    let band = exp(-pow((m - edge) * 18.0, 2.0)) * pow(moving, 0.6);
    col = col + (vec3<f32>(1.0, 0.97, 0.92) * 0.55 + u.glow.rgb * 0.6) * band;

    // legibility: darker left and bottom, like a TV home
    let leftDark = 1.0 - 0.6 * (1.0 - smoothstep(0.0, 0.6, p.x));
    let bottomDark = 1.0 - 0.75 * smoothstep(0.5, 1.0, p.y);
    let lum = dot(col, vec3<f32>(0.3, 0.59, 0.11));
    col = mix(vec3<f32>(lum), col, 0.78) * 0.5 * leftDark * bottomDark;

    // the selected card lights the floor beneath it
    let dg = vec2<f32>((p.x - u.glowX) * aspect, (p.y - u.glowY) * 1.3);
    col = col + u.glow.rgb * exp(-dot(dg, dg) * 10.0) * 0.55;

    // vignette
    let d = distance(p, vec2<f32>(0.5, 0.5)) * 1.2;
    col = col * (1.0 - smoothstep(0.5, 1.2, d) * 0.6);
    return vec4<f32>(max(col, vec3<f32>(0.0)), 1.0);
}
