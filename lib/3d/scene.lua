local Compat = SMODS and SMODS.load_file("lib/compat.lua", "rain")() or require("lib.compat")

local PostFX = Compat.load_module("lib/3d/postfx.lua")
local Math3D = Compat.load_module("lib/3d/math3d.lua")
local Vec3 = Math3D.Vec3
local Camera = Compat.load_module("lib/3d/camera.lua")
local Mesh = Compat.load_module("lib/3d/mesh.lua")
local Renderer = Compat.load_module("lib/3d/renderer.lua")
local AudioSystem = Compat.load_module("lib/audio/playback.lua")

local Scene3D = {}
Scene3D.__index = Scene3D

function Scene3D.new()
    local self = setmetatable({}, Scene3D)

    self.viewport = { x = 0, y = 0, w = 1280, h = 720 }
    self.showStats = false

    self.sceneCanvas = nil
    self.postFX = PostFX.new()

    self.camera = Camera.new(
        Vec3.new(0, 0.5, 0),
        0,
        0,
        math.rad(75),
        16 / 9,
        0.005,
        100
    )

    self.pokerTable = {
        pos = Vec3.new(0, -0.18, 3.2),
        rot = Vec3.new(0, 0, 0),

        shadow = Mesh.quad(1.35, { r = 0.02, g = 0.02, b = 0.02 }),
        wood   = Mesh.quad(1.18, { r = 0.24, g = 0.18, b = 0.12 }),
        rail   = Mesh.quad(1.02, { r = 0.10, g = 0.09, b = 0.09 }),
        felt   = Mesh.quad(0.82, { r = 0.08, g = 0.58, b = 0.44 }),

        leftWall  = Mesh.box(0.08, 0.5, 1.18*2, { r = 0.18, g = 0.13, b = 0.09 }),
        rightWall = Mesh.box(0.08, 0.5, 1.18*2, { r = 0.18, g = 0.13, b = 0.09 }),
        frontWall = Mesh.box(1.18*2, 0.5, 0.08, { r = 0.18, g = 0.13, b = 0.09 }),
        backWall  = Mesh.box(1.18*2, 0.5, 0.08, { r = 0.18, g = 0.13, b = 0.09 }),

        halfOuter = 1.18,
        wallH = 0.26,

        collideHalfX = 1.26,
        collideHalfZ = 1.26,
        collidePadding = 0.18,
    }

    self.tree = {
        trunk = Mesh.treeTrunk(),
        foliage = {
            Mesh.treeFoliage(1.5, 2.5, 2),
            Mesh.treeFoliage(3, 2.0, 2),
            Mesh.treeFoliage(4.5, 1.4, 1.8),
            Mesh.treeFoliage(6, 0.8, 1.5),
        }
    }
    self.treeBillboard = Mesh.billboard(1.5, { r=0.1, g=0.45, b=0.12 })

    self.treeInstances = {}

    math.randomseed(os.time())

    local cols = 20
    local rows = 20
    local spacingX = 4
    local spacingZ = 4
    local jitterX = 1.0
    local jitterZ = 1.0
    local startX = -((cols - 1) * spacingX) * 0.5
    local startZ = -((rows - 1) * spacingZ) * 0.5

    for row = 0, rows - 1 do
        for col = 0, cols - 1 do
            if row ~= rows/2 or col ~= cols/2 then
                local baseX = startX + col * spacingX
                local baseZ = startZ + row * spacingZ
                local x = baseX + (math.random() * 2 - 1) * jitterX
                local z = baseZ + (math.random() * 2 - 1) * jitterZ
                local yaw = math.random() * math.pi * 2

                self.treeInstances[#self.treeInstances + 1] = {
                    pos = Vec3.new(x, -0.5, z),
                    rot = Vec3.new(0, yaw, 0)
                }
            end
        end
    end

    self.worldBounds = {
        minX = -11.5,
        maxX = 11.5,
        minZ = -8.5,
        maxZ = 14.5,
        minY = -4.0,
        maxY = 8.0
    }

    self:updateViewport()

    AudioSystem.play("background", {
        loop = true,
        mode = "stream",
        volume = 0.6
    })

    return self
end

