Berry.AntiCheat = Berry.AntiCheat or {}

local blacklistedWeapons = {
    [`WEAPON_RAILGUN`] = "Railgun",
    [`WEAPON_RPG`] = "RPG",
    [`WEAPON_MINIGUN`] = "Minigun",
    [`WEAPON_GRENADELAUNCHER`] = "Grenade Launcher",
    [`WEAPON_HOMINGLAUNCHER`] = "Homing Launcher",
    [`WEAPON_COMPACTLAUNCHER`] = "Compact Launcher"
}

local playerState = {}
local entitySpamCount = {}

local function GetPlayerState(src)
    src = tonumber(src)
    if not src then return nil end
    playerState[src] = playerState[src] or {
        graceUntil = GetGameTimer() + 12000,
        evidence = 0,
        lastCoords = nil,
        lastHeartbeat = GetGameTimer()
    }
    return playerState[src]
end

function Berry.AntiCheat.ExtendGrace(source, durationMs)
    local state = GetPlayerState(source)
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

    -- Send Discord Webhook Log
    if Berry.Discord and Berry.Discord.SendLog then
        local playerInfo = Berry.Discord.GetPlayerInfo(source) .. "\n**Raison du Ban:** " .. banReason
        Berry.Discord.SendLog("AntiCheat", "🚨 BAN AUTOMATIQUE ANTICHEAT", playerInfo, "red")
    end

    if Berry.Database.Ready() then
        exports.oxmysql:insert('INSERT INTO berry_bans (identifier, name, reason, banned_by) VALUES (?, ?, ?, ?)', {
            license or "unknown",
            name,
            banReason,
            "Berry AntiCheat"
        })
    end

    DropPlayer(source, banReason)
end

-- Client Heartbeat (Anti-Core Stop / Freeze Protection)
RegisterNetEvent("berry:ac:heartbeat", function()
    local src = source
    local st = GetPlayerState(src)
    if st then
        st.lastHeartbeat = GetGameTimer()
    end
end)

-- Direct Event Trigger on Core Resource Stop Attempt
RegisterNetEvent("berry:ac:resourceStopped", function(reason)
    local src = source
    Berry.AntiCheat.BanPlayer(src, reason or "Tentative d'arrêt du Core détectée")
end)

RegisterNetEvent("berry:ac:violation", function(reason)
    local src = source
    local st = GetPlayerState(src)
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

-- Heartbeat Monitor Thread (Checks for client thread freezes or stopped core scripts)
CreateThread(function()
    while true do
        Wait(6000)
        local players = GetPlayers()
        local now = GetGameTimer()

        for _, srcStr in ipairs(players) do
            local src = tonumber(srcStr)
            if src and src > 0 then
                local st = GetPlayerState(src)
                if st and now > st.graceUntil then
                    -- If no heartbeat received in last 15 seconds, client disabled core or froze thread
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
                local st = GetPlayerState(src)
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
                local st = GetPlayerState(src)
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
        playerState[src] = nil
        entitySpamCount[src] = nil
    end
end)

exports("BanPlayer", Berry.AntiCheat.BanPlayer)
exports("ExtendGrace", Berry.AntiCheat.ExtendGrace)
