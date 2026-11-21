-- Exemplo Lua: roda em qualquer música quando o mod "example" está ativo (F5 no menu)
function onCreate()
    debugPrint("Mod example carregado (Lua)")
end

function onBeatHit(beat)
    if beat % 16 == 0 then
        cameraShake("game", 0.005, 0.2)
    end
end

function goodNoteHit(lane, rating)
    -- rating: sick / good / bad / shit
end
