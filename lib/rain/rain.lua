-- Shared rain system for both Balatro and Standalone modes

local Compat = SMODS and SMODS.load_file("lib/compat.lua", "rain")() or require("lib.compat")
local AudioSystem = Compat.load_module("lib/audio/playback.lua")

RAIN.rain_shader = nil
RAIN.rain_time = 0
RAIN.rain_playing = false
RAIN.current_rain_profile = nil

RAIN.early_forest = RAIN.early_forest or false
RAIN.mid_forest = RAIN.mid_forest or false
RAIN.end_forest = RAIN.end_forest or false
RAIN.fake_crash = RAIN.fake_crash or false

RAIN.fake_crash_scroll = 0
RAIN.fake_crash_end_height = 0
RAIN.fake_crash_message = [[Unable to witness the renderer]]

-- Rain profiles
RAIN.PROFILES = {
    gentle = {
        id = "gentle",
        volume = 0.5,
        alpha = 0.4,
        density = 80.0,
        speed = 1.5,
        brightness = 1.2
    },
    moderate = {
        id = "moderate",
        volume = 0.8,
        alpha = 0.6,
        density = 120.0,
        speed = 2.2,
        brightness = 1.6
    },
    heavy = {
        id = "heavy",
        volume = 1.2,
        alpha = 0.75,
        density = 180.0,
        speed = 3.0,
        brightness = 2.2
    },
    storm = {
        id = "storm",
        volume = 1.8,
        alpha = 0.85,
        density = 240.0,
        speed = 3.8,
        brightness = 2.8
    },
    -- Balatro-specific profiles
    soft = {
        id = "soft",
        volume = 0.8,
        alpha = 0.6,
        density = 100.0,
        speed = 2.0,
        brightness = 1.8
    },
    mid = {
        id = "mid",
        volume = 1.2,
        alpha = 0.7,
        density = 170.0,
        speed = 2.8,
        brightness = 2.2
    },
    end_forest = {
        id = "end_forest",
        volume = 3.0,
        alpha = 0.85,
        density = 240.0,
        speed = 3.8,
        brightness = 3.0
    },
    fake_crash = {
        id = "fake_crash",
        volume = 3.0,
        alpha = 0.90,
        density = 260.0,
        speed = 4.2,
        brightness = 3.2
    }
}

local SHADER_CODE = [[
    extern number iTime;
    extern vec2 iResolution;

    extern number rainSpeed;
    extern number rainDensity;
    extern number rainBrightness;
    extern number rainAlpha;

    #define RAIN_ANGLE -0.22
    #define RAIN_WIDTH 0.010
    #define STREAK_REPEAT 2.8
    #define STREAK_LENGTH 0.42

    float hash12(vec2 p)
    {
        vec3 p3 = fract(vec3(p.xyx) * 0.1031);
        p3 += dot(p3, p3.yzx + 33.33);
        return fract((p3.x + p3.y) * p3.z);
    }

    vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
    {
        vec2 uv = vec2(screen_coords.x, iResolution.y - screen_coords.y) / iResolution.y;

        vec2 ruv = uv;
        ruv.x += uv.y * RAIN_ANGLE;

        float col = floor(ruv.x * rainDensity);
        float colRand = hash12(vec2(col, 13.7));

        float xInCol = fract(ruv.x * rainDensity);
        float xDist = abs(xInCol - 0.5);
        float aa = fwidth(ruv.x * rainDensity) * 1.5;
        float thinLine = smoothstep(RAIN_WIDTH + aa, RAIN_WIDTH - aa, xDist);

        float y = uv.y * STREAK_REPEAT + iTime * rainSpeed + colRand * STREAK_REPEAT;
        float streakPos = fract(y);

        float streak = smoothstep(0.0, 0.08, streakPos) *
                       smoothstep(STREAK_LENGTH, STREAK_LENGTH - 0.10, streakPos);

        float visibility = step(0.35, colRand);

        float finalRain = thinLine * streak * visibility;

        vec3 rainColor = vec3(0.85, 0.88, 0.92) * finalRain * rainBrightness;
        float alphaOut = finalRain * rainAlpha;

        return vec4(rainColor, alphaOut) * color;
    }
]]

function RAIN.load_shader()
    RAIN.rain_shader = love.graphics.newShader(SHADER_CODE)
