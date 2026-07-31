Berry.Callbacks = Berry.Callbacks or {}

local clientRequestId = 0
local clientCallbacks = {}
local registeredClientCallbacks = {}

function Berry.Callbacks.Trigger(name, callback, ...)
    clientRequestId = clientRequestId + 1
    local requestId = clientRequestId
    clientCallbacks[requestId] = callback

    local fullCallbackName = name:find("^berry:") and name or ("berry:cb:" .. name)
    TriggerServerEvent("berry:triggerServerCallback", fullCallbackName, requestId, ...)
end

RegisterNetEvent("berry:serverCallbackResponse", function(requestId, ...)
    local cb = clientCallbacks[requestId]
    if cb then
        clientCallbacks[requestId] = nil
        cb(...)
    end
end)

function Berry.Callbacks.Register(name, callback)
    registeredClientCallbacks[name] = callback
end

RegisterNetEvent("berry:triggerClientCallback", function(name, requestId, ...)
    local cb = registeredClientCallbacks[name]
    if cb then
        cb(function(...)
            TriggerServerEvent("berry:clientCallbackResponse", requestId, ...)
        end, ...)
    end
end)
