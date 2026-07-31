if not lib then return end

local MultiChest = {}
MultiChest.Markers = {}

local function createMultiChestMarker(coords, multiChestId)
    if MultiChest.Markers[multiChestId] then
        MultiChest.Markers[multiChestId]:remove()
        MultiChest.Markers[multiChestId] = nil
    end

    local point = lib.points.new({
        coords = coords,
        distance = 16,
        multiChestId = multiChestId,
        marker = {
            type = 2,
            colour = {100, 100, 200},
            scale = {0.5, 0.5, 0.5}
        },
        prompt = {
            message = ('**%s**\n%s'):format(locale('multichest_title'), locale('interact_prompt', GetControlInstructionalButton(0, 38, true):sub(3))),
            options = { icon = 'fas fa-boxes' }
        },
        nearby = function(self)
            DrawMarker(
                self.marker.type,
                self.coords.x,
                self.coords.y,
                self.coords.z - 0.5,
                0.0, 0.0, 0.0,
                0.0, 0.0, 0.0,
                self.marker.scale[1],
                self.marker.scale[2],
                self.marker.scale[3],
                self.marker.colour[1],
                self.marker.colour[2],
                self.marker.colour[3],
                222,
                false, false, 0, true, false, false, false
            )

            if self.currentDistance < 1.5 then
                if not self.hasTextUi then
                    self.hasTextUi = true
                    lib.showTextUI(self.prompt.message, self.prompt.options)
                end

                if IsControlJustReleased(0, 38) then
                    lib.hideTextUI()
                    local lockers = lib.callback.await('ox_inventory:getMultiChest', false, self.multiChestId)
                    if lockers then
                        SendNUIMessage({
                            action = 'openMultiChest',
                            data = {
                                multiChestId = self.multiChestId,
                                lockers = lockers,
                                coords = self.coords
                            }
                        })
                        SetNuiFocus(true, true)
                    end
                end
            elseif self.hasTextUi then
                self.hasTextUi = false
                lib.hideTextUI()
            end
        end
    })

    MultiChest.Markers[multiChestId] = point
    return point
end

local function loadExistingMultiChests()
    local multichests = lib.callback.await('ox_inventory:getAllMultiChests', false)
    if type(multichests) ~= 'table' then
        return
    end

    for i = 1, #multichests do
        local entry = multichests[i]
        if entry and entry.id and entry.coords then
            createMultiChestMarker(entry.coords, entry.id)
        end
    end
end

RegisterCommand('createmultichest', function()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local forwardVector = GetEntityForwardVector(playerPed)
    local markerCoords = coords + forwardVector * 2.0
    
    local found, groundZ = GetGroundZFor_3dCoord(markerCoords.x, markerCoords.y, markerCoords.z + 10.0, false)
    if found then
        markerCoords = vector3(markerCoords.x, markerCoords.y, groundZ)
    end

    local multiChestId = lib.callback.await('ox_inventory:createMultiChest', false, markerCoords)
    if multiChestId then
        lib.notify({ type = 'success', description = locale('multichest_created') })
        createMultiChestMarker(markerCoords, multiChestId)
    else
        lib.notify({ type = 'error', description = locale('multichest_error') })
    end
end, false)

RegisterNUICallback('openLocker', function(data, cb)
    cb(true)
    SetNuiFocus(false, false)
    exports.ox_inventory:openInventory('stash', data.lockerId)
end)

RegisterNUICallback('manageLocker', function(data, cb)
    cb(true)
end)

RegisterNUICallback('addLocker', function(data, cb)
    cb(true)
    local lockerId = lib.callback.await('ox_inventory:addLockerToMultiChest', false, data.multiChestId)
    if lockerId then
        lib.notify({ type = 'success', description = locale('multichest_locker_added') })
        local lockers = lib.callback.await('ox_inventory:getMultiChest', false, data.multiChestId)
        if lockers then
            SendNUIMessage({
                action = 'updateMultiChest',
                data = {
                    multiChestId = data.multiChestId,
                    lockers = lockers
                }
            })
        end
    else
        lib.notify({ type = 'error', description = locale('multichest_locker_error') })
    end
end)

RegisterNUICallback('closeMultiChest', function(data, cb)
    cb(true)
    SetNuiFocus(false, false)
end)


RegisterNetEvent('ox_inventory:multiChestCreated', function(multiChestId, coords)
    if multiChestId and coords then
        createMultiChestMarker(coords, multiChestId)
    end
end)

RegisterNetEvent('ox_inventory:multiChestRemoved', function(multiChestId)
    if MultiChest.Markers[multiChestId] then
        MultiChest.Markers[multiChestId]:remove()
        MultiChest.Markers[multiChestId] = nil
    end
end)

CreateThread(function()
    Wait(2000)
    loadExistingMultiChests()
end)

return MultiChest

