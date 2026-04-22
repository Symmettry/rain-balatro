local AudioSystem = assert(SMODS.load_file("lib/audio/playback.lua"))()

RAIN.rain_shader = nil
RAIN.rain_time = 0
RAIN.was_in_menu = false
RAIN.rain_playing = false

function RAIN.load_rain_shader()
    RAIN.rain_shader = love.graphics.newShader([[
        extern number iTime;
        extern vec2 iResolution;

        #define RAIN_SPEED 2.0
        #define RAIN_ANGLE -0.2
        #define RAIN_LENGTH 0.4
        #define RAIN_WIDTH 0.02
        #define RAIN_DENSITY 100.0
        #define RAIN_BRIGHTNESS 1.8

        float hash12(vec2 p)
        {
            vec3 p3 = fract(vec3(p.xyx) * 0.1031);
            p3 += dot(p3, p3.yzx + 33.33);
            return fract((p3.x + p3.y) * p3.z);
        }

        vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
        {
            // Normalize using screen height so aspect stays consistent
            vec2 uv = vec2(screen_coords.x, iResolution.y - screen_coords.y) / iResolution.y;
            vec3 col = vec3(0.0);

            // Apply slant
            vec2 slantedUV = uv;
            slantedUV.x += uv.y * RAIN_ANGLE;

            // Scale rain grid
            vec2 rainUV = slantedUV * vec2(RAIN_DENSITY, 1.0 / RAIN_LENGTH);

            float colID = floor(rainUV.x);
            float noise = hash12(vec2(colID, 1.1));

            // Movement
            float time = iTime * RAIN_SPEED;
            float y = rainUV.y + time + (noise * 20.0);

            float cellY = fract(y);
            float rowY = floor(y);

            // Randomize whether a drop exists in this segment
            float dropID = hash12(vec2(colID, rowY));

            if (dropID > 0.6)
            {
                float xDist = abs(fract(rainUV.x) - 0.5);
                float w = fwidth(rainUV.x) * 1.5;
                float horizontalShape = smoothstep(RAIN_WIDTH + w, RAIN_WIDTH - w, xDist);

                float verticalShape = smoothstep(1.0, 0.0, cellY);
                verticalShape *= pow(1.0 - cellY, 2.0 / RAIN_LENGTH);

                float finalDrop = horizontalShape * verticalShape;

                col = vec3(0.6, 0.7, 0.9) * finalDrop * RAIN_BRIGHTNESS;
            }

            return vec4(col, 1.0) * color;
        }
    ]])
end

function RAIN.in_main_menu()
    return G and G.STAGE == G.STAGES.MAIN_MENU
end

function RAIN.update_rain_audio()
    local in_menu = RAIN.in_main_menu()

    if in_menu and not RAIN.was_in_menu then
        AudioSystem.play("rain", {
            mode = "static",
            loop = true,
            volume = 0.8
        })
        RAIN.rain_playing = true

    elseif not in_menu and RAIN.was_in_menu then
        AudioSystem.stop("rain", "static")
        RAIN.rain_playing = false
    end

    RAIN.was_in_menu = in_menu
end

function RAIN.draw_rain_overlay()
    if not RAIN.in_main_menu() or not RAIN.rain_shader then return end

    RAIN.rain_time = RAIN.rain_time + love.timer.getDelta()

    love.graphics.setShader(RAIN.rain_shader)
    RAIN.rain_shader:send("iTime", RAIN.rain_time)
    RAIN.rain_shader:send("iResolution", {
        love.graphics.getWidth(),
        love.graphics.getHeight()
    })

    love.graphics.setColor(1, 1, 1, 0.35)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1, 1)
end