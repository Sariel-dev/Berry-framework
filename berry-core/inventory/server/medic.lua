local ataTimers = {}

local function setPlayerState(src, key, value)
    local player = Player(src)
    if not player then return end
    player.state:set(key, value, true)
end

local function clearAtaTimer(src)
    if ataTimers[src] then
        ataTimers[src] = nil
    end
end

RegisterNetEvent('ox_inventory:medic:updateBodyParts', function(bodyParts)
    if type(bodyParts) ~= 'table' then return end
    setPlayerState(source, 'bodyParts', bodyParts)
end)

RegisterNetEvent('ox_inventory:medic:setDiseases', function(targetId, diseases)
    local src = source
    local target = tonumber(targetId) or src
    if type(diseases) ~= 'table' then diseases = {} end
    setPlayerState(target, 'diseases', diseases)
end)

RegisterNetEvent('ox_inventory:medic:addDisease', function(targetId, disease)
    local src = source
    local target = tonumber(targetId) or src
    if type(disease) ~= 'string' or disease == '' then return end

    local player = Player(target)
    if not player then return end

    local current = player.state.diseases
    if type(current) ~= 'table' then current = {} end

    for _, value in ipairs(current) do
        if value == disease then
            return
        end
    end

    table.insert(current, disease)
    setPlayerState(target, 'diseases', current)
end)

RegisterNetEvent('ox_inventory:medic:removeDisease', function(targetId, disease)
    local src = source
    local target = tonumber(targetId) or src
    if type(disease) ~= 'string' or disease == '' then return end

    local player = Player(target)
    if not player then return end

    local current = player.state.diseases
    if type(current) ~= 'table' then return end

    local filtered = {}
    for _, value in ipairs(current) do
        if value ~= disease then
            table.insert(filtered, value)
        end
    end

    setPlayerState(target, 'diseases', filtered)
end)

RegisterNetEvent('ox_inventory:medic:setAta', function(targetId, toggle, durationHours, part)
    local src = source
    local target = tonumber(targetId) or src

    clearAtaTimer(target)

    local enabled = toggle == true
    setPlayerState(target, 'ata', enabled)
    setPlayerState(target, 'ataPart', part)

    if enabled and durationHours and tonumber(durationHours) then
        local duration = tonumber(durationHours)
        local expiresAt = os.time() + math.floor(duration * 3600)
        setPlayerState(target, 'ataExpiresAt', expiresAt)

        ataTimers[target] = SetTimeout(math.floor(duration * 3600 * 1000), function()
            local player = Player(target)
            if not player then return end
            setPlayerState(target, 'ata', false)
            setPlayerState(target, 'ataPart', nil)
            setPlayerState(target, 'ataExpiresAt', nil)
            clearAtaTimer(target)
        end)
    else
        setPlayerState(target, 'ataExpiresAt', nil)
    end
end)

RegisterNetEvent('ox_inventory:medic:setExpectingRPDeath', function(targetId, toggle)
    local src = source
    local target = tonumber(targetId) or src
    setPlayerState(target, 'expectingRPDeath', toggle == true)
end)
