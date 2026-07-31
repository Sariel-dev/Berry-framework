if not lib then return end

local Locker = {}
Locker.Markers = {}

local function requestLockerSync()
    TriggerServerEvent('ox_inventory:requestLockersSync')
end

CreateThread(function()
    Wait(1000)
    requestLockerSync()
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource == cache.resource then
        requestLockerSync()
    end
end)

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
}

local Utils = require 'modules.utils.client'

local openLockerList
local openLockerDetails
local createLockerFromMenu
local openLockerAdminMenu

local function hasLockerPermission()
    return lib.callback.await('ox_inventory:lockerHasPermission', false)
end

local function canAccessLocker()
    return lib.callback.await('ox_inventory:lockerCanAccess', false)
end

local function canCreateLocker()
    return lib.callback.await('ox_inventory:lockerCanCreate', false)
end

local function formatLockerLabel(lockerId, label)
    return ('%s (#%s)'):format(label or locale('locker'), lockerId)
end

local function teleportToLocker(locker)
    if not locker or not locker.coords then
        return
    end
    
    SetEntityCoords(PlayerPedId(), locker.coords.x, locker.coords.y, locker.coords.z, false, false, false, true)
    lib.notify({ type = 'success', description = locale('locker_admin_teleport_success', formatLockerLabel(locker.id, locker.label)) })
end

local function deleteLocker(locker)
    if not locker or not locker.id then
        return
    end
    
    local alert = lib.alertDialog({
        header = locale('locker_admin_delete_title'),
        content = locale('locker_admin_delete_confirm', formatLockerLabel(locker.id, locker.label)),
        centered = true,
        cancel = true,
        labels = {
            confirm = locale('locker_admin_delete'),
            cancel = locale('ui_cancel')
        }
    })
    
    if alert ~= 'confirm' then
        return
    end
    
    local success = lib.callback.await('ox_inventory:removeLocker', false, locker.id)
    lib.notify({
        type = success and 'success' or 'error',
        description = success and locale('locker_admin_delete_success') or locale('locker_admin_delete_error')
    })
    
    if success then
        SetTimeout(200, openLockerList)
    end
end
 
openLockerDetails = function(locker)
    if not locker then
        return
    end
    
    lib.registerContext({
        id = 'locker_admin_details',
        title = formatLockerLabel(locker.id, locker.label),
        menu = 'locker_admin_list',
        options = {
            {
                title = locale('locker_admin_teleport'),
                description = locale('locker_admin_teleport_desc'),
                icon = 'location-dot',
                onSelect = function()
                    teleportToLocker(locker)
                end
            },
            {
                title = locale('locker_admin_delete'),
                description = locale('locker_admin_delete_desc'),
                icon = 'trash',
                onSelect = function()
                    deleteLocker(locker)
                end
            }
        }
    })
    
    lib.showContext('locker_admin_details')
end

openLockerList = function()
    if not hasLockerPermission() then
        return lib.notify({ type = 'error', description = locale('locker_admin_no_permission') })
    end
    
    local lockers = lib.callback.await('ox_inventory:getAllLockers', false) or {}
    
    if not lockers[1] then
        return lib.notify({ type = 'error', description = locale('locker_admin_no_lockers') })
    end
    
    local options = {}
    for i = 1, #lockers do
        local locker = lockers[i]
        options[#options + 1] = {
            title = formatLockerLabel(locker.id, locker.label),
            description = ('X: %.2f | Y: %.2f | Z: %.2f'):format(locker.coords.x, locker.coords.y, locker.coords.z),
            icon = 'box-archive',
            onSelect = function()
                openLockerDetails(locker)
            end
        }
    end
    
    options[#options + 1] = {
        title = locale('locker_admin_refresh'),
        icon = 'rotate',
        onSelect = openLockerList
    }
    
    lib.registerContext({
        id = 'locker_admin_list',
        title = locale('locker_admin_manage_title'),
        menu = 'locker_admin_main',
        options = options
    })
    
    lib.showContext('locker_admin_list')
