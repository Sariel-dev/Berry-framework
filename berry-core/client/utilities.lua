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

-- Event Handlers
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
