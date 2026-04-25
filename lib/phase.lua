-- Balatro phase management
-- Only loaded when running as Balatro mod

if not SMODS then return end

function RAIN.try_next_phase()
    if G and G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante > 5 then
        RAIN.fake_crash = true
        love.audio.stop()
    end
end
