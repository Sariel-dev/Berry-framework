local Berry = exports["berry-core"]:GetCoreObject()

local loadedProperties = {}

local function RefreshPropertyMarkers()
    -- Clear previous property markers
    for _, prop in ipairs(loadedProperties) do
        if prop.entry_coords then
            local entry = type(prop.entry_coords) == "string" and json.decode(prop.entry_coords) or prop.entry_coords
            if entry and entry.x then
                Berry.ClientUtils.RemoveMarker("prop_entry_" .. prop.id)
            end
        end
        if prop.exit_coords then
            local exit = type(prop.exit_coords) == "string" and json.decode(prop.exit_coords) or prop.exit_coords
            if exit and exit.x then
                Berry.ClientUtils.RemoveMarker("prop_exit_" .. prop.id)
            end
        end
        if prop.storage_coords then
            local store = type(prop.storage_coords) == "string" and json.decode(prop.storage_coords) or prop.storage_coords
            if store and store.x then
                Berry.ClientUtils.RemoveMarker("prop_storage_" .. prop.id)
            end
        end
    end

    -- Fetch latest from server
    Berry.TriggerServerCallback("berry:properties:getProperties", function(properties)
        loadedProperties = properties or {}
        local pData = Berry.GetPlayerData() or {}
        local charId = pData.characterId

        for _, prop in ipairs(loadedProperties) do
            local entry = type(prop.entry_coords) == "string" and json.decode(prop.entry_coords) or prop.entry_coords
            local exit = type(prop.exit_coords) == "string" and json.decode(prop.exit_coords) or prop.exit_coords
            local store = type(prop.storage_coords) == "string" and json.decode(prop.storage_coords) or prop.storage_coords
            local isOwner = charId and prop.owner_id == charId
            local isLocked = prop.is_locked == 1

            -- Entrance Marker
            if entry and entry.x then
                local labelText = prop.label .. " (~g~" .. prop.price .. "$~s~)"
                if prop.owner_id then
                    labelText = prop.label .. (isOwner and " ~b~[Votre Propriété]~s~" or " ~r~[Occupé]~s~")
                end

                Berry.ClientUtils.AddMarker("prop_entry_" .. prop.id, {
                    coords = vector3(entry.x, entry.y, entry.z),
                    text = labelText .. "\nAppuyez sur ~g~[E]~s~ pour interagir",
                    drawDistance = 15.0,
                    interactDistance = 2.0,
                    onInteract = function()
                        if not prop.owner_id then
                            TriggerServerEvent("berry:properties:buy", prop.id)
                        elseif isOwner then
                            TriggerServerEvent("berry:properties:enter", prop.id, exit)
                        elseif not isLocked then
                            TriggerServerEvent("berry:properties:enter", prop.id, exit)
                        else
                            Berry.ClientUtils.ShowNotification("Ce logement est verrouillé à clef.", "warn")
                        end
                    end
                })
            end

            -- Exit Marker
            if exit and exit.x then
                Berry.ClientUtils.AddMarker("prop_exit_" .. prop.id, {
                    coords = vector3(exit.x, exit.y, exit.z),
                    text = "Sortie du logement\nAppuyez sur ~g~[E]~s~ pour sortir",
                    drawDistance = 15.0,
                    interactDistance = 2.0,
                    onInteract = function()
                        TriggerServerEvent("berry:properties:exit", entry)
                    end
                })
            end

            -- Storage Marker
            if store and store.x and isOwner then
                Berry.ClientUtils.AddMarker("prop_storage_" .. prop.id, {
                    coords = vector3(store.x, store.y, store.z),
                    text = "Coffre de la Maison\nAppuyez sur ~g~[E]~s~ pour ouvrir",
                    drawDistance = 10.0,
                    interactDistance = 2.0,
                    onInteract = function()
                        exports["berry-core"]:OpenInventory("property_" .. prop.id)
                    end
                })
            end
        end
    end)
end

RegisterNetEvent("berry:properties:sync", function()
    RefreshPropertyMarkers()
end)

RegisterNetEvent("berry:clientCoreReady", function()
    Wait(2000)
    RefreshPropertyMarkers()
end)
