Berry.Events = Berry.Events or {}

local registeredClientEvents = {}

function Berry.Events.On(eventName, callback)
    local fullEventName = eventName:find("^berry:") and eventName or ("berry:" .. eventName)
    
    if not registeredClientEvents[fullEventName] then
        registeredClientEvents[fullEventName] = {}
        RegisterNetEvent(fullEventName, function(...)
            for _, handler in ipairs(registeredClientEvents[fullEventName]) do
                handler(...)
            end
        end)
    end

    table.insert(registeredClientEvents[fullEventName], callback)
end

function Berry.Events.EmitServer(eventName, ...)
    local fullEventName = eventName:find("^berry:") and eventName or ("berry:" .. eventName)
    TriggerServerEvent(fullEventName, ...)
end
