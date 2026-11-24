local lastImage = 0

function onCreate()
    for i = 1,6 do
        makeLuaSprite('tankscreamer'..i, 'dropimages/tank'..i, -280, 280)
        setProperty('tankscreamer'..i..'.alpha', 0)
        addLuaSprite('tankscreamer'..i, true)
        scaleObject('tankscreamer'..i, 2.75, 2.7)
    end
end

function onEvent(name, value1, value2)
    if name == 'TankScreamer' then
        if value1 == 'on' then

            local newImage = lastImage

            while newImage == lastImage do
                newImage = getRandomInt(1, 5)
            end

            lastImage = newImage

            for i = 1,5 do
                setProperty('tankscreamer'..i..'.alpha', 0)
            end

            setProperty('tankscreamer'..newImage..'.alpha', 1)

            runTimer('hidetank', 0.05)
        end
    end
end

function onTimerCompleted(tag)
    if tag == 'hidetank' then
        for i = 1,6 do
            setProperty('tankscreamer'..i..'.alpha', 0)
        end
    end
end