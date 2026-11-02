// App card: a thin box. Front face shows the app's print; sides are dark glass.
// A glossy sweep crosses the face when selected; the selected card also has a
// rim glow in its palette colour. Reflection copies fade with height.
// Output premultiplied alpha; drawn into a transparent canvas.
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
    mvp: mat4x4<f32>,
    model: mat4x4<f32>,
    glow: vec4<f32>,
    params: vec4<f32>,   // selected 0..1, reflection 0/1, sweep 0..2, time
    P: PrintParams,
};
@group(0) @binding(0) var<uniform> u: U;

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
    // the card face: +z for a card, -z for its reflection (turned over)
    let faceZ = select(0.03, -0.03, refl > 0.5);
    let front = step(0.029, in.local.z * sign(faceZ));
    if (front > 0.5) {
        // the print, framed by a dark bevel
        var uv = in.uv;
        if (refl > 0.5) {
            uv.x = 1.0 - uv.x;   // the back face's u runs the other way
        }
        let pr = print_color(vec2<f32>(uv.x * 1.0, uv.y * 0.6) * 1.4, u.P);
        let edge = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
        let bevel = smoothstep(0.0, 0.035, edge);
        col = mix(vec3<f32>(0.05, 0.05, 0.06), pr, bevel);
        // glass: a diagonal highlight that sweeps across when selected
        let s = uv.x * 0.8 + (1.0 - uv.y) * 0.6;
        let gloss = exp(-pow((s - (sweep - 0.4)) * 6.0, 2.0)) * 0.55
                  + smoothstep(0.55, 1.1, s) * 0.10;
        col = col + vec3<f32>(gloss);
        col = col * (0.75 + 0.35 * diff) + spec * 0.15;
        // rim light in the palette colour when selected
        let rim = (1.0 - smoothstep(0.0, 0.06, edge)) * sel;
        col = mix(col, u.glow.rgb, rim * 0.8);
    } else {
        // sides: dark glass with a lit edge
        col = vec3<f32>(0.06, 0.065, 0.075) * (0.5 + diff) + spec * 0.25;
        col = col + u.glow.rgb * sel * 0.25 * (0.3 + diff);
    }
    col = col * (0.9 + 0.25 * sel);

    var alpha = 1.0;
    if (refl > 0.5) {
        // reflection: strongest at the floor line, gone within the card height
        let height = max(u.glow.w, 0.01);
        let below = clamp((floorY - in.worldY) / height, 0.0, 1.0);
        alpha = 0.32 * pow(1.0 - below, 2.2);
        col = col * 0.75;
    }
    return vec4<f32>(col * alpha, alpha);
}
