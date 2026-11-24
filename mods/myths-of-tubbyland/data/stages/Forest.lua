local growTime = 60
local maxScale = 6
local startTime = 10

local growing = false
local appeared = false

local tinkyScale = 1
local tinkyScale2 = 1

local tinkyX = 800
local tinkyY = 1100
local tinkyStartScale = 1.2

local custardGrowTime = 18
local custardMaxScale = 2.3

local custardGrowing = false
local custardFalling = false

local custardScale = 0.3

local custardX = 990
local custardY = 1200

function onCreate()
    makeLuaSprite('newforest', 'dayforest/forest1.1', -300, 280)
    setScrollFactor('newforest', 1.0, 1.0)
    scaleObject('newforest', 3.8, 3.8)
    addLuaSprite('newforest', false)
    
    makeAnimatedLuaSprite('TinkyBack', 'characters/TinkyB', -300, 280)
    addAnimationByPrefix('TinkyBack', 'idle', 'idle', 24, false)
    addAnimationByPrefix('TinkyBack', 'left', 'left', 24, false)
    addAnimationByPrefix('TinkyBack', 'down', 'down', 24, false)
    addAnimationByPrefix('TinkyBack', 'up', 'up', 24, false)
    addAnimationByPrefix('TinkyBack', 'right', 'right', 24, false)
    setProperty('TinkyBack.antialiasing', false)

    scaleObject('TinkyBack', 3.8, 3.8)
    addLuaSprite('TinkyBack', true)
    setProperty('TinkyBack.visible', false)
    playAnim('TinkyBack', 'idle', true)

    makeAnimatedLuaSprite('tinkychase', 'characters/tinkyrun', tinkyX, tinkyY)
    addAnimationByPrefix('tinkychase', 'idle', 'idle', 24, false)
    addAnimationByPrefix('tinkychase', 'left', 'left', 24, false)
    addAnimationByPrefix('tinkychase', 'down', 'down', 24, false)
    addAnimationByPrefix('tinkychase', 'up', 'up', 24, false)
    addAnimationByPrefix('tinkychase', 'right', 'right', 24, false)

    scaleObject('tinkychase', tinkyStartScale, tinkyStartScale)
    addLuaSprite('tinkychase', false)
    setProperty('tinkychase.visible', false)
    playAnim('tinkychase', 'idle', true)
    setProperty('tinkychase.antialiasing', false)

    makeLuaSprite('custard', 'dayforest/custard', custardX, custardY)
    setScrollFactor('custard', 1.0, 1.0)
    scaleObject('custard', custardScale, custardScale)
    setProperty('custard.visible', false)
    addLuaSprite('custard', false)
end

function onSongStart()
    makeLuaSprite('text', 'dayforest/text', 610, 10)
    setScrollFactor('text', 1.0, 1.0)
    scaleObject('text', 0.6, 0.6)
    setObjectCamera('text', 'other')
    addLuaSprite('text', true)

    makeLuaSprite('collect', 'dayforest/collect', 130, -50)
    setScrollFactor('collect', 1.0, 1.0)
    scaleObject('collect', 1.0, 1.0)
    setObjectCamera('collect', 'other')
    addLuaSprite('collect', true)
end

function onCreatePost()
    for i = 0, 7 do
        setPropertyFromGroup('opponentStrums', i, 'visible', false)
    end

    for i = 0, 3 do
        setPropertyFromGroup('playerStrums', i, 'visible', false)
    end

    setProperty('scoreTxt.visible', false)
    setProperty('timeTxt.visible', false)

    setProperty('iconP1.alpha', 0)
    setProperty('healthBar.alpha', 0)

    setProperty('iconP2.alpha', 0)
    setProperty('dad.alpha', 0)

    setProperty('boyfriend.alpha', 0)

    setProperty('boyfriend.scale.x', 1)
    setProperty('boyfriend.scale.y', 1)
end

