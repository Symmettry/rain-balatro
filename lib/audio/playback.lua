local AudioSystem = {}
local _sources = {}

local function resolvePath(name)
    if not name:match("%.%w+$") then
        name = name .. ".wav"
    end
    return RAIN.mod.path .. "/assets/" .. name
end

local function readFileData(absPath, displayName)
    local f, err = io.open(absPath, "rb")
    assert(f, "Could not open audio file via io.open: " .. tostring(err) .. "\nPath: " .. absPath)

    local bytes = f:read("*a")
    f:close()

    assert(bytes and #bytes > 0, "Audio file was empty or unreadable: " .. absPath)

    return love.filesystem.newFileData(bytes, displayName)
end

local function getSource(name, mode)
    mode = mode or "stream"

    local cacheKey = name .. "::" .. mode
    if not _sources[cacheKey] then
        local absPath = resolvePath(name)
        local fileData = readFileData(absPath, name)
        _sources[cacheKey] = love.audio.newSource(fileData, mode)
    end

    return _sources[cacheKey]
end

function AudioSystem.play(name, opts)
    opts = opts or {}

    local src = getSource(name, opts.mode or "stream")
    src:setLooping(opts.loop or false)

    if opts.volume ~= nil then
        src:setVolume(opts.volume)
    end

    src:stop()
    src:play()
    return src
end

function AudioSystem.stop(name, mode)
    local key = name .. "::" .. (mode or "stream")
    if _sources[key] then
        _sources[key]:stop()
    end
end

function AudioSystem.stopAll()
    for _, src in pairs(_sources) do
        src:stop()
    end
end

return AudioSystem