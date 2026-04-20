local Math3D = assert(SMODS.load_file("lib/3d/math3d.lua"))()
local Vec3 = Math3D.Vec3

local Renderer = {
    showWireframe = false,
    lightDir = { x = 0.316, y = -0.737, z = 0.632 },

    renderScale = 0.3,
    minRenderW = 256,
    minRenderH = 144,
}

local viewBufX, viewBufY, viewBufZ = {}, {}, {}
local screenX, screenY = {}, {}

local canvasImageData = nil
local canvasImage = nil
local zbuffer = {}
local depthWriteColor = {0, 0, 0, 255}

local function clamp(x, a, b)
    if x < a then return a end
    if x > b then return b end
    return x
end

local function ensureBuffers(w, h)
    if (not canvasImageData) or canvasImageData:getWidth() ~= w or canvasImageData:getHeight() ~= h then
        canvasImageData = love.image.newImageData(w, h)
        canvasImage = love.graphics.newImage(canvasImageData)
        canvasImage:setFilter("nearest", "nearest")
        zbuffer = {}
        for y = 1, h do
            local row = {}
            for x = 1, w do
                row[x] = math.huge
            end
            zbuffer[y] = row
        end
    end
end

local function clearBuffers(w, h, r, g, b, a)
    local R = math.floor(clamp(r or 0, 0, 1) * 255 + 0.5)
    local G = math.floor(clamp(g or 0, 0, 1) * 255 + 0.5)
    local B = math.floor(clamp(b or 0, 0, 1) * 255 + 0.5)
    local A = math.floor(clamp(a or 1, 0, 1) * 255 + 0.5)

    for y = 1, h do
        local row = zbuffer[y]
        for x = 1, w do
            row[x] = math.huge
            canvasImageData:setPixel(x - 1, y - 1, R / 255, G / 255, B / 255, A / 255)
        end
    end
end

local function worldToView(v, model, camera, outX, outY, outZ, i)
    local w = Math3D.rotateEuler(v, model.rot)
    w.x = w.x + model.pos.x
    w.y = w.y + model.pos.y
    w.z = w.z + model.pos.z

    local relX = w.x - camera.pos.x
    local relY = w.y - camera.pos.y
    local relZ = w.z - camera.pos.z

    local cy, sy = math.cos(-camera.yaw), math.sin(-camera.yaw)
    local x1 = relX * cy + relZ * sy
    local z1 = -relX * sy + relZ * cy

    local cp, sp = math.cos(-camera.pitch), math.sin(-camera.pitch)
    outX[i] = x1
    outY[i] = relY * cp - z1 * sp
    outZ[i] = relY * sp + z1 * cp
end

local function project(x, y, z, camera, w, h)
    if z <= camera.near then
        return nil, nil
    end

    local f = camera._cachedF or (1 / math.tan(camera.fov * 0.5))
    camera._cachedF = f

    local ndcX = (x * f / camera.aspect) / z
    local ndcY = (y * f) / z

    return (ndcX * 0.5 + 0.5) * w, (-ndcY * 0.5 + 0.5) * h
end

local function triNormal(ax, ay, az, bx, by, bz, cx, cy, cz)
    local abx, aby, abz = bx - ax, by - ay, bz - az
    local acx, acy, acz = cx - ax, cy - ay, cz - az

    local nx = aby * acz - abz * acy
    local ny = abz * acx - abx * acz
    local nz = abx * acy - aby * acx

    local len = math.sqrt(nx * nx + ny * ny + nz * nz)
    if len > 0 then
        return nx / len, ny / len, nz / len
    end
    return 0, 0, 0
end

local function edge(ax, ay, bx, by, px, py)
    return (px - ax) * (by - ay) - (py - ay) * (bx - ax)
end

