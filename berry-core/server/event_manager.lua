Berry.Events = Berry.Events or {}

local registeredEvents = {}

function Berry.Events.On(eventName, callback)
    local fullEventName = eventName:find("^berry:") and eventName or ("berry:" .. eventName)
    
    if not registeredEvents[fullEventName] then
        registeredEvents[fullEventName] = {}
        RegisterNetEvent(fullEventName, function(...)
            local src = source
            if src and src > 0 then
                if not Berry.Security.ValidateEvent(src, fullEventName, {...}) then
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
