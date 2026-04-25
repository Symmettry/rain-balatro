-- Environment compatibility layer for Rain
-- Works with both Balatro (SMODS) and standalone LÖVE2D

local Compat = {}

-- Detect runtime environment
function Compat.is_balatro()
    return rawget(_G, "SMODS") ~= nil
end

function Compat.is_standalone()
    return not Compat.is_balatro()
end

-- Universal module loader
function Compat.load_module(path)
    if Compat.is_balatro() then
        local result = SMODS.load_file(path, "rain")
        if type(result) == "function" then
            return result()
        end
        return result
    else
        local require_path = path
            :gsub("%.lua$", "")
            :gsub("/", ".")
        return require(require_path)
    end
end

-- Resolve asset paths
function Compat.asset_path(subpath)
    if Compat.is_balatro() then
        return RAIN.mod.path .. "/assets/" .. subpath
    else
        return "assets/" .. subpath
    end
end

-- Audio file resolution
function Compat.sound_path(name)
    if not name:match("%.%w+$") then
        name = name .. ".wav"
    end
    if Compat.is_balatro() then
        return RAIN.mod.path .. "/assets/sounds/" .. name
    else
        return "assets/sounds/" .. name
    end
end

-- Read file data (for audio)
function Compat.read_file_data(path, display_name)
    if Compat.is_balatro() then
        -- Balatro: use io.open for absolute paths
        local f, err = io.open(path, "rb")
        assert(f, "Could not open audio file: " .. tostring(err) .. "\nPath: " .. path)
        local bytes = f:read("*a")
        f:close()
        assert(bytes and #bytes > 0, "Audio file was empty: " .. path)
        return love.filesystem.newFileData(bytes, display_name)
    else
        -- Standalone: use love.filesystem
        local bytes, err = love.filesystem.read("string", path)
        assert(bytes, "Could not read audio file: " .. tostring(err) .. "\nPath: " .. path)
        assert(#bytes > 0, "Audio file was empty: " .. path)
        return love.filesystem.newFileData(bytes, display_name)
    end
end

-- Print with prefix
function Compat.log(msg)
    local prefix = Compat.is_balatro() and "[Rain/Balatro]" or "[Rain/Standalone]"
    print(prefix .. " " .. msg)
end

return Compat
