function onCreate()
    makeVideoSprite('intro1', 'intro1', -70, -180, 'camHUD', false)
    scaleObject('intro1', 0.7, 0.7)
    setProperty('intro1.antialiasing', false)
    
    makeVideoSprite('afight', 'afight', 200, 115, 'camHUD', false)
    scaleObject('afight', 2, 2)
    setProperty('afight.antialiasing', false)
    
    makeVideoSprite('gdwalk', 'gdwalk', 280, 160, 'camHUD', false)
    scaleObject('gdwalk', 1.8, 1.8)
    setProperty('gdwalk.antialiasing', false)
    
    makeVideoSprite('gdwalk2', 'gdwalk2', 160, 0, 'camHUD', false)
    setProperty('gdwalk2.antialiasing', false)
    
    makeVideoSprite('gfd', 'gfd', 280, 160, 'camHUD', false)
    scaleObject('gfd', 1.8, 1.8)
    setProperty('gfd.antialiasing', false)
    
    makeVideoSprite('guardianready', 'guardianready', 280, 160, 'camHUD', false)
    scaleObject('guardianready', 1.8, 1.8)
    setProperty('guardianready.antialiasing', false)
    
    makeVideoSprite('fightdrop', 'fightdrop', -70, -180, 'camHUD', false)
    scaleObject('fightdrop', 0.7, 0.7)
    setProperty('fightdrop.antialiasing', false)
    
    makeVideoSprite('walk1', 'walk1', 200, 115, 'camHUD', false)
    scaleObject('walk1', 2, 2)
    setProperty('walk1.antialiasing', false)
    
    makeVideoSprite('walk2', 'walk2', 200, 115, 'camHUD', false)
    scaleObject('walk2', 2, 2)
    setProperty('walk2.antialiasing', false)
    
    makeVideoSprite('walk3', 'walk3', 200, 115, 'camHUD', false)
    scaleObject('walk3', 2, 2)
    setProperty('walk3.antialiasing', false)
    
    makeVideoSprite('guardianattack', 'guardianattack', 200, 115, 'camHUD', false)
    scaleObject('guardianattack', 2, 2)
    setProperty('guardianattack.antialiasing', false)
    
    makeVideoSprite('dipsylol', 'dipsylol', 100, -180, 'camHUD', false)
    scaleObject('dipsylol', 1.3, 1.3)
    setProperty('dipsylol.antialiasing', false)
end

function onSongStart()
    playVideoSprite('intro1')
    setObjectOrder('intro1', 0)
end

function onStepHit()
    if curStep == 1056 then
        playVideoSprite('afight')
        setObjectOrder('afight', 0)
    end

    if curStep == 1120 then
        playVideoSprite('gdwalk')
        setObjectOrder('gdwalk', 0)
    end
    
    if curStep == 1184 then
        removeLuaSprite('gdwalk', true)
        
        playVideoSprite('gdwalk2')
        setObjectOrder('gdwalk2', 0)
    end
    
    if curStep == 1248 then
        removeLuaSprite('gdwalk2', true)
        
        playVideoSprite('gfd')
        setObjectOrder('gfd', 0)
    end
    
    if curStep == 1264 then
        removeLuaSprite('gfd', true)
            
        playVideoSprite('guardianready')
        setObjectOrder('guardianready', 0)
    end
    
    if curStep == 1696 then
        playVideoSprite('fightdrop')
        setObjectOrder('fightdrop', 0)
    end
    
    if curStep == 1856 then
        playVideoSprite('walk1')
        setObjectOrder('walk1', 0)
    end
    
    
    if curStep == 1920 then
        playVideoSprite('walk2')
        setObjectOrder('walk2', 0)
    end
    
    if curStep == 1984 then
        playVideoSprite('walk3')
        setObjectOrder('walk3', 0)
    end
    
    if curStep == 2048 then
        playVideoSprite('guardianattack')
        setObjectOrder('guardianattack', 0)
    end
    
    if curStep == 2112 then
        playVideoSprite('dipsylol')
        setObjectOrder('dipsylol', 0)
    end
end