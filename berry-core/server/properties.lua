local Berry = exports["berry-core"]:GetCoreObject()

BerryProperties = BerryProperties or {}

function BerryProperties.GetAll()
    if not Berry.Database.Ready() then return {} end
    return MySQL.query.await("SELECT * FROM berry_properties") or {}
end

function BerryProperties.BuyProperty(source, propertyId)
    local player = Berry.GetPlayer(source)
    if not player then return false, "Joueur non chargé." end

    local propRow = MySQL.single.await("SELECT * FROM berry_properties WHERE id = ?", { propertyId })
    if not propRow then return false, "Propriété introuvable." end
    if propRow.owner_id ~= nil then return false, "Cette propriété appartient déjà à quelqu'un." end

    if player:GetMoney("bank") < propRow.price then
        return false, "Fonds insuffisants sur votre compte bancaire."
    end

    if player:RemoveMoney("bank", propRow.price, "property_purchase") then
        local charId = player:GetCharacterId()
        local storageId = "property_" .. propertyId

        MySQL.update.await("UPDATE berry_properties SET owner_id = ?, storage_id = ? WHERE id = ?", { charId, storageId, propertyId })

        -- Create Property Storage Inventory
        MySQL.insert.await("INSERT INTO berry_inventories (id, owner_type, owner_id, max_weight, max_slots) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE id=id", {
            storageId, "property", tostring(propertyId), 100000, 80
        })

        Berry.Logger.Info("PROPERTIES", "Personnage %d a acheté la propriété '%s' (%d) pour %d$", charId, propRow.name, propertyId, propRow.price)
        TriggerClientEvent("berry:properties:sync", -1)
        return true, "Félicitations ! Vous êtes le nouveau propriétaire."
    end

    return false, "Échec de la transaction."
end

function BerryProperties.ToggleLock(source, propertyId)
    local player = Berry.GetPlayer(source)
    if not player then return false, "Joueur non chargé." end

    local propRow = MySQL.single.await("SELECT * FROM berry_properties WHERE id = ?", { propertyId })
    if not propRow then return false, "Propriété introuvable." end

    local charId = player:GetCharacterId()
    local isAdmin = Berry.Permissions.Has(source, "admin")
    if propRow.owner_id ~= charId and not isAdmin then
        return false, "Vous n'avez pas les clés de ce logement."
    end

    local newLockState = (propRow.is_locked == 1) and 0 or 1
    MySQL.update.await("UPDATE berry_properties SET is_locked = ? WHERE id = ?", { newLockState, propertyId })

    TriggerClientEvent("berry:properties:sync", -1)
    return true, newLockState == 1 and "Logement verrouillé." or "Logement déverrouillé."
end

-- Callbacks & Net Events
Berry.RegisterServerCallback("berry:properties:getProperties", function(source, cb)
    cb(BerryProperties.GetAll())
end)

RegisterNetEvent("berry:properties:buy", function(propertyId)
    local src = source
    local ok, msg = BerryProperties.BuyProperty(src, propertyId)
    Berry.UI.Notify(src, { message = msg, type = ok and "success" or "error" })
end)

RegisterNetEvent("berry:properties:toggleLock", function(propertyId)
    local src = source
    local ok, msg = BerryProperties.ToggleLock(src, propertyId)
    Berry.UI.Notify(src, { message = msg, type = ok and "info" or "error" })
end)

RegisterNetEvent("berry:properties:enter", function(propertyId, exitCoords)
    local src = source
    SetPlayerRoutingBucket(src, tonumber(propertyId) or 1)
    if exitCoords then
        local ped = GetPlayerPed(src)
        SetEntityCoords(ped, exitCoords.x, exitCoords.y, exitCoords.z, false, false, false, false)
    end
    Berry.UI.Notify(src, { message = "Vous êtes entré dans le logement.", type = "info" })
end)

RegisterNetEvent("berry:properties:exit", function(entryCoords)
    local src = source
    SetPlayerRoutingBucket(src, 0)
    if entryCoords then
        local ped = GetPlayerPed(src)
        SetEntityCoords(ped, entryCoords.x, entryCoords.y, entryCoords.z, false, false, false, false)
    end
    Berry.UI.Notify(src, { message = "Vous êtes sorti du logement.", type = "info" })
end)

exports("BuyProperty", BerryProperties.BuyProperty)
