-- ============================================================================
-- Berry Framework — Server Security System (Security, Permissions, AntiCheat & Admin)
-- ============================================================================

Berry = Berry or {}

-- ----------------------------------------------------------------------------
-- 1. Security Manager
-- ----------------------------------------------------------------------------
Berry.Security = Berry.Security or {}

local rateLimitStore = {}
local GetGameTimer = GetGameTimer
local GetPlayerPed = GetPlayerPed
local DoesEntityExist = DoesEntityExist
local GetEntityCoords = GetEntityCoords
local string_format = string.format

function Berry.Security.CheckRateLimit(source, key, limit, intervalMs)
    if not BerryConfig.Security.EnableRateLimiting then return true end

    local now = GetGameTimer()
    local userKey = string_format("%s:%s", tostring(source), key)

    if not rateLimitStore[userKey] then
        rateLimitStore[userKey] = { count = 1, resetAt = now + intervalMs }
        return true
    end

    local entry = rateLimitStore[userKey]
    if now > entry.resetAt then
        entry.count = 1
        entry.resetAt = now + intervalMs
        return true
    end

    entry.count = entry.count + 1
    if entry.count > limit then
        Berry.Logger.Warn("SECURITY", "Rate limit exceeded for player %s on action '%s' (%d/%d)", tostring(source), key, entry.count, limit)
        return false
    end

    return true
end

function Berry.Security.ValidateDistance(source, targetCoords, maxDistance)
    if not source or source <= 0 then return false end
    local ped = GetPlayerPed(source)
    if not DoesEntityExist(ped) then return false end

    local playerCoords = GetEntityCoords(ped)
    local maxDist = maxDistance or BerryConfig.Security.MaxEventDistance or 250.0
    local distSqr = Berry.Utils.CalculateDistanceSqr(playerCoords, targetCoords)

    if distSqr > (maxDist * maxDist) then
        Berry.Logger.Warn("SECURITY", "Distance validation failed for player %s", tostring(source))
        return false
    end

    return true
end

function Berry.Security.ValidateEvent(source, eventName, payload)
    if not source or source <= 0 then
        Berry.Logger.Error("SECURITY", "Event %s triggered with invalid source %s", tostring(eventName), tostring(source))
        return false
    end

    local rateLimitCfg = BerryConfig.Security.DefaultRateLimit
    if not Berry.Security.CheckRateLimit(source, eventName, rateLimitCfg.maxRequests, rateLimitCfg.intervalMs) then
        return false
    end

    return true
end

function Berry.Security.ValidatePermission(source, permission)
    return Berry.Permissions.Has(source, permission)
end

-- ----------------------------------------------------------------------------
-- 2. Permission Manager
-- ----------------------------------------------------------------------------
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

    local player = Berry.GetPlayer and Berry.GetPlayer(source)
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

-- ----------------------------------------------------------------------------
-- 3. AntiCheat Engine
-- ----------------------------------------------------------------------------
Berry.AntiCheat = Berry.AntiCheat or {}

local blacklistedWeapons = {
    [`WEAPON_RAILGUN`] = "Railgun",
    [`WEAPON_RPG`] = "RPG",
    [`WEAPON_MINIGUN`] = "Minigun",
    [`WEAPON_GRENADELAUNCHER`] = "Grenade Launcher",
    [`WEAPON_HOMINGLAUNCHER`] = "Homing Launcher",
    [`WEAPON_COMPACTLAUNCHER`] = "Compact Launcher"
}

local playerAcState = {}
local entitySpamCount = {}

local function GetPlayerAcState(src)
    src = tonumber(src)
    if not src then return nil end
    playerAcState[src] = playerAcState[src] or {
        graceUntil = GetGameTimer() + 12000,
        evidence = 0,
        lastCoords = nil,
        lastHeartbeat = GetGameTimer()
    }
    return playerAcState[src]
end

function Berry.AntiCheat.ExtendGrace(source, durationMs)
    local state = GetPlayerAcState(source)
    if state then
        state.graceUntil = math.max(state.graceUntil, GetGameTimer() + (durationMs or 8000))
        state.evidence = 0
        state.lastCoords = nil
        state.lastHeartbeat = GetGameTimer()
    end
end

function Berry.AntiCheat.BanPlayer(source, reason)
    source = tonumber(source)
    if not source or source <= 0 then return end

    if Berry.Permissions.Has(source, "admin") or Berry.Permissions.Has(source, "superadmin") then
        Berry.Logger.Warn("ANTICHEAT", "Bypass Admin pour %d (%s)", source, reason)
        return
    end

    local license = GetPlayerIdentifierByType and GetPlayerIdentifierByType(source, "license") or GetPlayerIdentifier(source, 0)
    local name = GetPlayerName(source) or "Inconnu"
    local banReason = string.format("[Berry AntiCheat] %s", reason or "Violation de sécurité")

    Berry.Logger.Error("ANTICHEAT", "BAN APPLIQUÉ -> Joueur: %s (ID: %d) | Raison: %s", name, source, reason)

    if Berry.Discord and Berry.Discord.SendLog then
        local playerInfo = Berry.Discord.GetPlayerInfo(source) .. "\n**Raison du Ban:** " .. banReason
        Berry.Discord.SendLog("AntiCheat", "🚨 BAN AUTOMATIQUE ANTICHEAT", playerInfo, "red")
    end

    if Berry.Database and Berry.Database.Ready() then
        exports.oxmysql:insert('INSERT INTO berry_bans (identifier, name, reason, banned_by) VALUES (?, ?, ?, ?)', {
            license or "unknown",
            name,
            banReason,
            "Berry AntiCheat"
        })
    end

    DropPlayer(source, banReason)