end

createLockerFromMenu = function()
    if not hasLockerPermission() then
        return lib.notify({ type = 'error', description = locale('locker_admin_no_permission') })
    end
    
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local markerCoords = vector3(coords.x, coords.y, coords.z - 1.0)
    
    local input = lib.inputDialog(locale('locker_admin_create_title'), {
        { label = locale('locker_number'), type = 'input', required = false, placeholder = locale('locker_name_optional') }
    })
    
    if not input then
        return
    end
    
    local label = input[1] and input[1] ~= '' and input[1] or nil
    local lockerId = lib.callback.await('ox_inventory:createLocker', false, markerCoords, label)
    if type(lockerId) == 'number' then
        lib.notify({ type = 'success', description = locale('locker_created_success', (label or locale('locker'))) })
    else
        lib.notify({ type = 'error', description = locale('locker_create_error') })
    end
end

openLockerAdminMenu = function()
    if not hasLockerPermission() then
        return lib.notify({ type = 'error', description = locale('locker_admin_no_permission') })
    end
    
    lib.registerContext({
        id = 'locker_admin_main',
        title = locale('locker_admin_menu_title'),
        options = {
            {
                title = locale('locker_admin_create'),
                description = locale('locker_admin_create_desc'),
                icon = 'plus',
                onSelect = createLockerFromMenu
            },
            {
                title = locale('locker_admin_manage'),
                description = locale('locker_admin_manage_desc'),
                icon = 'boxes-stacked',
                onSelect = openLockerList
            },
            {
                title = locale('locker_admin_close'),
                icon = 'xmark',
                onSelect = function()
                    lib.hideContext()
                end
            }
        }
    })
    
    lib.showContext('locker_admin_main')
end

local function createLockerMarker(coords, lockerId, label)
    if not coords or not lockerId then
        return
    end

    if Locker.Markers[lockerId] then
        Locker.Markers[lockerId]:remove()
        Locker.Markers[lockerId] = nil
    end

    local prompt = {
        message = ('**%s**\n%s'):format(label or locale('locker'), locale('interact_prompt', GetControlInstructionalButton(0, 38, true):sub(3))),
        options = { icon = 'fas fa-box' }
    }

    local point = lib.points.new({
        coords = coords,
        distance = Config.MarkerDistance,
        lockerId = lockerId,
        label = label or locale('locker'),
        inv = 'locker',
        invId = lockerId,
        prompt = prompt,
        marker = client.craftingmarker,
        nearby = Utils.nearbyMarker
    })

    Locker.Markers[lockerId] = point
    return point
end

RegisterNetEvent('ox_inventory:lockerCreated', function(lockerId, coords, label, skipMarker)
    if Locker.Markers[lockerId] then
        Locker.Markers[lockerId]:remove()
        Locker.Markers[lockerId] = nil
    end

    if skipMarker == true then
        return
    end

    createLockerMarker(coords, lockerId, label)
end)

RegisterNetEvent('ox_inventory:lockerRemoved', function(lockerId)
    if Locker.Markers[lockerId] then
        Locker.Markers[lockerId]:remove()
        Locker.Markers[lockerId] = nil
    end
end)

RegisterNetEvent('ox_inventory:lockersLoaded', function(lockers)
    if type(lockers) ~= 'table' then return end

    for key, locker in pairs(lockers) do
        if locker and locker.coords then
            local lockerId = locker.id or key
            if locker.skipMarker ~= true then
                createLockerMarker(locker.coords, lockerId, locker.label)
            elseif Locker.Markers[lockerId] then
                Locker.Markers[lockerId]:remove()
                Locker.Markers[lockerId] = nil
            end
        end
    end
end)
RegisterCommand('lockeradmin', function()
    openLockerAdminMenu()
end, false)

