-- TV home menu: keyboard-driven selection over two rows (apps, inputs).
-- Draws the background print (bg.wgsl) and the 3D app cards (card.wgsl) into
-- two GPU canvases; the text around them is markup bound to the Menu view
-- model, which this script writes.

type App = {
    name: string,
    sub: string,
    print: string,
    palette: string,
    glow: { number },          -- r g b 0..1
    c: { { number } },         -- 4 palette colours
    kind: number,
    seed: number,
    scale: number,
    ink: number,
}

type Menu = {
    size: Vector,
    scale: number,
    time: number,
    apps: { App },
    inputs: { string },
    row: number,               -- 0 apps, 1 inputs
    selected: number,          -- app index, 0-based
    selectedF: number,
    scroll: number,
    scrollF: number,
    inputSel: number,
    inputSelF: number,
    prevApp: number,
    wipe: number,
    wipeDir: number,
    sweep: number,
    -- gpu
    bgCanvas: GPUCanvas?,
    cardCanvas: GPUCanvas?,
    bgPipeline: GPUPipeline?,
    bgUbo: GPUBuffer?,
    bgBind: GPUBindGroup?,
    cardPipeline: GPUPipeline?,
    cardUbo: GPUBuffer?,
    cardBind: GPUBindGroup?,
    vbuf: GPUBuffer?,
    ibuf: GPUBuffer?,
    sampler: ImageSampler,
    bgStaging: buffer,
    cardStaging: buffer,
    slot: number,
    -- view model
    vTitle: Property<string>?,
    vSub: Property<string>?,
    vCounter: Property<string>?,
    vPrint: Property<string>?,
    vClock: Property<string>?,
    vDate: Property<string>?,
    vHint: Property<string>?,
    vLabels: { Property<string> },
    vLabelX: { Property<number> },
    vLabelA: { Property<number> },
    vPillX: Property<number>?,
    vPillA: Property<number>?,
    vAppsA: Property<number>?,
    pushText: (self: Menu) -> (),
    selectApp: (self: Menu, index: number) -> (),
    cardRect: (self: Menu, i: number) -> (number, number, number, number),
}

local SLOTS = 5
local SPACING = 1.07
local FIRST_X = -1.98
local ROW_Y = -0.49
local CAM_Z = 6.0
local FOV = math.rad(30)
local LABELS = 7
local KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_ENTER, KEY_ESC, KEY_BACKSPACE = 263, 262, 265, 264, 257, 256, 259

local function rgb(r: number, g: number, b: number): { number }
    return { r / 255, g / 255, b / 255 }
end