end

function RAIN.get_current_ante()
    if G and G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante then
        return G.GAME.round_resets.ante
    end
    return 0
end

function RAIN.get_profile()
    if Compat.is_standalone() then
        -- Standalone: use the active profile set by user (1-4 keys)
        return RAIN.active_profile or RAIN.PROFILES.moderate
    end

    -- Balatro mode: ante-based progression
    if not G then return nil end

    local ante = RAIN.get_current_ante()

    if RAIN.fake_crash then
        return RAIN.PROFILES.fake_crash
    end

    if RAIN.end_forest then
        return RAIN.PROFILES.end_forest
    end

    if RAIN.mid_forest or (ante >= 3 and ante <= 5) then
        return RAIN.PROFILES.mid
    end

    if RAIN.early_forest or G.STAGE == G.STAGES.MAIN_MENU then
        return RAIN.PROFILES.soft
    end

    return nil
end

function RAIN.should_play()
    return RAIN.get_profile() ~= nil
end

function RAIN.update_audio()
    local profile = RAIN.get_profile()

    if not profile then
        if RAIN.rain_playing then
            AudioSystem.stop("rain_soft", "static")
            RAIN.rain_playing = false
            RAIN.current_rain_profile = nil
        end
        return
    end

    if not RAIN.rain_playing then
        AudioSystem.playCrossfadeLoop("rain_soft", {
            mode = "static",
            volume = profile.volume,
            overlap = 1.0
        })  
        RAIN.rain_playing = true
        RAIN.current_rain_profile = profile.id
        return
    end

    if RAIN.current_rain_profile ~= profile.id then
        AudioSystem.stop("rain_soft", "static")
        AudioSystem.playCrossfadeLoop("rain_soft", {
            mode = "static",
            volume = profile.volume,
            overlap = 1.0
        })
        RAIN.current_rain_profile = profile.id
    end
end

function RAIN.draw_overlay()
    local profile = RAIN.get_profile()
    if not profile or not RAIN.rain_shader then return end

    RAIN.rain_time = RAIN.rain_time + love.timer.getDelta()

    love.graphics.setShader(RAIN.rain_shader)
    RAIN.rain_shader:send("iTime", RAIN.rain_time)
    RAIN.rain_shader:send("iResolution", { love.graphics.getWidth(), love.graphics.getHeight() })
    RAIN.rain_shader:send("rainSpeed", profile.speed)
    RAIN.rain_shader:send("rainDensity", profile.density)
    RAIN.rain_shader:send("rainBrightness", profile.brightness)
    RAIN.rain_shader:send("rainAlpha", profile.alpha)

    love.graphics.setColor(1, 1, 1, profile.alpha)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1, 1)
end

-- Fake crash screen for Balatro mode
function RAIN.get_fake_crash_text()
    local msg = tostring(RAIN.fake_crash_message or "Unknown error")
    local p = table.concat({
        "Oops! The game crashed:",
        "",
        msg,
        "",
        "Additional Context:",
        "Balatro Version: " .. tostring(rawget(_G, "VERSION") or "???"),
        "Modded Version: " .. tostring(rawget(_G, "MODDED_VERSION") or "???"),
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
    if rawget(_G, "G") and G.C and G.C.BLACK then
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
    if RAIN.fake_crash_end_height < 0 then RAIN.fake_crash_end_height = 0 end

    if RAIN.fake_crash_scroll > RAIN.fake_crash_end_height then
        RAIN.fake_crash_scroll = RAIN.fake_crash_end_height
    end

    love.graphics.printf(p, pos, pos - RAIN.fake_crash_scroll, w - pos * 2)

    if RAIN.fake_crash_scroll ~= RAIN.fake_crash_end_height then
        love.graphics.polygon("fill", w - (pos / 2), h - arrowSize, w - (pos / 2) + arrowSize, h - (arrowSize * 2), w - (pos / 2) - arrowSize, h - (arrowSize * 2))
    end

    if RAIN.fake_crash_scroll ~= 0 then
        love.graphics.polygon("fill", w - (pos / 2), arrowSize, w - (pos / 2) + arrowSize, arrowSize * 2, w - (pos / 2) - arrowSize, arrowSize * 2)
    end
end

return RAIN