function onStepHit()
    if curStep == 32 then
        removeLuaSprite('text', true)
        removeLuaSprite('collect', true)
    end

    if curStep == 52 then
        for i = 0, 3 do
            setPropertyFromGroup('playerStrums', i, 'visible', true)
            setPropertyFromGroup('playerStrums', i, 'alpha', 0)
            noteTweenAlpha('playerStrumIn'..i, i + 4, 1, 0.5, 'quadInOut')
        end
    end
    
    if curStep == 318 then
        growing = false

        setProperty('boyfriend.scale.x', 1)
        setProperty('boyfriend.scale.y', 1)

        removeLuaSprite('newforest', true)
        setProperty('characterFog.alpha', 0)
        
        for i = 0, 3 do
            setPropertyFromGroup('playerStrums', i, 'visible', true)
            setPropertyFromGroup('playerStrums', i, 'alpha', 0)
            noteTweenAlpha('playerStrumIn'..i, i + 4, 0, 0.5, 'quadInOut')
        end
    end

    if curStep == 336 then
        makeLuaSprite('newforest2', 'dayforest/forest2.1', -300, 280)
        setScrollFactor('newforest2', 1.0, 1.0)
        scaleObject('newforest2', 3.8, 3.8)
        addLuaSprite('newforest2', false)
             
        makeLuaSprite('newforest15', 'dayforest/forest1.5', -300, 280)
        setScrollFactor('newforest15', 1.0, 1.0)
        scaleObject('newforest15', 3.8, 3.8)
        addLuaSprite('newforest15', false)
        
        setProperty('dad.alpha', 0)
        setProperty('TinkyBack.visible', true)

        setProperty('iconP2.alpha', 1)
        setProperty('iconP1.alpha', 1)
        setProperty('healthBar.alpha', 1)
        
        makeLuaSprite('characterFog', nil, -300, 280)
        makeGraphic('characterFog', 719, 405, 'FFFFFF')
        scaleObject('characterFog', 3.8, 3.8)
        setProperty('characterFog.alpha', 0.2)
        setObjectCamera('characterFog', 'game')
        addLuaSprite('characterFog', true)
        
        setProperty('characterFog.alpha', 0.2)
        
        for i = 0, 3 do
            setPropertyFromGroup('playerStrums', i, 'visible', true)
            setPropertyFromGroup('playerStrums', i, 'alpha', 0)
            noteTweenAlpha('playerStrumIn'..i, i + 4, 1, 0.5, 'quadInOut')
        end
    end
    
    if curStep == 352 then
        setProperty('newforest15.visible', false)
        setProperty('TinkyBack.visible', false)
        setProperty('dad.alpha', 1)
    end
    
    if curStep == 368 then
        setProperty('newforest15.visible', true)
        setProperty('TinkyBack.visible', true)
        setProperty('dad.alpha', 0)
    end
    
    if curStep == 384 then
        setProperty('newforest15.visible', false)
        setProperty('TinkyBack.visible', false)
        setProperty('dad.alpha', 1)
    end
    
    if curStep == 400 then
        setProperty('newforest15.visible', true)
        setProperty('TinkyBack.visible', true)
        setProperty('dad.alpha', 0)
    end
    
    if curStep == 416 then
        setProperty('newforest15.visible', false)
        setProperty('TinkyBack.visible', false)
        setProperty('dad.alpha', 1)
    end
    
    if curStep == 432 then
        setProperty('newforest15.visible', true)
        setProperty('TinkyBack.visible', true)
        setProperty('dad.alpha', 0)
    end
    
    if curStep == 448 then
        setProperty('newforest15.visible', false)
        setProperty('TinkyBack.visible', false)
        setProperty('dad.alpha', 1)
    end
    

    if curStep == 480 then
        setProperty('newforest15.visible', false)
        setProperty('TinkyBack.visible', false)
        setProperty('dad.alpha', 1)
    end
    
    if curStep == 512 then
        setProperty('newforest15.visible', true)
        setProperty('TinkyBack.visible', true)
        setProperty('dad.alpha', 0)
    end
    
    if curStep == 544 then
        setProperty('newforest15.visible', false)
        setProperty('TinkyBack.visible', false)
        setProperty('dad.alpha', 1)
    end
    
    if curStep == 576 then
        setProperty('newforest15.visible', true)
        setProperty('TinkyBack.visible', true)
        setProperty('dad.alpha', 0)
    end
    
    if curStep == 592 then
        setProperty('newforest15.visible', false)
        setProperty('TinkyBack.visible', false)
        setProperty('dad.alpha', 1)
    end

    if curStep == 608 then
        removeLuaSprite('newforest15')
        removeLuaSprite('newforest2', true)
        setProperty('characterFog.alpha', 0)
        
        setProperty('tinkychase.visible', true)
        setProperty('dad.alpha', 0)

        makeLuaSprite('screeneffect', 'screeneffect', 150, -20)
        setScrollFactor('screeneffect', 1.0, 1.0)
        scaleObject('screeneffect', 0.95, 1.3)
        setObjectCamera('screeneffect', 'other')
        addLuaSprite('screeneffect', true)
    end

    if curStep == 736 then        
        makeLuaSprite('newforest3', 'dayforest/forest3.1', -300, 280)
        setScrollFactor('newforest3', 1.0, 1.0)
        scaleObject('newforest3', 3.8, 3.8)
        setProperty('newforest3.alpha', 0.25)
        addLuaSprite('newforest3', false)
        
        setProperty('dad.alpha', 1)
        setProperty('tinkychase.visible', false)
        removeLuaSprite('screeneffect', true)
    end

    if curStep == 864 then
        removeLuaSprite('newforest3', true)
        
        makeLuaSprite('newforest4', 'dayforest/forest4.1', -300, 280)
        setScrollFactor('newforest4', 1.0, 1.0)
        scaleObject('newforest4', 3.8, 3.8)
        setProperty('newforest4.alpha', 0.2)
        addLuaSprite('newforest4', false)
        
        setProperty('boyfriend.alpha', 0)
    end

    if curStep == 896 then
        setProperty('boyfriend.alpha', 1)
        setProperty('dad.alpha', 0)
    end

    if curStep == 928 then
        setProperty('boyfriend.alpha', 0)
        setProperty('dad.alpha', 1)
    end

    if curStep == 960 then
        setProperty('boyfriend.alpha', 1)
        setProperty('dad.alpha', 0)
    end

    if curStep == 992 then
        removeLuaSprite('newforest4', true)
        
        setProperty('iconP2.alpha', 0)
        
        makeLuaSprite('newforest5', 'dayforest/forest5.1', -300, 280)
        setScrollFactor('newforest5', 1.0, 1.0)
        scaleObject('newforest5', 3.8, 3.8)
        setProperty('newforest5.alpha', 0.30)
        addLuaSprite('newforest5', false)
        
        setProperty('custard.visible', true)
        custardGrowing = true
        
        setProperty('boyfriend.alpha', 0)
    end

    if curStep == 1120 then
        setProperty('iconP2.alpha', 1)
        removeLuaSprite('newforest5', true)

        setProperty('boyfriend.alpha', 1)
        setProperty('dad.alpha', 1)
        
        makeLuaSprite('screeneffect', 'screeneffect', 150, -20)
        setScrollFactor('screeneffect', 1.0, 1.0)
        scaleObject('screeneffect', 0.95, 1.3)
        setObjectCamera('screeneffect', 'other')
        addLuaSprite('screeneffect', true)
    end

    if curStep == 1216 then
        removeLuaSprite('screeneffect', true)
    end