local APPS: { App } = {
    { name = 'Netflix', sub = 'Series and films', print = 'VERMILION', palette = 'CRIMSON', glow = rgb(255, 70, 90),
      c = { rgb(120, 10, 30), rgb(225, 40, 60), rgb(40, 8, 20), rgb(255, 205, 210) }, kind = 1, seed = 0.3, scale = 9, ink = 0.9 },
    { name = 'YouTube', sub = 'Videos, music, live', print = 'ORCHARD', palette = 'TANGERINE', glow = rgb(255, 150, 60),
      c = { rgb(80, 30, 10), rgb(235, 130, 40), rgb(250, 215, 160), rgb(60, 25, 10) }, kind = 0, seed = 1.1, scale = 8, ink = 0.8 },
    { name = 'Prime Video', sub = 'Films, series and sport', print = 'KOI POND', palette = 'LAGOON', glow = rgb(90, 220, 220),
      c = { rgb(20, 120, 125), rgb(190, 165, 110), rgb(30, 160, 170), rgb(30, 30, 35) }, kind = 2, seed = 2.2, scale = 10, ink = 0.7 },
    { name = 'Disney+', sub = 'Stories for everyone', print = 'AFTER HOURS', palette = 'ROYAL', glow = rgb(110, 130, 255),
      c = { rgb(20, 30, 120), rgb(70, 90, 230), rgb(225, 205, 90), rgb(25, 30, 90) }, kind = 0, seed = 3.3, scale = 7, ink = 0.6 },
    { name = 'Hulu', sub = 'Next-day TV', print = 'MOSS', palette = 'EMERALD', glow = rgb(60, 230, 140),
      c = { rgb(10, 60, 40), rgb(25, 150, 90), rgb(120, 220, 160), rgb(10, 35, 25) }, kind = 3, seed = 4.4, scale = 9, ink = 0.8 },
    { name = 'HBO Max', sub = 'Prestige drama', print = 'VELVET', palette = 'VIOLET', glow = rgb(170, 110, 255),
      c = { rgb(45, 20, 110), rgb(110, 70, 220), rgb(190, 170, 240), rgb(30, 15, 70) }, kind = 1, seed = 5.5, scale = 8, ink = 0.7 },
    { name = 'Apple TV+', sub = 'Originals', print = 'GRAPHITE', palette = 'SILVER', glow = rgb(230, 230, 240),
      c = { rgb(20, 20, 22), rgb(90, 92, 98), rgb(215, 215, 220), rgb(240, 240, 240) }, kind = 4, seed = 6.6, scale = 11, ink = 0.9 },
    { name = 'Peacock', sub = 'Shows, news and sport', print = 'PLUMAGE', palette = 'GOLD', glow = rgb(255, 215, 90),
      c = { rgb(15, 70, 70), rgb(210, 170, 70), rgb(40, 150, 140), rgb(25, 25, 20) }, kind = 2, seed = 7.7, scale = 9, ink = 0.85 },
    { name = 'Plex', sub = 'Your own library', print = 'MEADOW', palette = 'LIME', glow = rgb(200, 240, 60),
      c = { rgb(40, 60, 15), rgb(150, 190, 40), rgb(60, 110, 30), rgb(20, 30, 10) }, kind = 0, seed = 8.8, scale = 10, ink = 0.9 },
    { name = 'Tubi', sub = 'Free films', print = 'SALMON', palette = 'ORCHID', glow = rgb(255, 120, 200),
      c = { rgb(90, 20, 60), rgb(240, 170, 160), rgb(220, 60, 170), rgb(60, 15, 40) }, kind = 3, seed = 9.9, scale = 12, ink = 0.6 },
}

local INPUTS = { 'SMARTCAST', 'HDMI-1', 'HDMI-2', 'COMP', 'TV' }

-- ---------------------------------------------------------------- helpers
local function writeVec4(b: buffer, o: number, x: number, y: number, z: number, w: number)
    buffer.writef32(b, o, x)
    buffer.writef32(b, o + 4, y)
    buffer.writef32(b, o + 8, z)
    buffer.writef32(b, o + 12, w)
end

local function writePrint(b: buffer, o: number, app: App)
    for i = 1, 4 do
        local c = app.c[i]
        writeVec4(b, o + (i - 1) * 16, c[1], c[2], c[3], 1)
    end
    writeVec4(b, o + 64, app.kind, app.seed, app.scale, app.ink)
end

