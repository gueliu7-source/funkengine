local tankRunScale = 1.5
local tankRunX = 800
local tankRunY = 1000
local tankRunStartScale = 1

function onCreate()
    precacheImage('characters/morningpatrol/tankscream')

    makeLuaSprite('forest05', 's2forest/bg05', -620, 280)
    setScrollFactor('forest05', 1.0, 1.0)
    scaleObject('forest05', 3.8, 3.8)
    addLuaSprite('forest05', false)
    setProperty('forest05.alpha', 0)
    setProperty('forest05.antialiasing', false)
        
    makeLuaSprite('forest', 's2forest/bg', -280, 285)
    setScrollFactor('forest', 1.0, 1.0)
    scaleObject('forest', 2.45, 2.4)
    addLuaSprite('forest', false)
    setProperty('forest.alpha', 0)
    
    makeAnimatedLuaSprite('tank_run', 'characters/morningpatrol/tank_run', tankRunX, tankRunY)
    addAnimationByPrefix('tank_run', 'idle', 'idle', 24, true)
    scaleObject('tank_run', tankRunStartScale, tankRunStartScale)
    addLuaSprite('tank_run', false)
    setProperty('tank_run.visible', false)
    playAnim('tank_run', 'idle', true)
    setProperty('tank_run.antialiasing', false)

    makeAnimatedLuaSprite('guardian_house', 'characters/morningpatrol/guardian_house', 500, 900)
    addAnimationByPrefix('guardian_house', 'idle', 'idle', 24, false)
    addAnimationByPrefix('guardian_house', 'left', 'left', 24, false)
    addAnimationByPrefix('guardian_house', 'down', 'down', 24, false)
    addAnimationByPrefix('guardian_house', 'up', 'up', 24, false)
    addAnimationByPrefix('guardian_house', 'right', 'right', 24, false)
    scaleObject('guardian_house', 2.4, 2.4)
end

function onSongStart()
    makeLuaText('collect', 'Collect All 15 Teletubbie Custards', 520, 370, 330)
    setTextSize('collect', 13)
    setTextBorder('collect', 0, '000000')
    setProperty('collect.antialiasing', true)
    setObjectCamera('collect', 'other')
    addLuaText('collect')
    
end

function onCreatePost()
    for i = 0,7 do
        setPropertyFromGroup('opponentStrums', i, 'visible', false)
    end
    
    for i = 0, 3 do
    setPropertyFromGroup('playerStrums', i, 'visible', false)
    end

    setProperty('scoreTxt.visible', false)
    setProperty('timeTxt.visible', false)

    setProperty('iconP2.alpha', 0)
    setProperty('iconP1.alpha', 0)
    setProperty('boyfriend.alpha', 0)
    setProperty('dad.alpha', 0)
    setProperty('healthBar.alpha', 0)
end

