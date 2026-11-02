-- TV home menu: keyboard, mouse hover and click drive the selection over two
-- rows (apps, inputs). The script renders three things into two GPU canvases:
--   bg    quarter-resolution background: the current print, folded, defocused,
--         burned through by the next one on a change (bg.wgsl)
--   cards one 3D box per app with the print as its face (card.wgsl)
--   grain full-resolution film grain over the cards (grade.wgsl)
-- The ten prints are rendered once into textures (print.wgsl) on the first
-- frame. Text around the scene is markup bound to the Menu view model.

type App = {
    name: string,
    sub: string,
    print: string,
    palette: string,
    glow: { number },
    c: { { number } },
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
    row: number,
    selected: number,
    selectedF: number,
    scroll: number,
    scrollF: number,
    inputSel: number,
    inputSelF: number,
    sweep: number,
    -- background queue
    bgShown: number,
    bgFrom: number,
    bgTo: number,
    bgT: number,
    bgRunning: boolean,
    bgDir: number,
    bgSeed: number,
    bgQueue: { number },
    -- gpu
    ready: boolean,
    printsDone: boolean,
    bgCanvas: GPUCanvas?,
    cardCanvas: GPUCanvas?,
    sampler: ImageSampler,
    texSampler: GPUSampler?,
    printShader: Shader?,
    printPipeline: GPUPipeline?,
    printUbo: GPUBuffer?,
    printBind: GPUBindGroup?,
    printTex: { GPUTexture },
    printView: { GPUTextureView },
    bgPipeline: GPUPipeline?,
    bgUbo: GPUBuffer?,
    bgBind0: GPUBindGroup?,
    bgLayout1: GPUBindGroupLayout?,
    bgBind1: { [string]: GPUBindGroup },
    cardPipeline: GPUPipeline?,
    cardUbo: GPUBuffer?,
    cardBind0: GPUBindGroup?,
    cardBind1: { GPUBindGroup },
    cardLayout1: GPUBindGroupLayout?,
    gradePipeline: GPUPipeline?,
    gradeUbo: GPUBuffer?,
    gradeBind: GPUBindGroup?,
    vbuf: GPUBuffer?,
    ibuf: GPUBuffer?,
    printStaging: buffer,
    bgStaging: buffer,
    cardStaging: buffer,
    gradeStaging: buffer,
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
    hitTest: (self: Menu, px: number, py: number) -> (number, number),
    renderPrints: (self: Menu) -> (),
    hover: (self: Menu, kind: number, i: number) -> (),
}

local SLOTS = 5
local SPACING = 1.07
local FIRST_X = -1.98
local ROW_Y = -0.49
local CAM_Z = 6.0
local FOV = math.rad(30)
local LABELS = 7
local BG_DIV = 4            -- background renders at 1/4 of the screen
local PRINT_W, PRINT_H = 640, 400
local BURN_SECONDS = 1.1
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

local function boxGeometry(): (buffer, buffer)
    local hw, hh, hd = 0.5, 0.3, 0.03
    local faces = {
        { { 0, 0, 1 }, { 1, 0, 0 }, { 0, -1, 0 } },
        { { 0, 0, -1 }, { -1, 0, 0 }, { 0, -1, 0 } },
        { { 1, 0, 0 }, { 0, 0, -1 }, { 0, -1, 0 } },
        { { -1, 0, 0 }, { 0, 0, 1 }, { 0, -1, 0 } },
        { { 0, 1, 0 }, { 1, 0, 0 }, { 0, 0, -1 } },
        { { 0, -1, 0 }, { 1, 0, 0 }, { 0, 0, 1 } },
    }
    local vb = buffer.create(24 * 32)
    local ib = buffer.create(36 * 2)
    local vi = 0
    local ii = 0
    for _, face in ipairs(faces) do
        local n, ua, va = face[1], face[2], face[3]
        local ex = { hw * ua[1], hh * ua[2], hd * ua[3] }
        local ey = { hw * va[1], hh * va[2], hd * va[3] }
        local cx = { hw * n[1], hh * n[2], hd * n[3] }
        local corners = { { -1, -1, 0, 0 }, { 1, -1, 1, 0 }, { 1, 1, 1, 1 }, { -1, 1, 0, 1 } }
        local base = vi
        for _, c in ipairs(corners) do
            local o = vi * 32
            buffer.writef32(vb, o, cx[1] + ex[1] * c[1] + ey[1] * c[2])
            buffer.writef32(vb, o + 4, cx[2] + ex[2] * c[1] + ey[2] * c[2])
            buffer.writef32(vb, o + 8, cx[3] + ex[3] * c[1] + ey[3] * c[2])
            buffer.writef32(vb, o + 12, n[1])
            buffer.writef32(vb, o + 16, n[2])
            buffer.writef32(vb, o + 20, n[3])
            buffer.writef32(vb, o + 24, c[3])
            buffer.writef32(vb, o + 28, c[4])
            vi += 1
        end
        for _, idx in ipairs({ 0, 2, 1, 0, 3, 2 }) do
            buffer.writeu16(ib, ii * 2, base + idx)
            ii += 1
        end
    end
    return vb, ib
