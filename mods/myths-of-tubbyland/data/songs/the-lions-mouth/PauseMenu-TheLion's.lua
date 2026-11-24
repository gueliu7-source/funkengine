local selected = 1
local options = {'Resume', 'Restart', 'Quit'}
local fontName = 'LD Slender Regular.ttf'

function onPause()
    openCustomSubstate('custom_pause_menu', true)
    return Function_Stop
end

function onCustomSubstateCreate(name)
    selected = 1

    if name == 'custom_pause_menu' then
        makeLuaSprite('pauseBG', '', 0, 0)
        makeGraphic('pauseBG', 1280, 720, '000000')
        setObjectCamera('pauseBG', 'other')
        setProperty('pauseBG.alpha', 0.5)
        addLuaSprite('pauseBG', true)

        makeLuaSprite('Render', 'MenuPause Artwork/tlm', 300, 0)
        setObjectCamera('Render', 'other')
        scaleObject('Render', 1.15, 1.15)
        addLuaSprite('Render', true)
        
        makeLuaText('songTitle', 'The-Lions-Mouth', 600, 170, 20)
        
        setTextFont('songTitle', fontName)
        setTextSize('songTitle', 64)
        setTextAlignment('songTitle', 'left')
        setTextColor('sogTitle', 'FFFFFF')
        setObjectCamera('songTitle', 'other')
        setProperty('songTitle.antialiasing', true)
        
        addLuaText('songTitle')

        for i = 1, #options do
            local tag = 'btn_' .. options[i]
            
            makeLuaText(tag, options[i], 400, 200, 200 + (i * 80))
            
            setTextFont(tag, fontName)
            setTextSize(tag, 64)
            setTextAlignment(tag, 'left')
            setObjectCamera(tag, 'other')
            
            setProperty(tag .. '.antialiasing', true)
            
            addLuaText(tag)
        end
        
        updateSelection()
    end
end

function updateSelection()
    for i = 1, #options do
        local tag = 'btn_' .. options[i]
        if i == selected then
            setTextColor(tag, 'FFFFFF')
            setTextSize(tag, 72)
        else
            setTextColor(tag, '888888')
            setTextSize(tag, 64)
        end
    end
end

function onCustomSubstateUpdate(name, elapsed)
    if name == 'custom_pause_menu' then
        if keyJustPressed('up') or keyboardJustPressed('UP') or keyboardJustPressed('W') then
            selected = selected - 1
            if selected < 1 then selected = #options end
            updateSelection()
            playSound('scrollMenu', 0.6)
            
        elseif keyJustPressed('down') or keyboardJustPressed('DOWN') or keyboardJustPressed('S') then
            selected = selected + 1
            if selected > #options then selected = 1 end
            updateSelection()
            playSound('scrollMenu', 0.6)
        end

        if keyJustPressed('accept') then
            runOption(options[selected])
        end
    end
end

function runOption(chosen)
    if chosen == 'Resume' then
        removeLuaSprite('pauseBG', true)
        removeLuaSprite('Render', true)
        removeLuaSprite('songTitle', true)
        
        for i = 1, #options do
            removeLuaText('btn_' .. options[i], true)
        end
        
        closeCustomSubstate()
    elseif chosen == 'Restart' then
        restartSong()
    elseif chosen == 'Quit' then
        exitSong()
    end
end