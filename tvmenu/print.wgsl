// Renders one app's print into a texture, once. The print is a textile-like
// pattern from a palette, a pattern kind and a seed. The background and the
// cards then sample the texture instead of recomputing the pattern per pixel.
//
// kind: 0 dots, 1 crosses, 2 scales, 3 stripes, 4 squares

struct U {
    c0: vec4<f32>,   // base
    c1: vec4<f32>,   // band A
    c2: vec4<f32>,   // band B
    c3: vec4<f32>,   // pattern ink
    pp: vec4<f32>,   // kind, seed, scale, ink
    res: vec4<f32>,  // width, height, pad, pad
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
    for (var i = 0; i < 5; i = i + 1) {
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

@fragment
fn fs_main(in: VOut) -> @location(0) vec4<f32> {
    let p = in.position.xy / u.res.xy;
    let uv = vec2<f32>(p.x * (u.res.x / u.res.y), p.y) * 2.2;
    let seed = u.pp.y;
    let q = uv + vec2<f32>(seed * 3.1, seed * 1.7);
    let w1 = pfbm(q * 1.15);
    let w2 = pfbm(q * 2.4 + vec2<f32>(5.0, 2.0));
    let region = w1 + 0.22 * sin(q.y * 3.5 + w2 * 6.0) + 0.12 * sin(q.x * 2.2 + seed);
    var col = u.c0.rgb;
    let mA = smoothstep(0.40, 0.45, region);
    let mB = smoothstep(0.60, 0.65, region);
    col = mix(col, u.c1.rgb, mA);
    col = mix(col, u.c2.rgb, mB);
    // halftone-style pattern inside band A, density drifting across
    let density = pfbm(q * 1.8 + vec2<f32>(9.0, 4.0));
    let pm = pattern_mask(u.pp.x, q * u.pp.z, density);
    let inA = mA * (1.0 - mB);
    col = mix(col, u.c3.rgb, pm * inA * 0.9);
    // a finer pattern in band B
    let pm2 = pattern_mask(4.0 - u.pp.x, q * u.pp.z * 1.7 + 0.3, 0.35);
    col = mix(col, u.c0.rgb, pm2 * mB * 0.35);
    // ink blobs
    let ink = smoothstep(0.64, 0.70, pfbm(q * 1.5 + vec2<f32>(seed * 2.3, 9.0)));
    col = mix(col, u.c0.rgb * 0.25, ink * u.pp.w);
    // paper grain
    col = col * (0.94 + 0.08 * pnoise(q * 90.0));
    return vec4<f32>(col, 1.0);
}