function onStepHit()
    if curStep == 32 then
        doTweenAlpha('forest05Alpha', 'forest05', 1, 0.2, 'linear')
        
        removeLuaSprite('collect', true)
    end
    
    if curStep == 56 then
        for i = 0, 3 do
            setPropertyFromGroup('playerStrums', i, 'visible', true)
            setPropertyFromGroup('playerStrums', i, 'alpha', 0)
            noteTweenAlpha('playerStrumIn'..i, i + 4, 1, 0.5, 'quadInOut')
        end
    end
    
    if curStep == 60 then
        removeLuaSprite('forest05', true)
        
        makeLuaSprite('blackSc', nil, -300, 280)
        makeGraphic('blackSc', 719, 405, '000000')
        scaleObject('blackSc', 3.8, 3.8)
        setObjectCamera('blackSc', 'game')
        addLuaSprite('blackSc', true)
    end
    
    if curStep == 64 then
        doTweenAlpha('blackAlpha', 'blackSc', 0, 0.2, 'linear')
    end
    
    if curStep == 196 then
        setProperty('boyfriend.alpha', 0)
        setProperty('forest0.5.alpha', 1)
    end

    if curStep == 351 then
        removeLuaSprite('forest0.5', true)
        
        setProperty('forest.alpha', 1)
        
        setProperty('dad.alpha', 1)
        setProperty('boyfriend.alpha', 1)
        setProperty('healthBar.alpha', 1)
        setProperty('iconP2.alpha', 1)
        setProperty('iconP1.alpha', 1)
        
        makeLuaSprite('characterFog', nil, -620, 280)
        makeGraphic('characterFog', 719, 405, '7a977a')
        scaleObject('characterFog', 3.8, 3.8)
        setProperty('characterFog.alpha', 0.2)
        setObjectCamera('characterFog', 'game')
        addLuaSprite('characterFog', true)
    end
    
    if curStep == 624 then
        setProperty('dad.alpha', 0)
        removeLuaSprite('forest', true)
        removeLuaSprite('characterFog', true)
        setProperty('tank_run.visible', true)
        
        makeLuaSprite('screeneffect', 'screeneffect', 150, -20)
        setScrollFactor('screeneffect', 1.0, 1.0)
        scaleObject('screeneffect', 0.95, 1.3)
        setObjectCamera('screeneffect', 'other')
        addLuaSprite('screeneffect', true)
    end

    if curStep == 752 then
        setProperty('tank_run.visible', false)
        setProperty('screeneffect.visible', false)
        setProperty('boyfriend.alpha', 0)
        setProperty('dad.alpha', 1)
        
        makeLuaSprite('bgdome', 's2forest/bgdome', -300, 285)
        setScrollFactor('bgdome', 1.0, 1.0)
        scaleObject('bgdome', 2.4, 2.4)
        addLuaSprite('bgdome', false)
    
        makeLuaSprite('domeoverlay', 's2forest/domeoverlay', 280, 655)
        setScrollFactor('domeoverlay', 1.0, 1.0)
        scaleObject('domeoverlay', 2.4, 2.4)
        addLuaSprite('domeoverlay', true)
        
        addLuaSprite('guardian_house', true)
        playAnim('guardian_house', 'idle', true)
        
        makeLuaSprite('domeoverlay2', 's2forest/domeoverlay2', -300, 285)
        setScrollFactor('domeoverlay2', 1.0, 1.0)
        scaleObject('domeoverlay2', 2.4, 2.4)
        addLuaSprite('domeoverlay2', true)
        setProperty('domeoverlay2.alpha', 0.9)
        
        makeLuaSprite('characterFog', nil, -300, 280)
        makeGraphic('characterFog', 719, 405, '7a977a')
        scaleObject('characterFog', 3.8, 3.8)
        setProperty('characterFog.alpha', 0.2)
        setObjectCamera('characterFog', 'game')
        addLuaSprite('characterFog', true)
    end
    
    if curStep == 880 then
        removeLuaSprite('bgdome', true)
        removeLuaSprite('domeoverlay', true)
        removeLuaSprite('domeoverlay2', true)
        removeLuaSprite('guardian_house', true)
        
        makeLuaSprite('bg3', 's2forest/bg3', -280, 285)
        setScrollFactor('bg3', 1.0, 1.0)
        scaleObject('bg3', 2.45, 2.5)
        addLuaSprite('bg3', false)
        setProperty('bg3.alpha', 0.1)
        
        setProperty('boyfriend.alpha', 0)
        setProperty('characterFog.alpha', 0)
    end
    
    if curStep == 912 then
        setProperty('boyfriend.alpha', 1)
        setProperty('dad.alpha', 0)
    end
    
    if curStep == 944 then
        setProperty('boyfriend.alpha', 0)
        setProperty('dad.alpha', 1)
    end

    if curStep == 976 then
        setProperty('boyfriend.alpha', 1)
        setProperty('dad.alpha', 0)
    end
    
    if curStep == 1008 then
        removeLuaSprite('bg3', true)
        setProperty('iconP2.alpha', 0)
        setProperty('iconP1.alpha', 0)
        setProperty('healthBar.alpha', 0)
        setProperty('boyfriend.alpha', 0)
        
        makeLuaSprite('mem1', 's2forest/memory1', -700, 280)
        setScrollFactor('mem1', 1.0, 1.0)
        scaleObject('mem1', 3.8, 3.8)
        addLuaSprite('mem1', true)
        setProperty('mem1.alpha', 0)
        
        doTweenAlpha('mem1FadeIn', 'mem1', 0.5, 0.2, 'linear')
        doTweenX('mem1Move', 'mem1', -550, 10, 'linear')
    end
    
    if curStep == 1024 then
        doTweenAlpha('mem1FadeOut', 'mem1', 0, 0.2, 'linear')
        
        makeLuaSprite('mem2', 's2forest/memory2', -550, 280)
        setScrollFactor('mem2', 1.0, 1.0)
        scaleObject('mem2', 3.8, 3.8)
        addLuaSprite('mem2', true)
        setProperty('mem2.alpha', 0)
        
        doTweenAlpha('mem2FadeIn', 'mem2', 0.5, 0.2, 'linear')
        doTweenX('mem2Move', 'mem2', -700, 10, 'linear')
    end
    
    if curStep == 1040 then
        doTweenAlpha('mem2FadeOut', 'mem2', 0, 0.2, 'linear')

        makeLuaSprite('mem3', 's2forest/memory3', -700, 280)
        setScrollFactor('mem3', 1.0, 1.0)
        scaleObject('mem3', 3.8, 3.8)
        addLuaSprite('mem3', true)
        setProperty('mem3.alpha', 0)
        
        doTweenAlpha('mem3FadeIn', 'mem3', 0.5, 0.2, 'linear')        
        doTweenX('mem3move', 'mem3', -550, 10, 'linear')
    end
    
    if curStep == 1056 then
        doTweenAlpha('mem3FadeOut', 'mem3', 0, 0.2, 'linear')
        
        makeLuaSprite('mem4', 's2forest/memory4', -550, 280)
        setScrollFactor('mem4', 1.0, 1.0)
        scaleObject('mem4', 3.8, 3.8)
        addLuaSprite('mem4', true)
        setProperty('mem4.alpha', 0)
        
        doTweenAlpha('mem4FadeIn', 'mem4', 0.5, 0.2, 'linear')
        doTweenX('mem4Move', 'mem4', -700, 10, 'linear')
    end
    
    if curStep == 1072 then
        doTweenAlpha('mem4FadeOut', 'mem4', 0, 0.2, 'linear')
        
        makeLuaSprite('mem5', 's2forest/memory5', -550, 280)
        setScrollFactor('mem5', 1.0, 1.0)
        scaleObject('mem5', 3.8, 3.8)
        addLuaSprite('mem5', true)
    end
    
    if curStep == 1080 then
        removeLuaSprite('mem1', true)
        removeLuaSprite('mem2', true)
        removeLuaSprite('mem3', true)
        removeLuaSprite('mem4', true)
        removeLuaSprite('mem5', true)
        
        makeLuaSprite('mem6', 's2forest/memory6', -550, 280)
        setScrollFactor('mem6', 1.0, 1.0)
        scaleObject('mem6', 3.8, 3.8)
        addLuaSprite('mem6', true)
    end
    
    if curStep == 1088 then
        removeLuaSprite('mem6', true)
        
        makeLuaSprite('mem7', 's2forest/memory7', -550, 280)
        setScrollFactor('mem7', 1.0, 1.0)
        scaleObject('mem7', 3.8, 3.8)
        addLuaSprite('mem7', true)
    end
    
    if curStep == 1096 then
        removeLuaSprite('mem7', true)
        
        makeLuaSprite('mem8', 's2forest/memory8', -550, 280)
        setScrollFactor('mem8', 1.0, 1.0)
        scaleObject('mem8', 3.8, 3.8)
        addLuaSprite('mem8', true)
    end
    
    if curStep == 1100 then
        removeLuaSprite('mem8', true)
        
        makeLuaSprite('mem9', 's2forest/memory9', -550, 280)
        setScrollFactor('mem9', 1.0, 1.0)
        scaleObject('mem9', 3.8, 3.8)
        addLuaSprite('mem9', true)
    end
    
    if curStep == 1104 then
        removeLuaSprite('mem9', true)
        
        makeLuaSprite('mem10', 's2forest/memory10', -550, 280)
        setScrollFactor('mem10', 1.0, 1.0)
        scaleObject('mem10', 3.8, 3.8)
        addLuaSprite('mem10', true)
    end
    
    if curStep == 1112 then
        removeLuaSprite('mem10', true)
        
        makeLuaSprite('mem11', 's2forest/memory11', -550, 280)
        setScrollFactor('mem11', 1.0, 1.0)
        scaleObject('mem11', 3.8, 3.8)
        addLuaSprite('mem11', true)
    end
    
    if curStep == 1120 then
        removeLuaSprite('mem11', true)
        
        makeLuaSprite('mem12', 's2forest/memory12', -550, 280)
        setScrollFactor('mem12', 1.0, 1.0)
        scaleObject('mem12', 3.8, 3.8)
        addLuaSprite('mem12', true)
    end
    
    if curStep == 1124 then
        removeLuaSprite('mem12', true)
        
        makeLuaSprite('mem13', 's2forest/memory13', -550, 280)
        setScrollFactor('mem13', 1.0, 1.0)
        scaleObject('mem13', 3.8, 3.8)
        addLuaSprite('mem13', true)
    end
    
    if curStep == 1128 then
        removeLuaSprite('mem13', true)
        
        makeAnimatedLuaSprite('tankscream', 'characters/morningpatrol/tankscream', -600, 280)
        addAnimationByPrefix('tankscream', 'idle', 'idle', 24, true)
        addAnimationByPrefix('tankscream', 'scream', 'scream', 30, false)
        scaleObject('tankscream', 3.8, 3.8)
        addLuaSprite('tankscream', false)
        playAnim('tankscream', 'scream', true)
        setProperty('tankscream.antialiasing', false)
    end
    
    if curStep == 1132 then
        removeLuaSprite('tankscream', true)
    end
    
    if curStep == 1136 then
        setProperty('iconP2.alpha', 1)
        setProperty('iconP1.alpha', 1)
        setProperty('healthBar.alpha', 1)
        
        setProperty('boyfriend.alpha', 1)
        
        setProperty('tank_run.visible', true)
        
        setProperty('screeneffect.visible', true)
    end
    
    if curStep == 1264 then
        setProperty('iconP2.alpha', 0)
        setProperty('iconP1.alpha', 0)
        setProperty('healthBar.alpha', 0)
        setProperty('healthbar.alpha', 0)

        setProperty('boyfriend.alpha', 0)
        setProperty('tank_run.visible', false)
        removeLuaSprite('screeneffect', true)
        
        for i = 0, 3 do
            setPropertyFromGroup('playerStrums', i, 'visible', false)
        end
    end
