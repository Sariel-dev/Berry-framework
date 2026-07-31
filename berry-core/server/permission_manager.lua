Berry.Permissions = Berry.Permissions or {}

local playerPermissions = {}

function Berry.Permissions.Set(source, role)
    role = tostring(role or "citoyen"):lower()
    if BerryConstants.PermissionHierarchy[role] == nil then
        Berry.Logger.Warn("PERMISSIONS", "Rôle inconnu '%s' pour le joueur %s", role, tostring(source))
        return false
    end

    playerPermissions[source] = role
    Berry.Logger.Info("PERMISSIONS", "Permission du joueur %s définie sur '%s'", tostring(source), role)

    local player = Berry.GetPlayer(source)
    if player then
        player:SetData("group", role)
    end

    return true
end

function Berry.Permissions.Get(source)
    return playerPermissions[source] or "citoyen"
end

function Berry.Permissions.Has(source, requiredPermission)
    local playerRole = Berry.Permissions.Get(source)
    local playerLevel = BerryConstants.PermissionHierarchy[playerRole] or 0
    local requiredLevel = BerryConstants.PermissionHierarchy[tostring(requiredPermission):lower()] or 99

    return playerLevel >= requiredLevel
end

-- Command /setgroup [ID] [GROUPE]
RegisterCommand("setgroup", function(source, args)
    if source > 0 and not Berry.Permissions.Has(source, "fondateur") then
        Berry.UI.Notify(source, { message = "Seuls les Fondateurs peuvent utiliser /setgroup.", type = "error" })
        return
    end

    local targetId = tonumber(args[1])
    local group = args[2]

    if not targetId or not group then
        local msg = "Usage: /setgroup [ID] [citoyen | helper | moderateur | administrateur | co_fondateur | fondateur]"
        if source > 0 then Berry.UI.Notify(source, { message = msg, type = "warn" }) else print(msg) end
        return
    end

    if Berry.Permissions.Set(targetId, group) then
        local msg = string.format("Le groupe du joueur %d a été défini sur '%s'.", targetId, group)
        if source > 0 then Berry.UI.Notify(source, { message = msg, type = "success" }) else print(msg) end
        Berry.UI.Notify(targetId, { message = "Vos permissions ont été mises à jour: " .. group, type = "info" })

        -- Discord Webhook Log
        if Berry.Discord and Berry.Discord.SendLog then
            local executor = source > 0 and Berry.Discord.GetPlayerInfo(source) or "Console Serveur"
            local targetInfo = Berry.Discord.GetPlayerInfo(targetId)
            local logMsg = string.format("👤 **Exécuteur:** %s\n🎯 **Cible:** %s\n👑 **Nouveau Groupe:** `%s`", executor, targetInfo, group)
            Berry.Discord.SendLog("SetGroup", "👑 CHANGEMENT DE RANG PERMISSION", logMsg, "purple")
        end
    end
end, false)

AddEventHandler("playerDropped", function(reason)
    local src = source
    playerPermissions[src] = nil
end)

exports("SetPermission", Berry.Permissions.Set)
exports("GetPermission", Berry.Permissions.Get)
exports("HasPermission", Berry.Permissions.Has)
