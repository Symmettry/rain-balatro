local Scene3D = assert(SMODS.load_file("lib/3d/scene.lua"))()

RAIN = rawget(_G, "RAIN") or {}
_G.RAIN = RAIN

RAIN.mod = SMODS.current_mod
RAIN.rain_active = true

local scene3d = nil
local overlay_was_active = false

local orig_load = love.load
local orig_update = love.update
local orig_draw = love.draw
local orig_resize = love.resize
local orig_mousemoved = love.mousemoved
local orig_keypressed = love.keypressed
local orig_mousepressed = love.mousepressed
local orig_mousereleased = love.mousereleased
local orig_wheelmoved = love.wheelmoved
local orig_textinput = love.textinput

local function ensure_scene()
    if not scene3d then
        scene3d = Scene3D.new()
    end
    return scene3d
end

local function overlay_active()
    return RAIN and RAIN.rain_active == true
end

local function sync_overlay_state()
    local active = overlay_active()

    if active and not overlay_was_active then
        ensure_scene():onActivate()
        overlay_was_active = true
    elseif (not active) and overlay_was_active then
        if scene3d then scene3d:onDeactivate() end
        overlay_was_active = false
    end
end

love.load = function(...)
    if orig_load then
        orig_load(...)
    end
    ensure_scene()
    sync_overlay_state()
end

love.update = function(dt)
    sync_overlay_state()

    if overlay_active() then
        ensure_scene():update(dt)
        return
    end

    if orig_update then
        return orig_update(dt)
    end
end

love.draw = function(...)
    if overlay_active() then
        ensure_scene():draw()
        return
    end

    if orig_draw then
        return orig_draw(...)
    end
end

love.resize = function(w, h)
    if scene3d then
        scene3d:updateViewport()
    end

    if overlay_active() then
        return
    end

    if orig_resize then
        return orig_resize(w, h)
    end
end

love.mousemoved = function(x, y, dx, dy, istouch)
    if overlay_active() then
        ensure_scene():mousemoved(x, y, dx, dy, istouch)
        return
    end

    if orig_mousemoved then
        return orig_mousemoved(x, y, dx, dy, istouch)
    end
end

love.keypressed = function(key, scancode, isrepeat)
    if overlay_active() then
        ensure_scene():keypressed(key, scancode, isrepeat)

        if key == "escape" then
            RAIN.rain_active = false
            sync_overlay_state()
        end

        return
    end

    if orig_keypressed then
        return orig_keypressed(key, scancode, isrepeat)
    end
end

love.mousepressed = function(...)
    if overlay_active() then return end
    if orig_mousepressed then return orig_mousepressed(...) end
end

love.mousereleased = function(...)
    if overlay_active() then return end
    if orig_mousereleased then return orig_mousereleased(...) end
end

love.wheelmoved = function(...)
    if overlay_active() then return end
    if orig_wheelmoved then return orig_wheelmoved(...) end
end

love.textinput = function(...)
    if overlay_active() then return end
    if orig_textinput then return orig_textinput(...) end
end