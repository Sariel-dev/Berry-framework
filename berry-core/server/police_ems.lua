local Berry = exports["berry-core"]:GetCoreObject()

-- Handcuff Command & Event
RegisterCommand("cuff", function(source, args)
    local src = source
    local targetId = tonumber(args[1])

    if not targetId then
        Berry.UI.Notify(src, { message = "Usage: /cuff [ID_Joueur]", type = "warn" })
        return
    end

    if Berry.Security.ValidateDistance(src, GetEntityCoords(GetPlayerPed(targetId)), 5.0) then
        TriggerClientEvent("berry:police:cuffToggle", targetId)
        Berry.UI.Notify(src, { message = "Action de menottage effectuée.", type = "info" })
    else
        Berry.UI.Notify(src, { message = "Joueur trop éloigné.", type = "error" })
    end
end, false)

-- Escort Command & Event
RegisterCommand("escort", function(source, args)
    local src = source
    local targetId = tonumber(args[1])

    if not targetId then
        Berry.UI.Notify(src, { message = "Usage: /escort [ID_Joueur]", type = "warn" })
        return
    end

    if Berry.Security.ValidateDistance(src, GetEntityCoords(GetPlayerPed(targetId)), 5.0) then
        TriggerClientEvent("berry:police:escort", targetId, src)
        Berry.UI.Notify(src, { message = "Action d'escorte effectuée.", type = "info" })
    end
end, false)

-- Put in / Take out of vehicle
RegisterCommand("putinveh", function(source, args)
    local src = source
    local targetId = tonumber(args[1])
    if not targetId then return end

    local ped = GetPlayerPed(src)
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then
        TriggerClientEvent("berry:police:putInVehicle", targetId, VehToNet(veh))
    end
end, false)

RegisterCommand("outveh", function(source, args)
    local src = source
    local targetId = tonumber(args[1])
    if not targetId then return end

    TriggerClientEvent("berry:police:outOfVehicle", targetId)
end, false)

-- Revive & Heal Commands (EMS / Admin)
RegisterCommand("revive", function(source, args)
    local src = source
    local targetId = tonumber(args[1]) or src

    if src > 0 and not Berry.Permissions.Has(src, "admin") then
        local pData = Berry.GetPlayerData(src)
        if not pData or (pData.job and pData.job.name ~= "ambulance") then
            Berry.UI.Notify(src, { message = "Action réservée aux EMS et Administrateurs.", type = "error" })
            return
        end
    end

    TriggerClientEvent("berry:ems:revive", targetId)
    Berry.UI.Notify(src, { message = "Joueur " .. targetId .. " réanimé.", type = "success" })
end, false)

RegisterCommand("heal", function(source, args)
    local src = source
    local targetId = tonumber(args[1]) or src

    if src > 0 and not Berry.Permissions.Has(src, "admin") then
        local pData = Berry.GetPlayerData(src)
        if not pData or (pData.job and pData.job.name ~= "ambulance") then
            Berry.UI.Notify(src, { message = "Action réservée aux EMS et Administrateurs.", type = "error" })
            return
        end
    end

    TriggerClientEvent("berry:ems:heal", targetId)
    Berry.UI.Notify(src, { message = "Joueur " .. targetId .. " soigné.", type = "success" })
end, false)
