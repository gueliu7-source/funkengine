local enemyNotesX = -3000

function onUpdatePost()
    for i = 0, 3 do
        setPropertyFromGroup('opponentStrums', i, 'x', enemyNotesX + (i * 112))
    end

    setProperty('rating.visible', false)
    setProperty('comboSpr.visible', false)
    setProperty('comboGroup.visible', false)
end