local function boxGeometry(): (buffer, buffer)
    -- 24 vertices (pos3, nrm3, uv2), 36 indices. Unit card 1.0 x 0.6 x 0.06.
    local hw, hh, hd = 0.5, 0.3, 0.03
    local faces = {
        -- normal, u axis, v axis
        { { 0, 0, 1 }, { 1, 0, 0 }, { 0, -1, 0 } },   -- front
        { { 0, 0, -1 }, { -1, 0, 0 }, { 0, -1, 0 } }, -- back
        { { 1, 0, 0 }, { 0, 0, -1 }, { 0, -1, 0 } },  -- right
        { { -1, 0, 0 }, { 0, 0, 1 }, { 0, -1, 0 } },  -- left
        { { 0, 1, 0 }, { 1, 0, 0 }, { 0, 0, -1 } },   -- top
        { { 0, -1, 0 }, { 1, 0, 0 }, { 0, 0, 1 } },   -- bottom
    }
    local vb = buffer.create(24 * 32)
    local ib = buffer.create(36 * 2)
    local vi = 0
    local ii = 0
    for f, face in ipairs(faces) do
        local n, ua, va = face[1], face[2], face[3]
        local ex = { hw * ua[1], hh * ua[2], hd * ua[3] }
        local ey = { hw * va[1], hh * va[2], hd * va[3] }
        local cx = { hw * n[1], hh * n[2], hd * n[3] }
        local corners = { { -1, -1, 0, 0 }, { 1, -1, 1, 0 }, { 1, 1, 1, 1 }, { -1, 1, 0, 1 } }
        local base = vi
        for _, c in ipairs(corners) do
            local px = cx[1] + ex[1] * c[1] + ey[1] * c[2]
            local py = cx[2] + ex[2] * c[1] + ey[2] * c[2]
            local pz = cx[3] + ex[3] * c[1] + ey[3] * c[2]
            local o = vi * 32
            buffer.writef32(vb, o, px)
            buffer.writef32(vb, o + 4, py)
            buffer.writef32(vb, o + 8, pz)
            buffer.writef32(vb, o + 12, n[1])
            buffer.writef32(vb, o + 16, n[2])
            buffer.writef32(vb, o + 20, n[3])
            buffer.writef32(vb, o + 24, c[3])
            buffer.writef32(vb, o + 28, c[4])
            vi += 1
        end
        -- two triangles, counter-clockwise seen from outside
        for _, idx in ipairs({ 0, 2, 1, 0, 3, 2 }) do
            buffer.writeu16(ib, ii * 2, base + idx)
            ii += 1
        end
    end
    return vb, ib
end

