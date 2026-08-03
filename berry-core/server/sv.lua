-- ============================================================================
-- Berry Framework — Master Server Engine (sv.lua)
-- ============================================================================

Berry = Berry or {}

-- Enable Lua 5.4 Generational Garbage Collector for maximum throughput
if collectgarbage then
    pcall(function()
        collectgarbage("generational")
        collectgarbage("setpause", 110)
        collectgarbage("setstepmul", 300)
    end)
end

-- ============================================================================
-- SECTION 1: Infrastructure (Logger, Discord Logger, DB, Cache, Events, Callbacks, State, Modules, Bridges)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Logger System
-- ----------------------------------------------------------------------------
Berry.Logger = {}

local LogLevels = BerryConstants.LogLevels
local ConfigLevel = LogLevels[BerryConfig.Framework.LogLevel:sub(1,1):upper() .. BerryConfig.Framework.LogLevel:sub(2)] or LogLevels.Info

local function FormatMessage(category, levelStr, message, ...)
    local prefix = string.format("[BERRY:%s] [%s]", category:upper(), levelStr)
    local formatted = message
    if select('#', ...) > 0 then
        formatted = string.format(message, ...)
    end
    return string.format("%s %s", prefix, formatted)
end

function Berry.Logger.Debug(category, message, ...)
    if ConfigLevel <= LogLevels.Debug then
        print("^5" .. FormatMessage(category, "DEBUG", message, ...) .. "^7")
    end
end

function Berry.Logger.Info(category, message, ...)
    if ConfigLevel <= LogLevels.Info then
        print("^2" .. FormatMessage(category, "INFO", message, ...) .. "^7")
    end
end

function Berry.Logger.Warn(category, message, ...)
    if ConfigLevel <= LogLevels.Warn then
        print("^3" .. FormatMessage(category, "WARN", message, ...) .. "^7")
    end
end

function Berry.Logger.Error(category, message, ...)
    if ConfigLevel <= LogLevels.Error then
        print("^1" .. FormatMessage(category, "ERROR", message, ...) .. "^7")
    end
end

-- ----------------------------------------------------------------------------
-- Discord Logger System
-- ----------------------------------------------------------------------------
Berry.Discord = Berry.Discord or {}

