local Vec3 = assert(SMODS.load_file("lib/3d/math3d.lua"))().Vec3

local Mesh = {}

function Mesh.new(vertices, triangles, colors)
    return {
        vertices = vertices,
        triangles = triangles,
        colors = colors or {}
    }
end

function Mesh.cube(size)
    local s = (size or 1) * 0.5
    local v = {
        Vec3.new(-s, -s, -s),
        Vec3.new( s, -s, -s),
        Vec3.new( s,  s, -s),
        Vec3.new(-s,  s, -s),
        Vec3.new(-s, -s,  s),
        Vec3.new( s, -s,  s),
        Vec3.new( s,  s,  s),
        Vec3.new(-s,  s,  s),
    }
    local t = {
        {1, 2, 3}, {1, 3, 4},
        {5, 8, 7}, {5, 7, 6},
        {1, 5, 6}, {1, 6, 2},
        {2, 6, 7}, {2, 7, 3},
        {3, 7, 8}, {3, 8, 4},
        {4, 8, 5}, {4, 5, 1},
    }
    return Mesh.new(v, t, {r=0.9, g=0.9, b=1})
end

function Mesh.quad(size, color)
    local s = size or 1
    local v = {
        Vec3.new(-s, 0, -s),
        Vec3.new( s, 0, -s),
        Vec3.new( s, 0,  s),
        Vec3.new(-s, 0,  s),
    }
    local t = {{1, 2, 3}, {1, 3, 4}}
    return Mesh.new(v, t, color or {r=0.2, g=0.6, b=0.2})
end

function Mesh.treeTrunk()
    local v, t = {}, {}
    local vi = 1

    local function addVert(x, y, z)
        v[vi] = Vec3.new(x, y, z)
        vi = vi + 1
        return vi - 1
    end

    local function addTri(a, b, c)
        table.insert(t, {a, b, c})
    end

    local trunkH = 3
    local segments = 6

    for i = 0, segments - 1 do
        local angle = (i / segments) * math.pi * 2
        local nextAngle = ((i + 1) / segments) * math.pi * 2

        local rBottom = 0.4
        local rTop = 0.25

        local x1 = math.cos(angle) * rBottom
        local z1 = math.sin(angle) * rBottom
        local x2 = math.cos(nextAngle) * rBottom
        local z2 = math.sin(nextAngle) * rBottom

        local x3 = math.cos(angle) * rTop
        local z3 = math.sin(angle) * rTop
        local x4 = math.cos(nextAngle) * rTop
        local z4 = math.sin(nextAngle) * rTop

        local b1 = addVert(x1, 0, z1)
        local b2 = addVert(x2, 0, z2)
        local t1 = addVert(x3, trunkH, z3)
        local t2 = addVert(x4, trunkH, z4)

        addTri(b1, t1, b2)
        addTri(b2, t1, t2)
    end

    return Mesh.new(v, t, {r=0.4, g=0.25, b=0.1})
end

function Mesh.treeFoliage(y, radius, height, segments)
    local v, t = {}, {}
    local vi = 1

    local function addVert(x, y, z)
        v[vi] = Vec3.new(x, y, z)
        vi = vi + 1
        return vi - 1
    end

    local function addTri(a, b, c)
        table.insert(t, {a, b, c})
    end

    local segs = segments or 16
    local baseY = y
    local tipY = y + height
    local r = radius

    local tip = addVert(0, tipY, 0)
    local baseVerts = {}

    for i = 0, segs - 1 do
        local angle = (i / segs) * math.pi * 2
        local x = math.cos(angle) * r
        local z = math.sin(angle) * r
        baseVerts[i+1] = addVert(x, baseY, z)
    end

    for i = 1, segs do
        local next = i % segs + 1
        addTri(tip, baseVerts[next], baseVerts[i])
    end

    return Mesh.new(v, t, {r=0.1, g=0.45, b=0.12})
end

function Mesh.terrain(size, segments, heightFn, color)
    local s = size or 10
    local segs = segments or 32
    local hfn = heightFn or function(x, z) return 0 end
    local v, t = {}, {}
    local vi = 1

    for z = 0, segs do
        for x = 0, segs do
            local fx = (x / segs - 0.5) * s * 2
            local fz = (z / segs - 0.5) * s * 2
            v[vi] = Vec3.new(fx, hfn(fx, fz), fz)
            vi = vi + 1
        end
    end

    for z = 0, segs - 1 do
        for x = 0, segs - 1 do
            local i = z * (segs + 1) + x + 1
            local br = i + segs + 1
            table.insert(t, {i, i + 1, br + 1})
            table.insert(t, {i, br + 1, br})
        end
    end

    return Mesh.new(v, t, color or {r=0.2, g=0.5, b=0.2})
end

function Mesh.box(width, height, depth, color)
    local hx = (width or 1) * 0.5
    local hy = (height or 1) * 0.5
    local hz = (depth or 1) * 0.5

    local v = {
        Vec3.new(-hx, -hy, -hz), -- 1
        Vec3.new( hx, -hy, -hz), -- 2
        Vec3.new( hx,  hy, -hz), -- 3
        Vec3.new(-hx,  hy, -hz), -- 4
        Vec3.new(-hx, -hy,  hz), -- 5
        Vec3.new( hx, -hy,  hz), -- 6
        Vec3.new( hx,  hy,  hz), -- 7
        Vec3.new(-hx,  hy,  hz), -- 8
    }

    local t = {
        {1, 2, 3}, {1, 3, 4}, -- back
        {5, 8, 7}, {5, 7, 6}, -- front
        {1, 5, 6}, {1, 6, 2}, -- bottom
        {2, 6, 7}, {2, 7, 3}, -- right
        {3, 7, 8}, {3, 8, 4}, -- top
        {4, 8, 5}, {4, 5, 1}, -- left
    }

    return Mesh.new(v, t, color or { r = 0.5, g = 0.5, b = 0.5 })
end

return Mesh