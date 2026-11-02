// Deep water: depth gradient, drifting fog, angled light shafts, caustic shimmer.
// All 2D math on a full-screen triangle. Output is premultiplied, opaque.

struct U {
    time: f32,
    width: f32,
    height: f32,
    angle: f32,       // light angle, radians
    intensity: f32,   // 0..1
    jellyX: f32,      // normalized 0..1
    jellyY: f32,
    pad0: f32,
    top: vec4<f32>,
    bottom: vec4<f32>,
    light: vec4<f32>,
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

fn noise(p: vec2<f32>) -> f32 {
    let i = floor(p);
    let f = fract(p);
    let s = f * f * (3.0 - 2.0 * f);
    let a = hash(i);
    let b = hash(i + vec2<f32>(1.0, 0.0));
    let c = hash(i + vec2<f32>(0.0, 1.0));
    let d = hash(i + vec2<f32>(1.0, 1.0));
    return mix(mix(a, b, s.x), mix(c, d, s.x), s.y);
}

fn fbm(p: vec2<f32>) -> f32 {
    var v = 0.0;
    var a = 0.5;
    var q = p;
    for (var i = 0; i < 4; i = i + 1) {
        v = v + a * noise(q);
        q = q * 2.03 + vec2<f32>(17.0, 9.0);
        a = a * 0.5;
    }
    return v;
}

@fragment
fn fs_main(in: VOut) -> @location(0) vec4<f32> {
    let res = vec2<f32>(u.width, u.height);
    let p = in.position.xy / res;          // 0..1, y down
    let aspect = u.width / u.height;
    let t = u.time;

    // depth gradient with a slightly brighter centre band
    let depth = smoothstep(0.0, 1.0, p.y);
    var col = mix(u.top.rgb, u.bottom.rgb, depth);
    let centre = 1.0 - smoothstep(0.0, 0.75, abs(p.x - 0.5) * 2.0);
    col = col * (0.85 + 0.25 * centre);

    // slow fog, two layers drifting
    let fog1 = fbm(vec2<f32>(p.x * 2.2 * aspect, p.y * 2.2) + vec2<f32>(t * 0.015, -t * 0.02));
    let fog2 = fbm(vec2<f32>(p.x * 4.0 * aspect, p.y * 4.0) + vec2<f32>(-t * 0.02, -t * 0.035));
    let fog = (fog1 * 0.65 + fog2 * 0.35 - 0.45) * 0.35;
    col = col + u.light.rgb * max(fog, 0.0) * 0.35 * (1.0 - depth) + fog * 0.06;

    // light shafts: in a frame rotated by the light angle, bands along x fading with depth
    let c = cos(u.angle);
    let s = sin(u.angle);
    let q = vec2<f32>(p.x * aspect, p.y);
    let rx = q.x * c - q.y * s;
    let ry = q.x * s + q.y * c;
    let band = fbm(vec2<f32>(rx * 6.0 + t * 0.05, 0.3));
    let band2 = noise(vec2<f32>(rx * 14.0 - t * 0.04, 0.7));
    var shaft = pow(max(band - 0.42, 0.0) * 1.9, 1.6) + pow(max(band2 - 0.6, 0.0), 2.0) * 0.6;
    shaft = shaft * (1.0 - smoothstep(0.1, 0.95, ry)) * u.intensity;
    col = col + u.light.rgb * shaft * 0.75;

    // caustic shimmer, faint and only near the surface
    let ca = noise(q * 18.0 + vec2<f32>(t * 0.25, t * 0.18));
    let cb = noise(q * 23.0 - vec2<f32>(t * 0.21, t * 0.3));
    let caustic = pow(ca * cb, 2.2) * (1.0 - smoothstep(0.0, 0.55, p.y)) * u.intensity;
    col = col + u.light.rgb * caustic * 0.9;

    // the jelly lights the water around it a little
    let dj = distance(vec2<f32>(p.x * aspect, p.y), vec2<f32>(u.jellyX * aspect, u.jellyY));
    col = col + u.light.rgb * 0.08 * exp(-dj * dj * 14.0);

    return vec4<f32>(col, 1.0);
}
