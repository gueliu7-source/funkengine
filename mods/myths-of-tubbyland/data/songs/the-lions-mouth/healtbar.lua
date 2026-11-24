local xPlayer = 170
local yPlayer = 550

local xEnemy = 165
local yEnemy = 20

function onCreatePost()

    setProperty('healthBar.x', -60)
    setProperty('healthBar.y', 350)

    setProperty('healthBar.angle', -270)

end

function onUpdatePost()

    local health = getProperty('healthBar.percent')

    local topY = 100
    local barSize = 600

    setProperty('iconP2.x', xEnemy)
    setProperty('iconP2.y', yEnemy)

    setProperty('iconP1.x', xPlayer)
    setProperty('iconP1.y', yPlayer)

end

function opponentNoteHit(id, direction, noteType, isSustainNote)
    if not isSustainNote then
        local health = getProperty('health')
        
        if health > 0.25 then
            setProperty('health', health - 0.024)
        end
    end
end