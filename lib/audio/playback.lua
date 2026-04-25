local Compat = SMODS and SMODS.load_file("lib/compat.lua", "rain")() or require("lib.compat")

local AudioSystem = {}
AudioSystem.sources = {}
AudioSystem.active = {}
AudioSystem.crossfades = {}

local function resolvePath(name)
    if not name:match("%.%w+$") then
        name = name .. ".wav"
    end
    return Compat.sound_path(name)
end

local function readFileData(absPath, displayName)
    return Compat.read_file_data(absPath, displayName)
end

local function getFileData(name)
    local path = resolvePath(name)

    if not AudioSystem.sources[path] then
        AudioSystem.sources[path] = readFileData(path, name)
    end

    return AudioSystem.sources[path]
end

function AudioSystem.play(name, opts)
    opts = opts or {}

    local mode = opts.mode or "stream"
    local loop = opts.loop or false
    local volume = opts.volume or 1.0

    local key = name .. "_" .. mode

    if AudioSystem.active[key] then
        local src = AudioSystem.active[key]
        if src:isPlaying() then
            src:setVolume(volume)
            return src
        end
    end

    local fd = getFileData(name)
    local src = love.audio.newSource(fd, mode)

    src:setLooping(loop)
    src:setVolume(volume)
    src:play()

    AudioSystem.active[key] = src
    return src
end

function AudioSystem.playCrossfadeLoop(name, opts)
    opts = opts or {}

    local mode = opts.mode or "static"
    local volume = opts.volume or 1.0
    local overlap = opts.overlap or 1.0

    local key = name .. "_" .. mode .. "_crossfade"

    if AudioSystem.crossfades[key] then
        AudioSystem.crossfades[key].volume = volume
        return AudioSystem.crossfades[key]
    end

    local fd = getFileData(name)

    local srcA = love.audio.newSource(fd, mode)
    local srcB = love.audio.newSource(fd, mode)

    srcA:setLooping(false)
    srcB:setLooping(false)

    srcA:setVolume(volume)
    srcB:setVolume(0)

    srcA:play()

    local controller = {
        key = key,
        name = name,
        mode = mode,
        srcA = srcA,
        srcB = srcB,
        active = srcA,
        standby = srcB,
        volume = volume,
        overlap = overlap,
        fading = false
    }

    AudioSystem.crossfades[key] = controller
    return controller
end

function AudioSystem.update(dt)
    for key, loop in pairs(AudioSystem.crossfades) do
        local active = loop.active
        local standby = loop.standby

        local duration = active:getDuration("seconds")
        local pos = active:tell("seconds")

        if duration and duration > 0 then
            local remaining = duration - pos

            if remaining <= loop.overlap and not loop.fading then
                standby:stop()
                standby:seek(0)
                standby:setVolume(0)
                standby:play()
                loop.fading = true
            end

            if loop.fading then
                local fade = 1 - math.max(0, remaining / loop.overlap)

                active:setVolume(loop.volume * (1 - fade))
                standby:setVolume(loop.volume * fade)

                if remaining <= 0.03 then
                    active:stop()
                    active:setVolume(0)

                    loop.active = standby
                    loop.standby = active
                    loop.fading = false
                end
            else
                active:setVolume(loop.volume)
                standby:setVolume(0)
            end
        end
    end
end

function AudioSystem.setVolume(name, mode, volume)
    mode = mode or "static"

    local normalKey = name .. "_" .. mode
    local crossfadeKey = name .. "_" .. mode .. "_crossfade"

    if AudioSystem.active[normalKey] then
        AudioSystem.active[normalKey]:setVolume(volume)
    end

    if AudioSystem.crossfades[crossfadeKey] then
        AudioSystem.crossfades[crossfadeKey].volume = volume
    end
end

function AudioSystem.stop(name, mode)
    mode = mode or "stream"

    local normalKey = name .. "_" .. mode
    local crossfadeKey = name .. "_" .. mode .. "_crossfade"

    local src = AudioSystem.active[normalKey]
    if src then
        src:stop()
        AudioSystem.active[normalKey] = nil
    end

    local loop = AudioSystem.crossfades[crossfadeKey]
    if loop then
        if loop.srcA then loop.srcA:stop() end
        if loop.srcB then loop.srcB:stop() end
        AudioSystem.crossfades[crossfadeKey] = nil
    end
end

function AudioSystem.stopAll()
    for key, src in pairs(AudioSystem.active) do
        if src then
            src:stop()
        end
    end

    for key, loop in pairs(AudioSystem.crossfades) do
        if loop.srcA then loop.srcA:stop() end
        if loop.srcB then loop.srcB:stop() end
    end

    AudioSystem.active = {}
    AudioSystem.crossfades = {}
end

return AudioSystem