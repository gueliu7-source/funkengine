local imagePath = 'characters/thelionsmouth/DipsyDancing'
local spriteTag = 'dipsySprite'
local spawnChance = 10
local spriteActive = false

function onCreate()
    precacheImage(imagePath)
    math.randomseed(os.time())
end

function onStepHit()
    if curStep == 1440 then
        if math.random(1, 100) <= spawnChance then
            makeAnimatedLuaSprite(spriteTag, imagePath, -280, 280)
            addAnimationByPrefix(spriteTag, 'idle', 'perreo', 24, true)
            scaleObject(spriteTag, 3.8, 3.8)
            addLuaSprite(spriteTag, true)
            
            playAnim(spriteTag, 'idle', true)
            spriteActive = true
        end
    end
    
    if curStep == 1568 then
        if spriteActive then
            removeLuaSprite(spriteTag, true)
            spriteActive = false
        end
    end
end