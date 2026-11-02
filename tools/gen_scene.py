#!/usr/bin/env python3
"""Generate scene.rml: a deep-sea jellyfish, drawn in layers and deformed by bones.

Run from the project root:  python3 tools/gen_scene.py

Structure (first declared draws on top):
  Grade     full-screen WGSL overlay: vignette, haze, grain        (grade.luau)
  Input     pointer -> view model numbers                           (drift.luau)
  Beads     bioluminescent beads riding the tentacles (FollowPath)
  Jelly     bell: 9 vector layers skinned to two bones (apex, hem)
            tentacles + oral arms: one tapered path each, skinned to a bone chain
  Snow      marine snow and bubbles, script-drawn                   (snow.luau)
  Water     full-screen WGSL water: depth, light shafts, caustics   (water.luau)
"""
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "scene.rml"

W, H = 600, 800
JELLY_X, JELLY_Y = 300.0, 330.0

# ---------------------------------------------------------------- ids
_next = [100]


def nid():
    _next[0] += 1
    return f"0:{_next[0]}"


ID = {
    "artboard": "0:2", "style": "0:5", "sm": "0:7",
    "vm": "0:40", "vmInst": "0:41",
    "script_drift": "0:80", "script_water": "0:81", "script_snow": "0:82", "script_grade": "0:83",
    "conv_degs": "0:90",
}

VM_PROPS = {
    # colours, ARGB; alpha is part of the setting
    "waterTop": ("Color", "FF0A2A48"),
    "waterBottom": ("Color", "FF02060E"),
    "lightColor": ("Color", "FFA9DCFF"),
    "bellColor": ("Color", "8C5FC4DE"),
    "bellEdge": ("Color", "3A8FE0F2"),
    "glowColor": ("Color", "FF6FE6FF"),
    "coreColor": ("Color", "FFFFB063"),
    # light and grade
    "lightIntensity": ("Number", "0.65"),
    "lightAngle": ("Number", "-14"),
    "glowStrength": ("Number", "0.75"),
    "grain": ("Number", "0.07"),
    "vignette": ("Number", "0.6"),
    # written by drift.luau each frame
    "jellyX": ("Number", str(JELLY_X)),
    "jellyY": ("Number", str(JELLY_Y)),
    "jellyTilt": ("Number", "0"),
    "dartScaleX": ("Number", "1"),
    "dartScaleY": ("Number", "1"),
    "tentacleSwing": ("Number", "0"),
    "tentacleStretch": ("Number", "1"),
}
VM_ID = {name: f"0:{50 + i}" for i, name in enumerate(VM_PROPS)}


def path_of(prop):
    return f"{ID['vm']}-{VM_ID[prop]}"


# ---------------------------------------------------------------- xml helpers
def fmt(v):
    if isinstance(v, float):
        return f"{v:.4f}".rstrip("0").rstrip(".") if v != 0 else "0"
    return str(v)


def el(tag, attrs=None, children=(), depth=0):
    pad = "    " * depth
    a = "".join(f' {k}="{fmt(v)}"' for k, v in (attrs or {}).items() if v is not None)
    kids = [c for c in children if c]
    if not kids:
        return f"{pad}<{tag}{a}/>"
    inner = "\n".join(indent(c, depth + 1) for c in kids)
    return f"{pad}<{tag}{a}>\n{inner}\n{pad}</{tag}>"


def indent(block, depth):
    pad = "    " * depth
    return "\n".join(pad + line if line else line for line in block.split("\n"))


def bind(prop, key, converter=None):
    return el("DataBindContext", {"sourcePathIds": path_of(prop), "propertyKey": key, "converterId": converter})


def solid(color, bound=None, name="C"):
    return el("SolidColor", {"colorValue": color, "name": name}, [bind(bound, 37)] if bound else [])


def stop(color, pos, bound=None):
    return el("GradientStop", {"colorValue": color, "position": pos}, [bind(bound, 38)] if bound else [])


EASE = {"x1": 0.42, "y1": 0, "x2": 0.58, "y2": 1}


def kf(value, frame, ease=True, curve=None):
    if ease:
        return el("KeyFrameDouble", {"value": value, "frame": frame, "interpolationType": "cubic"},
                  [el("CubicEaseInterpolator", curve or EASE)])
    return el("KeyFrameDouble", {"value": value, "frame": frame, "interpolationType": "linear"})


