local lastImage = 0

function onCreate()
    for i = 1,5 do
        makeLuaSprite('tinkyscreamer'..i, 'dropimages/image'..i, 120, 0)
        setObjectCamera('tinkyscreamer'..i, 'hud')
        setProperty('tinkyscreamer'..i..'.alpha', 0)
        addLuaSprite('tinkyscreamer'..i, true)
        scaleObject('tinkyscreamer'..i, 1.8, 1.8)
    end
end

function onEvent(name, value1, value2)
    if name == 'TinkyScreamer' then
        if value1 == 'on' then

            local newImage = lastImage

            while newImage == lastImage do
                newImage = getRandomInt(1, 5)
            end

            lastImage = newImage

            for i = 1,5 do
                setProperty('tinkyscreamer'..i..'.alpha', 0)
            end

            setProperty('tinkyscreamer'..newImage..'.alpha', 1)

            runTimer('hideTinky', 0.05)
        end
    end
end

function onTimerCompleted(tag)
    if tag == 'hideTinky' then
        for i = 1,5 do
            setProperty('tinkyscreamer'..i..'.alpha', 0)
        end
    end
end