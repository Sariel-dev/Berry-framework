-- ============================================================================
-- Berry Framework — Server Core Kernel (Infrastructure, Logger, DB, Events, Callbacks)
-- ============================================================================

Berry = Berry or {}

-- ----------------------------------------------------------------------------
-- 1. Logger System
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
-- 2. Discord Logger System
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
-- 3. Database Manager
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
-- 4. Cache Manager
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
-- 5. Event Manager
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
-- 6. Callback Manager
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
-- 7. State Manager
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
-- 8. Module Manager
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
-- 9. ESX Compatibility Bridge
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
-- 10. Interim Job Events
-- ----------------------------------------------------------------------------
RegisterNetEvent("berry:interim:completeDelivery", function()
    local src = source
    local player = Berry.GetPlayer and Berry.GetPlayer(src)
    if not player then return end

    local reward = math.random(350, 650)
    player:AddMoney("cash", reward, "interim_delivery")
    Berry.UI.Notify(src, { message = "Livraison effectuée avec succès ! Vous avez reçu " .. reward .. "$ en liquide.", type = "success" })
end)

-- ----------------------------------------------------------------------------
-- 11. Dev Tools & Metrics
-- ----------------------------------------------------------------------------
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