def keyed(obj_id, prop, frames, ease=True):
    return el("KeyedObject", {"objectId": obj_id}, [
        el("KeyedProperty", {"property": prop}, [kf(v, f, ease) for f, v in frames])])


def wave(duration, samples, fn):
    frames = [(round(duration * i / samples), fn(i / samples)) for i in range(samples)]
    frames.append((duration, fn(0.0)))
    return frames


# ---------------------------------------------------------------- skinning helpers
def pack(wa, ia, wb, ib):
    """Two-tendon weight. ia/ib are tendon indices (0-based); weights sum to 255."""
    if wb <= 0:
        return 255, ia + 1
    if wa <= 0:
        return 255, ib + 1
    return wa | (wb << 8), (ia + 1) | ((ib + 1) << 8)


def weight_el(values, indices, cubic):
    if cubic:
        return el("CubicWeight", {"values": values, "indices": indices,
                                  "inValues": values, "inIndices": indices,
                                  "outValues": values, "outIndices": indices})
    return el("Weight", {"values": values, "indices": indices})


def vertex(kind, attrs, values, indices):
    cubic = kind != "StraightVertex"
    return el(kind, attrs, [weight_el(values, indices, cubic)])


def skin(tendons):
    """tendons: list of (bone_id, tx, ty, angle)."""
    kids = []
    for bone_id, tx, ty, ang in tendons:
        c, s = math.cos(ang), math.sin(ang)
        kids.append(el("Tendon", {"boneId": bone_id, "xx": c, "xy": s, "yx": -s, "yy": c, "tx": tx, "ty": ty}))
    return el("Skin", {"tx": 0, "ty": 0, "name": "Skin"}, kids)


# ---------------------------------------------------------------- bell
APEX_Y = -70.0
bone_apex = nid()
bone_hem = nid()
BELL_TENDONS = [(bone_apex, 0, APEX_Y, 0.0), (bone_hem, 0, 0, 0.0)]


def bell_weight(y):
    t = max(0.0, min(1.0, (y + 100.0) / 108.0))   # 0 at apex, 1 at hem
    h = int(round(255 * t))
    return pack(255 - h, 0, h, 1)


def dome_specs(s=1.0):
    """Vertex specs for the bell silhouette, clockwise from the apex."""
    v = []
    v.append(("CubicMirroredVertex", {"x": 0, "y": -98 * s, "rotation": 0, "distance": 92 * s}))
    v.append(("CubicMirroredVertex", {"x": 124 * s, "y": -38 * s, "rotation": 1.32, "distance": 34 * s}))
    v.append(("CubicDetachedVertex", {"x": 100 * s, "y": 8 * s, "inRotation": -1.05, "inDistance": 22 * s,
                                      "outRotation": 2.9, "outDistance": 14 * s}))
    hem = [(81, 26), (54, 10), (27, 26), (0, 10), (-27, 26), (-54, 10), (-81, 26)]
    for x, y in hem:
        d = 18 if y > 15 else 8
        v.append(("CubicMirroredVertex", {"x": x * s, "y": y * s, "rotation": 3.1416, "distance": d * s}))
    v.append(("CubicDetachedVertex", {"x": -100 * s, "y": 8 * s, "inRotation": 3.5, "inDistance": 14 * s,
                                      "outRotation": -2.09, "outDistance": 22 * s}))
    v.append(("CubicMirroredVertex", {"x": -124 * s, "y": -38 * s, "rotation": -1.32, "distance": 34 * s}))
    return v


def bell_path(s=1.0, specs=None, closed=True):
    specs = specs or dome_specs(s)
    kids = []
    for kind, attrs in specs:
        vals, idx = bell_weight(attrs["y"])
        kids.append(vertex(kind, attrs, vals, idx))
    kids.append(skin(BELL_TENDONS))
    return el("PointsPath", {"isClosed": closed, "isClockwise": True, "name": "P"}, kids)