RegisterNUICallback('getLockers', function(data, cb)
    local lockerId = data and data.lockerId
    if not lockerId or type(lockerId) ~= 'number' then
        cb({})
        return
    end
    
    if not canAccessLocker() then
        cb({})
        return
    end
    
    -- Vérifier que le lockerId correspond au locker actuellement ouvert
    local currentLockerId = LocalPlayer.state.currentLockerId
    if currentLockerId and currentLockerId ~= lockerId then
        cb({})
        return
    end
    
    local casiersData = lib.callback.await('ox_inventory:getCasiersFromLocker', false, lockerId)
    cb(casiersData or {})
end)

RegisterNUICallback('openLockerFromUI', function(data, cb)
    cb(true)
    
    if not data or not data.casierId or type(data.casierId) ~= 'string' then
        return
    end
    
    -- Vérifier que le casierId a le bon format
    if not data.casierId:match('^locker_casier_%d+$') then
        return
    end
    
    exports.ox_inventory:openInventory('stash', data.casierId)
end)

RegisterNUICallback('getCurrentLockerId', function(data, cb)
    local lockerId = LocalPlayer.state.currentLockerId
    cb(lockerId)
end)

RegisterNUICallback('manageCasier', function(data, cb)
    cb(true)
    
    if not data or not data.casierId or type(data.casierId) ~= 'number' then
        return
    end
    
    SendNUIMessage({
        action = 'showCasierManage',
        data = { casierId = data.casierId }
    })
end)

RegisterNUICallback('casierNeedsPin', function(data, cb)
    if not data or not data.casierId or type(data.casierId) ~= 'number' then
        cb(false)
        return
    end
    
    local result = lib.callback.await('ox_inventory:getCasierInfo', false, data.casierId)
    cb(result and result.hasCode or false)
end)

RegisterNUICallback('verifyCasierPin', function(data, cb)
    if not data or not data.casierId or type(data.casierId) ~= 'number' then
        cb({ success = false })
        return
    end
    
    local pinPattern = string.rep('%d', Config.PinCodeLength)
    if not data.pin or type(data.pin) ~= 'string' or #data.pin ~= Config.PinCodeLength or not data.pin:match('^' .. pinPattern .. '$') then
        cb({ success = false })
        return
    end
    
    local result = lib.callback.await('ox_inventory:verifyCasierPin', false, data.casierId, data.pin)
    cb(result)
end)

RegisterNUICallback('getCasierInfo', function(data, cb)
    if not data or not data.casierId or type(data.casierId) ~= 'number' then
        cb({ hasCode = false })
        return
    end
    
    local result = lib.callback.await('ox_inventory:getCasierInfo', false, data.casierId)
    cb(result)
end)

RegisterNUICallback('setCasierPin', function(data, cb)
    if not data or not data.casierId or type(data.casierId) ~= 'number' then
        cb(false)
        return
    end
    
    local pinPattern = string.rep('%d', Config.PinCodeLength)
    if not data.pin or type(data.pin) ~= 'string' or #data.pin ~= Config.PinCodeLength or not data.pin:match('^' .. pinPattern .. '$') then
        cb(false)
        return
    end
    
    lib.callback.await('ox_inventory:setCasierPin', false, data.casierId, data.pin)
    cb(true)
end)

RegisterNUICallback('removeCasierPin', function(data, cb)
    if not data or not data.casierId or type(data.casierId) ~= 'number' then
        cb(false)
        return
    end
    
    lib.callback.await('ox_inventory:removeCasierPin', false, data.casierId)
    cb(true)
end)

RegisterNUICallback('renameCasier', function(data, cb)
    if not data or not data.casierId or type(data.casierId) ~= 'number' then
        cb(false)
        return
    end
    
    if not data.newName or type(data.newName) ~= 'string' or #data.newName < Config.MinCasierNameLength or #data.newName > Config.MaxCasierNameLength then
        cb(false)
        return
    end
    
    local result = lib.callback.await('ox_inventory:renameCasier', false, data.casierId, data.newName)
    cb(result)
end)