-- ---------------------------------------------------------------- lifecycle
function init(self: Menu, context: Context): boolean
    local vm = context:viewModel()
    if vm ~= nil then
        self.vTitle = vm:getString('title')
        self.vSub = vm:getString('subtitle')
        self.vCounter = vm:getString('counter')
        self.vPrint = vm:getString('printLabel')
        self.vClock = vm:getString('clock')
        self.vDate = vm:getString('date')
        self.vHint = vm:getString('hint')
        self.vPillX = vm:getNumber('pillX')
        self.vPillA = vm:getNumber('pillA')
        self.vAppsA = vm:getNumber('appsA')
        self.vLabels = {}
        self.vLabelX = {}
        self.vLabelA = {}
        for i = 0, LABELS - 1 do
            local s = vm:getString(`label{i}`)
            local x = vm:getNumber(`labelX{i}`)
            local a = vm:getNumber(`labelA{i}`)
            if s ~= nil and x ~= nil and a ~= nil then
                table.insert(self.vLabels, s)
                table.insert(self.vLabelX, x)
                table.insert(self.vLabelA, a)
            end
        end
        self:pushText()
    end
    if self.bgPipeline ~= nil then
        return true
    end

    local bgShader = context:shader('bg')
    local cardShader = context:shader('card')
    if bgShader == nil or cardShader == nil then
        print('menu: shaders missing')
        return true
    end
    local bgCanvas = context:gpuCanvas()
    local cardCanvas = context:gpuCanvas()
    if bgCanvas == nil or cardCanvas == nil then
        print('menu: no gpu canvas')
        return true
    end
    self.bgCanvas = bgCanvas
    self.cardCanvas = cardCanvas

    -- background: full-screen triangle, one uniform block
    local bgPipeline = GPUPipeline.new({
        vertex = bgShader,
        fragment = bgShader,
        vertexLayout = {},
        colorTargets = { { format = bgCanvas.format } },
    })
    local bgUbo = GPUBuffer.new({ size = 208, usage = 'uniform', label = 'bg-u' })
    self.bgPipeline = bgPipeline
    self.bgUbo = bgUbo
    self.bgBind = GPUBindGroup.new({
        layout = bgPipeline:getBindGroupLayout(0),
        ubos = { { slot = 0, buffer = bgUbo } },
    })

    -- cards: one box, drawn once per card with a dynamic uniform offset.
    -- 256 is the largest alignment WebGPU allows, so it is safe everywhere;
    -- context:features() cannot be read in init on the web.
    self.slot = 256
    local layout = GPUBindGroupLayout.new({ shader = cardShader, groupIndex = 0, dynamicUBOs = { 0 } })
    local cardPipeline = GPUPipeline.new({
        vertex = cardShader,
        fragment = cardShader,
        vertexLayout = { {
            stride = 32,
            attributes = {
                { format = 'float32x3', slot = 0, offset = 0 },
                { format = 'float32x3', slot = 1, offset = 12 },
                { format = 'float32x2', slot = 2, offset = 24 },
            },
        } },
        bindGroupLayouts = { layout },
        colorTargets = { { format = cardCanvas.format, blend = {
            srcColor = 'one', dstColor = 'one-minus-src-alpha', colorOp = 'add',
            srcAlpha = 'one', dstAlpha = 'one-minus-src-alpha', alphaOp = 'add',
        } } },
        cullMode = 'back',
    })
    local cardUbo = GPUBuffer.new({ size = self.slot * 2 * #self.apps, usage = 'uniform', label = 'card-u' })
    self.cardPipeline = cardPipeline
    self.cardUbo = cardUbo
    self.cardBind = GPUBindGroup.new({
        layout = layout,
        ubos = { { slot = 0, buffer = cardUbo, offset = 0, size = 256 } },
    })
    self.cardStaging = buffer.create(self.slot * 2 * #self.apps)
    local vb, ib = boxGeometry()
    self.vbuf = GPUBuffer.new({ size = buffer.len(vb), usage = 'vertex', data = vb, immutable = true })
    self.ibuf = GPUBuffer.new({ size = buffer.len(ib), usage = 'index', data = ib, immutable = true })
    return true
end

function resize(self: Menu, size: Vector, scale: number)
    self.size = size
    self.scale = scale
    local w, h = math.floor(size.x * scale), math.floor(size.y * scale)
    if w > 0 and h > 0 then
        if self.bgCanvas ~= nil then
            self.bgCanvas:resize(w, h)
        end
        if self.cardCanvas ~= nil then
            self.cardCanvas:resize(w, h)
        end
    end
end

-- ---------------------------------------------------------------- input
local function setStr(p: Property<string>?, v: string)
    if p ~= nil then
        p.value = v
    end
end

local function setNum(p: Property<number>?, v: number)
    if p ~= nil then
        p.value = v
    end
end

function pushText(self: Menu)
    if self.row == 0 then
        local app = self.apps[self.selected + 1]
        setStr(self.vTitle, app.name)
        setStr(self.vSub, app.sub)
        setStr(self.vCounter, `APPS   {self.selected + 1} / {#self.apps}`)
        setStr(self.vPrint, `PRINT   {app.print}   ·   {app.palette}`)
    else
        local name = self.inputs[self.inputSel + 1]
        setStr(self.vTitle, name)
        setStr(self.vSub, name)
        setStr(self.vCounter, `INPUTS   {self.inputSel + 1} / {#self.inputs}`)
    end
    local clock = os.date('%I:%M')
    if string.sub(clock, 1, 1) == '0' then
        clock = string.sub(clock, 2)
    end
    setStr(self.vClock, clock)
    setStr(self.vDate, string.upper(os.date('%A, %B %d')))
    setStr(self.vHint, 'ARROWS MOVE   ·   OK OPENS   ·   BACK GOES UP')
end

function selectApp(self: Menu, index: number)
    local n = #self.apps
    index = math.max(0, math.min(n - 1, index))
    if index == self.selected then
        return
    end
    self.wipeDir = if index > self.selected then 1 else -1
    self.prevApp = self.selected
    self.selected = index
    self.wipe = 0
    self.sweep = 0
    if self.selected < self.scroll then
        self.scroll = self.selected
    elseif self.selected > self.scroll + SLOTS - 1 then
        self.scroll = self.selected - SLOTS + 1
    end
    self:pushText()
end

function keyboardEvent(self: Menu, event: KeyboardEvent): boolean
    if event.phase == 'up' then
        return false
    end
    local k = event.key
    if self.row == 0 then
        if k == KEY_LEFT then
            self:selectApp(self.selected - 1)
        elseif k == KEY_RIGHT then
            self:selectApp(self.selected + 1)
        elseif k == KEY_DOWN then
            self.row = 1
            self:pushText()
        elseif k == KEY_ENTER then
            self.sweep = 0
        else
            print(`key {k}`)
            return false
        end
        return true
    end
    if k == KEY_LEFT then
        self.inputSel = math.max(0, self.inputSel - 1)
    elseif k == KEY_RIGHT then
        self.inputSel = math.min(#self.inputs - 1, self.inputSel + 1)
    elseif k == KEY_UP or k == KEY_ESC or k == KEY_BACKSPACE then
        self.row = 0
    else
        return false
    end
    self:pushText()
    return true
end

-- Screen rectangle of card i: centre x/y and half size, in artboard points.
function cardRect(self: Menu, i: number): (number, number, number, number)
    local w = if self.size.x > 0 then self.size.x else 1280
    local h = if self.size.y > 0 then self.size.y else 720
    local ppu = (h / 2) / (CAM_Z * math.tan(FOV / 2))
    local sel = math.max(0, 1 - math.abs(self.selectedF - i))
    local scale = 0.86 + 0.16 * sel
    local z = 0.25 * sel
    local persp = CAM_Z / (CAM_Z - z)
    local x = FIRST_X + (i - self.scrollF) * SPACING
    local cx = w / 2 + x * ppu * persp
    local cy = h / 2 - ROW_Y * ppu * persp
    return cx, cy, 0.5 * scale * ppu * persp, 0.3 * scale * ppu * persp
end

function pointerDown(self: Menu, event: PointerEvent)
    local px, py = event.position.x, event.position.y
    -- app cards
    for i = 0, #self.apps - 1 do
        local cx, cy, hw, hh = self:cardRect(i)
        if math.abs(px - cx) <= hw and math.abs(py - cy) <= hh then
            if self.row == 0 and i == self.selected then
                self.sweep = 0          -- "open": sweep the gloss again
            else
                self.row = 0
                self:selectApp(i)
                self:pushText()
            end
            return
        end
    end
    -- input buttons: 150 x 50 from (60, 606), 160 apart
    if py >= 606 and py <= 656 then
        for i = 0, #self.inputs - 1 do
            local x0 = 60 + i * 160
            if px >= x0 and px <= x0 + 150 then
                self.row = 1
                self.inputSel = i
                self:pushText()
                return
            end
        end
    end
end

-- ---------------------------------------------------------------- per frame
function advance(self: Menu, seconds: number): boolean
    local s = math.min(seconds, 0.05)
    self.time += s
    local k = 1 - math.exp(-9 * s)
    self.selectedF += (self.selected - self.selectedF) * k
    self.scrollF += (self.scroll - self.scrollF) * (1 - math.exp(-7 * s))
    self.inputSelF += (self.inputSel - self.inputSelF) * k
    self.wipe = math.min(1, self.wipe + s * 1.7)
    self.sweep = math.min(2.2, self.sweep + s * 2.4)

    -- labels under the cards and the input pill: markup bound to these
    local w = if self.size.x > 0 then self.size.x else 1280
    local h = if self.size.y > 0 then self.size.y else 720
    local pxPerUnit = (h / 2) / (CAM_Z * math.tan(FOV / 2))
    for i = 1, #self.vLabels do
        local appIndex = math.floor(self.scrollF + 0.5) - 1 + (i - 1)   -- one before the window .. one after
        local app = self.apps[appIndex + 1]
        local x = FIRST_X + (appIndex - self.scrollF) * SPACING
        local px = w / 2 + x * pxPerUnit
        if app ~= nil then
            setStr(self.vLabels[i], app.name)
            setNum(self.vLabelX[i], px)
            local selAmt = math.max(0, 1 - math.abs(self.selectedF - appIndex))
            local inView = 1 - math.min(1, math.max(0, (math.abs(x) - 2.3) / 0.5))
            setNum(self.vLabelA[i], (0.35 + 0.65 * selAmt) * inView * (if self.row == 0 then 1 else 0.5))
        else
            setNum(self.vLabelA[i], 0)
        end
    end
    setNum(self.vPillX, 60 + 76 + self.inputSelF * 160)
    setNum(self.vPillA, if self.row == 1 then 1 else 0)
    setNum(self.vAppsA, if self.row == 0 then 1 else 0.45)
    return true
end

function draw(self: Menu, renderer: Renderer)
    local bgCanvas, cardCanvas = self.bgCanvas, self.cardCanvas
    local bgPipeline, cardPipeline = self.bgPipeline, self.cardPipeline
    local bgUbo, cardUbo = self.bgUbo, self.cardUbo
    local bgBind, cardBind = self.bgBind, self.cardBind
    local vbuf, ibuf = self.vbuf, self.ibuf
    if bgCanvas == nil or cardCanvas == nil or bgPipeline == nil or cardPipeline == nil
        or bgUbo == nil or cardUbo == nil or bgBind == nil or cardBind == nil
        or vbuf == nil or ibuf == nil then
        return
    end
    -- on the web the first resize can land before init made the canvases
    if bgCanvas.width == 0 or cardCanvas.width == 0 then
        local pw, ph = math.floor(self.size.x * self.scale), math.floor(self.size.y * self.scale)
        if pw <= 0 or ph <= 0 then
            return
        end
        bgCanvas:resize(pw, ph)
        cardCanvas:resize(pw, ph)
    end
    local w = if self.size.x > 0 then self.size.x else 1280
    local h = if self.size.y > 0 then self.size.y else 720
    local aspect = w / h
    local cur = self.apps[self.selected + 1]
    local prev = self.apps[self.prevApp + 1]
    local pxPerUnit = (h / 2) / (CAM_Z * math.tan(FOV / 2))

    -- background
    local b = self.bgStaging
    local selX = FIRST_X + (self.selectedF - self.scrollF) * SPACING
    buffer.writef32(b, 0, self.time)
    buffer.writef32(b, 4, self.wipe)
    buffer.writef32(b, 8, self.wipeDir)
    buffer.writef32(b, 12, 0.05)
    buffer.writef32(b, 16, bgCanvas.width)
    buffer.writef32(b, 20, bgCanvas.height)
    buffer.writef32(b, 24, 0.5 + selX * pxPerUnit / w)
    buffer.writef32(b, 28, 0.5 - (ROW_Y - 0.5) * pxPerUnit / h)
    local dim = if self.row == 0 then 1 else 0.35
    writeVec4(b, 32, cur.glow[1] * dim, cur.glow[2] * dim, cur.glow[3] * dim, 1)
    writePrint(b, 48, prev)
    writePrint(b, 128, cur)
    bgUbo:write(b)
    local pass = bgCanvas:beginRenderPass({
        color = { { loadOp = 'clear', storeOp = 'store', clearColor = { 0, 0, 0, 1 } } },
    })
    pass:setPipeline(bgPipeline)
    pass:setBindGroup(0, bgBind)
    pass:draw(3)
    pass:finish()

    -- cards: reflections first, then the boxes, far from the centre first
    local proj = Mat4.perspective(FOV, aspect, 0.1, 50)
    local view = Mat4.lookAt(Vector.xyz(0, 0, CAM_Z), Vector.xyz(0, 0, 0), Vector.xyz(0, 1, 0))
    local vp = proj * view
    local order: { number } = {}
    for i = 0, #self.apps - 1 do
        table.insert(order, i)
    end
    table.sort(order, function(a: number, c: number): boolean
        return math.abs(a - self.selectedF) > math.abs(c - self.selectedF)
    end)
    local cs = self.cardStaging
    local n = 0
    local draws: { number } = {}
    for pass_i = 1, 2 do
        local reflection = pass_i == 1
        for _, i in ipairs(order) do
            local app = self.apps[i + 1]
            local x = FIRST_X + (i - self.scrollF) * SPACING
            if math.abs(x) < 3.4 then
                local sel = math.max(0, 1 - math.abs(self.selectedF - i))
                local rowDim = if self.row == 0 then 1 else 0.45
                local scale = 0.86 + 0.16 * sel
                local z = 0.25 * sel
                local rotY = -x * 0.11
                local model = Mat4.fromTranslation(x, ROW_Y, z) * Mat4.fromRotationY(rotY) * Mat4.fromScale(scale, scale, 1)
                local floorY = ROW_Y - 0.3 * scale - 0.02
                if reflection then
                    -- a half turn about the floor line keeps the winding, so the
                    -- same pipeline draws it; the shader reads its back face
                    model = Mat4.fromTranslation(0, 2 * floorY, 0) * Mat4.fromRotationX(math.pi) * model
                end
                local mvp = vp * model
                local o = n * self.slot
                mvp:writeToBuffer(cs, o)
                model:writeToBuffer(cs, o + 64)
                writeVec4(cs, o + 128, app.glow[1], app.glow[2], app.glow[3], 0.6 * scale)
                local sweep = if sel > 0.5 then self.sweep else 2.2
                writeVec4(cs, o + 144, sel * rowDim, if reflection then 1 else 0, sweep, floorY)
                writePrint(cs, o + 160, app)
                table.insert(draws, o)
                n += 1
            end
        end
    end
    cardUbo:write(cs, 0, 0, n * self.slot)
    local cpass = cardCanvas:beginRenderPass({
        color = { { loadOp = 'clear', storeOp = 'store', clearColor = { 0, 0, 0, 0 } } },
    })
    cpass:setPipeline(cardPipeline)
    cpass:setVertexBuffer(0, vbuf)
    cpass:setIndexBuffer(ibuf, 'uint16')
    for _, o in ipairs(draws) do
        cpass:setBindGroup(0, cardBind, { o })
        cpass:drawIndexed(36)
    end
    cpass:finish()

    renderer:save()
    local inv = 1 / self.scale
    renderer:transform(Mat2D.values(inv, 0, 0, inv, 0, 0))
    renderer:drawImage(bgCanvas.image, self.sampler, 'srcOver', 1)
    renderer:drawImage(cardCanvas.image, self.sampler, 'srcOver', 1)
    renderer:restore()
end

return function(context: Context): Layout<Menu>
    return {
        size = Vector.xy(0, 0),
        scale = 1,
        time = 0,
        apps = APPS,
        inputs = INPUTS,
        row = 0,
        selected = 0,
        selectedF = 0,
        scroll = 0,
        scrollF = 0,
        inputSel = 0,
        inputSelF = 0,
        prevApp = 0,
        wipe = 1,
        wipeDir = 1,
        sweep = 0,
        bgCanvas = nil,
        cardCanvas = nil,
        bgPipeline = nil,
        bgUbo = nil,
        bgBind = nil,
        cardPipeline = nil,
        cardUbo = nil,
        cardBind = nil,
        vbuf = nil,
        ibuf = nil,
        sampler = ImageSampler('clamp', 'clamp', 'bilinear'),
        bgStaging = buffer.create(208),
        cardStaging = buffer.create(256),
        slot = 256,
        vTitle = nil,
        vSub = nil,
        vCounter = nil,
        vPrint = nil,
        vClock = nil,
        vDate = nil,
        vHint = nil,
        vLabels = {},
        vLabelX = {},
        vLabelA = {},
        vPillX = nil,
        vPillA = nil,
        vAppsA = nil,
        init = init,
        resize = resize,
        advance = advance,
        draw = draw,
        keyboardEvent = keyboardEvent,
        pointerDown = pointerDown,
        pushText = pushText,
        selectApp = selectApp,
        cardRect = cardRect,
    }
end