local discordColors = {
    red = 16711680,      -- AntiCheat / Ban (#FF0000)
    purple = 11030519,   -- SetGroup / Staff (#A855F7)
    orange = 16753920,   -- Admin Action (#FFA500)
    green = 65280,       -- Economy / Transaction (#00FF00)
    blue = 39423,        -- Inventory (#0099FF)
    cyan = 65535,        -- Properties (#00FFFF)
    grey = 8421504       -- Connections (#808080)
}

function Berry.Discord.SendLog(category, title, description, colorKey, fields)
    if not BerryConfig.DiscordWebhooks or not BerryConfig.DiscordWebhooks.Enabled then return end

    local webhookUrl = BerryConfig.DiscordWebhooks.Webhooks[category]
    if not webhookUrl or webhookUrl == "" then return end

    local embedColor = discordColors[colorKey] or discordColors.purple

    local embed = {
        {
            title = title or "Log Berry Framework",
            description = description or "",
            color = embedColor,
            footer = {
                text = (BerryConfig.DiscordWebhooks.ServerName or "Berry RP") .. " • " .. os.date("%d/%m/%Y à %H:%M:%S")
            },
            fields = fields or {}
        }
    }

    local payload = json.encode({
        username = "Berry Logs - " .. (category:upper()),
        avatar_url = BerryConfig.DiscordWebhooks.AvatarUrl,
        embeds = embed
    })

    PerformHttpRequest(webhookUrl, function(err, text, headers) end, 'POST', payload, { ['Content-Type'] = 'application/json' })
end

function Berry.Discord.GetPlayerInfo(src)
    if not src or src <= 0 then return "Console / Système" end
    local name = GetPlayerName(src) or "Inconnu"
    local license = GetPlayerIdentifierByType and GetPlayerIdentifierByType(src, "license") or "N/A"
    local discord = GetPlayerIdentifierByType and GetPlayerIdentifierByType(src, "discord") or "N/A"
    return string.format("**Joueur:** %s (ID: %d)\n**Licence:** `%s`\n**Discord:** `%s`", name, src, license, discord)
end

AddEventHandler("playerConnecting", function(name, setKickReason, deferrals)
    local src = source
    Berry.Discord.SendLog("Connections", "📥 Connexion Joueur", Berry.Discord.GetPlayerInfo(src), "grey")
end)

AddEventHandler("playerDropped", function(reason)
    local src = source
    local info = Berry.Discord.GetPlayerInfo(src) .. "\n**Raison:** " .. tostring(reason or "Déconnexion normale")
    Berry.Discord.SendLog("Connections", "📤 Déconnexion Joueur", info, "grey")
end)

exports("SendDiscordLog", Berry.Discord.SendLog)

-- ----------------------------------------------------------------------------
-- Database Manager
-- ----------------------------------------------------------------------------
Berry.Database = {}

local SlowQueryThreshold = BerryConfig.Database.SlowQueryThresholdMs or 100

function Berry.Database.Ready()
    return MySQL and MySQL.ready ~= nil
end

function Berry.Database.Query(query, params)
    local startTime = GetGameTimer()
    local result = MySQL.query.await(query, params or {})
    local duration = GetGameTimer() - startTime

    if duration >= SlowQueryThreshold then
        Berry.Logger.Warn("DATABASE", "Slow Query (%d ms): %s", duration, query)
    end

    return result
end

function Berry.Database.Scalar(query, params)
    local startTime = GetGameTimer()
    local result = MySQL.scalar.await(query, params or {})
    local duration = GetGameTimer() - startTime

    if duration >= SlowQueryThreshold then
        Berry.Logger.Warn("DATABASE", "Slow Query (%d ms): %s", duration, query)
    end

    return result
end

function Berry.Database.Single(query, params)
    local startTime = GetGameTimer()
    local result = MySQL.single.await(query, params or {})
    local duration = GetGameTimer() - startTime

    if duration >= SlowQueryThreshold then
        Berry.Logger.Warn("DATABASE", "Slow Query (%d ms): %s", duration, query)
    end

    return result
end

function Berry.Database.Insert(query, params)
    local startTime = GetGameTimer()
    local result = MySQL.insert.await(query, params or {})
    local duration = GetGameTimer() - startTime

    if duration >= SlowQueryThreshold then
        Berry.Logger.Warn("DATABASE", "Slow Query (%d ms): %s", duration, query)
    end

    return result
end

function Berry.Database.Update(query, params)
    local startTime = GetGameTimer()
    local result = MySQL.update.await(query, params or {})
    local duration = GetGameTimer() - startTime

    if duration >= SlowQueryThreshold then
        Berry.Logger.Warn("DATABASE", "Slow Query (%d ms): %s", duration, query)
    end

    return result
end

function Berry.Database.Transaction(queries, params)
    local startTime = GetGameTimer()
    local result = MySQL.transaction.await(queries, params or {})
    local duration = GetGameTimer() - startTime

    if duration >= SlowQueryThreshold then
        Berry.Logger.Warn("DATABASE", "Slow Transaction (%d ms)", duration)
    end

    return result
end

-- ----------------------------------------------------------------------------
-- Cache Manager
-- ----------------------------------------------------------------------------
Berry.Cache = {}

local cacheStore = {}

function Berry.Cache.Set(key, value, ttlSeconds)
    local expiry = ttlSeconds and (os.time() + ttlSeconds) or nil
    cacheStore[key] = {
        value = value,
        expiry = expiry
    }
end

function Berry.Cache.Get(key)
    local entry = cacheStore[key]
    if not entry then return nil end

    if entry.expiry and os.time() > entry.expiry then
        cacheStore[key] = nil
        return nil
    end

    return entry.value
end

function Berry.Cache.Invalidate(key)
    cacheStore[key] = nil
end

function Berry.Cache.Clear()
    cacheStore = {}
end

function Berry.Cache.Cleanup()
    local now = os.time()
    local count = 0
    for k, v in pairs(cacheStore) do
        if v.expiry and now > v.expiry then
            cacheStore[k] = nil
            count = count + 1
        end
    end
    if count > 0 then
        Berry.Logger.Debug("CACHE", "Cleaned up %d expired cache items.", count)
    end
end

-- ----------------------------------------------------------------------------
-- Event Manager
-- ----------------------------------------------------------------------------
Berry.Events = Berry.Events or {}

local registeredEvents = {}

function Berry.Events.On(eventName, callback)
    local fullEventName = eventName:find("^berry:") and eventName or ("berry:" .. eventName)
    
    if not registeredEvents[fullEventName] then
        registeredEvents[fullEventName] = {}
        RegisterNetEvent(fullEventName, function(...)
            local src = source
            if src and src > 0 then
                if Berry.Security and not Berry.Security.ValidateEvent(src, fullEventName, {...}) then
                    return
                end
            end
            for _, handler in ipairs(registeredEvents[fullEventName]) do
                handler(src, ...)
            end
        end)
    end

    table.insert(registeredEvents[fullEventName], callback)
    Berry.Logger.Debug("EVENTS", "Registered event handler for '%s'", fullEventName)
end

function Berry.Events.Emit(eventName, ...)
    local fullEventName = eventName:find("^berry:") and eventName or ("berry:" .. eventName)
    TriggerEvent(fullEventName, ...)
end

function Berry.Events.EmitClient(eventName, target, ...)
    local fullEventName = eventName:find("^berry:") and eventName or ("berry:" .. eventName)
    TriggerClientEvent(fullEventName, target, ...)
end

-- ----------------------------------------------------------------------------
-- Callback Manager
-- ----------------------------------------------------------------------------
Berry.Callbacks = Berry.Callbacks or {}

local serverCallbacks = {}
local clientCallbackId = 0
local clientCallbacks = {}

function Berry.Callbacks.Register(name, callback)
    local fullCallbackName = name:find("^berry:") and name or ("berry:cb:" .. name)
    serverCallbacks[fullCallbackName] = callback
    Berry.Logger.Debug("CALLBACKS", "Registered server callback '%s'", fullCallbackName)
end

RegisterNetEvent("berry:triggerServerCallback", function(name, requestId, ...)
    local src = source
    local fullCallbackName = name:find("^berry:") and name or ("berry:cb:" .. name)

    if Berry.Security and not Berry.Security.ValidateEvent(src, fullCallbackName, {...}) then
        return
    end

    local cb = serverCallbacks[fullCallbackName]
    if not cb then
        Berry.Logger.Warn("CALLBACKS", "Server callback '%s' requested by player %s does not exist.", fullCallbackName, tostring(src))
        return
    end

    cb(src, function(...)
        TriggerClientEvent("berry:serverCallbackResponse", src, requestId, ...)
    end, ...)
end)

function Berry.Callbacks.TriggerClient(source, name, callback, ...)
    clientCallbackId = clientCallbackId + 1
    local requestId = clientCallbackId
    clientCallbacks[requestId] = callback

    TriggerClientEvent("berry:triggerClientCallback", source, name, requestId, ...)
end

RegisterNetEvent("berry:clientCallbackResponse", function(requestId, ...)
    local cb = clientCallbacks[requestId]
    if cb then
        clientCallbacks[requestId] = nil
        cb(...)
    end
end)

-- ----------------------------------------------------------------------------
-- State Manager
-- ----------------------------------------------------------------------------
Berry.State = Berry.State or {}

function Berry.State.SetPlayerState(source, key, value, replicated)
    local playerState = Player(source).state
    if playerState then
        playerState:set(key, value, replicated or false)
    end
end

function Berry.State.GetPlayerState(source, key)
    local playerState = Player(source).state
    if playerState then
        return playerState[key]
    end
    return nil
end

function Berry.State.SetEntityState(entity, key, value, replicated)
    if DoesEntityExist(entity) then
        local entityState = Entity(entity).state
        if entityState then
            entityState:set(key, value, replicated or false)
        end
    end
end

function Berry.State.GetEntityState(entity, key)
    if DoesEntityExist(entity) then
        local entityState = Entity(entity).state
        if entityState then
            return entityState[key]
        end
    end
    return nil
end

-- ----------------------------------------------------------------------------
-- Module Manager
-- ----------------------------------------------------------------------------
Berry.ModuleManager = {}

local registeredModules = {}
local moduleLoadOrder = {}

function Berry.ModuleManager.RegisterModule(name, options)
    if registeredModules[name] then
        Berry.Logger.Warn("MODULE", "Module '%s' is already registered.", name)
        return false
    end

    local moduleData = {
        name = name,
        version = options.version or "1.0.0",
        dependencies = options.dependencies or {},
        onInit = options.onInit,
        onStart = options.onStart,
        onStop = options.onStop,
        loaded = false
    }

    registeredModules[name] = moduleData
    table.insert(moduleLoadOrder, name)
    Berry.Logger.Info("MODULE", "Registered module '%s' (v%s)", name, moduleData.version)
    return true
end

function Berry.ModuleManager.LoadAll()
    for _, name in ipairs(moduleLoadOrder) do
        local mod = registeredModules[name]
        if mod and not mod.loaded then
            local depsMet = true
            for _, dep in ipairs(mod.dependencies) do
                if not registeredModules[dep] or not registeredModules[dep].loaded then
                    Berry.Logger.Error("MODULE", "Cannot load module '%s': Missing dependency '%s'", name, dep)
                    depsMet = false
                    break
                end
            end

            if depsMet then
                if type(mod.onInit) == "function" then
                    mod.onInit()
                end
                if type(mod.onStart) == "function" then
                    mod.onStart()
                end
                mod.loaded = true
                Berry.Logger.Info("MODULE", "Module '%s' successfully started.", name)
            end
        end
    end
end

function Berry.ModuleManager.GetModules()
    return registeredModules
end

-- ----------------------------------------------------------------------------
-- ESX Compatibility Bridge
-- ----------------------------------------------------------------------------
ESX = ESX or {}

function ESX.GetPlayerFromId(source)
    local berryPlayer = Berry.GetPlayer and Berry.GetPlayer(source)
    if not berryPlayer then return nil end

    return {
        source = berryPlayer:GetSource(),
        identifier = berryPlayer:GetIdentifier(),
        getName = function() return berryPlayer:GetName() end,
        getMoney = function() return berryPlayer:GetMoney("cash") end,
        addMoney = function(amount) return berryPlayer:AddMoney("cash", amount, "esx_bridge") end,
        removeMoney = function(amount) return berryPlayer:RemoveMoney("cash", amount, "esx_bridge") end,
        getAccount = function(name) return { name = name, money = berryPlayer:GetMoney(name) } end,
        addAccountMoney = function(name, amount) return berryPlayer:AddMoney(name, amount, "esx_bridge") end,
        removeAccountMoney = function(name, amount) return berryPlayer:RemoveMoney(name, amount, "esx_bridge") end,
        getJob = function() return berryPlayer:GetJob() end,
        setJob = function(job, grade) return berryPlayer:SetJob(job, grade) end
    }
end

function ESX.RegisterServerCallback(name, cb)
    Berry.Callbacks.Register(name, cb)
end

AddEventHandler("esx:getSharedObject", function(cb)
    cb(ESX)
end)

exports("getSharedObject", function()
    return ESX
end)

-- ----------------------------------------------------------------------------
-- Interim Job Events & DevTools Metrics
-- ----------------------------------------------------------------------------
RegisterNetEvent("berry:interim:completeDelivery", function()
    local src = source
    local player = Berry.GetPlayer and Berry.GetPlayer(src)
    if not player then return end

    local reward = math.random(350, 650)
    player:AddMoney("cash", reward, "interim_delivery")
    Berry.UI.Notify(src, { message = "Livraison effectuée avec succès ! Vous avez reçu " .. reward .. "$ en liquide.", type = "success" })
end)

RegisterCommand("berrystats", function(source)
    if source > 0 and not Berry.Permissions.Has(source, "administrator") then
        return
    end

    local count = 0
    if Berry.PlayersBySource then
        for _ in pairs(Berry.PlayersBySource) do count = count + 1 end
    end

    local msg = string.format("[BERRY METRICS] Active Players: %d | Memory Usage: %.2f KB", count, collectgarbage("count"))
    if source > 0 then
        TriggerClientEvent("berry:notify", source, msg, "info")
    else
        print("^2" .. msg .. "^7")
    end
end, false)

-- ============================================================================
-- SECTION 2: Security, Permissions, AntiCheat & Admin Commands
-- ============================================================================

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
-- Permission Manager
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
-- AntiCheat Engine
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
        graceUntil = GetGameTimer() + 90000,
        evidence = 0,
        lastCoords = nil,
        lastHeartbeat = GetGameTimer(),
        hasStartedHeartbeat = false
    }
    return playerAcState[src]
end

function Berry.AntiCheat.ExtendGrace(source, durationMs)
    local state = GetPlayerAcState(source)
    if state then
        state.graceUntil = math.max(state.graceUntil, GetGameTimer() + (durationMs or 15000))
        state.evidence = 0
        state.lastCoords = nil
        state.lastHeartbeat = GetGameTimer()
    end
end

function Berry.AntiCheat.BanPlayer(source, reason)
    source = tonumber(source)
    if not source or source <= 0 then return end

    if Berry.Permissions.Has(source, "admin") or Berry.Permissions.Has(source, "superadmin") or Berry.Permissions.Has(source, "fondateur") then
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
        st.hasStartedHeartbeat = true
    end
end)

RegisterNetEvent("berry:ac:resourceStopped", function(reason)
    local src = source
    local st = GetPlayerAcState(src)
    if st and st.hasStartedHeartbeat then
        Berry.AntiCheat.BanPlayer(src, reason or "Tentative d'arrêt du Core détectée")
    end
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
                if st and st.hasStartedHeartbeat and now > st.graceUntil then
                    if (now - st.lastHeartbeat) > 25000 then
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
-- Admin Commands
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

-- ============================================================================
-- SECTION 3: Gameplay Systems (Player Manager, Characters, Economy, Jobs, Orgs, Vehicles, Properties, Police/EMS, Bootstrap)
-- ============================================================================

Berry.PlayersBySource = {}
Berry.PlayersByIdentifier = {}
Berry.PlayersByCharacterId = {}

local Player = {}
Player.__index = Player

function Berry.CreatePlayerObject(data)
    local self = setmetatable({}, Player)

    self.source = data.source
    self.identifier = data.identifier
    self.identifiers = data.identifiers or {}
    self.accountId = data.accountId or 0
    self.characterId = data.characterId or 0
    self.name = data.name or GetPlayerName(data.source) or "Unknown"

    self.position = data.position or BerryConfig.Player.DefaultSpawn
    self.money = data.money or Berry.Utils.DeepCopy(BerryConfig.Player.DefaultMoney)
    self.job = data.job or { name = "unemployed", grade = 0, label = "Unemployed", grade_name = "Unemployed", grade_salary = 0 }
    self.organization = data.organization or { name = "none", grade = 0, label = "None" }
    self.metadata = data.metadata or {}
    self.dirtyFields = {}

    return self
end

function Player:GetSource()
    return self.source
end

function Player:GetIdentifier()
    return self.identifier
end

function Player:GetCharacterId()
    return self.characterId
end

function Player:GetName()
    return self.name
end

function Player:GetPosition()
    local ped = GetPlayerPed(self.source)
    if DoesEntityExist(ped) then
        local coords = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)
        return { x = coords.x, y = coords.y, z = coords.z, heading = heading }
    end
    return self.position
end

function Player:GetMoney(account)
    account = account or "cash"
    return self.money[account] or 0
end

function Player:AddMoney(account, amount, reason)
    if not BerryTypes.IsPositiveNumber(amount) then
        Berry.Logger.Warn("PLAYER", "AddMoney failed for player %s: invalid amount %s", tostring(self.source), tostring(amount))
        return false
    end

    account = account or "cash"
    self.money[account] = (self.money[account] or 0) + amount
    self:MarkDirty("money")

    Berry.Logger.Info("PLAYER", "Added %s %.2f to account '%s' (Reason: %s)", self.name, amount, account, tostring(reason))
    TriggerClientEvent("berry:moneyChanged", self.source, account, self.money[account], amount, "add")
    return true
end

function Player:RemoveMoney(account, amount, reason)
    if not BerryTypes.IsPositiveNumber(amount) then
        Berry.Logger.Warn("PLAYER", "RemoveMoney failed for player %s: invalid amount %s", tostring(self.source), tostring(amount))
        return false
    end

    account = account or "cash"
    local current = self.money[account] or 0
    if current < amount then
        Berry.Logger.Warn("PLAYER", "RemoveMoney failed for player %s: insufficient funds in '%s' (Has: %.2f, Needs: %.2f)", tostring(self.source), account, current, amount)
        return false
    end

    self.money[account] = current - amount
    self:MarkDirty("money")

    Berry.Logger.Info("PLAYER", "Removed %s %.2f from account '%s' (Reason: %s)", self.name, amount, account, tostring(reason))
    TriggerClientEvent("berry:moneyChanged", self.source, account, self.money[account], amount, "remove")
    return true
end

function Player:GetJob()
    return self.job
end

function Player:SetJob(jobName, grade)
    self.job = {
        name = jobName,
        grade = grade or 0,
        label = jobName,
        grade_name = tostring(grade or 0),
        grade_salary = 0
    }
    self:MarkDirty("job")
    TriggerClientEvent("berry:jobChanged", self.source, self.job)
    return true
end

function Player:GetMetadata(key)
    if not key then return self.metadata end
    return self.metadata[key]
end

function Player:SetMetadata(key, value)
    if not key then return end
    self.metadata[key] = value
    self:MarkDirty("metadata")
    TriggerClientEvent("berry:metadataChanged", self.source, key, value)
end

function Player:MarkDirty(field)
    self.dirtyFields[field] = true
end

function Player:Save()
    if not self.characterId or self.characterId == 0 then return false end

    if self.dirtyFields["money"] or self.dirtyFields["job"] or self.dirtyFields["metadata"] or self.dirtyFields["position"] then
        local currentPos = self:GetPosition()
        local posJson = json.encode(currentPos)
        local metaJson = json.encode(self.metadata)

        Berry.Database.Update([[
            UPDATE berry_characters 
            SET position = ?, metadata = ? 
            WHERE id = ?
        ]], { posJson, metaJson, self.characterId })

        self.dirtyFields = {}
        Berry.Logger.Debug("PLAYER", "Saved player data for character ID %d (%s)", self.characterId, self.name)
        return true
    end

    return true
end

function Berry.GetPlayer(source)
    local src = tonumber(source)
    if not src then return nil end
    return Berry.PlayersBySource[src]
end

function Berry.GetPlayerByIdentifier(identifier)
    if not identifier then return nil end
    return Berry.PlayersByIdentifier[identifier]
end

function Berry.GetPlayerByCharacterId(characterId)
    local charId = tonumber(characterId)
    if not charId then return nil end
    return Berry.PlayersByCharacterId[charId]
end

function Berry.RegisterPlayer(playerObj)
    Berry.PlayersBySource[playerObj.source] = playerObj
    if playerObj.identifier then
        Berry.PlayersByIdentifier[playerObj.identifier] = playerObj
    end
    if playerObj.characterId and playerObj.characterId > 0 then
        Berry.PlayersByCharacterId[playerObj.characterId] = playerObj
    end
    Berry.Logger.Info("PLAYER", "Registered player %s (Source: %d, CharID: %d)", playerObj.name, playerObj.source, playerObj.characterId)
end

function Berry.UnregisterPlayer(source)
    local player = Berry.PlayersBySource[source]
    if player then
        player:Save()
        if player.identifier then
            Berry.PlayersByIdentifier[player.identifier] = nil
        end
        if player.characterId then
            Berry.PlayersByCharacterId[player.characterId] = nil
        end
        Berry.PlayersBySource[source] = nil
        Berry.Logger.Info("PLAYER", "Unregistered player source %d", source)
    end
end

exports("GetPlayer", Berry.GetPlayer)
exports("GetPlayerByIdentifier", Berry.GetPlayerByIdentifier)
exports("GetPlayerByCharacterId", Berry.GetPlayerByCharacterId)

-- ----------------------------------------------------------------------------
-- Character System & Callbacks
-- ----------------------------------------------------------------------------
BerryCharacters = BerryCharacters or {}
BerryCharacters.MaxCharacters = BerryConfig.Player.MaxCharacters or 4

local function GetPlayerLicenseIdentifier(src)
    local license = nil
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local id = GetPlayerIdentifier(src, i)
        if id and string.sub(id, 1, 8) == "license:" then
            license = id
            break
        end
    end
    return license or GetPlayerIdentifier(src, 0)
end

local function GetOrCreateAccountId(src, identifier)
    local row = MySQL.single.await("SELECT id FROM berry_accounts WHERE identifier = ?", { identifier })
    if row then return row.id end

    local insertId = MySQL.insert.await("INSERT INTO berry_accounts (identifier) VALUES (?)", { identifier })
    return insertId
end

Berry.Callbacks.Register("berry:characters:getCharacters", function(source, cb)
    local identifier = GetPlayerLicenseIdentifier(source)
    local accountId = GetOrCreateAccountId(source, identifier)

    local chars = MySQL.query.await("SELECT * FROM berry_characters WHERE account_id = ?", { accountId })
    for i = 1, #chars do
        if chars[i].position then
            chars[i].position = json.decode(chars[i].position)
        end
        if chars[i].metadata then
            chars[i].metadata = json.decode(chars[i].metadata)
        end
    end

    cb(chars)
end)

Berry.Callbacks.Register("berry:characters:createCharacter", function(source, cb, data)
    local identifier = GetPlayerLicenseIdentifier(source)
    local accountId = GetOrCreateAccountId(source, identifier)

    local countRow = MySQL.single.await("SELECT COUNT(*) as count FROM berry_characters WHERE account_id = ?", { accountId })
    if countRow and countRow.count >= BerryCharacters.MaxCharacters then
        return cb(false, "Max characters reached.")
    end

    local defaultPos = json.encode(BerryConfig.Player.DefaultSpawn)
    local defaultMeta = json.encode({ hunger = 100, thirst = 100 })

    local charId = MySQL.insert.await([[
        INSERT INTO berry_characters (account_id, firstname, lastname, dateofbirth, sex, position, metadata)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], { accountId, data.firstname, data.lastname, data.dateofbirth, data.sex or "m", defaultPos, defaultMeta })

    Berry.Logger.Info("CHARACTERS", "Created character ID %d for player source %d", charId, source)
    cb(true, charId)
end)

Berry.Callbacks.Register("berry:characters:selectCharacter", function(source, cb, charId)
    local identifier = GetPlayerLicenseIdentifier(source)
    local accountId = GetOrCreateAccountId(source, identifier)

    local charRow = MySQL.single.await("SELECT * FROM berry_characters WHERE id = ? AND account_id = ?", { charId, accountId })
    if not charRow then
        return cb(false, "Character not found.")
    end

    local pos = charRow.position and json.decode(charRow.position) or BerryConfig.Player.DefaultSpawn
    local meta = charRow.metadata and json.decode(charRow.metadata) or { hunger = 100, thirst = 100 }

    local playerObj = Berry.CreatePlayerObject({
        source = source,
        identifier = identifier,
        accountId = accountId,
        characterId = charId,
        name = string.format("%s %s", charRow.firstname, charRow.lastname),
        position = pos,
        metadata = meta
    })

    Berry.RegisterPlayer(playerObj)
    TriggerClientEvent("berry:playerLoaded", source, {
        characterId = charId,
        firstname = charRow.firstname,
        lastname = charRow.lastname,
        position = pos,
        metadata = meta,
        money = playerObj.money,
        job = playerObj.job
    })

    Berry.Logger.Info("CHARACTERS", "Player %s (source %d) loaded character %d", playerObj.name, source, charId)
    cb(true)
end)

-- ----------------------------------------------------------------------------
-- Economy Engine
-- ----------------------------------------------------------------------------
BerryEconomy = BerryEconomy or {}

function BerryEconomy.Transfer(source, targetSource, account, amount, reason)
    if not BerryTypes.IsPositiveNumber(amount) then
        return false, "Invalid amount."
    end

    local sender = Berry.GetPlayer(source)
    local receiver = Berry.GetPlayer(targetSource)

    if not sender then return false, "Sender not found." end
    if not receiver then return false, "Receiver not found." end

    account = account or "bank"
    reason = reason or "p2p_transfer"

    if sender:GetMoney(account) < amount then
        return false, "Insufficient funds."
    end

    if sender:RemoveMoney(account, amount, reason) then
        if receiver:AddMoney(account, amount, reason) then
            MySQL.insert.await([[
                INSERT INTO berry_transactions (source_id, target_id, amount, account_type, reason)
                VALUES (?, ?, ?, ?, ?)
            ]], { tostring(sender:GetCharacterId()), tostring(receiver:GetCharacterId()), amount, account, reason })

            Berry.Logger.Info("ECONOMY", "Transfer of %.2f (%s) from char %d to char %d succeeded.", amount, account, sender:GetCharacterId(), receiver:GetCharacterId())
            return true, "Transfer successful."
        else
            sender:AddMoney(account, amount, "transfer_rollback")
            return false, "Receiver transaction failed."
        end
    end

    return false, "Sender transaction failed."
end

Berry.Callbacks.Register("berry:economy:transfer", function(source, cb, targetSource, account, amount, reason)
    local success, msg = BerryEconomy.Transfer(source, targetSource, account, amount, reason)
    cb(success, msg)
end)

-- ----------------------------------------------------------------------------
-- Jobs & Paycheck Thread
-- ----------------------------------------------------------------------------
BerryJobs = BerryJobs or {}

function BerryJobs.SetPlayerJob(source, jobName, grade)
    local player = Berry.GetPlayer(source)
    if not player then return false, "Player not found." end

    local jobRow = MySQL.single.await("SELECT * FROM berry_jobs WHERE name = ?", { jobName })
    if not jobRow then return false, "Job does not exist." end

    local gradeRow = MySQL.single.await("SELECT * FROM berry_job_grades WHERE job_name = ? AND grade = ?", { jobName, grade or 0 })
    if not gradeRow then return false, "Job grade does not exist." end

    player.job = {
        name = jobName,
        label = jobRow.label,
        grade = gradeRow.grade,
        grade_name = gradeRow.name,
        grade_label = gradeRow.label,
        grade_salary = gradeRow.salary
    }

    player:MarkDirty("job")
    TriggerClientEvent("berry:jobChanged", source, player.job)
    Berry.Logger.Info("JOBS", "Set player %s job to %s (%s)", player:GetName(), jobName, gradeRow.label)
    return true
end

CreateThread(function()
    while true do
        Wait(15 * 60 * 1000)
        Berry.Logger.Info("JOBS", "Processing paychecks...")
        for _, player in pairs(Berry.PlayersBySource) do
            local job = player:GetJob()
            local salary = job.grade_salary or 200
            if salary > 0 then
                player:AddMoney("bank", salary, "paycheck")
                TriggerClientEvent("berry:notify", player:GetSource(), string.format("Salaire reçu : %d$ (%s)", salary, job.label or job.name))
            end
        end
    end
end)

-- ----------------------------------------------------------------------------
-- Organizations Engine
-- ----------------------------------------------------------------------------
BerryOrganizations = BerryOrganizations or {}

function BerryOrganizations.Create(id, label, orgType)
    MySQL.insert.await([[
        INSERT INTO berry_organizations (id, label, type, balance)
        VALUES (?, ?, ?, 0.00)
    ]], { id, label, orgType or "gang" })
    Berry.Logger.Info("ORGANIZATIONS", "Created organization '%s' (%s)", label, id)
    return true
end

function BerryOrganizations.AddMember(orgId, characterId, grade)
    MySQL.insert.await([[
        INSERT INTO berry_organization_members (organization_id, character_id, grade)
        VALUES (?, ?, ?)
    ]], { orgId, characterId, grade or 0 })
    return true
end

-- ----------------------------------------------------------------------------
-- Vehicles Manager
-- ----------------------------------------------------------------------------
BerryVehicles = BerryVehicles or {}

local function GeneratePlate()
    local plate
    local isUnique = false
    while not isUnique do
        plate = string.format("%s%03d%s", Berry.Utils.RandomString(3):upper(), math.random(100, 999), Berry.Utils.RandomString(2):upper())
        local existing = MySQL.single.await("SELECT plate FROM berry_vehicles WHERE plate = ?", { plate })
        if not existing then
            isUnique = true
        end
    end
    return plate
end

function BerryVehicles.GiveVehicle(source, model, garage)
    local player = Berry.GetPlayer(source)
    if not player then return false, "Player not loaded." end

    local plate = GeneratePlate()
    local charId = player:GetCharacterId()

    MySQL.insert.await([[
        INSERT INTO berry_vehicles (plate, owner_id, model, garage, state)
        VALUES (?, ?, ?, ?, 1)
    ]], { plate, charId, model, garage or "pillbox" })

    Berry.Logger.Info("VEHICLES", "Gave vehicle %s (Plate: %s) to character ID %d", model, plate, charId)
    return true, plate
end

Berry.Callbacks.Register("berry:vehicles:getOwned", function(source, cb)
    local player = Berry.GetPlayer(source)
    if not player then return cb({}) end

    local charId = player:GetCharacterId()
    local vehicles = MySQL.query.await("SELECT * FROM berry_vehicles WHERE owner_id = ?", { charId })
    cb(vehicles)
end)

-- ----------------------------------------------------------------------------
-- Properties Engine
-- ----------------------------------------------------------------------------
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

Berry.Callbacks.Register("berry:properties:getProperties", function(source, cb)
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

-- ----------------------------------------------------------------------------
-- Police & EMS Commands
-- ----------------------------------------------------------------------------
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

RegisterCommand("revive", function(source, args)
    local src = source
    local targetId = tonumber(args[1]) or src

    if src > 0 and not Berry.Permissions.Has(source, "admin") then
        local pData = Berry.GetPlayer(src)
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

    if src > 0 and not Berry.Permissions.Has(source, "admin") then
        local pData = Berry.GetPlayer(src)
        if not pData or (pData.job and pData.job.name ~= "ambulance") then
            Berry.UI.Notify(src, { message = "Action réservée aux EMS et Administrateurs.", type = "error" })
            return
        end
    end

    TriggerClientEvent("berry:ems:heal", targetId)
    Berry.UI.Notify(src, { message = "Joueur " .. targetId .. " soigné.", type = "success" })
end, false)

-- ----------------------------------------------------------------------------
-- Bootstrap & Server Lifecycle Threads
-- ----------------------------------------------------------------------------
local function PrintBanner()
    print([[
^5
  ____                        _____                                             _    
 |  _ \                      |  ___|                                           | |   
 | |_) | ___ _ __ _ __ _   _ | |_ _ __ __ _ _ __ ___   _____      _____  _ __| | __
 |  _ < / _ \ '__| '__| | | ||  _| '__/ _` | '_ ` _ \ / _ \ \ /\ / / _ \| '__| |/ /
 | |_) |  __/ |  | |  | |_| || | | | | (_| | | | | | |  __/\ V  V / (_) | |  |   < 
 |____/ \___|_|  |_|   \__, ||_| |_|  \__,_|_| |_| |_|\___| \_/\_/ \___/|_|  |_|\_\
                        __/ |                                                        
                       |___/    v1.0.0 — Ultimate Modern Roleplay Engine
^7]])
end

CreateThread(function()
    PrintBanner()
    Berry.Logger.Info("CORE", "Initializing Berry Framework core kernel (Lua 5.4 Generational GC Enabled)...")

    local dbReady = false
    local checkCount = 0
    while not dbReady and checkCount < 50 do
        if Berry.Database and Berry.Database.Ready() then
            dbReady = true
        else
            Wait(100)
            checkCount = checkCount + 1
        end
    end

    if dbReady then
        Berry.Logger.Info("CORE", "Database connection verified via oxmysql.")
    else
        Berry.Logger.Warn("CORE", "Database connection pending or oxmysql not ready yet.")
    end

    if Berry.ModuleManager then
        Berry.ModuleManager.LoadAll()
    end

    local saveInterval = (BerryConfig.Player.SaveIntervalSeconds or 300) * 1000
    CreateThread(function()
        while true do
            Wait(saveInterval)
            Berry.Logger.Debug("CORE", "Running periodic auto-save for online players...")
            for _, player in pairs(Berry.PlayersBySource) do
                player:Save()
            end
        end
    end)

    CreateThread(function()
        while true do
            Wait(60000)
            if Berry.Cache then Berry.Cache.Cleanup() end
            collectgarbage("step", 100)
        end
    end)

    Berry.Logger.Info("CORE", "Berry Framework core kernel running at maximum performance.")
    TriggerEvent("berry:coreReady")
end)

AddEventHandler("playerConnecting", function(playerName, setKickReason, deferrals)
    local src = source
    local maxClients = GetConvarInt("sv_maxclients", 32)
    local currentCount = #GetPlayers()
    local identifier = GetPlayerIdentifierByType and GetPlayerIdentifierByType(src, "license") or GetPlayerIdentifier(src, 0) or "N/A"

    print(string.format("^6[BERRY] ^2[+ CONNEXION] ^7Joueur: ^3%s ^7| ^5ID: [%d] ^7| ^4Licence: [%s] ^7| ^2Joueurs: [%d/%d]^7",
        tostring(playerName or "Inconnu"),
        src,
        tostring(identifier),
        currentCount + 1,
        maxClients
    ))
end)

AddEventHandler("playerDropped", function(reason)
    local src = source
    local playerName = GetPlayerName(src) or "Inconnu"
    local maxClients = GetConvarInt("sv_maxclients", 32)
    local currentCount = math.max(0, #GetPlayers() - 1)

    print(string.format("^6[BERRY] ^1[- DÉCONNEXION] ^7Joueur: ^3%s ^7| ^5ID: [%d] ^7| ^1Raison: [%s] ^7| ^3Joueurs: [%d/%d]^7",
        tostring(playerName),
        src,
        tostring(reason or "Déconnexion normale"),
        currentCount,
        maxClients
    ))

    Berry.UnregisterPlayer(src)
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        Berry.Logger.Info("CORE", "Resource stopping, saving all active players...")
        for _, player in pairs(Berry.PlayersBySource) do
            player:Save()
        end
    end
end)
