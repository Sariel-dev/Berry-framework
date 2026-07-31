-- ============================================================================
-- Berry Framework — Client Core Kernel (Utilities, UI Notifications, Events, Callbacks & State)
-- ============================================================================

Berry = Berry or {}

-- ----------------------------------------------------------------------------
-- 1. Client Utilities & UI Notifications
-- ----------------------------------------------------------------------------
Berry.ClientUtils = {}
Berry.UI = Berry.UI or {}

function Berry.UI.Notify(data)
    local msg = ""
    local nType = "info"
    local duration = 5000
    local title = "NOTIFICATION"
    local subtitle = "BERRY"

    if type(data) == "table" then
        msg = data.message or data.content or data.description or ""
        nType = data.type or data.variant or "info"
        duration = data.duration or 5000
        title = data.title or (nType:upper())
        subtitle = data.subtitle or "BERRY"
    else
        msg = tostring(data or "")
    end

    SendNUIMessage({
        action = "addNotification",
        title = title,
        subtitle = subtitle,
        message = msg,
        variant = nType,
        duration = duration
    })
end

function Berry.UI.ProgressBar(label, duration, cb)
    local dur = duration or 3000
    SendNUIMessage({
        action = "startProgressBar",
        label = label or "Action en cours...",
        duration = dur
    })

    if cb then
        SetTimeout(dur, function()
            cb()
        end)
    end
end

function Berry.ClientUtils.ShowNotification(message, msgType, duration)
    Berry.UI.Notify({ message = message, type = msgType or "info", duration = duration or 5000 })
end

function Berry.ClientUtils.GetPedCoords()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    return { x = coords.x, y = coords.y, z = coords.z, heading = heading }
end

function Berry.ClientUtils.DrawText3D(coords, text, size)
    local onScreen, _x, _y = World3dToScreen2d(coords.x, coords.y, coords.z)
    if onScreen then
        SetTextScale(size or 0.35, size or 0.35)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end

RegisterNetEvent("berry:notify", function(message, nType, duration, title, subtitle)
    Berry.UI.Notify({ message = message, type = nType, duration = duration, title = title, subtitle = subtitle })
end)

RegisterNetEvent("berry:progressbar", function(label, duration)
    Berry.UI.ProgressBar(label, duration)
end)

RegisterNetEvent("esx:showNotification", function(message)
    Berry.UI.Notify({ message = message, type = "info", title = "INFORMATION" })
end)

RegisterNetEvent("esx:showAdvancedNotification", function(sender, subject, message)
    Berry.UI.Notify({ message = message, title = sender, subtitle = subject, type = "info" })
end)

RegisterNetEvent("ox_lib:notify", function(payload)
    if type(payload) == "table" then
        local msg = payload.description or payload.text or payload.message
        Berry.UI.Notify({ message = msg, type = payload.type or "info", title = payload.title, duration = payload.duration })
    end
end)

RegisterNetEvent("QBCore:Notify", function(text, notifyType, length)
    Berry.UI.Notify({ message = text, type = notifyType or "info", duration = length or 5000 })
end)

RegisterNetEvent("QBCore:Client:Notify", function(text, notifyType, length)
    Berry.UI.Notify({ message = text, type = notifyType or "info", duration = length or 5000 })
end)

exports("addNotification", function(icon, header, title, subtitle, content, duration, sticky, variant)
    Berry.UI.Notify({ message = content or title, title = title or header, subtitle = subtitle, type = variant or "info", duration = duration })
end)

exports("Notify", function(message, nType, duration, title, subtitle)
    Berry.UI.Notify({ message = message, type = nType, duration = duration, title = title, subtitle = subtitle })
end)

exports("ProgressBar", function(label, duration, cb)
    Berry.UI.ProgressBar(label, duration, cb)
end)

-- ----------------------------------------------------------------------------
-- 2. Client Event Manager
-- ----------------------------------------------------------------------------
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

-- ----------------------------------------------------------------------------
-- 3. Client Callback Manager
-- ----------------------------------------------------------------------------
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

function Berry.TriggerServerCallback(name, callback, ...)
    Berry.Callbacks.Trigger(name, callback, ...)
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

-- ----------------------------------------------------------------------------
-- 4. Client State Manager
-- ----------------------------------------------------------------------------
Berry.State = Berry.State or {}

function Berry.State.GetLocalPlayerState(key)
    return LocalPlayer.state[key]
end

function Berry.State.SetLocalPlayerState(key, value, replicated)
    LocalPlayer.state:set(key, value, replicated or false)
end

function Berry.State.GetEntityState(entity, key)
    if DoesEntityExist(entity) then
        return Entity(entity).state[key]
    end
    return nil
end

-- ----------------------------------------------------------------------------
-- 5. Client Interim Job System
-- ----------------------------------------------------------------------------
local isWorkingInterim = false
local currentDeliveryBlip = nil

local deliveryPoints = {
    vector3(145.4, -1045.2, 29.3),
    vector3(-708.5, -914.2, 19.2),
    vector3(380.7, -825.1, 29.3),
    vector3(1159.8, -325.2, 69.2),
    vector3(-1222.8, -907.2, 12.3)
}

local function StartDeliveryJob()
    if isWorkingInterim then
        Berry.ClientUtils.ShowNotification("Vous avez déjà une mission de livraison en cours.", "warn")
        return
    end

    isWorkingInterim = true
    local targetCoords = deliveryPoints[math.random(1, #deliveryPoints)]

    Berry.ClientUtils.ShowNotification("Mission de livraison débutée ! Rendez-vous au point GPS.", "info")

    currentDeliveryBlip = AddBlipForCoord(targetCoords.x, targetCoords.y, targetCoords.z)
    SetBlipSprite(currentDeliveryBlip, 1)
    SetBlipColour(currentDeliveryBlip, 5)
    SetBlipRoute(currentDeliveryBlip, true)

    Berry.ClientUtils.AddMarker("interim_delivery", {
        coords = targetCoords,
        text = "Livraison de Colis\nAppuyez sur ~g~[E]~s~ pour livrer",
        drawDistance = 20.0,
        interactDistance = 2.5,
        onInteract = function()
            Berry.UI.ProgressBar("Livraison du colis en cours...", 4000, function()
                TriggerServerEvent("berry:interim:completeDelivery")
                RemoveBlip(currentDeliveryBlip)
                Berry.ClientUtils.RemoveMarker("interim_delivery")
                isWorkingInterim = false
            end)
        end
    })
end

RegisterNetEvent("berry:clientCoreReady", function()
    Wait(3000)
    if Berry.ClientUtils and Berry.ClientUtils.AddMarker then
        Berry.ClientUtils.AddMarker("job_center_interim", {
            coords = vector3(-266.3, -961.1, 31.2),
            text = "Pôle Emploi Intérim\nAppuyez sur ~g~[E]~s~ pour lancer une mission de livraison",
            drawDistance = 15.0,
            interactDistance = 2.0,
            onInteract = function()
                StartDeliveryJob()
            end
        })
    end
end)
