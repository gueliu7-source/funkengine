local enabled = false
local lastImage = 0

function onCreate()
    for i = 1,5 do
        makeLuaSprite('im'..i, 'dropimages/image'..i, -300, 280)
        scaleObject('im'..i, 3.8, 3.8)
        setProperty('im'..i..'.alpha', 0)
        addLuaSprite('im'..i, false)
    end
end

function onEvent(name, value1, value2)
    if name == 'IntenseScreamers' then
        if value1 == 'on' then
            enabled = true
        elseif value1 == 'off' then
            enabled = false

            for i = 1,5 do
                setProperty('im'..i..'.alpha', 0)
            end
        end
    end
end

function onStepHit()
    if enabled and curStep % 2 == 0 then
        local newImage = lastImage

        while newImage == lastImage do
            newImage = getRandomInt(1, 5)
        end

        lastImage = newImage

        for i = 1,5 do
            setProperty('im'..i..'.alpha', 0)
        end

        setProperty('im'..newImage..'.alpha', 1.0)
    end
end