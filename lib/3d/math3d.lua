local M = {}
local Vec3 = {}
Vec3.__index = Vec3
function Vec3.new(x, y, z)
    return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, Vec3)
end
function Vec3:add(v)
    return Vec3.new(self.x + v.x, self.y + v.y, self.z + v.z)
end
function Vec3:sub(v)
    return Vec3.new(self.x - v.x, self.y - v.y, self.z - v.z)
end
function Vec3:scale(s)
    return Vec3.new(self.x * s, self.y * s, self.z * s)
end
function Vec3:dot(v)
    return self.x * v.x + self.y * v.y + self.z * v.z
end
function Vec3:cross(v)
    return Vec3.new(
        self.y * v.z - self.z * v.y,
        self.z * v.x - self.x * v.z,
        self.x * v.y - self.y * v.x
    )
end
function Vec3:length()
    return math.sqrt(self.x * self.x + self.y * self.y + self.z * self.z)
end
function Vec3:normalized()
    local len = self:length()
    if len < 1e-8 then return nil end
    return self:scale(1 / len)
end
local function rotateX(v, a)
    local c, s = math.cos(a), math.sin(a)
    return Vec3.new(v.x, v.y * c - v.z * s, v.y * s + v.z * c)
end
local function rotateY(v, a)
    local c, s = math.cos(a), math.sin(a)
    return Vec3.new(v.x * c + v.z * s, v.y, -v.x * s + v.z * c)
end
local function rotateZ(v, a)
    local c, s = math.cos(a), math.sin(a)
    return Vec3.new(v.x * c - v.y * s, v.x * s + v.y * c, v.z)
end
function M.rotateEuler(v, rot)
    local r = rotateX(v, rot.x)
    r = rotateY(r, rot.y)
    r = rotateZ(r, rot.z)
    return r
end
M.Vec3 = Vec3
return M
