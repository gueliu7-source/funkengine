--the script don't work with 3 or 4 notes
local laneWidth = 720
local laneHeight = 90
local laneOffsetY = 200
local hitOffset = 80
local travelTime = 1400
local accelPower = 2.2
local noteScale = 0.5
local missWindow = 350

local doubleShrink    = 0.5
local doubleOffset    = laneHeight / 4
local doubleTolerance = 5

local noteImages = {'lionsmouth/purple0', 'lionsmouth/blue0', 'lionsmouth/green0', 'lionsmouth/red0'}
local zoneImages = {'lionsmouth/arrowLEFT0', 'lionsmouth/arrowDOWN0', 'lionsmouth/arrowUP0', 'lionsmouth/arrowRIGHT0'}

local enabled = false
local notes = {}
local firstIdx = 1
local clock = 0
local zoneFlash = 0
local targetKey = ''
local shownZones = {}
local failCount = 0
local blockedDuration = 0.6
local laneX, laneY, startX, hitX, centerY

function makeDipsyArrow(tag, image, x, y, scale)
    scale = scale or noteScale
    makeLuaSprite(tag, image, x, y)
    setObjectCamera(tag, 'hud')
    scaleObject(tag, scale, scale)
end

function slotScale(slot)
    if slot == 0 then return noteScale end
    return noteScale * doubleShrink
end

function slotCenterY(slot)
    if slot == 1 then return centerY - doubleOffset end
    if slot == 2 then return centerY + doubleOffset end
    return centerY
end

function onCreate()
    makeLuaText('blockedText', 'PARRY!', 500, 0, 0)
    setTextSize('blockedText', 45)
    setTextAlignment('blockedText', 'center')
    setObjectCamera('blockedText', 'hud')
    setTextFont('blockedText', 'LD Slender Regular.ttf')
    screenCenter('blockedText', 'x')
    setProperty('blockedText.y', screenHeight / 2 + 80)
    addLuaText('blockedText')
    setProperty('blockedText.antialiasing', true)
    setProperty('blockedText.alpha', 0)

    makeVideoSprite('ending1', 'ending1', 280, 115, 'camHUD', false)
    scaleObject('ending1', 2, 2)
    makeVideoSprite('ending2', 'ending2', -100, -180, 'camHUD', false)
    scaleObject('ending2', 0.7, 0.7)
end

function showParry()
    setTextString('blockedText', 'PARRY!')
    cancelTween('blockedFade')
    setProperty('blockedText.alpha', 1)
    doTweenAlpha('blockedFade', 'blockedText', 0, blockedDuration, 'linear')
end

function registerFail()
    failCount = failCount + 1
    if failCount >= 4 then
        setHealth(0)
    end
end

function onStepHit()
    if curStep == 2128 then
        if failCount >= 2 then
            playVideoSprite('ending2')
            setObjectOrder('ending2', 0)
            setProperty('ending2.antialiasing', false)
        else
            playVideoSprite('ending1')
            setObjectOrder('ending1', 0)
            setProperty('ending1.antialiasing', false)
        end
    end
end

function onCreatePost()
    laneX = (screenWidth - laneWidth) / 2
    laneY = (screenHeight - laneHeight) / 2 + laneOffsetY
    centerY = laneY + laneHeight / 2
    hitX = laneX + hitOffset
    startX = laneX + laneWidth - 40

    makeLuaSprite('dipsyLane', nil, laneX, laneY)
    makeGraphic('dipsyLane', laneWidth, laneHeight, '000000')
    setObjectCamera('dipsyLane', 'hud')
    setProperty('dipsyLane.alpha', 0.85)
    setProperty('dipsyLane.visible', enabled)
    addLuaSprite('dipsyLane', true)

    for d = 0, 3 do
        local tag = 'dipsyZone' .. d
        makeDipsyArrow(tag, zoneImages[d + 1], 0, 0)
        setProperty(tag .. '.x', hitX - getProperty(tag .. '.width') / 2)
        setProperty(tag .. '.y', centerY - getProperty(tag .. '.height') / 2)
        setProperty(tag .. '.visible', false)
        addLuaSprite(tag, true)
    end

    local total = getProperty('unspawnNotes.length')
    for i = 0, total - 1 do
        local must = getPropertyFromGroup('unspawnNotes', i, 'mustPress')
        local sus = getPropertyFromGroup('unspawnNotes', i, 'isSustainNote')
        if must and not sus then
            table.insert(notes, {
                time = getPropertyFromGroup('unspawnNotes', i, 'strumTime'),
                dir = getPropertyFromGroup('unspawnNotes', i, 'noteData') % 4,
                state = 'active',
                spawned = false,
                slot = 0
            })
        end
    end
    table.sort(notes, function(a, b)
        if a.time ~= b.time then return a.time < b.time end
        return a.dir < b.dir
    end)

    local k = 1
    while k <= #notes do
        local m = k
        while notes[m + 1] and notes[m + 1].time - notes[k].time <= doubleTolerance do
            m = m + 1
        end
        if m - k == 1 and notes[k].dir ~= notes[m].dir then
            local top, bot = notes[k], notes[m]
            if top.dir > bot.dir then top, bot = bot, top end
            top.slot, bot.slot = 1, 2
            top.partner, bot.partner = bot, top
        end
        k = m + 1
    end
end

function onEvent(name, value1, value2)
    if string.lower(name) ~= 'dipsyattack' then return end
    local v = string.lower(value1 or '')
    if v == 'on' then
        showDipsyLane()
    elseif v == 'off' then
        hideDipsyLane()
    end
end