end

RegisterNetEvent("berry:ac:heartbeat", function()
    local src = source
    local st = GetPlayerAcState(src)
    if st then
        st.lastHeartbeat = GetGameTimer()
    end
end)

RegisterNetEvent("berry:ac:resourceStopped", function(reason)
    local src = source
    Berry.AntiCheat.BanPlayer(src, reason or "Tentative d'arrêt du Core détectée")
end)

RegisterNetEvent("berry:ac:violation", function(reason)
    local src = source
    local st = GetPlayerAcState(src)
    if not st or GetGameTimer() < st.graceUntil then return end

    st.evidence = st.evidence + 1
    if st.evidence >= 2 then
        Berry.AntiCheat.BanPlayer(src, reason or "Violation client détectée")
    end
end)

RegisterNetEvent("berry:ac:extendGrace", function(duration)
    local src = source
    Berry.AntiCheat.ExtendGrace(src, duration)
end)

CreateThread(function()
    while true do
        Wait(6000)
        local players = GetPlayers()
        local now = GetGameTimer()

        for _, srcStr in ipairs(players) do
            local src = tonumber(srcStr)
            if src and src > 0 then
                local st = GetPlayerAcState(src)
                if st and now > st.graceUntil then
                    if (now - st.lastHeartbeat) > 15000 then
                        Berry.AntiCheat.BanPlayer(src, "Blocage du Core / Désactivation du script client (Heartbeat timeout)")
                    end
                end
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(2500)
        local players = GetPlayers()
        local now = GetGameTimer()

        for _, srcStr in ipairs(players) do
            local src = tonumber(srcStr)
            if src and src > 0 then
                local st = GetPlayerAcState(src)
                if st and now > st.graceUntil then
                    local ped = GetPlayerPed(src)
                    if DoesEntityExist(ped) and not IsPedInAnyVehicle(ped, false) then
                        local coords = GetEntityCoords(ped)
                        if st.lastCoords then
                            local distSqr = Berry.Utils.CalculateDistanceSqr(coords, st.lastCoords)
                            if distSqr > (200.0 * 200.0) then
                                if not Berry.Permissions.Has(src, "admin") then
                                    Berry.AntiCheat.BanPlayer(src, "Téléportation à pied (" .. math.floor(math.sqrt(distSqr)) .. "m)")
                                end
                            end
                        end
                        st.lastCoords = coords
                    end
                end
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(4000)
        local players = GetPlayers()
        local now = GetGameTimer()

        for _, srcStr in ipairs(players) do
            local src = tonumber(srcStr)
            if src and src > 0 then
                local st = GetPlayerAcState(src)
                if st and now > st.graceUntil then
                    local ped = GetPlayerPed(src)
                    if DoesEntityExist(ped) then
                        local weapon = GetSelectedPedWeapon(ped)
                        if blacklistedWeapons[weapon] then
                            Berry.AntiCheat.BanPlayer(src, "Arme interdite (" .. blacklistedWeapons[weapon] .. ")")
                        end
                    end
                end
            end
        end
    end
end)

AddEventHandler("entityCreating", function(entity)
    local owner = NetworkGetEntityOwner(entity)
    if owner and owner > 0 then
        entitySpamCount[owner] = (entitySpamCount[owner] or 0) + 1
        if entitySpamCount[owner] > 10 then
            CancelEvent()
            if entitySpamCount[owner] > 20 then
                Berry.AntiCheat.BanPlayer(owner, "Spam de création d'objets (" .. entitySpamCount[owner] .. " entités/sec)")
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(1000)
        entitySpamCount = {}
    end
end)

AddEventHandler("playerDropped", function()
    local src = tonumber(source)
    if src then
        playerAcState[src] = nil
        entitySpamCount[src] = nil
    end
end)

exports("BanPlayer", Berry.AntiCheat.BanPlayer)
exports("ExtendGrace", Berry.AntiCheat.ExtendGrace)

-- ----------------------------------------------------------------------------
-- 4. Admin Commands
-- ----------------------------------------------------------------------------
RegisterCommand("kick", function(source, args)
    if source > 0 and not Berry.Permissions.Has(source, "moderator") then
        return TriggerClientEvent("berry:notify", source, "Permission refusée.", "error")
    end

    local targetSrc = tonumber(args[1])
    local reason = args[2] or "Expulsé par un modérateur."
    if targetSrc then
        DropPlayer(targetSrc, reason)
        Berry.Logger.Info("ADMIN", "Player source %d kicked by source %d", targetSrc, source)
    end
end, false)

RegisterCommand("givemoney", function(source, args)
    if source > 0 and not Berry.Permissions.Has(source, "administrator") then
        return TriggerClientEvent("berry:notify", source, "Permission refusée.", "error")
    end

    local targetSrc = tonumber(args[1])
    local account = args[2] or "cash"
    local amount = tonumber(args[3])

    local targetPlayer = Berry.GetPlayer and Berry.GetPlayer(targetSrc)
    if targetPlayer and amount then
        targetPlayer:AddMoney(account, amount, "admin_grant")
        if source > 0 then
            TriggerClientEvent("berry:notify", source, string.format("Donné %.2f$ à %s", amount, targetPlayer:GetName()), "success")
        end
    end
end, false)
