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
