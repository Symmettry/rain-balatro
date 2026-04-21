RAIN.rain_shader = nil
RAIN.rain_time = 0

function RAIN.load_rain_shader()
    RAIN.rain_shader = love.graphics.newShader([[
        extern number iTime;
        extern vec2 iResolution;

        vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
        {
            vec2 uv = screen_coords / iResolution;

            // simple vertical rain streaks
            float x = floor(uv.x * 140.0) / 140.0;
            float speed = 1.8;
            float y = fract(uv.y * 8.0 + iTime * speed + sin(x * 400.0) * 0.2);

            float streak = smoothstep(0.02, 0.0, abs(y - 0.5)) * 0.35;
            streak *= smoothstep(0.8, 0.2, uv.y);

            vec3 rain = vec3(streak);

            return vec4(rain, streak);
        }
    ]])
end

function RAIN.in_main_menu()
    return G and G.STAGE == G.STAGES.MAIN_MENU
end

function RAIN.draw_rain_overlay()
    if not RAIN.in_main_menu() or not RAIN.rain_shader then return end

    RAIN.rain_time = RAIN.rain_time + love.timer.getDelta()

    love.graphics.setShader(RAIN.rain_shader)
    RAIN.rain_shader:send("iTime", RAIN.rain_time)
    RAIN.rain_shader:send("iResolution", {love.graphics.getWidth(), love.graphics.getHeight()})

    love.graphics.setColor(1, 1, 1, 0.35)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1, 1)
end