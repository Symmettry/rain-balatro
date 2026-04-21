local PostFX = {}
PostFX.__index = PostFX

function PostFX.new()
    local shader = love.graphics.newShader([[
extern number time;

float rand(float n) {
    return fract(sin(n) * 43758.5453123);
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 px)
{
    vec2 u = uv;

    u.y += sin(time * 0.7) * 0.004;

    float pixelSize = 2.5;
    vec2 uvPix = floor(u * vec2(800.0, 600.0) / pixelSize) * pixelSize / vec2(800.0, 600.0);

    vec4 c = Texel(tex, uvPix);

    float scan = 0.9 + 0.1 * sin(px.y * 0.5);

    float glitch = sin(uv.y * 20.0 + time * 0.75) * 0.002;
    c = Texel(tex, vec2(uv.x + glitch, uv.y));

    float noise = fract(sin(dot(u * time, vec2(12.9898,78.233))) * 43758.5453);
    c.rgb += (noise - 0.5) * 0.05;

    vec2 p = u * 2.0 - 1.0;
    float vignette = 1.0 - dot(p, p) * 0.6;

    float gray = dot(c.rgb, vec3(0.3, 0.59, 0.11));
    c.rgb = mix(c.rgb, vec3(gray), 0.4);

    c.rgb *= scan * vignette;

    float flicker = step(0.92, rand(floor(time * 8.0)));
    c.rgb *= 1.0 - flicker * 0.25;

    c.rgb *= 0.6;

    return c * color;
}
    ]])

    return setmetatable({
        shader = shader
    }, PostFX)
end

function PostFX:send(t)
    self.shader:send("time", t or 0)
end

return PostFX