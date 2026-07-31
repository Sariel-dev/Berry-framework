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

    if not Berry.Security.ValidateEvent(src, fullCallbackName, {...}) then
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
