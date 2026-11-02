// Background: the selected app's print, blown up, folded like cloth, defocused,
// darkened for legibility; a soft-edged wipe to the next print on selection,
// with a light band riding the wipe edge; the selected card's glow; vignette
// and grain. Opaque, premultiplied.
//
// --- begin print.wgsl (keep in sync) ---
struct PrintParams {
    c0: vec4<f32>,
    c1: vec4<f32>,
    c2: vec4<f32>,
    c3: vec4<f32>,
    pp: vec4<f32>,
};

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

fn pfbm(p: vec2<f32>) -> f32 {
    var v = 0.0;
    var a = 0.5;
    var q = p;
    for (var i = 0; i < 4; i = i + 1) {
        v = v + a * pnoise(q);
        q = q * 2.07 + vec2<f32>(13.0, 7.0);
        a = a * 0.5;
    }
    return v;
}

fn pattern_mask(kind: f32, q: vec2<f32>, density: f32) -> f32 {
    let cell = fract(q) - 0.5;
    let r = 0.12 + 0.3 * density;
    if (kind < 0.5) {
        return 1.0 - smoothstep(r - 0.04, r + 0.04, length(cell));
    } else if (kind < 1.5) {
        let arm = 0.06;
        let a = step(abs(cell.x), arm) * step(abs(cell.y), r);
        let b = step(abs(cell.y), arm) * step(abs(cell.x), r);
        return max(a, b);
    } else if (kind < 2.5) {
        let row = floor(q.y);
        let sx = fract(q.x + 0.5 * (row - 2.0 * floor(row * 0.5))) - 0.5;
        let sy = fract(q.y);
        let d = length(vec2<f32>(sx, sy - 1.0));
        return (1.0 - smoothstep(0.42, 0.5, d)) * smoothstep(0.3, 0.4, d);
    } else if (kind < 3.5) {
        return step(fract(q.x * 0.5), 0.25 + 0.35 * density);
    }
    let sq = max(abs(cell.x), abs(cell.y));
    return 1.0 - smoothstep(r - 0.03, r + 0.03, sq);
}

fn print_color(uv: vec2<f32>, P: PrintParams) -> vec3<f32> {
    let seed = P.pp.y;
    let q = uv + vec2<f32>(seed * 3.1, seed * 1.7);
    let w1 = pfbm(q * 1.15);
    let w2 = pfbm(q * 2.4 + vec2<f32>(5.0, 2.0));
    let region = w1 + 0.22 * sin(q.y * 3.5 + w2 * 6.0) + 0.12 * sin(q.x * 2.2 + seed);
    var col = P.c0.rgb;
    let mA = smoothstep(0.40, 0.45, region);
    let mB = smoothstep(0.60, 0.65, region);
    col = mix(col, P.c1.rgb, mA);
    col = mix(col, P.c2.rgb, mB);
    let density = pfbm(q * 1.8 + vec2<f32>(9.0, 4.0));
    let pm = pattern_mask(P.pp.x, q * P.pp.z, density);
    let inA = mA * (1.0 - mB);
    col = mix(col, P.c3.rgb, pm * inA * 0.9);
    let pm2 = pattern_mask(4.0 - P.pp.x, q * P.pp.z * 1.7 + 0.3, 0.35);
    col = mix(col, P.c0.rgb, pm2 * mB * 0.35);
    let ink = smoothstep(0.64, 0.70, pfbm(q * 1.5 + vec2<f32>(seed * 2.3, 9.0)));
    col = mix(col, P.c0.rgb * 0.25, ink * P.pp.w);
    col = col * (0.94 + 0.08 * pnoise(q * 90.0));
    return col;
}
// --- end print.wgsl ---

struct U {
    time: f32,
    t: f32,          // wipe progress 0..1
    dir: f32,        // +1 new print enters from the right, -1 from the left
    grain: f32,
    width: f32,
    height: f32,
    glowX: f32,      // selected card centre, 0..1
    glowY: f32,
    glow: vec4<f32>,
    A: PrintParams,  // outgoing
    B: PrintParams,  // incoming
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

fn folded(p: vec2<f32>, t: f32) -> vec2<f32> {
    // cloth folds: low-frequency displacement, slowly drifting
    let n1 = pfbm(p * 1.6 + vec2<f32>(t * 0.03, 0.0));
    let n2 = pfbm(p * 1.6 + vec2<f32>(7.0, t * 0.02));
    return p + vec2<f32>(n1 - 0.5, n2 - 0.5) * 0.18;
}

fn sample_print(P: PrintParams, p: vec2<f32>, t: f32) -> vec3<f32> {
    // five taps = cheap defocus
    let q = folded(p, t) * 2.2;
    let d = 0.022;
    var c = print_color(q, P);
    c = c + print_color(q + vec2<f32>(d, 0.0), P);
    c = c + print_color(q - vec2<f32>(d, 0.0), P);
    c = c + print_color(q + vec2<f32>(0.0, d), P);
    c = c + print_color(q - vec2<f32>(0.0, d), P);
    return c * 0.2;
}

@fragment
fn fs_main(in: VOut) -> @location(0) vec4<f32> {
    let res = vec2<f32>(u.width, u.height);
    let p = in.position.xy / res;
    let aspect = u.width / u.height;
    let pa = vec2<f32>(p.x * aspect, p.y);

    let a = sample_print(u.A, pa, u.time);
    let b = sample_print(u.B, pa + vec2<f32>(0.37, 0.11), u.time);

    // wipe: the incoming print sweeps across from one side
    let edge = select(1.25 - u.t * 1.5, u.t * 1.5 - 0.25, u.dir > 0.0);
    let m = select(smoothstep(edge - 0.12, edge + 0.12, p.x), 1.0 - smoothstep(edge - 0.12, edge + 0.12, p.x), u.dir > 0.0);
    var col = mix(b, a, m);
    let band = exp(-pow((p.x - edge) * 9.0, 2.0)) * (1.0 - abs(2.0 * u.t - 1.0));
    col = col + u.glow.rgb * band * 0.9 + vec3<f32>(band) * 0.4;

    // legibility: darker on the left and towards the bottom, like a TV home
    let leftDark = 1.0 - 0.6 * (1.0 - smoothstep(0.0, 0.6, p.x));
    let bottomDark = 1.0 - 0.75 * smoothstep(0.5, 1.0, p.y);
    let lum = dot(col, vec3<f32>(0.3, 0.59, 0.11));
    col = mix(vec3<f32>(lum), col, 0.8) * 0.52 * leftDark * bottomDark;

    // the selected card lights the floor beneath it
    let dg = vec2<f32>((p.x - u.glowX) * aspect, (p.y - u.glowY) * 1.3);
    let g = exp(-dot(dg, dg) * 10.0);
    col = col + u.glow.rgb * g * 0.55;

    // vignette + grain
    let d = distance(p, vec2<f32>(0.5, 0.5)) * 1.2;
    col = col * (1.0 - smoothstep(0.5, 1.2, d) * 0.55);
    let frame = floor(u.time * 24.0);
    let gr = ph(in.position.xy + vec2<f32>(frame * 13.7, frame * 7.3)) - 0.5;
    col = col + gr * u.grain;

    return vec4<f32>(max(col, vec3<f32>(0.0)), 1.0);
}