RegisterNUICallback('canDeleteCasier', function(data, cb)
    if not data or not data.casierId or type(data.casierId) ~= 'number' then
        cb({ canDelete = false, hasItems = false })
        return
    end
    
    local result = lib.callback.await('ox_inventory:canDeleteCasier', false, data.casierId)
    if result and result.hasItems and not result.canDelete then
        lib.notify({ type = 'error', description = locale('locker_delete_has_items') })
    end
    cb(result)
end)

RegisterNUICallback('deleteCasier', function(data, cb)
    if not data or not data.casierId or type(data.casierId) ~= 'number' then
        cb({ success = false })
        return
    end
    
    local result = lib.callback.await('ox_inventory:deleteCasier', false, data.casierId)
    if result and result.success then
        lib.notify({ type = 'success', description = locale('locker_delete_success') })
    end
    cb(result)
end)

RegisterNUICallback('emptyCasier', function(data, cb)
    local result = lib.callback.await('ox_inventory:emptyCasier', false, data.casierId)
    if result and result.success then
        lib.notify({ type = 'success', description = locale('locker_empty_success') })
    end
    cb(result)
end)

RegisterNUICallback('createLockerFromUI', function(data, cb)
    cb(true)
    
    local lockerId = data and data.lockerId
    if not lockerId or type(lockerId) ~= 'number' then
        return
    end
    
    if not canCreateLocker() then
        lib.notify({ type = 'error', description = locale('locker_admin_no_permission') })
        return
    end
    
    -- Vérifier que le lockerId correspond au locker actuellement ouvert
    local currentLockerId = LocalPlayer.state.currentLockerId
    if currentLockerId and currentLockerId ~= lockerId then
        lib.notify({ type = 'error', description = locale('locker_invalid_error') })
        return
    end
    
    local newCasier = lib.callback.await('ox_inventory:addCasierToLocker', false, lockerId)
    if newCasier then
        lib.notify({ type = 'success', description = locale('locker_created_success', locale('locker')) })
        local casiersData = lib.callback.await('ox_inventory:getCasiersFromLocker', false, lockerId)
        SendNUIMessage({
            action = 'setLockers',
            data = casiersData or {}
        })
    else
        lib.notify({ type = 'error', description = locale('locker_create_error') })
    end
end)

RegisterNUICallback('updateCasierInfo', function(data, cb)
    cb(true)
    
    local casierId = data and data.casierId
    if not casierId or type(casierId) ~= 'number' then
        return
    end
    
    local result = lib.callback.await('ox_inventory:updateCasierInfo', false, casierId, data.name, data.code, data.note)
    if result and result.success then
        lib.notify({ type = 'success', description = locale('locker_updated_success') })
        
        -- Rafraîchir la liste des casiers
        local currentLockerId = LocalPlayer.state.currentLockerId
        if currentLockerId then
            local casiersData = lib.callback.await('ox_inventory:getCasiersFromLocker', false, currentLockerId)
            SendNUIMessage({
                action = 'setLockers',
                data = casiersData or {}
            })
        end
    else
        local errorReason = (result and result.message) or locale('locker_update_error')
        lib.notify({ type = 'error', description = errorReason })
    end
end)

RegisterNUICallback('giveCasierCard', function(data, cb)
    cb(true)
    
    local casierId = data and data.casierId
    if not casierId or type(casierId) ~= 'number' then
        return
    end
    
    local result = lib.callback.await('ox_inventory:giveCasierCard', false, casierId)
    if result then
        lib.notify({ type = 'success', description = locale('card_created_success') })
    else
        lib.notify({ type = 'error', description = locale('card_create_error') })
    end
end)

exports('createLockerMarker', function(coords, lockerId, label)
    return createLockerMarker(coords, lockerId, label)
end)

return Locker
