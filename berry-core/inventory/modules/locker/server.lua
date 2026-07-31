if not lib then return end

local function noop(...) end
local print = noop
local warn = noop

local Locker = {}
Locker.Data = {}
local lockerDataReady = false

-- Configuration des lockers depuis Config.Locker
local Config = Config and Config.Locker or {
    MaxLockers = 1000,
    MaxCasiersPerLocker = 100,
    CasierSlots = 50,
    CasierMaxWeight = 50000,
    MarkerDistance = 16.0,
    InteractionDistance = 1.5,
    MinLockerNameLength = 1,
    MaxLockerNameLength = 255,
    MinCasierNameLength = 1,
    MaxCasierNameLength = 255,
    PinCodeLength = 4,
    CheckPermissions = true,
    AllowedGroups = {'admin', 'superadmin'},
    AccessGroups = nil,
    CreateGroups = nil,
}

-- Framework handles (fallback if globals are not ready)
local ESX = rawget(_G, 'ESX')
local QBCore = rawget(_G, 'QBCore')
local Ox = rawget(_G, 'Ox')

if (shared and shared.framework == 'esx') and not ESX then
    local ok, obj = pcall(function()
        return exports.es_extended and exports.es_extended:getSharedObject()
    end)
    if ok and obj then
        ESX = obj
        _G.ESX = obj
    end
end

if (shared and (shared.framework == 'qb' or shared.framework == 'qbx')) and not QBCore then
    local ok, obj = pcall(function()
        return exports['qb-core'] and exports['qb-core']:GetCoreObject()
    end)
    if ok and obj then
        QBCore = obj
        _G.QBCore = obj
    end
end

if not Ox then
    Ox = rawget(_G, 'Ox')
end

local function hasLockerPermission(source)
    if not source or type(source) ~= 'number' then
        return false
    end
    
    if not Config.CheckPermissions then
        return true
    end
    
    local allowedGroups = Config.AllowedGroups or {'admin', 'superadmin'}
    local framework = (shared and shared.framework) or 'unknown'
    
    local success, allowed = pcall(function()
        if shared and shared.framework == 'esx' then
            if not _G.ESX then
                return false
            end
            
            local xPlayer = ESX.GetPlayerFromId(source)
            if not xPlayer then
                return false
            end
            
            for i = 1, #allowedGroups do
                local group = allowedGroups[i]
                
                if xPlayer.getGroup and xPlayer.getGroup() == group then
                    return true
                end
                
                if xPlayer.get and xPlayer.get('group') == group then
                    return true
                end
                
                if xPlayer.variables and xPlayer.variables.group == group then
                    return true
                end
                
                if xPlayer.job and xPlayer.job.name == group then
                    return true
                end
            end
        elseif shared and (shared.framework == 'qb' or shared.framework == 'qbx') then
            if not _G.QBCore then
                return false
            end
            
            local Player = QBCore.Functions.GetPlayer(source)
            if not Player then
                return false
            end
            
            for i = 1, #allowedGroups do
                local group = allowedGroups[i]
                if Player.PlayerData and Player.PlayerData.job and Player.PlayerData.job.name == group then
                    return true
                end
            end
        else
            if not _G.Ox then
                return false
            end
            
            local player = Ox.GetPlayer(source)
            if not player then
                return false
            end
            
            for i = 1, #allowedGroups do
                local group = allowedGroups[i]
                if player.hasGroup and player.hasGroup(group) then
                    return true
                end
            end
        end
        
        return false
    end)
    
    if not success then
        warn(('Locker permission check failed: %s'):format(allowed))
        return false
    end
    
    if allowed == true then
        return true
    end

    return false
end

local function createLockerStash(lockerId, label)
    local stashName = 'locker_casier_' .. lockerId
    exports.ox_inventory:RegisterStash(stashName, label, Config.CasierSlots, Config.CasierMaxWeight)
    return stashName
end

local function normalizeLockerOptions(options)
    if type(options) ~= 'table' then
        return {
            skipMarker = false,
        }
    end

    return {
        skipMarker = options.skipMarker == true,
    }
