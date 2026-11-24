local posX = 0
local posY = 680
local fuente = 'LD Slender Regular.ttf'

function onCreatePost()
    setTextFont('botplayTxt', fuente)
    
    setTextBorder('botplayTxt', 0, '000000')
    
    setProperty('botplayTxt.antialiasing', true)
    
    setProperty('botplayTxt.x', posX)
    setProperty('botplayTxt.y', posY)
end

function onUpdatePost()
    if botPlay then
        setProperty('botplayTxt.text', 'LET HIM COOK')
        setProperty('botplayTxt.visible', true)
    else
        setProperty('botplayTxt.visible', false)
    end
end