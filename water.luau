-- Full-screen water background rendered by water.wgsl. Colours, light angle
-- and intensity are read from the Scene view model every frame.

type Water = {
    size: Vector,
    scale: number,
    time: number,
    canvas: GPUCanvas?,
    pipeline: GPUPipeline?,
    ubo: GPUBuffer?,
    bindGroup: GPUBindGroup?,
    sampler: ImageSampler,
    staging: buffer,
    waterTop: Property<Color>?,
    waterBottom: Property<Color>?,
    lightColor: Property<Color>?,
    lightIntensity: Property<number>?,
    lightAngle: Property<number>?,
    jellyX: Property<number>?,
    jellyY: Property<number>?,
}

local function writeColor(b: buffer, offset: number, prop: Property<Color>?, fallback: Color)
    local c = fallback
    if prop ~= nil then
        c = prop.value
    end
    local f = Color.toFloat(c)
    buffer.writef32(b, offset, f[1])
    buffer.writef32(b, offset + 4, f[2])
    buffer.writef32(b, offset + 8, f[3])
    buffer.writef32(b, offset + 12, f[4])
end

function init(self: Water, context: Context): boolean
    local vm = context:viewModel()
    if vm ~= nil then
        self.waterTop = vm:getColor('waterTop')
        self.waterBottom = vm:getColor('waterBottom')
        self.lightColor = vm:getColor('lightColor')
        self.lightIntensity = vm:getNumber('lightIntensity')
        self.lightAngle = vm:getNumber('lightAngle')
        self.jellyX = vm:getNumber('jellyX')
        self.jellyY = vm:getNumber('jellyY')
    end
    if self.pipeline ~= nil then
        return true
    end
    local shader = context:shader('water')
    if shader == nil then
        print('water: shader missing')
        return true
    end
    local canvas = context:gpuCanvas()
    if canvas == nil then
        print('water: no gpu canvas')
        return true
    end
    self.canvas = canvas
    local pipeline = GPUPipeline.new({
        vertex = shader,
        fragment = shader,
        vertexLayout = {},
        colorTargets = { { format = canvas.format } },
    })
    local ubo = GPUBuffer.new({ size = 80, usage = 'uniform', label = 'water-u' })
    self.pipeline = pipeline
    self.ubo = ubo
    self.bindGroup = GPUBindGroup.new({
        layout = pipeline:getBindGroupLayout(0),
        ubos = { { slot = 0, buffer = ubo } },
    })
    return true
end

function resize(self: Water, size: Vector, scale: number)
    self.size = size
    self.scale = scale
    local canvas = self.canvas
    if canvas ~= nil and size.x > 0 and size.y > 0 then
        canvas:resize(math.floor(size.x * scale), math.floor(size.y * scale))
    end
end

function advance(self: Water, seconds: number): boolean
    self.time += seconds
    return true
end

local function num(prop: Property<number>?, fallback: number): number
    if prop ~= nil then
        return prop.value
    end
    return fallback
end

function draw(self: Water, renderer: Renderer)
    local canvas = self.canvas
    local pipeline = self.pipeline
    local ubo = self.ubo
    local bg = self.bindGroup
    if canvas == nil or pipeline == nil or ubo == nil or bg == nil or canvas.width == 0 then
        return
    end
    local b = self.staging
    local w = if self.size.x > 0 then self.size.x else 600
    local h = if self.size.y > 0 then self.size.y else 800
    buffer.writef32(b, 0, self.time)
    buffer.writef32(b, 4, canvas.width)
    buffer.writef32(b, 8, canvas.height)
    buffer.writef32(b, 12, num(self.lightAngle, -14) * math.pi / 180)
    buffer.writef32(b, 16, num(self.lightIntensity, 0.65))
    buffer.writef32(b, 20, num(self.jellyX, 300) / w)
    buffer.writef32(b, 24, num(self.jellyY, 330) / h)
    buffer.writef32(b, 28, 0)
    writeColor(b, 32, self.waterTop, Color.rgb(10, 42, 72))
    writeColor(b, 48, self.waterBottom, Color.rgb(2, 6, 14))
    writeColor(b, 64, self.lightColor, Color.rgb(169, 220, 255))
    ubo:write(b)

    local pass = canvas:beginRenderPass({
        color = { { loadOp = 'clear', storeOp = 'store', clearColor = { 0, 0, 0, 1 } } },
    })
    pass:setPipeline(pipeline)
    pass:setBindGroup(0, bg)
    pass:draw(3)
    pass:finish()

    renderer:save()
    local inv = 1 / self.scale
    renderer:transform(Mat2D.values(inv, 0, 0, inv, 0, 0))
    renderer:drawImage(canvas.image, self.sampler, 'srcOver', 1)
    renderer:restore()
end

return function(context: Context): Layout<Water>
    return {
        size = Vector.xy(0, 0),
        scale = 1,
        time = 0,
        canvas = nil,
        pipeline = nil,
        ubo = nil,
        bindGroup = nil,
        sampler = ImageSampler('clamp', 'clamp', 'bilinear'),
        staging = buffer.create(80),
        waterTop = nil,
        waterBottom = nil,
        lightColor = nil,
        lightIntensity = nil,
        lightAngle = nil,
        jellyX = nil,
        jellyY = nil,
        init = init,
        resize = resize,
        advance = advance,
        draw = draw,
    }
end