def canal_path(x_end, y_end):
    """One radial canal: a curve from just below the apex to a hem point."""
    specs = [
        ("StraightVertex", {"x": 0, "y": -88}),
        ("CubicMirroredVertex", {"x": x_end * 0.55, "y": -50 + y_end * 0.2, "rotation": math.atan2(y_end + 88, x_end), "distance": 26}),
        ("StraightVertex", {"x": x_end, "y": y_end}),
    ]
    return bell_path(specs=specs, closed=False)


organ_ids = []
core_glow_id = nid()


def bell():
    rim = el("Shape", {"blendModeValue": "screen", "opacity": 0.7, "name": "RimLight", "id": nid()}, [
        bell_path(),
        el("Stroke", {"thickness": 5, "cap": "round", "join": "round", "name": "Soft"}, [
            solid("FF6FE6FF", "glowColor"), el("Feather", {"strength": 9, "name": "F"})]),
        el("Stroke", {"thickness": 1.1, "cap": "round", "join": "round", "name": "Crisp"}, [
            solid("FF6FE6FF", "glowColor")]),
    ])
    canals = []
    for xe, ye in ((-92, 2), (-58, 16), (-24, 22), (24, 22), (58, 16), (92, 2)):
        canals.append(el("Shape", {"opacity": 0.5, "blendModeValue": "screen", "name": "Canal", "id": nid()}, [
            canal_path(xe, ye),
            el("Stroke", {"thickness": 1.1, "cap": "round", "name": "S"}, [
                solid("FF6FE6FF", "glowColor"), el("Feather", {"strength": 2.5, "name": "F"})]),
        ]))
    canal_group = el("Node", {"name": "Canals", "id": nid()}, canals)

    veil = el("Shape", {"y": -6, "opacity": 0.9, "name": "Veil", "id": nid()}, [
        bell_path(0.8),
        el("Fill", {"name": "F"}, [
            el("LinearGradient", {"startX": 0, "startY": -80, "endX": 0, "endY": 18, "name": "G"}, [
                stop("3CFFFFFF", 0), stop("00FFFFFF", 1)])]),
        el("Stroke", {"thickness": 1, "name": "S"}, [solid("26FFFFFF")]),
    ])
    body = el("Shape", {"name": "Body", "id": nid()}, [
        bell_path(),
        el("Fill", {"name": "F"}, [
            el("RadialGradient", {"startX": 0, "startY": -52, "endX": 0, "endY": 84, "name": "G"}, [
                stop("8C5FC4DE", 0, "bellColor"), stop("8C5FC4DE", 0.42, "bellColor"), stop("3A8FE0F2", 1, "bellEdge")])]),
    ])
    edge = el("Shape", {"opacity": 0.95, "name": "EdgeDepth", "id": nid()}, [
        bell_path(),
        el("Stroke", {"thickness": 16, "position": "inside", "name": "Inner"}, [
            solid("3A8FE0F2", "bellEdge"), el("Feather", {"strength": 14, "inner": True, "name": "F"})]),
    ])
    shade = el("Shape", {"name": "Shade", "id": nid()}, [
        bell_path(),
        el("Fill", {"name": "F"}, [
            el("LinearGradient", {"startX": 0, "startY": -70, "endX": 0, "endY": 26, "name": "G"}, [
                stop("00000000", 0), stop("66041020", 1)])]),
    ])
    glow = el("Shape", {"blendModeValue": "screen", "opacity": 0.75, "name": "Glow", "id": nid()}, [
        bind("glowStrength", 18),
        bell_path(1.05),
        el("Fill", {"fillRule": "clockwise", "name": "F"}, [
            solid("FF6FE6FF", "glowColor"), el("Feather", {"strength": 52, "name": "Feather"})]),
    ])

    # Things parented to the apex bone ride its scale: the highlight and the organs.
    highlight = el("Shape", {"x": -40, "y": 2, "rotation": -0.5, "blendModeValue": "screen", "opacity": 0.55,
                             "name": "Highlight", "id": nid()}, [
        el("Ellipse", {"width": 92, "height": 30, "originX": 0.5, "originY": 0.5, "name": "P"}),
        el("Fill", {"fillRule": "clockwise", "name": "F"}, [
            solid("70FFFFFF"), el("Feather", {"strength": 16, "name": "Feather"})]),
    ])
    organs = []
    for ang in (0.0, 1.5708, 3.1416, 4.7124):
        oid = nid()
        organ_ids.append(oid)
        organs.append(el("Shape", {"x": 25 * math.cos(ang), "y": 32 + 13 * math.sin(ang), "rotation": ang,
                                   "opacity": 0.36, "blendModeValue": "screen", "name": "Organ", "id": oid}, [
            el("Ellipse", {"width": 30, "height": 13, "originX": 0.5, "originY": 0.5, "name": "P"}),
            el("Fill", {"fillRule": "clockwise", "name": "F"}, [
                solid("FFFFB063", "coreColor"), el("Feather", {"strength": 5, "name": "Feather"})]),
        ]))
    core = [
        el("Shape", {"x": 0, "y": 30, "blendModeValue": "screen", "name": "CoreBright", "id": nid()}, [
            el("Ellipse", {"width": 40, "height": 24, "originX": 0.5, "originY": 0.5, "name": "P"}),
            el("Fill", {"name": "F"}, [
                el("RadialGradient", {"startX": 0, "startY": 0, "endX": 20, "endY": 0, "name": "G"}, [
                    stop("FFFFB063", 0, "coreColor"), stop("00FFB063", 1)])]),
        ]),
        el("Shape", {"x": 0, "y": 32, "blendModeValue": "screen", "opacity": 0.7, "name": "CoreGlow", "id": core_glow_id}, [
            el("Ellipse", {"width": 104, "height": 66, "originX": 0.5, "originY": 0.5, "name": "P"}),
            el("Fill", {"fillRule": "clockwise", "name": "F"}, [
                solid("FFFFB063", "coreColor"), el("Feather", {"strength": 32, "name": "Feather"})]),
        ]),
    ]
    apex_bone = el("RootBone", {"x": 0, "y": APEX_Y, "length": 1, "rotation": 0, "name": "Apex", "id": bone_apex},
                   [highlight, *organs, *core])
    hem_bone = el("RootBone", {"x": 0, "y": 0, "length": 1, "rotation": 0, "name": "Hem", "id": bone_hem})

    # Draw order: bones are containers, so the apex bone's children sit where it is declared.
    return el("Node", {"name": "Bell", "id": nid()}, [rim, canal_group, apex_bone, veil, body, edge, shade, glow, hem_bone])