local function rasterTriangle(tri, rw, rh)
    local x1, y1 = tri.v[1], tri.v[2]
    local x2, y2 = tri.v[3], tri.v[4]
    local x3, y3 = tri.v[5], tri.v[6]

    local z1, z2, z3 = tri.d[1], tri.d[2], tri.d[3]

    local minX = math.floor(math.min(x1, x2, x3))
    local maxX = math.ceil(math.max(x1, x2, x3))
    local minY = math.floor(math.min(y1, y2, y3))
    local maxY = math.ceil(math.max(y1, y2, y3))

    if maxX < 0 or maxY < 0 or minX >= rw or minY >= rh then
        return
    end

    minX = clamp(minX, 0, rw - 1)
    maxX = clamp(maxX, 0, rw - 1)
    minY = clamp(minY, 0, rh - 1)
    maxY = clamp(maxY, 0, rh - 1)

    local area = edge(x1, y1, x2, y2, x3, y3)
    if math.abs(area) < 1e-8 then
        return
    end

    local invArea = 1 / area

    local r = clamp(tri.c.r * tri.b, 0, 1)
    local g = clamp(tri.c.g * tri.b, 0, 1)
    local b = clamp(tri.c.b * tri.b, 0, 1)

    for py = minY, maxY do
        local row = zbuffer[py + 1]
        for px = minX, maxX do
            local sx = px + 0.5
            local sy = py + 0.5

            local w0 = edge(x2, y2, x3, y3, sx, sy) * invArea
            local w1 = edge(x3, y3, x1, y1, sx, sy) * invArea
            local w2 = edge(x1, y1, x2, y2, sx, sy) * invArea

            local inside =
                (w0 >= 0 and w1 >= 0 and w2 >= 0) or
                (w0 <= 0 and w1 <= 0 and w2 <= 0)

            if inside then
                local depth = w0 * z1 + w1 * z2 + w2 * z3
                if depth < row[px + 1] then
                    row[px + 1] = depth
                    canvasImageData:setPixel(px, py, r, g, b, 1)
                end
            end
        end
    end

    if Renderer.showWireframe then
        love.graphics.setColor(1, 1, 1, 0.25)
        love.graphics.line(x1 / rw, y1 / rh, x2 / rw, y2 / rh)
        love.graphics.line(x2 / rw, y2 / rh, x3 / rw, y3 / rh)
        love.graphics.line(x3 / rw, y3 / rh, x1 / rw, y1 / rh)
    end
end