end

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
    if self.ready then
        return true
    end

    local printShader = context:shader('print')
    local bgShader = context:shader('bg')
    local cardShader = context:shader('card')
    local gradeShader = context:shader('grade')
    if printShader == nil or bgShader == nil or cardShader == nil or gradeShader == nil then
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
    local fmt = bgCanvas.format
    local texSampler = GPUSampler.new({ wrapU = 'mirror-repeat', wrapV = 'mirror-repeat' })
    self.texSampler = texSampler

    -- prints: one texture per app, rendered on the first frame
    self.printShader = printShader
    local printPipeline = GPUPipeline.new({
        vertex = printShader, fragment = printShader, vertexLayout = {},
        colorTargets = { { format = fmt } },
    })
    local printUbo = GPUBuffer.new({ size = 96, usage = 'uniform', label = 'print-u' })
    self.printPipeline = printPipeline
    self.printUbo = printUbo
    self.printBind = GPUBindGroup.new({
        layout = printPipeline:getBindGroupLayout(0),
        ubos = { { slot = 0, buffer = printUbo } },
    })
    self.printTex = {}
    self.printView = {}
    for i = 1, #self.apps do
        local tex = GPUTexture.new({ width = PRINT_W, height = PRINT_H, format = fmt, renderTarget = true, label = `print{i}` })
        self.printTex[i] = tex
        self.printView[i] = tex:view()
    end

    -- background
    local bgLayout0 = GPUBindGroupLayout.new({ shader = bgShader, groupIndex = 0 })
    local bgLayout1 = GPUBindGroupLayout.new({ shader = bgShader, groupIndex = 1 })
    local bgPipeline = GPUPipeline.new({
        vertex = bgShader, fragment = bgShader, vertexLayout = {},
        bindGroupLayouts = { bgLayout0, bgLayout1 },
        colorTargets = { { format = fmt } },
    })
    local bgUbo = GPUBuffer.new({ size = 48, usage = 'uniform', label = 'bg-u' })
    self.bgPipeline = bgPipeline
    self.bgUbo = bgUbo
    self.bgLayout1 = bgLayout1
    self.bgBind0 = GPUBindGroup.new({ layout = bgLayout0, ubos = { { slot = 0, buffer = bgUbo } } })
    self.bgBind1 = {}

    -- cards: one box, drawn once per card with a dynamic uniform offset
    self.slot = 256
    local cardLayout0 = GPUBindGroupLayout.new({ shader = cardShader, groupIndex = 0, dynamicUBOs = { 0 } })
    local cardLayout1 = GPUBindGroupLayout.new({ shader = cardShader, groupIndex = 1 })
    local cardPipeline = GPUPipeline.new({
        vertex = cardShader, fragment = cardShader,
        vertexLayout = { {
            stride = 32,
            attributes = {
                { format = 'float32x3', slot = 0, offset = 0 },
                { format = 'float32x3', slot = 1, offset = 12 },
                { format = 'float32x2', slot = 2, offset = 24 },
            },
        } },
        bindGroupLayouts = { cardLayout0, cardLayout1 },
        colorTargets = { { format = fmt, blend = {
            srcColor = 'one', dstColor = 'one-minus-src-alpha', colorOp = 'add',
            srcAlpha = 'one', dstAlpha = 'one-minus-src-alpha', alphaOp = 'add',
        } } },
        cullMode = 'back',
    })
    local cardUbo = GPUBuffer.new({ size = self.slot * 2 * #self.apps, usage = 'uniform', label = 'card-u' })
    self.cardPipeline = cardPipeline
    self.cardUbo = cardUbo
    self.cardLayout1 = cardLayout1
    self.cardBind0 = GPUBindGroup.new({ layout = cardLayout0, ubos = { { slot = 0, buffer = cardUbo, offset = 0, size = 256 } } })
    self.cardBind1 = {}
    for i = 1, #self.apps do
        self.cardBind1[i] = GPUBindGroup.new({
            layout = cardLayout1,
            textures = { { slot = 0, view = self.printView[i] } },
            samplers = { { slot = 1, sampler = texSampler } },
        })
    end
    self.cardStaging = buffer.create(self.slot * 2 * #self.apps)
    local vb, ib = boxGeometry()
    self.vbuf = GPUBuffer.new({ size = buffer.len(vb), usage = 'vertex', data = vb, immutable = true })
    self.ibuf = GPUBuffer.new({ size = buffer.len(ib), usage = 'index', data = ib, immutable = true })

    -- grain over the cards
    local gradePipeline = GPUPipeline.new({
        vertex = gradeShader, fragment = gradeShader, vertexLayout = {},
        colorTargets = { { format = fmt, blend = {
            srcColor = 'one', dstColor = 'one-minus-src-alpha', colorOp = 'add',
            srcAlpha = 'one', dstAlpha = 'one-minus-src-alpha', alphaOp = 'add',
        } } },
    })
    local gradeUbo = GPUBuffer.new({ size = 16, usage = 'uniform', label = 'grade-u' })
    self.gradePipeline = gradePipeline
    self.gradeUbo = gradeUbo
    self.gradeBind = GPUBindGroup.new({ layout = gradePipeline:getBindGroupLayout(0), ubos = { { slot = 0, buffer = gradeUbo } } })
    self.ready = true
    return true
end

function resize(self: Menu, size: Vector, scale: number)
    self.size = size
    self.scale = scale
    local w, h = math.floor(size.x * scale), math.floor(size.y * scale)
    if w > 0 and h > 0 then
        if self.bgCanvas ~= nil then
            self.bgCanvas:resize(math.max(1, math.floor(w / BG_DIV)), math.max(1, math.floor(h / BG_DIV)))
        end
        if self.cardCanvas ~= nil then
            self.cardCanvas:resize(w, h)
        end
    end
end

-- Each print, once, into its texture.
function renderPrints(self: Menu)
    local canvas, pipeline, ubo, bind = self.bgCanvas, self.printPipeline, self.printUbo, self.printBind
    if canvas == nil or pipeline == nil or ubo == nil or bind == nil then
        return
    end
    local b = self.printStaging
    for i, app in ipairs(self.apps) do
        for k = 1, 4 do
            local c = app.c[k]
            writeVec4(b, (k - 1) * 16, c[1], c[2], c[3], 1)
        end
        writeVec4(b, 64, app.kind, app.seed, app.scale, app.ink)
        writeVec4(b, 80, PRINT_W, PRINT_H, 0, 0)
        ubo:write(b)
        local pass = canvas:beginRenderPass({
            color = { { view = self.printView[i], loadOp = 'clear', storeOp = 'store', clearColor = { 0, 0, 0, 1 } } },
        })
        pass:setPipeline(pipeline)
        pass:setBindGroup(0, bind)
        pass:draw(3)
        pass:finish()
    end
    self.printsDone = true
end

-- ---------------------------------------------------------------- selection
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
    self.selected = index
    self.sweep = 0
    if self.selected < self.scroll then
        self.scroll = self.selected
    elseif self.selected > self.scroll + SLOTS - 1 then
        self.scroll = self.selected - SLOTS + 1
    end
    -- the background follows later, one burn at a time
    table.insert(self.bgQueue, index)
    self:pushText()
end

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

-- Returns (kind, index): kind 0 = app card, 1 = input button, -1 = nothing.
function hitTest(self: Menu, px: number, py: number): (number, number)
    for i = 0, #self.apps - 1 do
        local cx, cy, hw, hh = self:cardRect(i)
        if math.abs(px - cx) <= hw and math.abs(py - cy) <= hh then
            return 0, i
        end
    end
    if py >= 606 and py <= 656 then
        for i = 0, #self.inputs - 1 do
            local x0 = 60 + i * 160
            if px >= x0 and px <= x0 + 150 then
                return 1, i
            end
        end
    end
    return -1, 0
end

function hover(self: Menu, kind: number, i: number)
    if kind == 0 then
        if self.row ~= 0 or i ~= self.selected then
            self.row = 0
            self:selectApp(i)
            self:pushText()
        end
    elseif kind == 1 then
        if self.row ~= 1 or i ~= self.inputSel then
            self.row = 1
            self.inputSel = i
            self:pushText()
        end
    end
end

function pointerMove(self: Menu, event: PointerEvent)
    local kind, i = self:hitTest(event.position.x, event.position.y)
    self:hover(kind, i)
end

function pointerDown(self: Menu, event: PointerEvent)
    local kind, i = self:hitTest(event.position.x, event.position.y)
    if kind == 0 and self.row == 0 and i == self.selected then
        self.sweep = 0          -- "open": sweep the gloss again
    else
        self:hover(kind, i)
    end
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

-- ---------------------------------------------------------------- per frame
function advance(self: Menu, seconds: number): boolean
    local s = math.min(seconds, 0.05)
    self.time += s
    local k = 1 - math.exp(-9 * s)
    self.selectedF += (self.selected - self.selectedF) * k
    self.scrollF += (self.scroll - self.scrollF) * (1 - math.exp(-7 * s))
    self.inputSelF += (self.inputSel - self.inputSelF) * k
    self.sweep = math.min(2.2, self.sweep + s * 2.4)

    -- background burns: one at a time, in the order they were asked for
    if self.bgRunning then
        self.bgT = math.min(1, self.bgT + s / BURN_SECONDS)
        if self.bgT >= 1 then
            self.bgRunning = false
            self.bgShown = self.bgTo
            self.bgFrom = self.bgTo
        end
    elseif #self.bgQueue > 0 then
        local target = table.remove(self.bgQueue, 1) :: number
        if target ~= self.bgShown then
            self.bgFrom = self.bgShown
            self.bgTo = target
            self.bgDir = if target > self.bgShown then 1 else -1
            self.bgSeed = math.random()
            self.bgT = 0
            self.bgRunning = true
        end
    end

    local w = if self.size.x > 0 then self.size.x else 1280
    local h = if self.size.y > 0 then self.size.y else 720
    local pxPerUnit = (h / 2) / (CAM_Z * math.tan(FOV / 2))
    for i = 1, #self.vLabels do
        local appIndex = math.floor(self.scrollF + 0.5) - 1 + (i - 1)
        local app = self.apps[appIndex + 1]
        local x = FIRST_X + (appIndex - self.scrollF) * SPACING
        if app ~= nil then
            setStr(self.vLabels[i], app.name)
            setNum(self.vLabelX[i], w / 2 + x * pxPerUnit)
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
    local bgPipeline, cardPipeline, gradePipeline = self.bgPipeline, self.cardPipeline, self.gradePipeline
    local bgUbo, cardUbo, gradeUbo = self.bgUbo, self.cardUbo, self.gradeUbo
    local bgBind0, bgLayout1, cardBind0, gradeBind = self.bgBind0, self.bgLayout1, self.cardBind0, self.gradeBind
    local vbuf, ibuf, texSampler = self.vbuf, self.ibuf, self.texSampler
    if not self.ready or bgCanvas == nil or cardCanvas == nil or bgPipeline == nil or cardPipeline == nil
        or gradePipeline == nil or bgUbo == nil or cardUbo == nil or gradeUbo == nil or bgBind0 == nil
        or bgLayout1 == nil or cardBind0 == nil or gradeBind == nil or vbuf == nil or ibuf == nil or texSampler == nil then
        return
    end
    -- on the web the first resize can land before init made the canvases
    if bgCanvas.width == 0 or cardCanvas.width == 0 then
        local pw, ph = math.floor(self.size.x * self.scale), math.floor(self.size.y * self.scale)
        if pw <= 0 or ph <= 0 then
            return
        end
        bgCanvas:resize(math.max(1, math.floor(pw / BG_DIV)), math.max(1, math.floor(ph / BG_DIV)))
        cardCanvas:resize(pw, ph)
    end
    if not self.printsDone then
        self:renderPrints()
    end
    local w = if self.size.x > 0 then self.size.x else 1280
    local h = if self.size.y > 0 then self.size.y else 720
    local aspect = w / h
    local cur = self.apps[self.selected + 1]
    local pxPerUnit = (h / 2) / (CAM_Z * math.tan(FOV / 2))

    -- background
    local key = `{self.bgFrom}-{self.bgTo}`
    local bind1 = self.bgBind1[key]
    if bind1 == nil then
        bind1 = GPUBindGroup.new({
            layout = bgLayout1,
            textures = { { slot = 0, view = self.printView[self.bgFrom + 1] }, { slot = 1, view = self.printView[self.bgTo + 1] } },
            samplers = { { slot = 2, sampler = texSampler } },
        })
        self.bgBind1[key] = bind1
    end
    local b = self.bgStaging
    local selX = FIRST_X + (self.selectedF - self.scrollF) * SPACING
    buffer.writef32(b, 0, self.time)
    buffer.writef32(b, 4, if self.bgRunning then self.bgT else 1)
    buffer.writef32(b, 8, self.bgDir)
    buffer.writef32(b, 12, self.bgSeed)
    buffer.writef32(b, 16, bgCanvas.width)
    buffer.writef32(b, 20, bgCanvas.height)
    buffer.writef32(b, 24, 0.5 + selX * pxPerUnit / w)
    buffer.writef32(b, 28, 0.5 - (ROW_Y - 0.5) * pxPerUnit / h)
    local dim = if self.row == 0 then 1 else 0.35
    writeVec4(b, 32, cur.glow[1] * dim, cur.glow[2] * dim, cur.glow[3] * dim, 1)
    bgUbo:write(b)
    local pass = bgCanvas:beginRenderPass({
        color = { { loadOp = 'clear', storeOp = 'store', clearColor = { 0, 0, 0, 1 } } },
    })
    pass:setPipeline(bgPipeline)
    pass:setBindGroup(0, bgBind0)
    pass:setBindGroup(1, bind1)
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
    local drawApp: { number } = {}
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
                local model = Mat4.fromTranslation(x, ROW_Y, z) * Mat4.fromRotationY(-x * 0.11) * Mat4.fromScale(scale, scale, 1)
                local floorY = ROW_Y - 0.3 * scale - 0.02
                if reflection then
                    model = Mat4.fromTranslation(0, 2 * floorY, 0) * Mat4.fromRotationX(math.pi) * model
                end
                local mvp = vp * model
                local o = n * self.slot
                mvp:writeToBuffer(cs, o)
                model:writeToBuffer(cs, o + 64)
                writeVec4(cs, o + 128, app.glow[1], app.glow[2], app.glow[3], 0.6 * scale)
                local sweep = if sel > 0.5 then self.sweep else 2.2
                writeVec4(cs, o + 144, sel * rowDim, if reflection then 1 else 0, sweep, floorY)
                table.insert(draws, o)
                table.insert(drawApp, i + 1)
                n += 1
            end
        end
    end
    cardUbo:write(cs, 0, 0, n * self.slot)
    local g = self.gradeStaging
    buffer.writef32(g, 0, self.time)
    buffer.writef32(g, 4, cardCanvas.width)
    buffer.writef32(g, 8, cardCanvas.height)
    buffer.writef32(g, 12, 0.07)
    gradeUbo:write(g)

    local cpass = cardCanvas:beginRenderPass({
        color = { { loadOp = 'clear', storeOp = 'store', clearColor = { 0, 0, 0, 0 } } },
    })
    cpass:setPipeline(cardPipeline)
    cpass:setVertexBuffer(0, vbuf)
    cpass:setIndexBuffer(ibuf, 'uint16')
    for d, o in ipairs(draws) do
        cpass:setBindGroup(0, cardBind0, { o })
        cpass:setBindGroup(1, self.cardBind1[drawApp[d]])
        cpass:drawIndexed(36)
    end
    cpass:setPipeline(gradePipeline)
    cpass:setBindGroup(0, gradeBind)
    cpass:draw(3)
    cpass:finish()

    renderer:save()
    local inv = 1 / self.scale
    renderer:transform(Mat2D.values(inv * BG_DIV, 0, 0, inv * BG_DIV, 0, 0))
    renderer:drawImage(bgCanvas.image, self.sampler, 'srcOver', 1)
    renderer:restore()
    renderer:save()
    renderer:transform(Mat2D.values(inv, 0, 0, inv, 0, 0))
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
        sweep = 0,
        bgShown = 0,
        bgFrom = 0,
        bgTo = 0,
        bgT = 1,
        bgRunning = false,
        bgDir = 1,
        bgSeed = 0.37,
        bgQueue = {},
        ready = false,
        printsDone = false,
        bgCanvas = nil,
        cardCanvas = nil,
        sampler = ImageSampler('clamp', 'clamp', 'bilinear'),
        texSampler = nil,
        printShader = nil,
        printPipeline = nil,
        printUbo = nil,
        printBind = nil,
        printTex = {},
        printView = {},
        bgPipeline = nil,
        bgUbo = nil,
        bgBind0 = nil,
        bgLayout1 = nil,
        bgBind1 = {},
        cardPipeline = nil,
        cardUbo = nil,
        cardBind0 = nil,
        cardBind1 = {},
        cardLayout1 = nil,
        gradePipeline = nil,
        gradeUbo = nil,
        gradeBind = nil,
        vbuf = nil,
        ibuf = nil,
        printStaging = buffer.create(96),
        bgStaging = buffer.create(48),
        cardStaging = buffer.create(256),
        gradeStaging = buffer.create(16),
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
        pointerMove = pointerMove,
        pointerDown = pointerDown,
        pushText = pushText,
        selectApp = selectApp,
        cardRect = cardRect,
        hitTest = hitTest,
        renderPrints = renderPrints,
        hover = hover,
    }
end