end

local function createLockerInternal(source, coords, label, options)
    if source and source > 0 and not hasLockerPermission(source) then
        return false
    end

    if not coords or type(coords) ~= 'vector3' then
        return false
    end

    if label and (type(label) ~= 'string' or #label < Config.MinLockerNameLength or #label > Config.MaxLockerNameLength) then
        label = nil
    end

    local lockerOptions = normalizeLockerOptions(options)

    local lockersCount = MySQL.scalar.await([[
        SELECT COUNT(*) FROM ox_inventory_lockers
    ]]) or 0

    if lockersCount >= Config.MaxLockers then
        return false
    end

    local lockerLabel = label or locale('default_locker_label', os.time())
    local result = MySQL.insert.await([[
        INSERT INTO ox_inventory_lockers (coords_x, coords_y, coords_z, label, skip_marker, created_at)
        VALUES (?, ?, ?, ?, ?, NOW())
    ]], { coords.x, coords.y, coords.z, lockerLabel, lockerOptions.skipMarker and 1 or 0 })

    if not result then
        return false
    end

    local lockerId = result
    lockerLabel = label or locale('default_locker_label', lockerId)
    createLockerStash(lockerId, lockerLabel)

    local lockerData = {
        id = lockerId,
        coords = vector3(coords.x, coords.y, coords.z),
        label = lockerLabel,
        skipMarker = lockerOptions.skipMarker
    }

    Locker.Data[lockerId] = lockerData
    TriggerClientEvent('ox_inventory:lockerCreated', -1, lockerId, lockerData.coords, lockerLabel, lockerData.skipMarker)
    return lockerId
end

local function hasJobAccess(source, groups)
    if not groups or type(groups) ~= 'table' then
        return true
    end
    
    local success, result = pcall(function()
        if shared and shared.framework == 'esx' then
            if not _G.ESX then return false end
            local xPlayer = ESX.GetPlayerFromId(source)
            if not xPlayer then return false end
            local job = xPlayer.job and xPlayer.job.name
            local grade = xPlayer.job and xPlayer.job.grade or 0
            if job and groups[job] ~= nil then
                return grade >= groups[job]
            end
        elseif shared and (shared.framework == 'qb' or shared.framework == 'qbx') then
            if not _G.QBCore then return false end
            local Player = QBCore.Functions.GetPlayer(source)
            if not Player then return false end
            local job = Player.PlayerData and Player.PlayerData.job and Player.PlayerData.job.name
            local grade = Player.PlayerData and Player.PlayerData.job and Player.PlayerData.job.grade and Player.PlayerData.job.grade.level or 0
            if job and groups[job] ~= nil then
                return grade >= groups[job]
            end
        else
            if not _G.Ox then return false end
            local player = Ox.GetPlayer(source)
            if not player then return false end
            for jobName, minGrade in pairs(groups) do
                if player.hasGroup and player.hasGroup(jobName, minGrade) then
                    return true
                end
            end
        end
        return false
    end)
    
    return success and result or false
end

local function canAccessLocker(source)
    if not Config.AccessGroups then
        return true
    end
    return hasJobAccess(source, Config.AccessGroups)
end

local function canCreateLocker(source)
    if not Config.CreateGroups then
        -- By default, creating/using casiers follows locker access rules,
        -- while locker administration remains protected by hasLockerPermission.
        return canAccessLocker(source)
    end
    return hasJobAccess(source, Config.CreateGroups)
end

local function lockerParentExists(lockerId)
    if not lockerId or type(lockerId) ~= 'number' then
        return false
    end

    if Locker.Data[lockerId] then
        return true
    end

    local okLockers, inLockers = pcall(function()
        return MySQL.scalar.await('SELECT 1 FROM ox_inventory_lockers WHERE id = ? LIMIT 1', { lockerId })
    end)

    if okLockers and inLockers then
        return true
    end

    local okMulti, inMulti = pcall(function()
        return MySQL.scalar.await('SELECT 1 FROM ox_inventory_multichest_lockers WHERE id = ? LIMIT 1', { lockerId })
    end)

    return okMulti and inMulti and true or false
end

lib.callback.register('ox_inventory:lockerHasPermission', function(source)
    return hasLockerPermission(source)
end)

lib.callback.register('ox_inventory:lockerCanAccess', function(source)
    return canAccessLocker(source)
end)

lib.callback.register('ox_inventory:lockerCanCreate', function(source)
    return canCreateLocker(source)
end)

lib.callback.register('ox_inventory:getAllLockers', function(source)
    if not hasLockerPermission(source) then
        return {}
    end
    
    local lockers = {}
    for lockerId, data in pairs(Locker.Data) do
        lockers[#lockers + 1] = {
            id = lockerId,
            label = data.label,
            coords = data.coords
        }
    end
    
    table.sort(lockers, function(a, b)
        return a.id < b.id
    end)
    
    return lockers
end)

lib.callback.register('ox_inventory:createLocker', function(source, coords, label)
    return createLockerInternal(source, coords, label)
end)

exports('createLocker', function(coords, label, options)
	return createLockerInternal(nil, coords, label, options)
end)

lib.callback.register('ox_inventory:getLocker', function(source, lockerId)
    if Locker.Data[lockerId] then
        return Locker.Data[lockerId]
    end

    local result = MySQL.query.await([[
        SELECT id, coords_x, coords_y, coords_z, label
        FROM ox_inventory_lockers
        WHERE id = ?
    ]], { lockerId })

    if result and result[1] then
        local locker = {
            id = lockerId,
            coords = vector3(result[1].coords_x, result[1].coords_y, result[1].coords_z),
            label = result[1].label or locale('default_locker_label', lockerId)
        }
        Locker.Data[lockerId] = locker
        return locker
    end
    return nil
end)

lib.callback.register('ox_inventory:getCasiersFromLocker', function(source, lockerId)
    if not lockerId or type(lockerId) ~= 'number' then
        return {}
    end
    
    if not canAccessLocker(source) then
        return {}
    end
    
    -- Vérifier que le locker existe
    if not lockerParentExists(lockerId) then
        return {}
    end
    
    local result = MySQL.query.await([[
        SELECT id, casier_number, label, pin_code
        FROM ox_inventory_locker_casiers
        WHERE locker_id = ?
        ORDER BY casier_number ASC
    ]], { lockerId })

    local casiers = {}
    if result then
        for _, casier in ipairs(result) do
            local casierId = casier.id
            local casierLabel = casier.label or locale('default_locker_label', casier.casier_number)
            local stashId = 'locker_casier_' .. casierId
            
            -- Vérifier si le casier est vide
            local inv = exports.ox_inventory:GetInventory(stashId)
            local isEmpty = true
            if inv and inv.items then
                for _, item in pairs(inv.items) do
                    if item then
                        isEmpty = false
                        break
                    end
                end
            end
            
            table.insert(casiers, {
                id = casierId,
                casierId = stashId,
                label = casierLabel,
                code = casier.pin_code,
                isEmpty = isEmpty,
                hasManageKey = false,
                note = ''
            })
        end
    end
    return casiers
end)

lib.callback.register('ox_inventory:addCasierToLocker', function(source, lockerId)
    if not lockerId or type(lockerId) ~= 'number' then
        return nil
    end
    
    if not canAccessLocker(source) then
        return nil
    end
    
    if not canCreateLocker(source) then
        return nil
    end
    
    -- Vérifier que le locker existe
    if not lockerParentExists(lockerId) then
        return nil
    end
    
    -- Vérifier la limite de casiers par locker
    local lockersCount = MySQL.scalar.await([[
        SELECT COUNT(*) FROM ox_inventory_locker_casiers
        WHERE locker_id = ?
    ]], { lockerId }) or 0
    
    if lockersCount >= Config.MaxCasiersPerLocker then
        return nil
    end

    local casierNumber = lockersCount + 1
    local label = locale('default_locker_label', string.format('%02d', casierNumber))

    local result = MySQL.insert.await([[
        INSERT INTO ox_inventory_locker_casiers (locker_id, casier_number, label, created_at)
        VALUES (?, ?, ?, NOW())
    ]], { lockerId, casierNumber, label })

    if result then
        local casierId = result
        createLockerStash(casierId, label)
        return {
            id = casierId,
            casierId = 'locker_casier_' .. casierId,
            label = label
        }
    end
    return nil
end)

lib.callback.register('ox_inventory:getCasierInfo', function(source, casierId)
    if not casierId or type(casierId) ~= 'number' then
        return { hasCode = false }
    end
    
    local success, result = pcall(function()
        return MySQL.query.await([[
            SELECT id, pin_code, locker_id
            FROM ox_inventory_locker_casiers
            WHERE id = ?
        ]], { casierId })
    end)

    if success and result and result[1] then
        return {
            hasCode = result[1].pin_code ~= nil and result[1].pin_code ~= ''
        }
    end
    return { hasCode = false }
end)

lib.callback.register('ox_inventory:setCasierPin', function(source, casierId, pin)
    if not casierId or type(casierId) ~= 'number' then
        return false
    end
    
    local pinPattern = string.rep('%d', Config.PinCodeLength)
    if not pin or type(pin) ~= 'string' or #pin ~= Config.PinCodeLength or not pin:match('^' .. pinPattern .. '$') then
        return false
    end
    
    -- Vérifier que le casier existe et que le locker parent existe
    local casierInfo = MySQL.query.await([[\
        SELECT id, locker_id, pin_code\
        FROM ox_inventory_locker_casiers
        WHERE id = ?
    ]], { casierId })
    
    if not casierInfo or not casierInfo[1] then
        return false
    end
    
    MySQL.query.await([[
        UPDATE ox_inventory_locker_casiers
        SET pin_code = ?
        WHERE id = ?
    ]], { pin, casierId })
    return true
end)

lib.callback.register('ox_inventory:removeCasierPin', function(source, casierId)
    if not casierId or type(casierId) ~= 'number' then
        return false
    end
    
    -- Vérifier que le casier existe et que le locker parent existe
    local casierInfo = MySQL.query.await([[
        SELECT id, locker_id
        FROM ox_inventory_locker_casiers
        WHERE id = ?
    ]], { casierId })
    
    if not casierInfo or not casierInfo[1] then
        return false
    end
    
    MySQL.query.await([[
        UPDATE ox_inventory_locker_casiers
        SET pin_code = NULL
        WHERE id = ?
    ]], { casierId })
    return true
end)

lib.callback.register('ox_inventory:renameCasier', function(source, casierId, newName)
    if not casierId or type(casierId) ~= 'number' then
        return false
    end
    
    if not newName or type(newName) ~= 'string' or #newName < Config.MinCasierNameLength or #newName > Config.MaxCasierNameLength then
        return false
    end
    
    -- Vérifier que le casier existe et que le locker parent existe
    local casierInfo = MySQL.query.await([[
        SELECT id, locker_id
        FROM ox_inventory_locker_casiers
        WHERE id = ?
    ]], { casierId })
    
    if not casierInfo or not casierInfo[1] then
        return false
    end
    
    MySQL.query.await([[
        UPDATE ox_inventory_locker_casiers
        SET label = ?
        WHERE id = ?
    ]], { newName, casierId })
    
    -- Mettre à jour le label du stash aussi
    local casierStashName = 'locker_casier_' .. casierId
    exports.ox_inventory:RegisterStash(casierStashName, newName, Config.CasierSlots, Config.CasierMaxWeight)
    
    return true
end)

lib.callback.register('ox_inventory:updateCasierInfo', function(source, casierId, newName, newCode, newNote)
    if not casierId or type(casierId) ~= 'number' then
        return { success = false, message = 'ID de casier invalide' }
    end

    local ok, resultOrError = pcall(function()
        -- Vérifier que le casier existe
        local casierInfo = MySQL.query.await([[
            SELECT id, locker_id, pin_code
            FROM ox_inventory_locker_casiers
            WHERE id = ?
        ]], { casierId })

        if not casierInfo or not casierInfo[1] then
            return { success = false, message = 'Casier introuvable' }
        end

        -- Mettre à jour le nom si fourni
        if newName and type(newName) == 'string' and #newName >= Config.MinCasierNameLength and #newName <= Config.MaxCasierNameLength then
            MySQL.query.await([[
                UPDATE ox_inventory_locker_casiers
                SET label = ?
                WHERE id = ?
            ]], { newName, casierId })

            -- Mettre à jour le label du stash
            local casierStashName = 'locker_casier_' .. casierId
            exports.ox_inventory:RegisterStash(casierStashName, newName, Config.CasierSlots, Config.CasierMaxWeight)
        end

        -- Mettre à jour le code si fourni
        if newCode then
            if type(newCode) == 'string' and #newCode == Config.PinCodeLength then
                local pinPattern = string.rep('%d', Config.PinCodeLength)
                if not newCode:match('^' .. pinPattern .. '$') then
                    return { success = false, message = ('Le code PIN doit contenir %s chiffres'):format(Config.PinCodeLength) }
                end

                MySQL.query.await([[
                    UPDATE ox_inventory_locker_casiers
                    SET pin_code = ?
                    WHERE id = ?
                ]], { newCode, casierId })
            elseif newCode == json.null or newCode == '' then
                -- Supprimer le code
                MySQL.query.await([[
                    UPDATE ox_inventory_locker_casiers
                    SET pin_code = NULL
                    WHERE id = ?
                ]], { casierId })
            else
                return { success = false, message = ('Le code PIN doit contenir %s chiffres'):format(Config.PinCodeLength) }
            end
        end

        -- Mettre à jour la note si fourni
        if newNote and type(newNote) == 'string' then
            MySQL.query.await([[
                UPDATE ox_inventory_locker_casiers
                SET note = ?
                WHERE id = ?
            ]], { newNote, casierId })
        end

        return { success = true }
    end)

    if not ok then
        return { success = false, message = ('Erreur SQL: %s'):format(tostring(resultOrError)) }
    end

    return resultOrError
end)

lib.callback.register('ox_inventory:giveCasierCard', function(source, casierId)
    if not casierId or type(casierId) ~= 'number' then
        return false
    end
    
    -- Vérifier que le casier existe
    local casierInfo = MySQL.query.await([[
        SELECT id, locker_id, label
        FROM ox_inventory_locker_casiers
        WHERE id = ?
    ]], { casierId })
    
    if not casierInfo or not casierInfo[1] then
        return false
    end
    
    -- Créer une carte d'accès pour le casier
    local success = exports.ox_inventory:AddItem(source, 'locker_card', 1, {
        casierId = casierId,
        lockerId = casierInfo[1].locker_id,
        label = casierInfo[1].label or locale('default_locker_label', casierId),
        description = 'Carte d\'accès au casier'
    })
    
    return success
end)

lib.callback.register('ox_inventory:canDeleteCasier', function(source, casierId)
    if not casierId or type(casierId) ~= 'number' then
        return { canDelete = false, hasItems = false }
    end
    
    -- Vérifier que le casier existe et que le locker parent existe
    local casierInfo = MySQL.query.await([[
        SELECT id, locker_id
        FROM ox_inventory_locker_casiers
        WHERE id = ?
    ]], { casierId })
    
    if not casierInfo or not casierInfo[1] then
        return { canDelete = false, hasItems = false }
    end
    
    local casierStashName = 'locker_casier_' .. casierId
    local stash = exports.ox_inventory:GetInventory(casierStashName)
    
    if stash then
        local hasItems = false
        for _, item in pairs(stash.items) do
            if item and item.count and item.count > 0 then
                hasItems = true
                break
            end
        end
        
        return {
            canDelete = not hasItems,
            hasItems = hasItems
        }
    end
    
    return { canDelete = true, hasItems = false }
end)

lib.callback.register('ox_inventory:deleteCasier', function(source, casierId)
    if not casierId or type(casierId) ~= 'number' then
        return { success = false, message = 'ID invalide' }
    end
    
    -- Vérifier que le casier existe et que le locker parent existe
    local casierInfo = MySQL.query.await([[
        SELECT id, locker_id
        FROM ox_inventory_locker_casiers
        WHERE id = ?
    ]], { casierId })
    
    if not casierInfo or not casierInfo[1] then
        return { success = false, message = 'Casier introuvable' }
    end
    
    -- Vérifier qu'il n'y a pas d'items
    local casierStashName = 'locker_casier_' .. casierId
    local stash = exports.ox_inventory:GetInventory(casierStashName)
    
    if stash then
        for _, item in pairs(stash.items) do
            if item and item.count and item.count > 0 then
                return { success = false, message = 'Le casier contient encore des items' }
            end
        end
        
        -- Supprimer l'inventaire du stash
        exports.ox_inventory:RemoveInventory(stash)
    end
    
    -- Supprimer le casier de la base de données
    MySQL.query.await([[
        DELETE FROM ox_inventory_locker_casiers
        WHERE id = ?
    ]], { casierId })
    
    return { success = true }
end)

lib.callback.register('ox_inventory:emptyCasier', function(source, casierId)
    local casierStashName = 'locker_casier_' .. casierId
    local stash = exports.ox_inventory:GetInventory(casierStashName)
    
    if stash then
        -- Vider tous les items
        for slot, item in pairs(stash.items) do
            if item and item.count and item.count > 0 then
                exports.ox_inventory:RemoveItem(casierStashName, item.name, item.count)
            end
        end
        return { success = true }
    end
    
    return { success = false }
end)

lib.callback.register('ox_inventory:verifyCasierPin', function(source, casierId, pin)
    if not casierId or type(casierId) ~= 'number' then
        return { success = false }
    end
    
    if not pin or type(pin) ~= 'string' or #pin ~= Config.PinCodeLength then
        return { success = false }
    end
    
    local success, result = pcall(function()
        return MySQL.query.await([[
            SELECT pin_code, locker_id
            FROM ox_inventory_locker_casiers
            WHERE id = ?
        ]], { casierId })
    end)

    if success and result and result[1] then
        local storedPin = result[1].pin_code
        if not storedPin or storedPin == '' then
            return { success = true }
        end
        return { success = storedPin == pin }
    end
    return { success = false }
end)

CreateThread(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS ox_inventory_lockers (
            id INT AUTO_INCREMENT PRIMARY KEY,
            coords_x FLOAT NOT NULL,
            coords_y FLOAT NOT NULL,
            coords_z FLOAT NOT NULL,
            label VARCHAR(255),
            skip_marker TINYINT(1) NOT NULL DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]])

    local hasSkipMarker = MySQL.scalar.await([[
        SELECT COUNT(*) 
        FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE TABLE_SCHEMA = DATABASE() 
        AND TABLE_NAME = 'ox_inventory_lockers' 
        AND COLUMN_NAME = 'skip_marker'
    ]])

    if not hasSkipMarker or hasSkipMarker == 0 then
        pcall(function()
            MySQL.query([[
                ALTER TABLE ox_inventory_lockers
                ADD COLUMN skip_marker TINYINT(1) NOT NULL DEFAULT 0
            ]])
        end)
    end

    MySQL.query([[
        CREATE TABLE IF NOT EXISTS ox_inventory_locker_casiers (
            id INT AUTO_INCREMENT PRIMARY KEY,
            locker_id INT NOT NULL,
            casier_number INT NOT NULL,
            label VARCHAR(255),
            pin_code VARCHAR(4),
            note TEXT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (locker_id) REFERENCES ox_inventory_lockers(id) ON DELETE CASCADE,
            UNIQUE KEY unique_casier (locker_id, casier_number)
        )
    ]])

    Wait(100)

    local hasPinCode = MySQL.scalar.await([[
        SELECT COUNT(*) 
        FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE TABLE_SCHEMA = DATABASE() 
        AND TABLE_NAME = 'ox_inventory_locker_casiers' 
        AND COLUMN_NAME = 'pin_code'
    ]])

    if not hasPinCode or hasPinCode == 0 then
        pcall(function()
            MySQL.query([[
                ALTER TABLE ox_inventory_locker_casiers
                ADD COLUMN pin_code VARCHAR(4) NULL
            ]])
        end)
    end

    local hasNote = MySQL.scalar.await([[
        SELECT COUNT(*) 
        FROM INFORMATION_SCHEMA.COLUMNS 
        WHERE TABLE_SCHEMA = DATABASE() 
        AND TABLE_NAME = 'ox_inventory_locker_casiers' 
        AND COLUMN_NAME = 'note'
    ]])

    if not hasNote or hasNote == 0 then
        pcall(function()
            MySQL.query([[
                ALTER TABLE ox_inventory_locker_casiers
                ADD COLUMN note TEXT NULL
            ]])
        end)
    end

    Wait(100)

    local result = MySQL.query.await([[
        SELECT id, coords_x, coords_y, coords_z, label, skip_marker
        FROM ox_inventory_lockers
    ]])

    if result then
        for _, locker in ipairs(result) do
            local lockerId = locker.id
            local lockerLabel = locker.label or ('Locker #%s'):format(lockerId)
            local coords = vector3(locker.coords_x, locker.coords_y, locker.coords_z)
            
            Locker.Data[lockerId] = {
                id = lockerId,
                coords = coords,
                label = lockerLabel,
                skipMarker = locker.skip_marker == 1
            }
        end
        
        Wait(100)
        
        local casiersResult = MySQL.query.await([[
            SELECT id, locker_id, casier_number, label
            FROM ox_inventory_locker_casiers
        ]])
        
        if casiersResult then
            for _, casier in ipairs(casiersResult) do
                local casierLabel = casier.label or locale('default_locker_label', casier.casier_number)
                createLockerStash(casier.id, casierLabel)
            end
        end
        
        Wait(1000)
        for lockerId, locker in pairs(Locker.Data) do
            TriggerClientEvent('ox_inventory:lockerCreated', -1, lockerId, locker.coords, locker.label, locker.skipMarker == true)
        end
    end

    lockerDataReady = true
