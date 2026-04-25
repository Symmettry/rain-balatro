-- Rain - Hybrid Balatro Mod + Standalone LÖVE2D Experience
-- Auto-detects environment and runs appropriate mode

RAIN = rawget(_G, "RAIN") or {}
_G.RAIN = RAIN

-- Load compatibility layer first
local Compat = SMODS and SMODS.load_file("lib/compat.lua", "rain")() or require("lib.compat")


-- Load shared rain system
local RainSystem = Compat.load_module("lib/rain/rain.lua")

-- Load 3D scene
local Scene3D = Compat.load_module("lib/3d/scene.lua")

-- Module references
local AudioSystem = Compat.load_module("lib/audio/playback.lua")

-- Runtime state
local scene3d = nil
local overlay_was_active = false
local standalone_initialized = false

-- Original LÖVE callbacks (for Balatro hooking)
local orig_callbacks = {}

-- ============================================================================
-- MODE: BALATRO MOD
-- ============================================================================

local function init_balatro_mode()
    Compat.log("Initializing Balatro mode")

    RAIN.mod = SMODS.current_mod
    RAIN.rain_active = false
    RAIN.fake_crash = false
    RAIN.fake_crash_started = nil

    -- Load Balatro-specific integrations
    Compat.load_module("lib/audio/sounds.lua")
    Compat.load_module("lib/phase.lua")

    -- Hook into LÖVE callbacks
    orig_callbacks.update = love.update
    orig_callbacks.draw = love.draw
    orig_callbacks.resize = love.resize
    orig_callbacks.mousemoved = love.mousemoved
    orig_callbacks.keypressed = love.keypressed
    orig_callbacks.mousepressed = love.mousepressed
    orig_callbacks.mousereleased = love.mousereleased
    orig_callbacks.wheelmoved = love.wheelmoved
    orig_callbacks.textinput = love.textinput

    function RAIN.ensure_scene()
        if not scene3d and RAIN.rain_active then
            scene3d = Scene3D.new()
        end
        return scene3d
    end

    function RAIN.overlay_active()
        return RAIN.rain_active == true
    end

    function RAIN.sync_overlay_state()
        local active = RAIN.overlay_active()
        if active and not overlay_was_active then
            RAIN.ensure_scene():onActivate()
            overlay_was_active = true
            love.mouse.setRelativeMode(true)
        elseif (not active) and overlay_was_active then
            if scene3d then scene3d:onDeactivate() end
            overlay_was_active = false
            love.mouse.setRelativeMode(false)
        end
    end

    -- Override LÖVE callbacks
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

        RainSystem.update_audio()

        -- Call phase logic
        if RAIN.try_next_phase then
            RAIN.try_next_phase()
        end

        if orig_callbacks.update then
            return orig_callbacks.update(dt)
        end
    end

    love.draw = function(...)
        if RAIN.fake_crash then
            RainSystem.draw_fake_crash()
            return
        end

        if RAIN.overlay_active() then
            RAIN.ensure_scene():draw()
            return
        end

        local result
        if orig_callbacks.draw then
            result = orig_callbacks.draw(...)
        end

        RainSystem.draw_overlay()
        return result
    end

    love.resize = function(w, h)
        if scene3d then
            scene3d:updateViewport()
        end
        if RAIN.overlay_active() then
            return
        end
        if orig_callbacks.resize then
            return orig_callbacks.resize(w, h)
        end
    end

    love.mousemoved = function(x, y, dx, dy, istouch)
        if RAIN.overlay_active() then
            RAIN.ensure_scene():mousemoved(x, y, dx, dy, istouch)
            return
        end
        if orig_callbacks.mousemoved then
            return orig_callbacks.mousemoved(x, y, dx, dy, istouch)
        end
    end

    love.keypressed = function(key, scancode, isrepeat)
        if RAIN.overlay_active() then
            RAIN.ensure_scene():keypressed(key, scancode, isrepeat)
            return
        end
        if orig_callbacks.keypressed then
            return orig_callbacks.keypressed(key, scancode, isrepeat)
        end
    end

    love.mousepressed = function(...)
        if RAIN.overlay_active() then return end
        if orig_callbacks.mousepressed then
            return orig_callbacks.mousepressed(...)
        end
    end

    love.mousereleased = function(...)
        if RAIN.overlay_active() then return end
        if orig_callbacks.mousereleased then
            return orig_callbacks.mousereleased(...)
        end
    end

    love.wheelmoved = function(x, y)
        if RAIN.fake_crash then
            RAIN.fake_crash_scroll = RAIN.fake_crash_scroll - y * 20
            if RAIN.fake_crash_scroll < 0 then RAIN.fake_crash_scroll = 0 end
            return
        end
        if RAIN.overlay_active() then return end
        if orig_callbacks.wheelmoved then
            return orig_callbacks.wheelmoved(x, y)
        end
    end

    love.textinput = function(...)
        if RAIN.overlay_active() then return end
        if orig_callbacks.textinput then
            return orig_callbacks.textinput(...)
        end
    end

    -- Initial setup
    RAIN.load_rain_shader = RainSystem.load_shader
    RAIN.draw_rain_overlay = RainSystem.draw_overlay
    RAIN.update_rain_audio = RainSystem.update_audio
    RAIN.get_rain_profile = RainSystem.get_profile
    RAIN.get_current_ante = RainSystem.get_current_ante
    RAIN.should_play_rain = RainSystem.should_play
    RAIN.draw_fake_crash = RainSystem.draw_fake_crash
    RAIN.get_fake_crash_text = RainSystem.get_fake_crash_text

    -- Load shader and initialize
    RainSystem.load_shader()
    RAIN.ensure_scene()
    RAIN.sync_overlay_state()

    Compat.log("Balatro mode initialized")