function placeDipsyZone(n)
    local tag = 'dipsyZone' .. n.dir
    local s = slotScale(n.slot)
    setProperty(tag .. '.scale.x', s)
    setProperty(tag .. '.scale.y', s)
    setProperty(tag .. '.y', slotCenterY(n.slot) - getProperty(tag .. '.height') / 2)
    setProperty(tag .. '.visible', true)
    table.insert(shownZones, {dir = n.dir, scale = s})
end

function setDipsyTarget(n)
    local top, bot = n, n.partner
    if n.slot == 2 then top, bot = n.partner, n end

    local key = top.dir .. ':' .. (bot and bot.dir or -1)
    if key == targetKey then return end
    targetKey = key

    for d = 0, 3 do
        setProperty('dipsyZone' .. d .. '.visible', false)
    end
    shownZones = {}
    placeDipsyZone(top)
    if bot then placeDipsyZone(bot) end
end

function ensureDipsyOrder()
    if luaSpriteExists('dipsyLane') then
        setObjectCamera('dipsyLane', 'hud')
    end
    for d = 0, 3 do
        local zTag = 'dipsyZone' .. d
        if luaSpriteExists(zTag) then
            setObjectCamera(zTag, 'hud')
        end
    end
end

function showDipsyLane()
    enabled = true
    targetKey = ''
    setProperty('dipsyLane.visible', true)
    setProperty('dipsyLane.alpha', 0.85)
    ensureDipsyOrder()
end

function hideDipsyLane()
    enabled = false
    targetKey = ''
    shownZones = {}
    setProperty('dipsyLane.visible', false)
    for d = 0, 3 do
        setProperty('dipsyZone' .. d .. '.visible', false)
    end
    for i = firstIdx, #notes do
        local n = notes[i]
        if n.spawned then
            removeLuaSprite(n.tag, true)
            n.spawned = false
            if n.state ~= 'active' then n.state = 'done' end
        end
    end
end

function spawnDipsyNote(n, i)
    local tag = 'dipsyNote' .. i
    n.tag = tag
    n.scale = slotScale(n.slot)
    makeDipsyArrow(tag, noteImages[n.dir + 1], startX, centerY, n.scale)
    setProperty(tag .. '.alpha', 1)
    addLuaSprite(tag, true)
    n.w = getProperty(tag .. '.width')
    n.h = getProperty(tag .. '.height')
    setProperty(tag .. '.y', slotCenterY(n.slot) - n.h / 2)
    n.spawned = true
end

function updateDipsyNote(n, timeLeft)
    local tag = n.tag

    if n.state == 'active' then
        local p = 1 - timeLeft / travelTime
        if p < 0 then p = 0 end
        if p > 1 then p = 1 end

        local x = startX + (hitX - startX) * (p ^ accelPower)
        setProperty(tag .. '.x', x - n.w / 2)

        setProperty(tag .. '.alpha', 1)

        if timeLeft < -missWindow then
            n.state = 'missed'
            n.resolvedAt = clock
            registerFail()
        end
    else
        local t = (clock - n.resolvedAt) / 0.25
        if t >= 1 then
            removeLuaSprite(tag, true)
            n.spawned = false
            n.state = 'done'
        elseif n.state == 'hit' then
            local s = n.scale * (1 + t * 0.7)
            setProperty(tag .. '.scale.x', s)
            setProperty(tag .. '.scale.y', s)
            setProperty(tag .. '.alpha', 1 - t)
        else
            setProperty(tag .. '.alpha', 0.5 * (1 - t))
        end
    end
end

function onUpdate(elapsed)
    clock = clock + elapsed
    local pos = getSongPosition()

    while firstIdx <= #notes do
        local n = notes[firstIdx]
        if n.state == 'done' then
            firstIdx = firstIdx + 1
        elseif not n.spawned and n.time < pos - missWindow then
            n.state = 'done'
            firstIdx = firstIdx + 1
        else
            break
        end
    end

    if not enabled then return end

    local j = firstIdx
    while j <= #notes and notes[j].state ~= 'active' do
        j = j + 1
    end
    if j <= #notes then
        setDipsyTarget(notes[j])
    end

    if zoneFlash > 0 then
        zoneFlash = zoneFlash - elapsed * 4
        if zoneFlash < 0 then zoneFlash = 0 end
        for _, z in ipairs(shownZones) do
            local s = z.scale * (1 + 0.25 * zoneFlash)
            setProperty('dipsyZone' .. z.dir .. '.scale.x', s)
            setProperty('dipsyZone' .. z.dir .. '.scale.y', s)
        end
    end

    local i = firstIdx
    while i <= #notes do
        local n = notes[i]
        local timeLeft = n.time - pos
        if timeLeft > travelTime then break end

        if n.state ~= 'done' then
            if not n.spawned then
                if timeLeft > -missWindow then
                    spawnDipsyNote(n, i)
                else
                    n.state = 'done'
                end
            end
            if n.spawned then
                updateDipsyNote(n, timeLeft)
            end
        end
        i = i + 1
    end
end

function resolveDipsyNote(dir, result)
    local pos = getSongPosition()
    for i = firstIdx, #notes do
        local n = notes[i]
        local timeLeft = n.time - pos
        if timeLeft > 400 then break end

        if n.state == 'active' and n.dir == dir and timeLeft >= -500 then
            if n.spawned then
                n.state = 'hit'
                n.resolvedAt = clock
                zoneFlash = 1
                showParry()
            else
                n.state = 'done'
            end
            return
        end
    end
end

function goodNoteHit(membersIndex, noteData, noteType, isSustainNote)
    if isSustainNote then return end
    resolveDipsyNote(noteData, 'hit')
end