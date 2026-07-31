if not lib then return end

local MultiChest = {}
MultiChest.Data = {}

local db = require 'modules.mysql.server'
local Inventory = require 'modules.inventory.server'

local function createLockerStash(lockerId, label)
    local stashName = 'multichest_locker_' .. lockerId
    exports.ox_inventory:RegisterStash(stashName, label, 50, 50000)
    return stashName
end

lib.callback.register('ox_inventory:getAllMultiChests', function()
    local multichests = {}

    for multiChestId, entry in pairs(MultiChest.Data) do
        if entry and entry.coords then
            multichests[#multichests + 1] = {
                id = multiChestId,
                coords = entry.coords,
            }
        end
    end

    return multichests
end)

lib.callback.register('ox_inventory:createMultiChest', function(source, coords)
    if type(coords) ~= 'vector3' then return false end
    
    local playerCoords = GetEntityCoords(GetPlayerPed(source))
    local distance = #(playerCoords - coords)
    if distance > 5.0 then return false end
    
    local result = MySQL.insert.await([[
        INSERT INTO ox_inventory_multichests (coords_x, coords_y, coords_z, created_at)
        VALUES (?, ?, ?, NOW())
    ]], { coords.x, coords.y, coords.z })

    if result then
        local multiChestId = result
        MultiChest.Data[multiChestId] = {
            id = multiChestId,
            coords = coords,
            lockers = {}
        }
        TriggerClientEvent('ox_inventory:multiChestCreated', -1, multiChestId, coords)
        return multiChestId
    end
    return false
end)

lib.callback.register('ox_inventory:getMultiChest', function(source, multiChestId)
    if not MultiChest.Data[multiChestId] then
        local result = MySQL.query.await([[
            SELECT id, coords_x, coords_y, coords_z
            FROM ox_inventory_multichests
            WHERE id = ?
        ]], { multiChestId })

        if result and result[1] then
            MultiChest.Data[multiChestId] = {
                id = multiChestId,
                coords = vector3(result[1].coords_x, result[1].coords_y, result[1].coords_z),
                lockers = {}
            }
        else
            return nil
        end
    end

    local lockersResult = MySQL.query.await([[
        SELECT id, locker_number, label
        FROM ox_inventory_multichest_lockers
        WHERE multichest_id = ?
        ORDER BY locker_number ASC
    ]], { multiChestId })

    local lockers = {}
    if lockersResult then
        for _, locker in ipairs(lockersResult) do
            table.insert(lockers, {
                id = locker.id,
                lockerId = 'multichest_locker_' .. locker.id,
                number = locker.locker_number,
                label = locker.label or (locale('multichest_locker') .. ' ' .. string.format('%02d', locker.locker_number))
            })
        end
    end

    MultiChest.Data[multiChestId].lockers = lockers
    return lockers
end)

lib.callback.register('ox_inventory:addLockerToMultiChest', function(source, multiChestId)
    if not MultiChest.Data[multiChestId] then
        return false
    end

    local lockersCount = MySQL.scalar.await([[
        SELECT COUNT(*) FROM ox_inventory_multichest_lockers
        WHERE multichest_id = ?
    ]], { multiChestId }) or 0

    local lockerNumber = lockersCount + 1
    local label = locale('multichest_locker') .. ' ' .. string.format('%02d', lockerNumber)

    local result = MySQL.insert.await([[
        INSERT INTO ox_inventory_multichest_lockers (multichest_id, locker_number, label, created_at)
        VALUES (?, ?, ?, NOW())
    ]], { multiChestId, lockerNumber, label })

    if result then
        local lockerId = result
        createLockerStash(lockerId, label)
        return lockerId
    end
    return false
end)

lib.callback.register('ox_inventory:searchMultiChestLockers', function(source, multiChestId, searchTerm)
    local query = [[
        SELECT id, locker_number, label
        FROM ox_inventory_multichest_lockers
        WHERE multichest_id = ?
    ]]

    local params = { multiChestId }

    if searchTerm and searchTerm ~= '' then
        query = query .. [[ AND (label LIKE ? OR locker_number LIKE ?)]]
        local searchPattern = '%' .. searchTerm .. '%'
        table.insert(params, searchPattern)
        table.insert(params, searchPattern)
    end

    query = query .. [[ ORDER BY locker_number ASC]]

    local lockersResult = MySQL.query.await(query, params)

    local lockers = {}
    if lockersResult then
        for _, locker in ipairs(lockersResult) do
            table.insert(lockers, {
                id = locker.id,
                lockerId = 'multichest_locker_' .. locker.id,
                number = locker.locker_number,
                label = locker.label or (locale('multichest_locker') .. ' ' .. string.format('%02d', locker.locker_number))
            })
        end
    end

    return lockers
end)

CreateThread(function()
    Wait(2000)
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS ox_inventory_multichests (
            id INT AUTO_INCREMENT PRIMARY KEY,
            coords_x FLOAT NOT NULL,
            coords_y FLOAT NOT NULL,
            coords_z FLOAT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]])

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS ox_inventory_multichest_lockers (
            id INT AUTO_INCREMENT PRIMARY KEY,
            multichest_id INT NOT NULL,
            locker_number INT NOT NULL,
            label VARCHAR(255),
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (multichest_id) REFERENCES ox_inventory_multichests(id) ON DELETE CASCADE,
            UNIQUE KEY unique_locker (multichest_id, locker_number)
        )
    ]])

    local results = MySQL.query.await('SELECT id, coords_x, coords_y, coords_z FROM ox_inventory_multichests')
    if results then
        for _, result in ipairs(results) do
            MultiChest.Data[result.id] = {
                id = result.id,
                coords = vector3(result.coords_x, result.coords_y, result.coords_z),
                lockers = {}
            }
            TriggerClientEvent('ox_inventory:multiChestCreated', -1, result.id, MultiChest.Data[result.id].coords)
        end
    end

    local lockersResults = MySQL.query.await([[
        SELECT id, multichest_id, locker_number, label
        FROM ox_inventory_multichest_lockers
    ]])
    if lockersResults then
        for _, locker in ipairs(lockersResults) do
            createLockerStash(locker.id, locker.label or (locale('multichest_locker') .. ' ' .. string.format('%02d', locker.locker_number)))
        end
    end
end)

return MultiChest

