local custardCount = 15
local failedShown = false

function onCreate()
    makeLuaText('custardText', '15 Custards Remaining', 520, 370, 330)
    setTextSize('custardText', 13)
    setTextBorder('custardText', 0, '000000')
    setProperty('custardText.antialiasing', true)
    setObjectCamera('custardText', 'other')
    addLuaText('custardText')
    
    setProperty('custardText.alpha', 0)
end

function onCreatePost()
    for i = 0, getProperty('unspawnNotes.length')-1 do
        if getPropertyFromGroup('unspawnNotes', i, 'noteType') == 'CustardNoteS2' then
            setPropertyFromGroup('unspawnNotes', i, 'texture', 'custard')
            setPropertyFromGroup('unspawnNotes', i, 'isSustainNote', false)

            setPropertyFromGroup('unspawnNotes', i, 'scale.x', 0.7)
            setPropertyFromGroup('unspawnNotes', i, 'scale.y', 0.7)

            setPropertyFromGroup('unspawnNotes', i, 'noAnimation', true)
        end
    end
end

function goodNoteHit(id, direction, noteType, isSustainNote)
    if noteType == 'CustardNoteS2' then
        setProperty('health', getProperty('health') + 0.2)
        
        if custardCount > 0 then
            custardCount = custardCount - 1
        end

        setTextString('custardText', custardCount .. ' Custards Remaining')

        setProperty('custardText.alpha', 1)

        cancelTimer('hideCustardText')
        runTimer('hideCustardText', 2)
    end
end

function onStepHit()
    if curStep == 1264 and not failedShown then
        failedShown = true
        if custardCount > 0 then
            setTextString('custardText', 'failed')
            setProperty('custardText.alpha', 1)

            cancelTimer('hideCustardText')
            runTimer('hideCustardText', 2)
        end
    elseif curStep == 1280 then
        removeLuaText('custardText', true)
    end
end

function onTimerCompleted(tag)
    if tag == 'hideCustardText' then
        setProperty('custardText.alpha', 0)
    end
end