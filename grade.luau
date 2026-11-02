-- Top-most full-screen pass: grade.wgsl. Grain and vignette amounts come from
-- the Scene view model.

type Grade = {
    size: Vector,
    scale: number,
    time: number,
    canvas: GPUCanvas?,
    pipeline: GPUPipeline?,
    ubo: GPUBuffer?,
    bindGroup: GPUBindGroup?,
    sampler: ImageSampler,
    staging: buffer,
    grain: Property<number>?,
    vignette: Property<number>?,
}

function init(self: Grade, context: Context): boolean
    local vm = context:viewModel()
    if vm ~= nil then
        self.grain = vm:getNumber('grain')
        self.vignette = vm:getNumber('vignette')
    end
    if self.pipeline ~= nil then
        return true
    end
    local shader = context:shader('grade')
    if shader == nil then
        print('grade: shader missing')
        return true
    end
    local canvas = context:gpuCanvas()
    if canvas == nil then
        print('grade: no gpu canvas')
        return true
    end
    self.canvas = canvas
    local pipeline = GPUPipeline.new({
        vertex = shader,
        fragment = shader,
        vertexLayout = {},
        colorTargets = { { format = canvas.format } },
    })
    local ubo = GPUBuffer.new({ size = 32, usage = 'uniform', label = 'grade-u' })
    self.pipeline = pipeline
    self.ubo = ubo
    self.bindGroup = GPUBindGroup.new({
        layout = pipeline:getBindGroupLayout(0),
        ubos = { { slot = 0, buffer = ubo } },
    })
    return true
end

function resize(self: Grade, size: Vector, scale: number)
    self.size = size
    self.scale = scale
    local canvas = self.canvas
    if canvas ~= nil and size.x > 0 and size.y > 0 then
        canvas:resize(math.floor(size.x * scale), math.floor(size.y * scale))
    end
end

function advance(self: Grade, seconds: number): boolean
    self.time += seconds
    return true
end

local function num(prop: Property<number>?, fallback: number): number
    if prop ~= nil then
        return prop.value
    end
    return fallback
end

function draw(self: Grade, renderer: Renderer)
    local canvas = self.canvas
    local pipeline = self.pipeline
    local ubo = self.ubo
    local bg = self.bindGroup
    if canvas == nil or pipeline == nil or ubo == nil or bg == nil or canvas.width == 0 then
        return
    end
    local b = self.staging
    buffer.writef32(b, 0, self.time)
    buffer.writef32(b, 4, canvas.width)
    buffer.writef32(b, 8, canvas.height)
    buffer.writef32(b, 12, num(self.grain, 0.07))
    buffer.writef32(b, 16, num(self.vignette, 0.6))
    buffer.writef32(b, 20, 0)
    buffer.writef32(b, 24, 0)
    buffer.writef32(b, 28, 0)
    ubo:write(b)

    local pass = canvas:beginRenderPass({
        color = { { loadOp = 'clear', storeOp = 'store', clearColor = { 0, 0, 0, 0 } } },
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

return function(context: Context): Layout<Grade>
    return {
        size = Vector.xy(0, 0),
        scale = 1,
        time = 0,
        canvas = nil,
        pipeline = nil,
        ubo = nil,
        bindGroup = nil,
        sampler = ImageSampler('clamp', 'clamp', 'bilinear'),
        staging = buffer.create(32),
        grain = nil,
        vignette = nil,
        init = init,
        resize = resize,
        advance = advance,
        draw = draw,
    }
end
