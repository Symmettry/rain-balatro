local Scene3D = assert(SMODS.load_file("lib/3d/scene.lua"))()

RAIN = rawget(_G, "RAIN") or {}
_G.RAIN = RAIN

assert(SMODS.load_file("lib/rain/rain.lua"))()
assert(SMODS.load_file("lib/audio/sounds.lua"))()
assert(SMODS.load_file("lib/phase.lua"))()

RAIN.mod = SMODS.current_mod
RAIN.rain_active = false
RAIN.fake_crash = false
RAIN.fake_crash_started = nil
RAIN.fake_crash_message = [[Unable to witness the renderer]]

local scene3d = nil
local overlay_was_active = false

local orig_update = love.update
local orig_draw = love.draw
local orig_resize = love.resize
local orig_mousemoved = love.mousemoved
local orig_keypressed = love.keypressed
local orig_mousepressed = love.mousepressed
local orig_mousereleased = love.mousereleased
local orig_wheelmoved = love.wheelmoved
local orig_textinput = love.textinput

function RAIN.ensure_scene()
    if not scene3d and RAIN.rain_active then
        scene3d = Scene3D.new()
    end
    return scene3d
end

function RAIN.overlay_active()
    return RAIN and RAIN.rain_active == true
end

function RAIN.sync_overlay_state()
    local active = RAIN.overlay_active()

    if active and not overlay_was_active then
        RAIN.ensure_scene():onActivate()
        overlay_was_active = true
    elseif (not active) and overlay_was_active then
        if scene3d then scene3d:onDeactivate() end
        overlay_was_active = false
    end
end

function RAIN.on_load()
    RAIN.ensure_scene()
    RAIN.sync_overlay_state()
    RAIN.load_rain_shader()
end
RAIN.on_load()

love.update = function(dt)
    if RAIN.fake_crash then
        if not RAIN.fake_crash_started then
            RAIN.fake_crash_started = love.timer.getTime()
            love.audio.stop()
        end

        if love.timer.getTime() - RAIN.fake_crash_started >= 3 then
            G.GAME = nil
            RAIN.fake_crash = false
            RAIN.rain_active = true
            return
        end

        return
    end

    RAIN.sync_overlay_state()

    if RAIN.overlay_active() then
        RAIN.ensure_scene():update(dt)
        return
    end

    RAIN.update_rain_audio()
    RAIN.try_next_phase()

    if orig_update then
        return orig_update(dt)
    end
end

love.draw = function(...)
    if RAIN.fake_crash then
        RAIN.draw_fake_crash()
        return
    end

    if RAIN.overlay_active() then
        RAIN.ensure_scene():draw()
        return
    end

    local draw
    if orig_draw then
        draw = orig_draw(...)
    end

    RAIN.draw_rain_overlay()

    return draw
end

love.resize = function(w, h)
    if scene3d then
        scene3d:updateViewport()
    end

    if RAIN.overlay_active() then
        return
    end

    if orig_resize then
        return orig_resize(w, h)
    end
end

love.mousemoved = function(x, y, dx, dy, istouch)
    if RAIN.overlay_active() then
        RAIN.ensure_scene():mousemoved(x, y, dx, dy, istouch)
        return
    end

    if orig_mousemoved then
        return orig_mousemoved(x, y, dx, dy, istouch)
    end
end

love.keypressed = function(key, scancode, isrepeat)
    if RAIN.overlay_active() then
        RAIN.ensure_scene():keypressed(key, scancode, isrepeat)
        return
    end

    if orig_keypressed then
        return orig_keypressed(key, scancode, isrepeat)
    end
end

love.mousepressed = function(...)
    if RAIN.overlay_active() then return end
    if orig_mousepressed then return orig_mousepressed(...) end
end

love.mousereleased = function(...)
    if RAIN.overlay_active() then return end
    if orig_mousereleased then return orig_mousereleased(...) end
end

love.wheelmoved = function(...)
    if RAIN.overlay_active() then return end
    if orig_wheelmoved then return orig_wheelmoved(...) end
end

love.textinput = function(...)
    if RAIN.overlay_active() then return end
    if orig_textinput then return orig_textinput(...) end
end

RAIN.fake_crash_scroll = RAIN.fake_crash_scroll or 0
RAIN.fake_crash_end_height = RAIN.fake_crash_end_height or 0

function RAIN.get_fake_crash_text()
    local msg = tostring(RAIN.fake_crash_message or "Unknown error")

    local p = table.concat({
        "Oops! The game crashed:",
        "",
        msg,
        "",
        "Additional Context:",
        "Balatro Version: " .. tostring(VERSION or "???"),
        "Modded Version: " .. tostring(MODDED_VERSION or "???"),
        "Platform: " .. tostring(love.system and love.system.getOS() or "???"),
        "",
        "Press ESC to exit",
        "Restarting..."
    }, "\n")

    p = p:gsub("\t", "")
    p = p:gsub("%[string \"(.-)\"%]", "%1")

    return p
end

function RAIN.draw_fake_crash()
    if love.graphics.isActive and not love.graphics.isActive() then return end

    local background = {0, 0, 0, 1}
    if G and G.C and G.C.BLACK then
        background = G.C.BLACK
    end

    love.graphics.clear(background)
    love.graphics.origin()
    love.graphics.setColor(1, 1, 1, 1)

    if not RAIN.fake_crash_font then
        local ok, font = pcall(love.graphics.newFont, "resources/fonts/m6x11plus.ttf", 20)
        RAIN.fake_crash_font = ok and font or love.graphics.getFont()
    end
    love.graphics.setFont(RAIN.fake_crash_font)

    local p = RAIN.get_fake_crash_text()
    local pos = 70
    local arrowSize = 20
    local w, h = love.graphics.getDimensions()

    local font = love.graphics.getFont()
    local _, lines = font:getWrap(p, w - pos * 2)
    local lineHeight = font:getHeight()

    RAIN.fake_crash_end_height = #lines * lineHeight - h + pos * 2
    if RAIN.fake_crash_end_height < 0 then
        RAIN.fake_crash_end_height = 0
    end

    if RAIN.fake_crash_scroll > RAIN.fake_crash_end_height then
        RAIN.fake_crash_scroll = RAIN.fake_crash_end_height
    end

    love.graphics.printf(
        p,
        pos,
        pos - RAIN.fake_crash_scroll,
        w - pos * 2
    )

    if RAIN.fake_crash_scroll ~= RAIN.fake_crash_end_height then
        love.graphics.polygon(
            "fill",
            w - (pos / 2), h - arrowSize,
            w - (pos / 2) + arrowSize, h - (arrowSize * 2),
            w - (pos / 2) - arrowSize, h - (arrowSize * 2)
        )
    end

    if RAIN.fake_crash_scroll ~= 0 then
        love.graphics.polygon(
            "fill",
            w - (pos / 2), arrowSize,
            w - (pos / 2) + arrowSize, arrowSize * 2,
            w - (pos / 2) - arrowSize, arrowSize * 2
        )
    end
end

local orig_wheelmoved = love.wheelmoved
love.wheelmoved = function(x, y)
    if RAIN.fake_crash then
        RAIN.fake_crash_scroll = RAIN.fake_crash_scroll - y * 20
        if RAIN.fake_crash_scroll < 0 then RAIN.fake_crash_scroll = 0 end
        return
    end

    if RAIN.overlay_active() then return end
    if orig_wheelmoved then return orig_wheelmoved(x, y) end
end