local function clipPolygonAgainstNear(poly, nearZ)
    local out = {}

    local function inside(v)
        return v.z >= nearZ
    end

    local function intersect(a, b)
        local dz = b.z - a.z
        if math.abs(dz) < 1e-8 then
            return { x = a.x, y = a.y, z = nearZ }
        end
        local t = (nearZ - a.z) / dz
        return {
            x = a.x + (b.x - a.x) * t,
            y = a.y + (b.y - a.y) * t,
            z = nearZ
        }
    end

    for i = 1, #poly do
        local a = poly[i]
        local b = poly[(i % #poly) + 1]

        local aIn = inside(a)
        local bIn = inside(b)

        if aIn and bIn then
            out[#out + 1] = { x = b.x, y = b.y, z = b.z }
        elseif aIn and not bIn then
            out[#out + 1] = intersect(a, b)
        elseif (not aIn) and bIn then
            out[#out + 1] = intersect(a, b)
            out[#out + 1] = { x = b.x, y = b.y, z = b.z }
        end
    end

    return out
end

local function clipTriangleAgainstNear(ax, ay, az, bx, by, bz, cx, cy, cz, nearZ)
    local poly = {
        { x = ax, y = ay, z = az },
        { x = bx, y = by, z = bz },
        { x = cx, y = cy, z = cz },
    }
    return clipPolygonAgainstNear(poly, nearZ)
end

local function emitClippedTriangleFan(outTris, poly, color, camera, rw, rh)
    if #poly < 3 then
        return
    end

    for i = 2, #poly - 1 do
        local a = poly[1]
        local b = poly[i]
        local c = poly[i + 1]

        local sx1, sy1 = project(a.x, a.y, a.z, camera, rw, rh)
        local sx2, sy2 = project(b.x, b.y, b.z, camera, rw, rh)
        local sx3, sy3 = project(c.x, c.y, c.z, camera, rw, rh)

        if sx1 and sx2 and sx3 then
            local nx, ny, nz = triNormal(a.x, a.y, a.z, b.x, b.y, b.z, c.x, c.y, c.z)

            local brightness = math.abs(
                nx * Renderer.lightDir.x +
                ny * Renderer.lightDir.y +
                nz * Renderer.lightDir.z
            )
            if brightness < 0.1 then
                brightness = 0.1
            end

            outTris[#outTris + 1] = {
                v = { sx1, sy1, sx2, sy2, sx3, sy3 },
                d = { a.z, b.z, c.z },
                b = brightness,
                c = color
            }
        end
    end
end

function Renderer.collectClippedQuad(outTris, mesh, model, camera, rw, rh)
    local verts = {}

    for i = 1, 4 do
        local w = Math3D.rotateEuler(mesh.vertices[i], model.rot)
        w.x = w.x + model.pos.x
        w.y = w.y + model.pos.y
        w.z = w.z + model.pos.z

        local relX = w.x - camera.pos.x
        local relY = w.y - camera.pos.y
        local relZ = w.z - camera.pos.z

        local cy, sy = math.cos(-camera.yaw), math.sin(-camera.yaw)
        local x1 = relX * cy + relZ * sy
        local z1 = -relX * sy + relZ * cy

        local cp, sp = math.cos(-camera.pitch), math.sin(-camera.pitch)
        local y2 = relY * cp - z1 * sp
        local z2 = relY * sp + z1 * cp

        verts[i] = { x = x1, y = y2, z = z2 }
    end

    local clipped = clipPolygonAgainstNear(verts, camera.near)
    if #clipped < 3 then
        return
    end

    local color = mesh.colors or { r = 0.15, g = 0.4, b = 0.15 }

    for i = 2, #clipped - 1 do
        local a = clipped[1]
        local b = clipped[i]
        local c = clipped[i + 1]

        local sx1, sy1 = project(a.x, a.y, a.z, camera, rw, rh)
        local sx2, sy2 = project(b.x, b.y, b.z, camera, rw, rh)
        local sx3, sy3 = project(c.x, c.y, c.z, camera, rw, rh)

        if sx1 and sx2 and sx3 then
            local nx, ny, nz = triNormal(a.x, a.y, a.z, b.x, b.y, b.z, c.x, c.y, c.z)

            local brightness = math.abs(
                nx * Renderer.lightDir.x +
                ny * Renderer.lightDir.y +
                nz * Renderer.lightDir.z
            )
            if brightness < 0.1 then brightness = 0.1 end

            outTris[#outTris + 1] = {
                v = { sx1, sy1, sx2, sy2, sx3, sy3 },
                d = { a.z, b.z, c.z },
                b = brightness,
                c = color
            }
        end
    end
end

function Renderer.drawInfiniteFloor(camera, x, y, w, h, skyColor, floorColor, horizonColor)
    local pitch = -(camera.pitch or 0)

    local horizonY = h * (0.5 + math.tan(pitch) * 0.6)

    if horizonY < 0 then horizonY = 0 end
    if horizonY > h then horizonY = h end

    local sky = skyColor or { r = 0.02, g = 0.02, b = 0.03 }
    local floor = floorColor or { r = 0.15, g = 0.40, b = 0.15 }
    local horizon = horizonColor or { r = 0.35, g = 0.45, b = 0.35 }

    love.graphics.setColor(sky.r, sky.g, sky.b, 1)
    love.graphics.rectangle("fill", x, y, w, horizonY)

    local bandH = math.max(2, math.floor(h * 0.02))
    love.graphics.setColor(horizon.r, horizon.g, horizon.b, 1)
    love.graphics.rectangle("fill", x, y + horizonY - bandH * 0.5, w, bandH)

    love.graphics.setColor(floor.r, floor.g, floor.b, 1)
    love.graphics.rectangle("fill", x, y + horizonY, w, h - horizonY)

    love.graphics.setColor(1, 1, 1, 1)
end

local function appendMeshTriangles(outTris, mesh, model, camera, rw, rh, vertexOffset, opts)
    opts = opts or {}
    vertexOffset = vertexOffset or 0

    local n = #mesh.vertices
    for i = 1, n do
        local idx = vertexOffset + i
        worldToView(mesh.vertices[i], model, camera, viewBufX, viewBufY, viewBufZ, idx)
    end

    local defaultColor = mesh.colors or { r = 0.9, g = 0.9, b = 1 }

    for i = 1, #mesh.triangles do
        local tri = mesh.triangles[i]
        local ia = vertexOffset + tri[1]
        local ib = vertexOffset + tri[2]
        local ic = vertexOffset + tri[3]

        local ax, ay, az = viewBufX[ia], viewBufY[ia], viewBufZ[ia]
        local bx, by, bz = viewBufX[ib], viewBufY[ib], viewBufZ[ib]
        local cx, cy, cz = viewBufX[ic], viewBufY[ic], viewBufZ[ic]

        local allBehind = (az <= camera.near and bz <= camera.near and cz <= camera.near)
        local allInFront = (az > camera.near and bz > camera.near and cz > camera.near)

        if allInFront then
            local sx1, sy1 = project(ax, ay, az, camera, rw, rh)
            local sx2, sy2 = project(bx, by, bz, camera, rw, rh)
            local sx3, sy3 = project(cx, cy, cz, camera, rw, rh)

            if sx1 and sx2 and sx3 then
                local nx, ny, nz = triNormal(ax, ay, az, bx, by, bz, cx, cy, cz)

                local brightness = math.abs(
                    nx * Renderer.lightDir.x +
                    ny * Renderer.lightDir.y +
                    nz * Renderer.lightDir.z
                )
                if brightness < 0.1 then
                    brightness = 0.1
                end

                outTris[#outTris + 1] = {
                    v = { sx1, sy1, sx2, sy2, sx3, sy3 },
                    d = { az, bz, cz },
                    b = brightness,
                    c = defaultColor
                }
            end

        elseif not allBehind and (opts.alwaysRender or opts.allowPartialNear) then
            local clipped = clipTriangleAgainstNear(ax, ay, az, bx, by, bz, cx, cy, cz, camera.near)
            emitClippedTriangleFan(outTris, clipped, defaultColor, camera, rw, rh)
        end
    end

    return vertexOffset + n
end

function Renderer.collectMeshTriangles(outTris, mesh, model, camera, w, h, opts)
    appendMeshTriangles(outTris, mesh, model, camera, w, h, 0, opts)
end

function Renderer.collectMeshListTriangles(outTris, meshes, model, camera, w, h, opts)
    local vertexOffset = 0
    for _, mesh in ipairs(meshes) do
        vertexOffset = appendMeshTriangles(outTris, mesh, model, camera, w, h, vertexOffset, opts)
    end
end

function Renderer.beginFrame(viewW, viewH, clearColor)
    local rw = math.max(Renderer.minRenderW, math.floor(viewW * Renderer.renderScale + 0.5))
    local rh = math.max(Renderer.minRenderH, math.floor(viewH * Renderer.renderScale + 0.5))

    ensureBuffers(rw, rh)
    clearBuffers(
        rw,
        rh,
        clearColor and clearColor.r or 0,
        clearColor and clearColor.g or 0,
        clearColor and clearColor.b or 0,
        clearColor and clearColor.a or 0
    )

    return rw, rh
end

function Renderer.drawTriangleList(tris, rw, rh)
    for i = 1, #tris do
        rasterTriangle(tris[i], rw, rh)
    end
end

function Renderer.endFrame(dstX, dstY, dstW, dstH)
    canvasImage:replacePixels(canvasImageData)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(
        canvasImage,
        dstX,
        dstY,
        0,
        dstW / canvasImage:getWidth(),
        dstH / canvasImage:getHeight()
    )
end

function Renderer.drawMesh(mesh, model, camera, w, h)
    local tris = {}
    local rw, rh = Renderer.beginFrame(w, h)
    Renderer.collectMeshTriangles(tris, mesh, model, camera, rw, rh)
    Renderer.drawTriangleList(tris, rw, rh)
    Renderer.endFrame(0, 0, w, h)
end

function Renderer.drawMeshList(meshes, model, camera, w, h)
    local tris = {}
    local rw, rh = Renderer.beginFrame(w, h)
    Renderer.collectMeshListTriangles(tris, meshes, model, camera, rw, rh)
    Renderer.drawTriangleList(tris, rw, rh)
    Renderer.endFrame(0, 0, w, h)
end

return Renderer