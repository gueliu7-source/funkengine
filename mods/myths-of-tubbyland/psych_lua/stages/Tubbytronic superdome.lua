function onCreate()
    precacheImage('lionsmouth/DipsyJumpA')
    precacheImage('characters/thelionsmouth/fight1')
    precacheImage('characters/thelionsmouth/fight2')
    
    for i = 1, 8 do
        precacheImage('lionsmouth/f'..i)
    end
    
    makeLuaSprite('bg', 'dome/bg', -300, 280)
    setScrollFactor('bg', 1.0, 1.0)
    scaleObject('bg', 3.8, 3.8)
    addLuaSprite('bg', false)
    setProperty('bg.alpha', 0)
            
    makeAnimatedLuaSprite('guardian', 'lionsmouth/GuardianBlack', 150, -50)
    setScrollFactor('guardian', 1.0, 1.0)
    scaleObject('guardian', 3.4, 3.4)
    
    addAnimationByPrefix('guardian', 'idle', 'idle', 24, false)
    addAnimationByPrefix('guardian', 'left', 'left', 24, false)
    addAnimationByPrefix('guardian', 'down', 'down', 24, false)
    addAnimationByPrefix('guardian', 'up', 'up', 24, false)
    addAnimationByPrefix('guardian', 'right', 'right', 24, false)
    
    addLuaSprite('guardian', true)
    
    setProperty('guardian.visible', false)
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
    setProperty('iconP1.alpha', 0)
    setProperty('iconP2.alpha', 0)
    setProperty('healthBar.alpha', 0)
    setProperty('dad.alpha', 0)
    setProperty('boyfriend.alpha', 0)
    setProperty('showRating', false)
    setProperty('showCombo', false)
    setProperty('showComboNum', false)
end