function Scene3D:ensureCanvas()
    local w, h = self.viewport.w, self.viewport.h
    if (not self.sceneCanvas)
        or self.sceneCanvas:getWidth() ~= w
        or self.sceneCanvas:getHeight() ~= h then
        self.sceneCanvas = love.graphics.newCanvas(w, h)
        self.sceneCanvas:setFilter("linear", "linear")
    end
end

function Scene3D:updateViewport()
    local winW, winH = love.graphics.getDimensions()
    self.viewport.x = 0
    self.viewport.y = 0
    self.viewport.w = winW
    self.viewport.h = winH
    self.camera.aspect = winW / winH
    self:ensureCanvas()
end

function Scene3D:onActivate()
    Compat.log("3D Scene activated")
end

function Scene3D:onDeactivate()
    Compat.log("3D Scene deactivated")
end

function Scene3D:keypressed(key)
    if key == "f" then
        Renderer.showWireframe = not Renderer.showWireframe
    elseif key == "p" then
        self.showStats = not self.showStats
    elseif key == "1" then
        RAIN.active_profile = RAIN.PROFILES.gentle
    elseif key == "2" then
        RAIN.active_profile = RAIN.PROFILES.moderate
    elseif key == "3" then
        RAIN.active_profile = RAIN.PROFILES.heavy
    elseif key == "4" then
        RAIN.active_profile = RAIN.PROFILES.storm
    elseif key == "m" then
        local newVol = love.audio.getVolume() > 0 and 0 or 1
        love.audio.setVolume(newVol)
    elseif key == "escape" and Compat.is_standalone() then
        love.event.quit()
    end
end

function Scene3D:mousemoved(_, _, dx, dy)
    self.camera:look(dx, dy)
end

function Scene3D:update(dt)
    dt = math.min(dt, 0.1)

    local move = Vec3.new(0, 0, 0)

    if love.keyboard.isDown("w") then move = move:add(self.camera:forwardFlat()) end
    if love.keyboard.isDown("s") then move = move:sub(self.camera:forwardFlat()) end
    if love.keyboard.isDown("a") then move = move:sub(self.camera:rightFlat()) end
    if love.keyboard.isDown("d") then move = move:add(self.camera:rightFlat()) end

    local b = self.worldBounds
    if self.camera.pos.x < b.minX then self.camera.pos.x = b.minX end
    if self.camera.pos.x > b.maxX then self.camera.pos.x = b.maxX end
    if self.camera.pos.z < b.minZ then self.camera.pos.z = b.minZ end
    if self.camera.pos.z > b.maxZ then self.camera.pos.z = b.maxZ end
    if self.camera.pos.y < b.minY then self.camera.pos.y = b.minY end
    if self.camera.pos.y > b.maxY then self.camera.pos.y = b.maxY end

    if move.x ~= 0 or move.y ~= 0 or move.z ~= 0 then
        local len = math.sqrt(move.x * move.x + move.y * move.y + move.z * move.z)
        move = Vec3.new(move.x / len, move.y / len, move.z / len)
        local nextPos = self.camera.pos:add(move:scale(self.camera.speed * dt))

        local t = self.pokerTable
        local pad = t.collidePadding or 0.0
        local minX = t.pos.x - t.collideHalfX - pad
        local maxX = t.pos.x + t.collideHalfX + pad
        local minZ = t.pos.z - t.collideHalfZ - pad
        local maxZ = t.pos.z + t.collideHalfZ + pad

        local insideX = nextPos.x > minX and nextPos.x < maxX
        local insideZ = nextPos.z > minZ and nextPos.z < maxZ

        if insideX and insideZ then
            local oldPos = self.camera.pos
            local tryX = Vec3.new(nextPos.x, oldPos.y, oldPos.z)
            local tryZ = Vec3.new(oldPos.x, oldPos.y, nextPos.z)
            local tryXInside = tryX.x > minX and tryX.x < maxX and tryX.z > minZ and tryX.z < maxZ
            local tryZInside = tryZ.x > minX and tryZ.x < maxX and tryZ.z > minZ and tryZ.z < maxZ

            if not tryXInside then
                self.camera.pos = tryX
            elseif not tryZInside then
                self.camera.pos = tryZ
            end
        else
            self.camera.pos = nextPos
        end
    end
end

