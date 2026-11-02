-- Marine snow and a few bubbles, drawn with the Renderer. Sits behind the
-- jellyfish and in front of the water shader.

type Mote = { x: number, y: number, r: number, vy: number, phase: number, a: number }
type Bubble = { x: number, y: number, r: number, vy: number, phase: number }

type Snow = {
    size: Vector,
    time: number,
    motes: { Mote },
    bubbles: { Bubble },
    motePath: Path,
    bubblePath: Path,
    hiPath: Path,
    motePaint: Paint,
    ringPaint: Paint,
    hiPaint: Paint,
}

local K = 0.5522847  -- cubic circle constant

local function circle(path: Path, cx: number, cy: number, r: number)
    local k = K * r
    path:moveTo(Vector.xy(cx + r, cy))
    path:cubicTo(Vector.xy(cx + r, cy + k), Vector.xy(cx + k, cy + r), Vector.xy(cx, cy + r))
    path:cubicTo(Vector.xy(cx - k, cy + r), Vector.xy(cx - r, cy + k), Vector.xy(cx - r, cy))
    path:cubicTo(Vector.xy(cx - r, cy - k), Vector.xy(cx - k, cy - r), Vector.xy(cx, cy - r))
    path:cubicTo(Vector.xy(cx + k, cy - r), Vector.xy(cx + r, cy - k), Vector.xy(cx + r, cy))
    path:close()
end

function init(self: Snow, context: Context): boolean
    if #self.motes > 0 then
        return true
    end
    math.randomseed(7)
    for i = 1, 90 do
        table.insert(self.motes, {
            x = math.random() * 600,
            y = math.random() * 800,
            r = 0.6 + math.random() * 1.6,
            vy = 4 + math.random() * 9,
            phase = math.random() * 6.283,
            a = 0.25 + math.random() * 0.5,
        })
    end
    for i = 1, 6 do
        table.insert(self.bubbles, {
            x = 40 + math.random() * 520,
            y = math.random() * 800,
            r = 2.5 + math.random() * 4,
            vy = 26 + math.random() * 22,
            phase = math.random() * 6.283,
        })
    end
    return true
end

function resize(self: Snow, size: Vector)
    self.size = size
end

function advance(self: Snow, seconds: number): boolean
    local s = math.min(seconds, 0.05)
    self.time += s
    local w = if self.size.x > 0 then self.size.x else 600
    local h = if self.size.y > 0 then self.size.y else 800
    for _, m in ipairs(self.motes) do
        m.y -= m.vy * s
        m.x += math.sin(self.time * 0.5 + m.phase) * 4 * s
        if m.y < -4 then
            m.y = h + 4
            m.x = math.random() * w
        end
    end
    for _, b in ipairs(self.bubbles) do
        b.y -= b.vy * s
        b.x += math.sin(self.time * 1.6 + b.phase) * 10 * s
        if b.y < -10 then
            b.y = h + 10
            b.x = 40 + math.random() * (w - 80)
        end
    end
    return true
end

function draw(self: Snow, renderer: Renderer)
    -- motes: one path per brightness bucket would be cheaper; 90 draws is fine here
    for _, m in ipairs(self.motes) do
        self.motePath:reset()
        circle(self.motePath, m.x, m.y, m.r)
        local tw = 0.75 + 0.25 * math.sin(self.time * 1.3 + m.phase)
        self.motePaint.color = Color.rgba(215, 240, 255, math.floor(255 * m.a * tw))
        renderer:drawPath(self.motePath, self.motePaint)
    end
    for _, b in ipairs(self.bubbles) do
        self.bubblePath:reset()
        circle(self.bubblePath, b.x, b.y, b.r)
        renderer:drawPath(self.bubblePath, self.ringPaint)
        self.hiPath:reset()
        circle(self.hiPath, b.x - b.r * 0.35, b.y - b.r * 0.35, b.r * 0.28)
        renderer:drawPath(self.hiPath, self.hiPaint)
    end
end

return function(context: Context): Layout<Snow>
    return {
        size = Vector.xy(0, 0),
        time = 0,
        motes = {},
        bubbles = {},
        motePath = Path.new(),
        bubblePath = Path.new(),
        hiPath = Path.new(),
        motePaint = Paint.with({ color = Color.rgba(215, 240, 255, 120), style = 'fill', feather = 1.2 }),
        ringPaint = Paint.with({ color = Color.rgba(200, 235, 255, 110), style = 'stroke', thickness = 1 }),
        hiPaint = Paint.with({ color = Color.rgba(255, 255, 255, 150), style = 'fill' }),
        init = init,
        resize = resize,
        advance = advance,
        draw = draw,
    }
end