function onStepHit()
    if curStep == 245 then
        for i = 0, 3 do
            setPropertyFromGroup('playerStrums', i, 'visible', true)
            setPropertyFromGroup('playerStrums', i, 'alpha', 0)
            noteTweenAlpha('playerStrumIn'..i, i + 4, 1, 0.5, 'quadInOut')
        end
    end
    
    if curStep == 546 then
        setProperty('dad.alpha', 1)
        setProperty('boyfriend.alpha', 1)
        setProperty('bg.alpha', 1)
        setProperty('iconP1.alpha', 1)
        setProperty('iconP2.alpha', 1)
        setProperty('healthBar.alpha', 1)
    end
    
    if curStep == 799 then
        for i = 0, 3 do
            setPropertyFromGroup('playerStrums', i, 'visible', true)
            setPropertyFromGroup('playerStrums', i, 'alpha', 0)
            noteTweenAlpha('playerStrumIn'..i, i + 4, 0, 0.5, 'quadInOut')
        end
    end
    
    if curStep == 800 then
        setProperty('iconP2.alpha', 0)
        setProperty('iconP1.alpha', 0)
        setProperty('healthBar.alpha', 0)
        setProperty('boyfriend.alpha', 0)
        setProperty('dad.alpha', 0)
        removeLuaSprite('bg', true)
        
        makeAnimatedLuaSprite('fight1', 'characters/thelionsmouth/fight1', -10, 200)
        setScrollFactor('fight1', 1.0, 1.0)
        scaleObject('fight1', 2.7, 2.7)
    
        addAnimationByPrefix('fight1', 'idle', 'idle', 24, false)
        addAnimationByPrefix('fight1', 'fight1', 'fight1', 18, false)
    
        addLuaSprite('fight1', true)
        playAnim('fight1', 'fight1', true)
    end
    
    if curStep == 832 then
        setProperty('fight1.alpha', 0)
        
        makeAnimatedLuaSprite('fight2', 'characters/thelionsmouth/fight2', -10, 200)
        setScrollFactor('fight2', 1.0, 1.0)
        scaleObject('fight2', 2.7, 2.7)
    
        addAnimationByPrefix('fight2', 'idle', 'idle', 24, false)
        addAnimationByPrefix('fight2', 'fight2', 'fight2', 18, false)
    
        addLuaSprite('fight2', true)
        playAnim('fight2', 'fight2', true)
    end
    
    if curStep == 864 then
        setProperty('fight2.alpha', 0)
        setProperty('fight1.alpha', 1)
        playAnim('fight1', 'fight1', true)
    end
    
    if curStep == 896 then
        setProperty('fight1.alpha', 0)
        setProperty('fight2.alpha', 1)
        playAnim('fight2', 'fight2', true)
            
        for i = 0, 3 do
            setPropertyFromGroup('playerStrums', i, 'visible', true)
            setPropertyFromGroup('playerStrums', i, 'alpha', 0)
            noteTweenAlpha('playerStrumIn'..i, i + 4, 1, 0.5, 'quadInOut')
        end
    end
    
    if curStep == 928 then
        setProperty('fight2.alpha', 0)
        setProperty('fight1.alpha', 1)
        playAnim('fight1', 'fight1', true)
        
        for i = 0, 3 do
            setPropertyFromGroup('playerStrums', i, 'visible', true)
            setPropertyFromGroup('playerStrums', i, 'alpha', 0)
            noteTweenAlpha('playerStrumIn'..i, i + 4, 0, 0.5, 'quadInOut')
        end
    end
    
    if curStep == 960 then
        setProperty('fight1.alpha', 0)
        setProperty('fight2.alpha', 1)
        playAnim('fight2', 'fight2', true)
    end
    
    if curStep == 992 then
        setProperty('fight2.alpha', 0)
        setProperty('fight1.alpha', 1)
        playAnim('fight1', 'fight1', true)
    end
    
    if curStep == 1024 then
        setProperty('fight1.alpha', 0)
        setProperty('fight2.alpha', 1)
        playAnim('fight2', 'fight2', true)
    end
    
    if curStep == 1040 then
        setHealth(2.0)
    end
        
    if curStep == 1056 then
        setProperty('fight2.alpha', 0)
    end
    
    if curStep == 1080 then
        for i = 0, 3 do
            setPropertyFromGroup('playerStrums', i, 'visible', true)
            setPropertyFromGroup('playerStrums', i, 'alpha', 0)
            noteTweenAlpha('playerStrumIn'..i, i + 4, 1, 0.5, 'quadInOut')
        end
    end
    
    if curStep == 1312 then
        makeLuaSprite('bg2', 'dome/bg2', -300, 280)
        setScrollFactor('bg2', 1.0, 1.0)
        scaleObject('bg2', 3.8, 3.8)
        addLuaSprite('bg2', false)
        
        setProperty('boyfriend.alpha', 1)
        setProperty('dad.alpha', 1)
        
        doTweenAlpha('iconP2FadeIn', 'iconP2', 1, 0.2, 'linear')
        doTweenAlpha('healthBarFadeIn', 'healthBar', 1, 0.2, 'linear')
        doTweenAlpha('iconP1FadeIn', 'iconP1', 1, 0.2, 'linear')
    end
    
    if curStep == 1440 then
        removeLuaSprite('bg2', true)
        
        setProperty('boyfriend.alpha', 0)
        setProperty('dad.alpha', 0)
        
        setProperty('iconP1.alpha', 0)
        setProperty('iconP2.alpha', 0)
        setProperty('healthBar.alpha', 0)
        
        makeLuaSprite('bgred', '', -300, 280)
        makeGraphic('bgred', 1000, 1000, 'FF0000')
        setScrollFactor('bgred', 1.0, 1.0)
        scaleObject('bgred', 3.8, 3.8)
        addLuaSprite('bgred', false)
        
        makeLuaSprite('i1', 'lionsmouth/i1', 0, 20)
        setScrollFactor('i1', 1.0, 1.0)
        scaleObject('i1', 3, 3)
        addLuaSprite('i1', false)
        
        setProperty('guardian.visible', true)
    
        doTweenX('guardianMove', 'guardian', 430, 10, 'linear')
        
        setProperty('boyfriend.alpha', 0)
        setProperty('dad.alpha', 0)
    end
    
    if curStep == 1448 then
        removeLuaSprite('i1', true)
        
        makeLuaSprite('i2', 'lionsmouth/i2', 0, 20)
        setScrollFactor('i2', 1.0, 1.0)
        scaleObject('i2', 3, 3)
        addLuaSprite('i2', false)
    end
    
    if curStep == 1456 then
        removeLuaSprite('i2', true)
        
        makeLuaSprite('i3', 'lionsmouth/i3', 0, 20)
        setScrollFactor('i3', 1.0, 1.0)
        scaleObject('i3', 3, 3)
        addLuaSprite('i3', false)
    end
    
    if curStep == 1464 then
        removeLuaSprite('i3', true)
        
        makeLuaSprite('i4', 'lionsmouth/i4', 0, 20)
        setScrollFactor('i4', 1.0, 1.0)
        scaleObject('i4', 3, 3)
        addLuaSprite('i4', false)
    end
    
    if curStep == 1472 then
        removeLuaSprite('i4', true)
        
        makeLuaSprite('i5', 'lionsmouth/i5', 0, 20)
        setScrollFactor('i5', 1.0, 1.0)
        scaleObject('i5', 3, 3)
        addLuaSprite('i5', false)
    end
    
    if curStep == 1480 then
        removeLuaSprite('i5', true)
        
        makeLuaSprite('i6', 'lionsmouth/i6', 0, 20)
        setScrollFactor('i6', 1.0, 1.0)
        scaleObject('i6', 3, 3)
        addLuaSprite('i6', false)
    end
    
    if curStep == 1488 then
        removeLuaSprite('i6', true)
        
        makeLuaSprite('i7', 'lionsmouth/i7', 0, 20)
        setScrollFactor('i7', 1.0, 1.0)
        scaleObject('i7', 3, 3)
        addLuaSprite('i7', false)
    end
    
    if curStep == 1496 then
        removeLuaSprite('i7', true)
        
        makeLuaSprite('i8', 'lionsmouth/i8', 0, 20)
        setScrollFactor('i8', 1.0, 1.0)
        scaleObject('i8', 3, 3)
        addLuaSprite('i8', false)
    end
    
    if curStep == 1504 then
        removeLuaSprite('i8', true)
        
        makeLuaSprite('i9', 'lionsmouth/i9', 0, 20)
        setScrollFactor('i9', 1.0, 1.0)
        scaleObject('i9', 3, 3)
        addLuaSprite('i9', false)
    end
    
    if curStep == 1512 then
        removeLuaSprite('i9', true)
        
        makeLuaSprite('i10', 'lionsmouth/i10', 0, 20)
        setScrollFactor('i10', 1.0, 1.0)
        scaleObject('i10', 3, 3)
        addLuaSprite('i10', false)
    end
    
    if curStep == 1520 then
        removeLuaSprite('i10', true)
        
        makeLuaSprite('i11', 'lionsmouth/i11', 0, 20)
        setScrollFactor('i11', 1.0, 1.0)
        scaleObject('i11', 3, 3)
        addLuaSprite('i11', false)
    end
    
    if curStep == 1528 then
        removeLuaSprite('i11', true)
        
        makeLuaSprite('i12', 'lionsmouth/i12', 0, 20)
        setScrollFactor('i12', 1.0, 1.0)
        scaleObject('i12', 3, 3)
        addLuaSprite('i12', false)
    end
    
    if curStep == 1536 then
        removeLuaSprite('i12', true)
        
        makeLuaSprite('i13', 'lionsmouth/i13', 0, 20)
        setScrollFactor('i13', 1.0, 1.0)
        scaleObject('i13', 3, 3)
        addLuaSprite('i13', false)
    end
    
    if curStep == 1544 then
        removeLuaSprite('i13', true)
        
        makeLuaSprite('i14', 'lionsmouth/i14', 0, 20)
        setScrollFactor('i14', 1.0, 1.0)
        scaleObject('i14', 3, 3)
        addLuaSprite('i14', false)
    end
    
    if curStep == 1552 then
        doTweenAlpha('i14Alpha', 'i14', 0, 0.3, 'linear')
        doTweenAlpha('bgredAlpha', 'bgred', 0, 0.3, 'linear')

        doTweenX('guardianX', 'guardian', -350, 1, 'expoOut')
        doTweenY('guardianY', 'guardian', 900, 1, 'expoOut')

        doTweenX('guardianScaleX', 'guardian.scale', 1.8, 1, 'expoOut')
        doTweenY('guardianScaleY', 'guardian.scale', 1.8, 1, 'expoOut')

        makeAnimatedLuaSprite('Dipsy_Jump', 'lionsmouth/Dipsy_Jump', -350, 300)
        setScrollFactor('Dipsy_Jump', 1.0, 1.0)
        scaleObject('Dipsy_Jump', 3.8, 3.8)
        addAnimationByPrefix('Dipsy_Jump', 'salto', 'ElSaltoDelPapu', 24, false)
        addLuaSprite('Dipsy_Jump', false)
        setObjectCamera('Dipsy_Jump', 'game')
        setAntialiasing('Dipsy_Jump', false)
        objectPlayAnimation('Dipsy_Jump', 'salto', true)
    end
    
    if curStep == 1562 then
        doTweenY('guardianFall', 'guardian', 2000, 0.5, 'cubeIn')
    end
    
    
    if curStep == 1567 then
        removeLuaSprite('i14', true)
        removeLuaSprite('bgred', true)
        removeLuaSprite('guardian', true)
        
        for i = 0, 3 do
            setPropertyFromGroup('playerStrums', i, 'visible', true)
            setPropertyFromGroup('playerStrums', i, 'alpha', 0)
            noteTweenAlpha('playerStrumIn'..i, i + 4, 0, 0.5, 'quadInOut')
        end
    end
    
    if curStep == 1568 then
        for i = 1, 8 do
            makeLuaSprite('f'..i, 'lionsmouth/f'..i, -300, 280)
            setScrollFactor('f'..i, 1.0, 1.0)
            scaleObject('f'..i, 3.8, 3.8)
            setProperty('f'..i..'.alpha', 0)
            addLuaSprite('f'..i, false)
        end
        
        setProperty('f1.alpha', 1)
        doTweenAlpha('f1Fade', 'f1', 0, 0.2, 'linear')
        
        removeLuaSprite('Dipsy_Jump', true)
        removeLuaSprite('guardian')
    end
    
    if curStep == 1572 then
        setProperty('f2.alpha', 1)
        doTweenAlpha('f2Fade', 'f2', 0, 0.2, 'linear')
    end
    
    if curStep == 1576 then
        setProperty('f3.alpha', 1)
        doTweenAlpha('f3Fade', 'f3', 0, 0.2, 'linear')
    end
    
    if curStep == 1580 then
        setProperty('f4.alpha', 1)
        doTweenAlpha('f4Fade', 'f4', 0, 0.2, 'linear')
    end
    
    if curStep == 1584 then
        setProperty('f5.alpha', 1)
        doTweenAlpha('f5Fade', 'f5', 0, 0.2, 'linear')
    end

    if curStep == 1588 then
        setProperty('f6.alpha', 1)
        doTweenAlpha('f6Fade', 'f6', 0, 0.2, 'linear')
    end
    
    if curStep == 1592 then
        setProperty('f7.alpha', 1)
        doTweenAlpha('f7Fade', 'f7', 0, 0.2, 'linear')
    end
    
    if curStep == 1596 then
        setProperty('f8.alpha', 1)
        doTweenAlpha('f8Fade', 'f8', 0, 0.2, 'linear')
    end
    
    if curStep == 1600 then
        setProperty('f1.alpha', 1)
        doTweenAlpha('f1Fade', 'f1', 0, 0.2, 'linear')
    end
    
    if curStep == 1604 then
        setProperty('f2.alpha', 1)
        doTweenAlpha('f2Fade', 'f2', 0, 0.2, 'linear')
    end
    
    if curStep == 1608 then
        setProperty('f3.alpha', 1)
        doTweenAlpha('f3Fade', 'f3', 0, 0.2, 'linear')
    end
    
    if curStep == 1612 then
        setProperty('f4.alpha', 1)
        doTweenAlpha('f4Fade', 'f4', 0, 0.2, 'linear')
    end
    
    if curStep == 1616 then
        setProperty('f5.alpha', 1)
        doTweenAlpha('f5Fade', 'f5', 0, 0.2, 'linear')
    end

    if curStep == 1620 then
        setProperty('f6.alpha', 1)
        doTweenAlpha('f6Fade', 'f6', 0, 0.2, 'linear')
    end
    
    if curStep == 1624 then
        setProperty('f7.alpha', 1)
        doTweenAlpha('f7Fade', 'f7', 0, 0.2, 'linear')
    end
    
    if curStep == 1628 then
        setProperty('f8.alpha', 1)
        doTweenAlpha('f8Fade', 'f8', 0, 0.2, 'linear')
    end
    
    if curStep == 1632 then
        setProperty('f1.alpha', 1)
        doTweenAlpha('f1Fade', 'f1', 0, 0.2, 'linear')
    end
    
    if curStep == 1636 then
        setProperty('f2.alpha', 1)
        doTweenAlpha('f2Fade', 'f2', 0, 0.2, 'linear')
    end
    
    if curStep == 1640 then
        setProperty('f3.alpha', 1)
        doTweenAlpha('f3Fade', 'f3', 0, 0.2, 'linear')
    end
    
    if curStep == 1644 then
        setProperty('f4.alpha', 1)
        doTweenAlpha('f4Fade', 'f4', 0, 0.2, 'linear')
    end
    
    if curStep == 1648 then
        setProperty('f5.alpha', 1)
        doTweenAlpha('f5Fade', 'f5', 0, 0.2, 'linear')
    end

    if curStep == 1652 then
        setProperty('f6.alpha', 1)
        doTweenAlpha('f6Fade', 'f6', 0, 0.2, 'linear')
    end
    
    if curStep == 1656 then
        setProperty('f7.alpha', 1)
        doTweenAlpha('f7Fade', 'f7', 0, 0.2, 'linear')
    end
    
    if curStep == 1660 then
        setProperty('f8.alpha', 1)
        doTweenAlpha('f8Fade', 'f8', 0, 0.2, 'linear')
    end
    
    if curStep == 1664 then
        setProperty('f1.alpha', 1)
        doTweenAlpha('f1Fade', 'f1', 0, 0.2, 'linear')
    end
    
    if curStep == 1668 then
        setProperty('f2.alpha', 1)
        doTweenAlpha('f2Fade', 'f2', 0, 0.2, 'linear')
    end
    
    if curStep == 1672 then
        setProperty('f3.alpha', 1)
        doTweenAlpha('f3Fade', 'f3', 0, 0.2, 'linear')
    end
    
    if curStep == 1676 then
        setProperty('f4.alpha', 1)
        doTweenAlpha('f4Fade', 'f4', 0, 0.2, 'linear')
    end
    
    if curStep == 1680 then
        setProperty('f5.alpha', 1)
        doTweenAlpha('f5Fade', 'f5', 0, 0.2, 'linear')
    end
    
    if curStep == 1684 then
        setProperty('f6.alpha', 1)
        doTweenAlpha('f6Fade', 'f6', 0, 0.2, 'linear')
    end
    
    if curStep == 1688 then
        for i = 1, 8 do
            removeLuaSprite('f'..i, true)
        end
    end

    if curStep == 1687 then
        makeLuaSprite('blackBox', '', -300, 280)
        makeGraphic('blackBox', 719, 405, '000000')
        scaleObject('blackBox', 3.8, 3.8)
        addLuaSprite('blackBox', true)
    
        makeLuaSprite('0000', 'lionsmouth/0000', -300, 280)
        setScrollFactor('0000', 1.0, 1.0)
        scaleObject('0000', 3.8, 3.8)
        addLuaSprite('0000', true)
    end
    
    if curStep == 1689 then
        removeLuaSprite('0000', true)
    
        makeLuaSprite('0001', 'lionsmouth/0001', -300, 280)
        setScrollFactor('0001', 1.0, 1.0)
        scaleObject('0001', 3.8, 3.8)
        addLuaSprite('0001', true)
    end
    
    if curStep == 1690 then
        removeLuaSprite('0001', true)
    
        makeLuaSprite('0002', 'lionsmouth/0002', -300, 280)
        setScrollFactor('0002', 1.0, 1.0)
        scaleObject('0002', 3.8, 3.8)
        addLuaSprite('0002', true)
    end
    
    if curStep == 1691 then
        removeLuaSprite('0002', true)
    
        makeAnimatedLuaSprite('DipsyJumpA', 'lionsmouth/DipsyJumpA', -300, 280)
        setScrollFactor('DipsyJumpA', 1.0, 1.0)
        scaleObject('DipsyJumpA', 3.8, 3.8)

        addAnimationByPrefix('DipsyJumpA', 'idle', 'idle', 24, true)
        addAnimationByPrefix('DipsyJumpA', 'jump', 'jump', 24, false)

        addLuaSprite('DipsyJumpA', true)

        objectPlayAnimation('DipsyJumpA', 'jump', true)
    end
    
    if curStep == 1696 then
        removeLuaSprite('blackBox', true)
        removeLuaSprite('DipsyJumpA', true)
    end
    
    if curStep == 1824 then
        setProperty('boyfriend.alpha', 1)
    end
    
    if curStep == 1856 then
        setProperty('boyfriend.alpha', 0)
    end
    
    if curStep == 1876 then
        for i = 0, 3 do
            setPropertyFromGroup('playerStrums', i, 'visible', true)
            setPropertyFromGroup('playerStrums', i, 'alpha', 0)
            noteTweenAlpha('playerStrumIn'..i, i + 4, 1, 0.5, 'quadInOut')
        end
    end
    
    if curStep == 2128 then
        for i = 0, 3 do
            setPropertyFromGroup('playerStrums', i, 'visible', true)
            setPropertyFromGroup('playerStrums', i, 'alpha', 0)
            noteTweenAlpha('playerStrumIn'..i, i + 4, 0, 0.5, 'quadInOut')
        end
    end
    
    if curStep == 2208 then
        for i = 0, 3 do
            setPropertyFromGroup('playerStrums', i, 'visible', true)
            setPropertyFromGroup('playerStrums', i, 'alpha', 0)
            noteTweenAlpha('playerStrumIn'..i, i + 4, 1, 0.5, 'quadInOut')
        end
    end
    
    if curStep == 2256 then
        for i = 0, 3 do
            setPropertyFromGroup('playerStrums', i, 'visible', true)
            setPropertyFromGroup('playerStrums', i, 'alpha', 0)
            noteTweenAlpha('playerStrumIn'..i, i + 4, 0, 0.5, 'quadInOut')
        end
    end
    
    if curStep == 2299 then
        makeLuaSprite('letter', 'lionsmouth/letter3', 300, 260)
        setScrollFactor('letter', 1.0, 1.0)
        scaleObject('letter', 1.5, 1.5)
        addLuaSprite('letter', true)
        setProperty('letter.alpha', 0)
        
        doTweenAlpha('letter1Fade', 'letter', 1, 0.5, 'linear')
    end
    
    if curStep == 2334 then
        doTweenAlpha('letter1Fade2', 'letter', 0, 0.2, 'linear')
    end
    
    if curStep == 2336 then
        makeLuaSprite('letter2', 'lionsmouth/letter4', 300, 260)
        setScrollFactor('letter2', 1.0, 1.0)
        scaleObject('letter2', 1.5, 1.5)
        addLuaSprite('letter2', true)
        setProperty('letter2.alpha', 0)
        
        doTweenAlpha('letter2Fade', 'letter2', 1, 0.5, 'linear')
    end
    
    if curStep == 2376 then
        doTweenAlpha('letter2Fade2', 'letter2', 0, 1, 'linear')
    end
end


function goodNoteHit(id, direction, noteType, isSustainNote)
    if getProperty('guardian.visible') then
        if not isSustainNote then
            if direction == 0 then
                playAnim('guardian', 'left', true)
            elseif direction == 1 then
                playAnim('guardian', 'down', true)
            elseif direction == 2 then
                playAnim('guardian', 'up', true)
            elseif direction == 3 then
                playAnim('guardian', 'right', true)
            end
        end
    end
end

function onBeatHit()
    if getProperty('guardian.visible') then
        if getProperty('guardian.animation.curAnim.finished') then
            playAnim('guardian', 'idle', true)
        end
    end
end