local custardCount = 0

local textX = 320
local textY = 600

function onCreate()
    addCharacterToList('guardianpunch', 'boyfriend')
    addCharacterToList('guardianmiss1', 'boyfriend')
    addCharacterToList('guardianmiss2', 'boyfriend')
    addCharacterToList('goodending1', 'boyfriend')
    addCharacterToList('goodending2', 'boyfriend')

    if not luaTextExists('custardText') then
        local username = os.getenv("USERNAME") or "Player"

        makeLuaText('custardText', 'Collected '..tostring(username)..' 0/10 custards', 600, textX, textY)
        setTextAlignment('custardText', 'center')
        setObjectCamera('custardText', 'other')
        setTextFont('custardText', 'LD Slender Regular.ttf')
        setTextSize('custardText', 48)
        setTextBorder('custardText', 2, '000000')
        addLuaText('custardText')
        setProperty('custardText.antialiasing', true)
    end

    setProperty('custardText.alpha', 0)
end

function onCreatePost()
    for i = 0, getProperty('unspawnNotes.length')-1 do
        if getPropertyFromGroup('unspawnNotes', i, 'noteType') == 'CustardNote' then
            setPropertyFromGroup('unspawnNotes', i, 'texture', 'custard')
            setPropertyFromGroup('unspawnNotes', i, 'isSustainNote', false)

            setPropertyFromGroup('unspawnNotes', i, 'scale.x', 0.7)
            setPropertyFromGroup('unspawnNotes', i, 'scale.y', 0.7)

            setPropertyFromGroup('unspawnNotes', i, 'noAnimation', true)
        end
    end
end

function goodNoteHit(id, direction, noteType, isSustainNote)
    if noteType == 'CustardNote' then
        setProperty('health', getProperty('health') + 0.23)
        
        custardCount = custardCount + 1

        local username = os.getenv("USERNAME") or "Player"
        setTextString('custardText', tostring(username)..' collected '..tostring(custardCount)..'/10 custards')

        setProperty('custardText.alpha', 1)

        cancelTimer('hideCustardText')
        runTimer('hideCustardText', 2)
    end
end

function onStepHit()
    if curStep == 1216 then
        setProperty('dad.visible', false)
        setProperty('boyfriend.visible', true)

        if custardCount >= 10 then
            triggerEvent('Change Character', 'boyfriend', 'guardianpunch')
            characterPlayAnim('boyfriend', 'punch', true)
            setProperty('boyfriend.specialAnim', true)
        else 
            triggerEvent('Change Character', 'boyfriend', 'guardianmiss1')
            characterPlayAnim('boyfriend', 'miss', true)
            setProperty('boyfriend.specialAnim', true)
        end
    end
    
    if curStep == 1228 then
        if custardCount < 10 then
            triggerEvent('Change Character', 'boyfriend', 'guardianmiss2')
            characterPlayAnim('boyfriend', 'miss', true)
            setProperty('boyfriend.specialAnim', true)
        end
    end

    if curStep == 1248 then
        if custardCount >= 10 then
            setProperty('iconP2.alpha', 0)
            triggerEvent('Change Character', 'boyfriend', 'goodending1')
            characterPlayAnim('boyfriend', 'ending', true)
            setProperty('boyfriend.specialAnim', true)
        else
            setProperty('dad.alpha', 0)
            setProperty('boyfriend.alpha', 0)
            setProperty('iconP1.alpha', 0)
            setProperty('health', 0.01)

            makeLuaSprite('badend1', 'dayforest/bad_ending1', -300, 280)
            setScrollFactor('badend1', 1.0, 1.0)
            scaleObject('badend1', 3.8, 3.8)
            addLuaSprite('badend1', false)
        end
    end
    
    if curStep == 1275 then
        if custardCount >= 10 then
            triggerEvent('Change Character', 'boyfriend', 'goodending2')
            characterPlayAnim('boyfriend', 'ending', true)
            setProperty('boyfriend.specialAnim', true)
        end
    end
    
    if curStep == 1280 then
        if custardCount < 10 then
            removeLuaSprite('badend1', true)
        
            makeLuaSprite('badend2', 'dayforest/bad_ending2', -300, 280)
            setScrollFactor('badend2', 1.0, 1.0)
            scaleObject('badend2', 3.8, 3.8)
            addLuaSprite('badend2', false)
        end
    end
     
    if curStep == 1290 then
        if custardCount < 10 then
            setProperty('health', 0)
        end
    end
end

function onTimerCompleted(tag)
    if tag == 'hideCustardText' then
        setProperty('custardText.alpha', 0)
    end
end