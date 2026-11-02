-- Drives the jellyfish from the pointer. The markup binds position, tilt and
-- the dart squash to view model numbers; this script only writes those.
--
-- Idle: a slow wander around the artboard centre.
-- Hover: the jelly drifts lazily toward the pointer and tilts into its motion.
-- Press: it contracts and darts away from the pointer, then settles.

type Drift = {
    size: Vector,
    jellyX: Property<number>?,
    jellyY: Property<number>?,
    jellyTilt: Property<number>?,
    dartScaleX: Property<number>?,
    dartScaleY: Property<number>?,
    tentacleSwing: Property<number>?,
    tentacleStretch: Property<number>?,
    t: number,
    x: number,
    y: number,
    vx: number,
    vy: number,
    px: number,
    py: number,
    hasPointer: boolean,
    dart: number,
    tilt: number,
    swing: number,
    stretch: number,
}

local function clamp(v: number, lo: number, hi: number): number
    if v < lo then
        return lo
    elseif v > hi then
        return hi
    end
    return v
end

function init(self: Drift, context: Context): boolean
    -- init runs twice; the view model is nil the first time.
    local vm = context:viewModel()
    if vm == nil then
        return true
    end
    self.jellyX = vm:getNumber('jellyX')
    self.jellyY = vm:getNumber('jellyY')
    self.jellyTilt = vm:getNumber('jellyTilt')
    self.dartScaleX = vm:getNumber('dartScaleX')
    self.dartScaleY = vm:getNumber('dartScaleY')
    self.tentacleSwing = vm:getNumber('tentacleSwing')
    self.tentacleStretch = vm:getNumber('tentacleStretch')
    return true
end

function resize(self: Drift, size: Vector)
    self.size = size
end

function pointerMove(self: Drift, event: PointerEvent)
    self.px = event.position.x
    self.py = event.position.y
    self.hasPointer = true
end

function pointerExit(self: Drift, event: PointerEvent)
    self.hasPointer = false
end

function pointerDown(self: Drift, event: PointerEvent)
    self.px = event.position.x
    self.py = event.position.y
    -- flee direction: away from the press; straight up if the press is on top of it
    local dx = self.x - self.px
    local dy = self.y - self.py
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 20 then
        dx, dy, len = 0, -1, 1
    end
    local speed = 560
    self.vx += dx / len * speed
    self.vy += dy / len * speed
    self.dart = 1
end

function advance(self: Drift, seconds: number): boolean
    local s = math.min(seconds, 0.05)
    self.t += s
    local w = if self.size.x > 0 then self.size.x else 600
    local h = if self.size.y > 0 then self.size.y else 800

    -- where it wants to be
    local tx = w * 0.5 + 70 * math.sin(self.t * 0.23)
    local ty = h * 0.42 + 40 * math.sin(self.t * 0.37 + 1.2)
    if self.hasPointer then
        -- hover a little above the pointer rather than on it
        tx = self.px
        ty = self.py - 60
    end

    -- lazy follow plus the dart impulse
    local k = 1 - math.exp(-0.9 * s)
    local nx = self.x + (tx - self.x) * k + self.vx * s
    local ny = self.y + (ty - self.y) * k + self.vy * s
    nx = clamp(nx, 90, w - 90)
    ny = clamp(ny, 130, h - 220)
    local fx = (nx - self.x) / s
    local fy = (ny - self.y) / s
    self.x, self.y = nx, ny
    local damp = math.exp(-2.4 * s)
    self.vx *= damp
    self.vy *= damp
    self.dart *= math.exp(-2.6 * s)

    -- secondary motion, all smoothed so nothing snaps
    local ks = 1 - math.exp(-4 * s)
    self.tilt += (clamp(fx * 0.0016, -0.4, 0.4) - self.tilt) * ks
    self.swing += (clamp(-fx * 0.0022, -0.5, 0.5) - self.swing) * ks
    self.stretch += (clamp(1 - fy * 0.0012, 0.85, 1.4) - self.stretch) * ks

    if self.jellyX ~= nil then
        self.jellyX.value = self.x
    end
    if self.jellyY ~= nil then
        self.jellyY.value = self.y
    end
    if self.jellyTilt ~= nil then
        self.jellyTilt.value = self.tilt
    end
    if self.dartScaleX ~= nil then
        self.dartScaleX.value = 1 - 0.24 * self.dart
    end
    if self.dartScaleY ~= nil then
        self.dartScaleY.value = 1 + 0.14 * self.dart
    end
    if self.tentacleSwing ~= nil then
        self.tentacleSwing.value = self.swing
    end
    if self.tentacleStretch ~= nil then
        self.tentacleStretch.value = self.stretch + 0.25 * self.dart
    end
    return true
end

return function(context: Context): Layout<Drift>
    return {
        size = Vector.xy(0, 0),
        jellyX = nil,
        jellyY = nil,
        jellyTilt = nil,
        dartScaleX = nil,
        dartScaleY = nil,
        tentacleSwing = nil,
        tentacleStretch = nil,
        t = 0,
        x = 300,
        y = 330,
        vx = 0,
        vy = 0,
        px = 300,
        py = 330,
        hasPointer = false,
        dart = 0,
        tilt = 0,
        swing = 0,
        stretch = 1,
        init = init,
        resize = resize,
        advance = advance,
        pointerMove = pointerMove,
        pointerExit = pointerExit,
        pointerDown = pointerDown,
    }
end
