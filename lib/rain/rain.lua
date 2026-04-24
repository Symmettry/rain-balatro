local AudioSystem = assert(SMODS.load_file("lib/audio/playback.lua"))()

RAIN.rain_shader = nil
RAIN.rain_time = 0

RAIN.rain_playing = false
RAIN.current_rain_profile = nil

RAIN.early_forest = RAIN.early_forest or false
RAIN.mid_forest = RAIN.mid_forest or false
RAIN.end_forest = RAIN.end_forest or false
RAIN.fake_crash = RAIN.fake_crash or false

function RAIN.load_rain_shader()
    RAIN.rain_shader = love.graphics.newShader([[
        extern number iTime;
        extern vec2 iResolution;

        extern number rainSpeed;
        extern number rainDensity;
        extern number rainBrightness;
        extern number rainAlpha;

        #define RAIN_ANGLE -0.2
        #define RAIN_LENGTH 0.4
        #define RAIN_WIDTH 0.02

        float hash12(vec2 p)
        {
            vec3 p3 = fract(vec3(p.xyx) * 0.1031);
            p3 += dot(p3, p3.yzx + 33.33);
            return fract((p3.x + p3.y) * p3.z);
        }

        vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
        {
            vec2 uv = vec2(screen_coords.x, iResolution.y - screen_coords.y) / iResolution.y;
            vec3 col = vec3(0.0);

            vec2 slantedUV = uv;
            slantedUV.x += uv.y * RAIN_ANGLE;

            vec2 rainUV = slantedUV * vec2(rainDensity, 1.0 / RAIN_LENGTH);

            float colID = floor(rainUV.x);
            float noise = hash12(vec2(colID, 1.1));

            float time = iTime * rainSpeed;
            float y = rainUV.y + time + (noise * 20.0);

            float cellY = fract(y);
            float rowY = floor(y);

            float dropID = hash12(vec2(colID, rowY));

            if (dropID > 0.6)
            {
                float xDist = abs(fract(rainUV.x) - 0.5);
                float w = fwidth(rainUV.x) * 1.5;
                float horizontalShape = smoothstep(RAIN_WIDTH + w, RAIN_WIDTH - w, xDist);

                float verticalShape = smoothstep(1.0, 0.0, cellY);
                verticalShape *= pow(1.0 - cellY, 2.0 / RAIN_LENGTH);

                float finalDrop = horizontalShape * verticalShape;

                col = vec3(0.6, 0.7, 0.9) * finalDrop * rainBrightness;
            }

            return vec4(col, rainAlpha) * color;
        }
    ]])
end

function RAIN.get_current_ante()
    if G and G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante then
        return G.GAME.round_resets.ante
    end

    return 0
end

function RAIN.get_rain_profile()
    if not G then return nil end

    local ante = RAIN.get_current_ante()

    -- Highest priority
    if RAIN.fake_crash then
        return {
            id = "fake_crash",
            volume = 3.0,
            alpha = 0.90,
            density = 260.0,
            speed = 4.2,
            brightness = 3.2
        }
    end

    if RAIN.end_forest then
        return {
            id = "end_forest",
            volume = 3.0,
            alpha = 0.85,
            density = 240.0,
            speed = 3.8,
            brightness = 3.0
        }
    end

    if RAIN.mid_forest or (ante >= 3 and ante <= 5) then
        return {
            id = "mid",
            volume = 1.2,
            alpha = 0.7,
            density = 170.0,
            speed = 2.8,
            brightness = 2.2
        }
    end

    if RAIN.early_forest or G.STAGE == G.STAGES.MAIN_MENU then
        return {
            id = "soft",
            volume = 0.8,
            alpha = 0.6,
            density = 100.0,
            speed = 2.0,
            brightness = 1.8
        }
    end

    return nil
end

function RAIN.should_play_rain()
    return RAIN.get_rain_profile() ~= nil
end

function RAIN.update_rain_audio()
    local profile = RAIN.get_rain_profile()

    if not profile then
        if RAIN.rain_playing then
            AudioSystem.stop("rain_soft", "static")
            RAIN.rain_playing = false
            RAIN.current_rain_profile = nil
        end

        return
    end

    if not RAIN.rain_playing then
        AudioSystem.play("rain_soft", {
            mode = "static",
            loop = true,
            volume = profile.volume
        })

        RAIN.rain_playing = true
        RAIN.current_rain_profile = profile.id
        return
    end

    if RAIN.current_rain_profile ~= profile.id then
        AudioSystem.stop("rain_soft", "static")

        AudioSystem.play("rain_soft", {
            mode = "static",
            loop = true,
            volume = profile.volume
        })

        RAIN.current_rain_profile = profile.id
    end
end

function RAIN.draw_rain_overlay()
    local profile = RAIN.get_rain_profile()

    if not profile or not RAIN.rain_shader then return end

    RAIN.rain_time = RAIN.rain_time + love.timer.getDelta()

    love.graphics.setShader(RAIN.rain_shader)

    RAIN.rain_shader:send("iTime", RAIN.rain_time)
    RAIN.rain_shader:send("iResolution", {
        love.graphics.getWidth(),
        love.graphics.getHeight()
    })

    RAIN.rain_shader:send("rainSpeed", profile.speed)
    RAIN.rain_shader:send("rainDensity", profile.density)
    RAIN.rain_shader:send("rainBrightness", profile.brightness)
    RAIN.rain_shader:send("rainAlpha", profile.alpha)

    love.graphics.setColor(1, 1, 1, profile.alpha)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1, 1)
end