end

-- ============================================================================
-- MODE: STANDALONE
-- ============================================================================

local function init_standalone_mode()
    Compat.log("Initializing Standalone mode")

    standalone_initialized = true
    RAIN.active_profile = RainSystem.PROFILES.moderate

    -- Scene instance
    scene3d = Scene3D.new()

    -- Override LÖVE callbacks for standalone
    love.load = function()
        love.window.setTitle("Rain - A Peaceful Forest Walk")
        if not love.window.getMode() then
            love.window.setMode(1280, 720, { resizable = true, vsync = true })
        end
        love.mouse.setRelativeMode(true)

        RainSystem.load_shader()

        AudioSystem.playCrossfadeLoop("rain_soft", {
            mode = "static",
            volume = profile.volume,
            overlap = 1.0
        })

        Compat.log("Controls: WASD=Move, Mouse=Look, 1-4=Rain intensity, F=Wireframe, M=Mute, ESC=Quit")
    end

    love.update = function(dt)
        RainSystem.rain_time = RainSystem.rain_time + dt

        -- Update rain audio based on current profile
        if RAIN.active_profile then
            AudioSystem.playCrossfadeLoop("rain_soft", {
                mode = "static",
                volume = profile.volume,
                overlap = 1.0
            })
        end

        if scene3d then
            scene3d:update(dt)
        end
    end

    love.draw = function()
        if not scene3d then return end

        -- Draw 3D scene
        scene3d:draw()

        -- Draw rain overlay
        if RainSystem.rain_shader and RAIN.active_profile then
            love.graphics.setShader(RainSystem.rain_shader)
            RainSystem.rain_shader:send("iTime", RainSystem.rain_time)
            RainSystem.rain_shader:send("iResolution", { love.graphics.getWidth(), love.graphics.getHeight() })
            RainSystem.rain_shader:send("rainSpeed", RAIN.active_profile.speed)
            RainSystem.rain_shader:send("rainDensity", RAIN.active_profile.density)
            RainSystem.rain_shader:send("rainBrightness", RAIN.active_profile.brightness)
            RainSystem.rain_shader:send("rainAlpha", RAIN.active_profile.alpha)

            love.graphics.setColor(1, 1, 1, RAIN.active_profile.alpha)
            love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
            love.graphics.setShader()
            love.graphics.setColor(1, 1, 1, 1)
        end

        -- Draw UI
        love.graphics.setColor(1, 1, 1, 0.7)
        local font = love.graphics.getFont()
        local y = 10
        love.graphics.print("Rain - 1-4: intensity, F: wireframe, M: mute, ESC: quit", 10, y)
        local profile_name = RAIN.active_profile == RainSystem.PROFILES.gentle and "Gentle" or
                            RAIN.active_profile == RainSystem.PROFILES.moderate and "Moderate" or
                            RAIN.active_profile == RainSystem.PROFILES.heavy and "Heavy" or "Storm"
        love.graphics.print("Intensity: " .. profile_name, 10, y + 20)
    end

    love.resize = function(w, h)
        if scene3d then
            scene3d:updateViewport()
        end
    end

    love.mousemoved = function(x, y, dx, dy, istouch)
        if scene3d then
            scene3d:mousemoved(x, y, dx, dy, istouch)
        end
    end

    love.keypressed = function(key, scancode, isrepeat)
        if scene3d then
            scene3d:keypressed(key, scancode, isrepeat)
        end
    end

    love.quit = function()
        AudioSystem.stopAll()
    end

    -- Trigger load immediately since we might be past initial load
    if love.load then love.load() end

    Compat.log("Standalone mode initialized")
end

-- ============================================================================
-- ENTRY POINT
-- ============================================================================

if Compat.is_balatro() then
    init_balatro_mode()
else
    init_standalone_mode()
end
