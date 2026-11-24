local enabled = false
local lastImage = 0

function onCreate()
    for i = 1,6 do
        makeLuaSprite('tank'..i, 'dropimages/tank'..i, -280, 280)
        scaleObject('tank'..i, 2.75, 2.7)
        setProperty('tank'..i..'.alpha', 0)
        addLuaSprite('tank'..i, false)
    end
end

function onEvent(name, value1, value2)
    if name == 'ScreamersS2' then
        if value1 == 'on' then
            enabled = true
        elseif value1 == 'off' then
            enabled = false

            for i = 1,6 do
                setProperty('tank'..i..'.alpha', 0)
            end
        end
    end
end

function onStepHit()
    if enabled and curStep % 2 == 0 then
        local newImage = lastImage

        while newImage == lastImage do
            newImage = getRandomInt(1, 6)
        end

        lastImage = newImage

        for i = 1,6 do
            setProperty('tank'..i..'.alpha', 0)
        end

        setProperty('tank'..newImage..'.alpha', 0.3)
    end
end