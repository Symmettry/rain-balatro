local Vec3 = assert(SMODS.load_file("lib/3d/math3d.lua"))().Vec3
local Camera = {}
Camera.__index = Camera

function Camera.new(pos, yaw, pitch, fov, aspect, near, far)
    return setmetatable({
        pos = pos or Vec3.new(0, 0, 0),
        yaw = yaw or 0,
        pitch = pitch or 0,
        fov = fov or math.rad(75),
        aspect = aspect or 16 / 9,
        near = near or 0.1,
        far = far or 100.0,
        speed = 4.0,
        sensitivity = 0.0025
    }, Camera)
end

function Camera:look(dx, dy)
    self.yaw = self.yaw + dx * self.sensitivity
    self.pitch = self.pitch + dy * self.sensitivity
    local lim = math.rad(89)
    if self.pitch > lim then self.pitch = lim end
    if self.pitch < -lim then self.pitch = -lim end
end

function Camera:forward()
    local cp = math.cos(self.pitch)
    return Vec3.new(
        math.sin(self.yaw) * cp,
        math.sin(self.pitch),
        math.cos(self.yaw) * cp
    ):normalized()
end

function Camera:right()
    return self:forward():cross(Vec3.new(0, 1, 0)):normalized():scale(-1)
end

function Camera:forwardFlat()
    return Vec3.new(
        math.sin(self.yaw),
        0,
        math.cos(self.yaw)
    ):normalized()
end

function Camera:rightFlat()
    local f = self:forwardFlat()
    return f:cross(Vec3.new(0, 1, 0)):normalized():scale(-1)
end

function Camera:project(worldPos, screenW, screenH)
    local rel = worldPos:sub(self.pos)
    local cy, sy = math.cos(-self.yaw), math.sin(-self.yaw)
    local x1 = rel.x * cy + rel.z * sy
    local z1 = -rel.x * sy + rel.z * cy
    local cp, sp = math.cos(-self.pitch), math.sin(-self.pitch)
    local y2 = rel.y * cp - z1 * sp
    local z2 = rel.y * sp + z1 * cp
    if z2 <= self.near then return nil end
    local f = 1 / math.tan(self.fov * 0.5)
    local ndcX = (x1 * f / self.aspect) / z2
    local ndcY = (y2 * f) / z2
    return (ndcX * 0.5 + 0.5) * screenW, (-ndcY * 0.5 + 0.5) * screenH
end

return Camera