function Scene3D:draw()
    local vp = self.viewport
    self:ensureCanvas()

    love.graphics.push("all")
    love.graphics.setCanvas(self.sceneCanvas)
    love.graphics.clear(0, 0, 0, 0)

    Renderer.drawInfiniteFloor(
        self.camera,
        0, 0, vp.w, vp.h,
        { r = 0.02, g = 0.02, b = 0.03 },
        { r = 0.15, g = 0.40, b = 0.15 },
        { r = 0.28, g = 0.34, b = 0.28 }
    )

    Renderer.lightDir = Vec3.new(0.3, -0.8, 0.5):normalized()

    local rw, rh = Renderer.beginFrame(vp.w, vp.h, { r = 0, g = 0, b = 0, a = 0 })
    local tris = {}

    local tp = self.pokerTable.pos
    local tr = self.pokerTable.rot

    Renderer.collectMeshTriangles(tris, self.pokerTable.shadow, { pos = Vec3.new(tp.x, tp.y - 0.05, tp.z), rot = tr }, self.camera, rw, rh)
    Renderer.collectMeshTriangles(tris, self.pokerTable.wood,   { pos = Vec3.new(tp.x, tp.y, tp.z), rot = tr }, self.camera, rw, rh)
    Renderer.collectMeshTriangles(tris, self.pokerTable.rail,   { pos = Vec3.new(tp.x, tp.y + 0.01, tp.z), rot = tr }, self.camera, rw, rh)
    Renderer.collectMeshTriangles(tris, self.pokerTable.felt,   { pos = Vec3.new(tp.x, tp.y + 0.02, tp.z), rot = tr }, self.camera, rw, rh)

    local halfOuter = self.pokerTable.halfOuter
    local wallH = self.pokerTable.wallH

    Renderer.collectMeshTriangles(tris, self.pokerTable.leftWall,  { pos = Vec3.new(tp.x - halfOuter, tp.y - wallH * 0.5, tp.z), rot = tr }, self.camera, rw, rh)
    Renderer.collectMeshTriangles(tris, self.pokerTable.rightWall, { pos = Vec3.new(tp.x + halfOuter, tp.y - wallH * 0.5, tp.z), rot = tr }, self.camera, rw, rh)
    Renderer.collectMeshTriangles(tris, self.pokerTable.frontWall, { pos = Vec3.new(tp.x, tp.y - wallH * 0.5, tp.z + halfOuter), rot = tr }, self.camera, rw, rh)
    Renderer.collectMeshTriangles(tris, self.pokerTable.backWall,  { pos = Vec3.new(tp.x, tp.y - wallH * 0.5, tp.z - halfOuter), rot = tr }, self.camera, rw, rh)

    for i = 1, #self.treeInstances do
        local inst = self.treeInstances[i]
        local dx = inst.pos.x - self.camera.pos.x
        local dz = inst.pos.z - self.camera.pos.z
        local distSq = dx*dx + dz*dz

        if distSq < 300 then
            Renderer.collectMeshTriangles(tris, self.tree.trunk, { pos = inst.pos, rot = inst.rot }, self.camera, rw, rh)
            Renderer.collectMeshListTriangles(tris, self.tree.foliage, { pos = inst.pos, rot = inst.rot }, self.camera, rw, rh)
        else
            local angle = math.atan2(self.camera.pos.x - inst.pos.x, self.camera.pos.z - inst.pos.z)
            Renderer.collectMeshTriangles(tris, self.treeBillboard, { pos = inst.pos, rot = Vec3.new(0, angle, 0) }, self.camera, rw, rh)
        end
    end

    Renderer.drawTriangleList(tris, rw, rh)
    Renderer.endFrame(0, 0, vp.w, vp.h)

    love.graphics.setCanvas()
    self.postFX:send(love.timer.getTime())

    love.graphics.setScissor(vp.x, vp.y, vp.w, vp.h)
    love.graphics.setShader(self.postFX.shader)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.sceneCanvas, vp.x, vp.y)
    love.graphics.setShader()
    love.graphics.setScissor()

    RAIN.draw_overlay()

    love.graphics.origin()
    love.graphics.pop()

    -- Draw debug stats if enabled
    if self.showStats then
        Renderer.drawStats(10, self.viewport.h - 20)
    end
end

return Scene3D