end

function goodNoteHit(id, direction, noteType, isSustainNote)
    if getProperty('guardian_house.visible') then
        if direction == 0 then
            playAnim('guardian_house', 'left', true)
        elseif direction == 1 then
            playAnim('guardian_house', 'down', true)
        elseif direction == 2 then
            playAnim('guardian_house', 'up', true)
        elseif direction == 3 then
            playAnim('guardian_house', 'right', true)
        end
    end
end

function onBeatHit()
    if getProperty('tank_run.visible') then
        if getProperty('tank_run.animation.curAnim.finished') then
            playAnim('tank_run', 'idle', true)
        end
    end
    
    if getProperty('guardian_house.visible') then
        if getProperty('guardian_house.animation.curAnim.finished') then
            playAnim('guardian_house', 'idle', true)
        end
    end
end

function onUpdate(elapsed)
    if getProperty('tank_run.visible') then
        local hp = getProperty('health')
        local minScale = 1.5
        local maxScaleValue = 5

        local healthPercent = hp / 2

        local targetScale = maxScaleValue - ((maxScaleValue - minScale) * healthPercent)
        tankRunScale = tankRunScale + (targetScale - tankRunScale) * (elapsed * 5)

        local centerX = getProperty('tank_run.x') + (getProperty('tank_run.width') / 2)
        local centerY = getProperty('tank_run.y') + (getProperty('tank_run.height') / 2)

        scaleObject('tank_run', tankRunStartScale * tankRunScale, tankRunStartScale * tankRunScale)
        setProperty('tank_run.x', centerX - (getProperty('tank_run.width') / 2))
        setProperty('tank_run.y', centerY - (getProperty('tank_run.height') / 2))
    end
end