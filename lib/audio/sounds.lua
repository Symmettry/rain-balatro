SMODS.Sound {
    key = "music1_distorted",
    path = "music1_distorted.ogg",
    volume = 1
}

RAIN.distorted = {
    music1 = true,
}

local _play_sound = play_sound
play_sound = function(sound_code, per, vol)
    if RAIN.distorted[sound_code] ~= nil then
        sound_code = 'rain_' .. sound_code .. '_distorted'
    end
    return _play_sound(sound_code, per, vol)
end