end

function onUpdate(elapsed)
    local songPos = getSongPosition() / 1000

    if songPos >= startTime and not appeared then
        appeared = true
        growing = true
        doTweenAlpha('bfFadeIn', 'boyfriend', 1, 4, 'linear')
    end

    if growing and getProperty('boyfriend') ~= nil then
        local currentX = getProperty('boyfriend.scale.x')

        if currentX < maxScale then
            local step = (maxScale - 2) / growTime
            local newScale = currentX + step * elapsed

            if newScale > maxScale then
                newScale = maxScale
            end

            setProperty('boyfriend.scale.x', newScale)
            setProperty('boyfriend.scale.y', newScale)
        end
    end

    if getProperty('tinkychase.visible') then
        local hp = getProperty('health')
        local minScale = 0.8
        local maxScaleValue = 4

        local healthPercent = hp / 2

        local targetScale = maxScaleValue - ((maxScaleValue - minScale) * healthPercent)
        tinkyScale = tinkyScale + (targetScale - tinkyScale) * (elapsed * 5)

        local centerX = getProperty('tinkychase.x') + (getProperty('tinkychase.width') / 2)
        local centerY = getProperty('tinkychase.y') + (getProperty('tinkychase.height') / 2)

        scaleObject('tinkychase', tinkyStartScale * tinkyScale, tinkyStartScale * tinkyScale)
        setProperty('tinkychase.x', centerX - (getProperty('tinkychase.width') / 2))
        setProperty('tinkychase.y', centerY - (getProperty('tinkychase.height') / 2))
    end

    if custardGrowing then
        local currentScale = getProperty('custard.scale.x')

        if currentScale < custardMaxScale then
            local step = (custardMaxScale - 0.1) / custardGrowTime
            local newScale = currentScale + step * elapsed

            if newScale > custardMaxScale then
                newScale = custardMaxScale
            end

            setProperty('custard.scale.x', newScale)
            setProperty('custard.scale.y', newScale)
        else
            custardGrowing = false
            doTweenY('custardFall', 'custard', screenHeight + 2000, 1.3, 'cubeIn')
        end
    end
end

function opponentNoteHit(id, direction, noteType, isSustainNote)
    local chars = {'tinkychase', 'TinkyBack'}

    for i = 1, #chars do
        if getProperty(chars[i]..'.visible') then
            if direction == 0 then
                playAnim(chars[i], 'left', true)
            elseif direction == 1 then
                playAnim(chars[i], 'down', true)
            elseif direction == 2 then
                playAnim(chars[i], 'up', true)
            elseif direction == 3 then
                playAnim(chars[i], 'right', true)
            end
        end
    end
end

function onBeatHit()
    local chars = {'tinkychase', 'TinkyBack'}

    for i = 1, #chars do
        if getProperty(chars[i]..'.visible') then
            if getProperty(chars[i]..'.animation.curAnim.finished') then
                playAnim(chars[i], 'idle', true)
            end
        end
    end
end

function onTweenCompleted(tag)
    if tag == 'custardFall' then
        removeLuaSprite('custard', true)
    end
end