# ---------------------------------------------------------------- tentacles
THIN = dict(count=13, segs=5, seg_len=62, w0=3.6, w1=0.9, spread=98)
ARMS = dict(count=4, segs=4, seg_len=56, w0=15, w1=5, spread=44)

tentacle_bones = []    # (bone_id, kind, i, k, base_rot)
tentacle_shapes = []   # (shape_id, kind, i)
tentacle_root = nid()


def tentacle(kind, i, x0, y0, splay, segs, seg_len, w0, w1, frill):
    """One tentacle: a bone chain plus a tapered closed path skinned to it."""
    L = segs * seg_len
    bone_ids = [nid() for _ in range(segs)]
    tendons = [(bone_ids[k], 0, k * seg_len, math.pi / 2) for k in range(segs)]

    def w_at(y):
        """Blend between the bone that owns y and the next one."""
        k = min(segs - 1, max(0, int(y // seg_len)))
        t = (y - k * seg_len) / seg_len
        if k == segs - 1:
            return pack(255, k, 0, k)
        # smoothstep so joints bend softly
        t = t * t * (3 - 2 * t)
        b = int(round(255 * t))
        return pack(255 - b, k, b, k + 1)

    def width(y):
        u = y / L
        return w0 + (w1 - w0) * (u ** 0.85)

    step = seg_len / 2
    n = int(L / step)
    specs = []
    for j in range(n + 1):                       # right side, down
        y = j * step
        w = width(y) + (frill * math.sin(j * 1.9) if frill else 0)
        specs.append(("CubicMirroredVertex", {"x": w, "y": y, "rotation": 1.5708, "distance": step * 0.4}))
    specs.append(("CubicMirroredVertex", {"x": 0, "y": L + w1 * 2.2, "rotation": 3.1416, "distance": w1 * 1.2}))   # tip
    for j in range(n, -1, -1):                   # left side, up
        y = j * step
        w = width(y) + (frill * math.sin(j * 1.9 + 0.8) if frill else 0)
        specs.append(("CubicMirroredVertex", {"x": -w, "y": y, "rotation": -1.5708, "distance": step * 0.4}))

    verts = []
    for kind_v, attrs in specs:
        vals, idx = w_at(min(L, max(0, attrs["y"])))
        verts.append(vertex(kind_v, attrs, vals, idx))
    verts.append(skin(tendons))

    # bone chain, pointing down
    chain = None
    for k in range(segs - 1, -1, -1):
        tentacle_bones.append((bone_ids[k], kind, i, k, math.pi / 2 if k == 0 else 0.0))
        if k == 0:
            chain = el("RootBone", {"x": 0, "y": 0, "length": seg_len, "rotation": 1.5707964, "name": f"{kind}{i}b0", "id": bone_ids[0]}, [chain])
        else:
            chain = el("Bone", {"length": seg_len, "rotation": 0, "name": f"{kind}{i}b{k}", "id": bone_ids[k]}, [chain])

    shape_id = nid()
    tentacle_shapes.append((shape_id, kind, i))
    if kind == "Arm":
        paints = [
            el("Fill", {"name": "F"}, [
                el("LinearGradient", {"startX": 0, "startY": 0, "endX": 0, "endY": L, "name": "G"}, [
                    stop("8C5FC4DE", 0, "bellColor"), stop("3A8FE0F2", 0.7, "bellEdge"), stop("00FFFFFF", 1)])]),
            el("Stroke", {"thickness": 1, "name": "Edge"}, [solid("2EFFFFFF")]),
        ]
        shape_attrs = {"opacity": 0.8, "name": f"Arm{i}", "id": shape_id}
    else:
        paints = [
            el("Fill", {"name": "F"}, [
                el("LinearGradient", {"startX": 0, "startY": 0, "endX": 0, "endY": L, "name": "G"}, [
                    stop("FF6FE6FF", 0, "glowColor"), stop("FF6FE6FF", 0.35, "glowColor"), stop("00FFFFFF", 1)])]),
            el("Stroke", {"thickness": 2.4, "cap": "round", "name": "Glow"}, [
                solid("FF6FE6FF", "glowColor"), el("Feather", {"strength": 5, "name": "F"})]),
        ]
        shape_attrs = {"opacity": 0.62, "blendModeValue": "screen", "name": f"Ten{i}", "id": shape_id}
    shape = el("Shape", shape_attrs, [el("PointsPath", {"isClosed": True, "isClockwise": True, "name": "P"}, verts), *paints])
    return el("Node", {"x": x0, "y": y0, "rotation": splay, "name": f"{kind}{i}", "id": nid()}, [shape, chain])


def tentacles_group():
    kids = []
    for i in range(ARMS["count"]):
        t = (i / (ARMS["count"] - 1)) * 2 - 1
        kids.append(tentacle("Arm", i, t * ARMS["spread"], 2, t * 0.2, ARMS["segs"], ARMS["seg_len"],
                             ARMS["w0"], ARMS["w1"], frill=3.0))
    for i in range(THIN["count"]):
        t = (i / (THIN["count"] - 1)) * 2 - 1
        y = 12 + 12 * abs(math.sin(i * 1.3))
        kids.append(tentacle("Ten", i, t * THIN["spread"], y, t * 0.3, THIN["segs"], THIN["seg_len"],
                             THIN["w0"], THIN["w1"], frill=0.0))
    return el("Node", {"name": "Tentacles", "id": tentacle_root}, [
        bind("tentacleSwing", 15), bind("tentacleStretch", 17), *kids])


bead_ids = []


def beads():
    kids = []
    for shape_id, kind, i in tentacle_shapes:
        if kind == "Arm":
            continue
        bid = nid()
        cid = nid()
        bead_ids.append((bid, cid, i))
        kids.append(el("Shape", {"blendModeValue": "screen", "opacity": 0.0, "name": "Bead", "id": bid}, [
            el("FollowPathConstraint", {"targetId": shape_id, "distance": 0, "orient": True, "name": "Ride", "id": cid}),
            el("Ellipse", {"width": 7, "height": 7, "originX": 0.5, "originY": 0.5, "name": "P"}),
            el("Fill", {"fillRule": "clockwise", "name": "F"}, [
                solid("FFFFFFFF"), el("Feather", {"strength": 6, "name": "Feather"})]),
        ]))
    return el("Node", {"name": "Beads", "id": nid()}, kids)


# ---------------------------------------------------------------- jellyfish assembly
breath_tent = nid()


def jellyfish():
    dart = el("Node", {"name": "Dart", "id": nid()}, [
        bind("dartScaleX", 16), bind("dartScaleY", 17),
        bell(),
        el("Node", {"name": "TentacleBreath", "id": breath_tent}, [tentacles_group()]),
    ])
    return el("Node", {"x": JELLY_X, "y": JELLY_Y, "name": "Jelly", "id": nid()}, [
        bind("jellyX", 13), bind("jellyY", 14), bind("jellyTilt", 15), dart])


# ---------------------------------------------------------------- animations
def anim_breath():
    aid = nid()
    D = 210

    def pulse(t, lag=0.0):
        """0 relaxed .. 1 contracted. Quick contraction, slow relaxation."""
        u = (t - lag) % 1.0
        if u < 0.22:
            p = u / 0.22
            return 0.5 - 0.5 * math.cos(math.pi * p)
        p = (u - 0.22) / 0.78
        return 0.5 + 0.5 * math.cos(math.pi * p)

    hem_sx = lambda t: 1 - 0.16 * pulse(t)
    hem_sy = lambda t: 1 + 0.10 * pulse(t)
    hem_y = lambda t: 10 * pulse(t)
    apex_sx = lambda t: 1 - 0.05 * pulse(t, 0.05)
    apex_sy = lambda t: 1 + 0.09 * pulse(t, 0.05)
    apex_y = lambda t: APEX_Y - 6 * pulse(t, 0.05)
    return aid, el("LinearAnimation", {"loopValue": "loop", "duration": D, "name": "Breath", "id": aid}, [
        keyed(bone_hem, "scaleX", wave(D, 14, hem_sx)),
        keyed(bone_hem, "scaleY", wave(D, 14, hem_sy)),
        keyed(bone_hem, "y", wave(D, 14, hem_y)),
        keyed(bone_apex, "scaleX", wave(D, 14, apex_sx)),
        keyed(bone_apex, "scaleY", wave(D, 14, apex_sy)),
        keyed(bone_apex, "y", wave(D, 14, apex_y)),
        keyed(breath_tent, "scaleX", wave(D, 14, hem_sx)),
        keyed(breath_tent, "y", wave(D, 14, hem_y)),
    ])


def anim_tentacles():
    aid = nid()
    D = 330
    kids = []
    for bone_id, kind, i, k, base in tentacle_bones:
        if kind == "Arm":
            amp, phase, lag = 0.04 + 0.035 * k, i * 1.1 + 0.6, 0.85
        else:
            amp, phase, lag = 0.05 + 0.045 * k, i * 0.7, 0.95

        def fn(u, amp=amp, phase=phase, lag=lag, k=k, base=base):
            return base + amp * math.sin(2 * math.pi * u + phase - k * lag) \
                + 0.35 * amp * math.sin(4 * math.pi * u + phase * 1.7 - k * lag * 1.3)
        kids.append(keyed(bone_id, "rotation", wave(D, 11, fn)))
    return aid, el("LinearAnimation", {"loopValue": "loop", "duration": D, "name": "Tentacle Wave", "id": aid}, kids)


def anim_pulse():
    aid = nid()
    D = 260
    kids = []
    for n, (bid, cid, i) in enumerate(bead_ids):
        start = (n * 37) % 150
        travel = 95
        frames_d = [(0, 0.0), (start, 0.0), (start + travel, 1.0), (D, 1.0)]
        frames_o = [(0, 0.0), (start, 0.0), (start + 12, 0.9), (start + travel - 20, 0.6), (start + travel, 0.0), (D, 0.0)]
        kids.append(keyed(bid, "opacity", frames_o, ease=False))
        kids.append(keyed(cid, "distance", frames_d, ease=False))
    kids.append(keyed(core_glow_id, "opacity", [(0, 0.5), (18, 1.0), (80, 0.5), (D, 0.5)]))
    for oid in organ_ids:
        kids.append(keyed(oid, "opacity", [(0, 0.36), (24, 0.6), (90, 0.36), (D, 0.36)]))
    return aid, el("LinearAnimation", {"loopValue": "loop", "duration": D, "name": "Pulse", "id": aid}, kids)


# ---------------------------------------------------------------- assembly
def state_machine(anim_ids):
    layers = []
    for n, aid in enumerate(anim_ids):
        st = nid()
        layers.append(el("StateMachineLayer", {"name": f"L{n}", "id": nid()}, [
            el("AnyState", {"x": 400, "y": 0}), el("ExitState", {"x": 520, "y": 0}),
            el("EntryState", {"x": 0, "y": 0}, [el("StateTransition", {"stateToId": st})]),
            el("AnimationState", {"x": 200, "y": 0, "animationId": aid, "id": st}),
        ]))
    return el("StateMachine", {"name": "Main", "id": ID["sm"]}, layers)


def view_model():
    props, vals = [], []
    for name, (typ, default) in VM_PROPS.items():
        props.append(el(f"ViewModelProperty{typ}", {"name": name, "id": VM_ID[name]}))
        vals.append(el(f"ViewModelInstance{typ}", {"propertyValue": default, "viewModelPropertyId": VM_ID[name]}))
    return el("ViewModel", {"defaultInstanceId": ID["vmInst"], "name": "Scene", "id": ID["vm"]}, [
        *props, el("ViewModelInstance", {"exports": True, "name": "Default", "id": ID["vmInst"]}, vals)])


def script_layer(name, script_id):
    lid, sty, sid = nid(), nid(), nid()
    return el("LayoutComponent", {"width": W, "height": H, "styleId": sty, "name": name, "id": lid}, [
        el("LayoutComponentStyle", {"positionTypeValue": "absolute",
                                    "positionLeft": 0, "positionLeftUnitsValue": "points",
                                    "positionTop": 0, "positionTopUnitsValue": "points",
                                    "positionRight": 0, "positionRightUnitsValue": "points",
                                    "positionBottom": 0, "positionBottomUnitsValue": "points",
                                    "name": "Style", "id": sty}),
        el("ScriptedLayout", {"scriptAssetId": script_id, "name": name, "id": sid}),
    ])


def build():
    jelly = jellyfish()
    bead_group = beads()
    breath = anim_breath()
    tent = anim_tentacles()
    anims = [breath, tent, anim_pulse()]

    artboard = el("Artboard", {
        "defaultStateMachineId": ID["sm"], "viewModelId": ID["vm"], "viewModelInstanceId": ID["vmInst"],
        "styleId": ID["style"], "clip": True, "width": W, "height": H, "name": "Deep", "id": ID["artboard"]}, [
        el("LayoutComponentStyle", {"name": "Artboard Style", "id": ID["style"]}),
        el("Fill", {"name": "Base"}, [solid("FF02060E", "waterBottom")]),
        script_layer("Grade", ID["script_grade"]),
        script_layer("Input", ID["script_drift"]),
        bead_group,
        jelly,
        script_layer("Snow", ID["script_snow"]),
        script_layer("Water", ID["script_water"]),
        state_machine([a for a, _ in anims]),
        *[x for _, x in anims],
    ])

    doc = el("Rive", {"version": "1", "kind": "fragment"}, [
        artboard,
        view_model(),
        el("DataConverterSystemDegsToRads", {"operationType": "2", "operationValue": "0.017453292",
                                             "name": "DegsToRads", "id": ID["conv_degs"]}),
        el("ScriptAsset", {"file": "drift.luau", "name": "drift", "id": ID["script_drift"]}),
        el("ScriptAsset", {"file": "water.luau", "name": "water", "id": ID["script_water"]}),
        el("ScriptAsset", {"file": "snow.luau", "name": "snow", "id": ID["script_snow"]}),
        el("ScriptAsset", {"file": "grade.luau", "name": "grade", "id": ID["script_grade"]}),
    ])
    OUT.write_text(doc + "\n")
    print(f"wrote {OUT} ({len(doc.splitlines())} lines, last id 0:{_next[0]})")


if __name__ == "__main__":
    build()
