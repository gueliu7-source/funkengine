function onCreate()
    makeVideoSprite('intromp', 'intromp', -70, -180, 'camHUD', false)
    scaleObject('intromp', 0.7, 0.7)
    setProperty('intromp.antialiasing', false)
    
    makeVideoSprite('walkmp', 'walkmp', 275, 155, 'camHUD', false)
    scaleObject('walkmp', 1.8, 1.8)
    setProperty('walkmp.antialiasing', false)
    
    makeVideoSprite('tankf', 'tankf', 250, 160, 'camHUD', false)
    scaleObject('tankf', 1.8, 1.8)
    setProperty('tankf.antialiasing', false)
    
    makeVideoSprite('endingmp', 'endingmp', 275, 160, 'camHUD', false)
    scaleObject('endingmp', 1.8, 1.8)
    setProperty('endingmp.antialiasing', false)
end

function onSongStart()
    playVideoSprite('intromp')
    setObjectOrder('intromp', 0)
end

function onStepHit()
    if curStep == 64 then
        playVideoSprite('walkmp')
        setObjectOrder('walkmp', 0)
    end
    
    if curStep == 188 then
        makeLuaSprite('blackScr', nil, -300, 0)
        makeGraphic('blackScr', 719, 405, '000000')
        scaleObject('blackScr', 3.8, 3.8)
        setObjectCamera('blackScr', 'other')
        addLuaSprite('blackScr', true)
        
        setProperty('blackScr.alpha', 0.5)
    end
    
    if curStep == 190 then
        setProperty('blackScr.alpha', 1)
    end
    
    if curStep == 193 then
        doTweenAlpha('blackScrAlpha', 'blackScr', 0, 0.9, 'linear')
    end
    
    if curStep == 328 then
        setProperty('blackScr.alpha', 0.5)
    end
    
    if curStep == 330 then
        setProperty('blackScr.alpha', 1)
    end
    
    if curStep == 335 then
        setProperty('walkmp.x', -3000)
        setProperty('blackScr.alpha', 0)
    end
    
    if curStep == 480 then
        playVideoSprite('tankf')
        setObjectOrder('tankf', 0)
    end
    
    if curStep == 1264 then
        playVideoSprite('endingmp')
        setObjectOrder('endingmp', 0)
    end
end