end)


RegisterNetEvent('ox_inventory:requestLockersSync', function()
    local src = source
    if not src or src <= 0 then return end

    local function sendLockers()
        TriggerClientEvent('ox_inventory:lockersLoaded', src, Locker.Data)
    end

    if lockerDataReady then
        sendLockers()
        return
    end

    CreateThread(function()
        local attempts = 0

        while not lockerDataReady and attempts < 50 do
            Wait(100)
            attempts = attempts + 1
        end

        if lockerDataReady then
            sendLockers()
        end
    end)
end)

lib.callback.register('ox_inventory:removeLocker', function(source, lockerId)
    if not hasLockerPermission(source) then
        return false
    end
    
    if not lockerId or type(lockerId) ~= 'number' then
        return false
    end
    
    local result = MySQL.query.await([[
        DELETE FROM ox_inventory_lockers
        WHERE id = ?
    ]], { lockerId })

    if result then
        if Locker.Data[lockerId] then
            Locker.Data[lockerId] = nil
        end
        TriggerClientEvent('ox_inventory:lockerRemoved', -1, lockerId)
        return true
    end
    return false
end)

exports('createLocker', function(coords, label)
    local result = MySQL.insert.await([[
        INSERT INTO ox_inventory_lockers (coords_x, coords_y, coords_z, label, created_at)
        VALUES (?, ?, ?, ?, NOW())
    ]], { coords.x, coords.y, coords.z, label or locale('default_locker_label', os.time()) })

    if result then
        local lockerId = result
        local lockerLabel = label or locale('default_locker_label', lockerId)
        createLockerStash(lockerId, lockerLabel)
        
        local lockerData = {
            id = lockerId,
            coords = vector3(coords.x, coords.y, coords.z),
            label = lockerLabel
        }
        
        Locker.Data[lockerId] = lockerData
        
        TriggerClientEvent('ox_inventory:lockerCreated', -1, lockerId, lockerData.coords, lockerLabel)
        return lockerId
    end
    return false
end)

return Locker

