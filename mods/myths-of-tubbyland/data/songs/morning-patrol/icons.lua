local xPlayer = 280
local xEnemy = 880

function onUpdatePost()
    setProperty('iconP1.x', xPlayer)
    setProperty('iconP2.x', xEnemy)
    setProperty('healthBar.flipX', true)
    iconP1Modifier = getProperty('healthBar.x') + ((getProperty('healthBar.width') * getProperty('healthBar.percent') * 0.01) + (150 * getProperty('iconP1.scale.x') - 150) / 2 - 26)
    iconP2Modifier = getProperty('healthBar.x') + ((getProperty('healthBar.width') * getProperty('healthBar.percent') * 0.01) - (150 * getProperty('iconP2.scale.x')) / 2 - 26 * 2)
end

function opponentNoteHit(id, direction, noteType, isSustainNote)
    if not isSustainNote then
        local health = getProperty('health')
        
        if health > 0.25 then
            setProperty('health', health - 0.019)
        end
    end
end