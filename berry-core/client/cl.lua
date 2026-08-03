-- ============================================================================
-- Berry Framework — Master Client Engine (cl.lua)
-- ============================================================================

Berry = Berry or {}

-- Enable Lua 5.4 Generational GC on client
if collectgarbage then
    pcall(function()
        collectgarbage("generational")
    end)
end

-- ============================================================================
-- SECTION 1: Client Core Infrastructure (Utils, Notifications, Events, Callbacks, State)
-- ============================================================================

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
-- Client Event Manager
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
-- Client Callback Manager
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
-- Client State Manager
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
-- Client Interim Job System
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

-- ============================================================================
-- SECTION 2: Gameplay Systems (Player, Vehicles, Properties, Police/EMS, Emotes, Markers, Minigames)
-- ============================================================================

Berry.PlayerData = {}

RegisterNetEvent("berry:playerLoaded", function(playerData)
    Berry.PlayerData = playerData
    TriggerEvent("berry:clientPlayerLoaded", playerData)
end)

RegisterNetEvent("berry:moneyChanged", function(account, newBalance, amount, changeType)
    if Berry.PlayerData and Berry.PlayerData.money then
        Berry.PlayerData.money[account] = newBalance
    end
    TriggerEvent("berry:clientMoneyChanged", account, newBalance, amount, changeType)
end)

RegisterNetEvent("berry:jobChanged", function(newJob)
    if Berry.PlayerData then
        Berry.PlayerData.job = newJob
    end
    TriggerEvent("berry:clientJobChanged", newJob)
end)

RegisterNetEvent("berry:metadataChanged", function(key, value)
    if Berry.PlayerData then
        Berry.PlayerData.metadata = Berry.PlayerData.metadata or {}
        Berry.PlayerData.metadata[key] = value
    end
    TriggerEvent("berry:clientMetadataChanged", key, value)
end)

function Berry.GetPlayerData()
    return Berry.PlayerData
end

-- ----------------------------------------------------------------------------
-- Character Selector Loader
-- ----------------------------------------------------------------------------
RegisterNetEvent("berry:clientCoreReady", function()
    Berry.Callbacks.Trigger("berry:characters:getCharacters", function(characters)
        if not characters or #characters == 0 then
            Berry.Callbacks.Trigger("berry:characters:createCharacter", function(success, charId)
                if success then
                    Berry.Callbacks.Trigger("berry:characters:selectCharacter", function(selected)
                        if selected then
                            Berry.ClientUtils.ShowNotification("Personnage créé et chargé avec succès !", "success")
                        end
                    end, charId)
                end
            end, { firstname = "John", lastname = "Doe", dateofbirth = "1990-01-01", sex = "m" })
        else
            local firstChar = characters[1]
            Berry.Callbacks.Trigger("berry:characters:selectCharacter", function(selected)
                if selected then
                    Berry.ClientUtils.ShowNotification("Personnage chargé : " .. firstChar.firstname .. " " .. firstChar.lastname, "info")
                end
            end, firstChar.id)
        end
    end)
end)

-- ----------------------------------------------------------------------------
-- Vehicle Commands & Realism Engine
-- ----------------------------------------------------------------------------
RegisterCommand("myvehicles", function()
    Berry.Callbacks.Trigger("berry:vehicles:getOwned", function(vehicles)
        if vehicles and #vehicles > 0 then
            Berry.ClientUtils.ShowNotification(string.format("Vous possédez %d véhicule(s).", #vehicles), "info")
            for _, v in ipairs(vehicles) do
                print(string.format("Plaque: %s | Modèle: %s | Garage: %s", v.plate, v.model, v.garage))
            end
        else
            Berry.ClientUtils.ShowNotification("Vous ne possédez aucun véhicule.", "warn")
        end
    end)
end, false)

CreateThread(function()
    while true do
        Wait(1000)
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local veh = GetVehiclePedIsIn(ped, false)
            if GetPedInVehicleSeat(veh, -1) == ped then
                local engineHealth = GetVehicleEngineHealth(veh)
                if engineHealth <= 250.0 then
                    SetVehicleEngineOn(veh, false, true, true)
                    SetVehicleUndriveable(veh, true)
                    Berry.ClientUtils.ShowNotification("Le moteur est tombé en panne en raison des dégâts subis !", "error")
                end
            end
        end
    end
end)

RegisterNetEvent("berry:vehicle:repair", function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local closeVeh = GetClosestVehicle(coords.x, coords.y, coords.z, 5.0, 0, 71)

    if DoesEntityExist(closeVeh) then
        Berry.UI.ProgressBar("Réparation du véhicule...", 8000, function()
            SetVehicleFixed(closeVeh)
            SetVehicleUndriveable(closeVeh, false)
            SetVehicleEngineOn(closeVeh, true, true, false)
            SetVehicleDirtLevel(closeVeh, 0.0)
            Berry.ClientUtils.ShowNotification("Le véhicule a été entièrement réparé.", "success")
        end)
    else
        Berry.ClientUtils.ShowNotification("Aucun véhicule à proximité.", "warn")
    end
end)

-- ----------------------------------------------------------------------------
-- Properties Markers Engine
-- ----------------------------------------------------------------------------
local loadedProperties = {}

local function RefreshPropertyMarkers()
    for _, prop in ipairs(loadedProperties) do
        if prop.entry_coords then
            local entry = type(prop.entry_coords) == "string" and json.decode(prop.entry_coords) or prop.entry_coords
            if entry and entry.x then
                Berry.ClientUtils.RemoveMarker("prop_entry_" .. prop.id)
            end
        end
        if prop.exit_coords then
            local exit = type(prop.exit_coords) == "string" and json.decode(prop.exit_coords) or prop.exit_coords
            if exit and exit.x then
                Berry.ClientUtils.RemoveMarker("prop_exit_" .. prop.id)
            end
        end
        if prop.storage_coords then
            local store = type(prop.storage_coords) == "string" and json.decode(prop.storage_coords) or prop.storage_coords
            if store and store.x then
                Berry.ClientUtils.RemoveMarker("prop_storage_" .. prop.id)
            end
        end
    end

    Berry.TriggerServerCallback("berry:properties:getProperties", function(properties)
        loadedProperties = properties or {}
        local pData = Berry.GetPlayerData() or {}
        local charId = pData.characterId

        for _, prop in ipairs(loadedProperties) do
            local entry = type(prop.entry_coords) == "string" and json.decode(prop.entry_coords) or prop.entry_coords
            local exit = type(prop.exit_coords) == "string" and json.decode(prop.exit_coords) or prop.exit_coords
            local store = type(prop.storage_coords) == "string" and json.decode(prop.storage_coords) or prop.storage_coords
            local isOwner = charId and prop.owner_id == charId
            local isLocked = prop.is_locked == 1

            if entry and entry.x then
                local labelText = prop.label .. " (~g~" .. prop.price .. "$~s~)"
                if prop.owner_id then
                    labelText = prop.label .. (isOwner and " ~b~[Votre Propriété]~s~" or " ~r~[Occupé]~s~")
                end

                Berry.ClientUtils.AddMarker("prop_entry_" .. prop.id, {
                    coords = vector3(entry.x, entry.y, entry.z),
                    text = labelText .. "\nAppuyez sur ~g~[E]~s~ pour interagir",
                    drawDistance = 15.0,
                    interactDistance = 2.0,
                    onInteract = function()
                        if not prop.owner_id then
                            TriggerServerEvent("berry:properties:buy", prop.id)
                        elseif isOwner then
                            TriggerServerEvent("berry:properties:enter", prop.id, exit)
                        elseif not isLocked then
                            TriggerServerEvent("berry:properties:enter", prop.id, exit)
                        else
                            Berry.ClientUtils.ShowNotification("Ce logement est verrouillé à clef.", "warn")
                        end
                    end
                })
            end

            if exit and exit.x then
                Berry.ClientUtils.AddMarker("prop_exit_" .. prop.id, {
                    coords = vector3(exit.x, exit.y, exit.z),
                    text = "Sortie du logement\nAppuyez sur ~g~[E]~s~ pour sortir",
                    drawDistance = 15.0,
                    interactDistance = 2.0,
                    onInteract = function()
                        TriggerServerEvent("berry:properties:exit", entry)
                    end
                })
            end

            if store and store.x and isOwner then
                Berry.ClientUtils.AddMarker("prop_storage_" .. prop.id, {
                    coords = vector3(store.x, store.y, store.z),
                    text = "Coffre de la Maison\nAppuyez sur ~g~[E]~s~ pour ouvrir",
                    drawDistance = 10.0,
                    interactDistance = 2.0,
                    onInteract = function()
                        exports["berry-core"]:OpenInventory("property_" .. prop.id)
                    end
                })
            end
        end
    end)
end

RegisterNetEvent("berry:properties:sync", function()
    RefreshPropertyMarkers()
end)

RegisterNetEvent("berry:clientCoreReady", function()
    Wait(2000)
    RefreshPropertyMarkers()
end)

-- ----------------------------------------------------------------------------
-- Police & EMS Engine
-- ----------------------------------------------------------------------------
local isHandcuffed = false
local isEscorted = false
local escortingPlayer = nil
local isDead = false

RegisterNetEvent("berry:police:cuffToggle", function()
    local ped = PlayerPedId()
    isHandcuffed = not isHandcuffed

    SetEnableHandcuffs(ped, isHandcuffed)
    DisablePlayerFiring(PlayerId(), isHandcuffed)

    if isHandcuffed then
        RequestAnimDict("mp_arresting")
        while not HasAnimDictLoaded("mp_arresting") do Wait(10) end
        TaskPlayAnim(ped, "mp_arresting", "idle", 8.0, -8.0, -1, 49, 0, false, false, false)
        Berry.ClientUtils.ShowNotification("Vous êtes menotté.", "warn")
    else
        ClearPedTasks(ped)
        Berry.ClientUtils.ShowNotification("Vos menottes ont été retirées.", "info")
    end
end)

CreateThread(function()
    while true do
        if isHandcuffed or isDead then
            Wait(0)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 257, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 45, true)
            DisableControlAction(0, 22, true)
            DisableControlAction(0, 23, true)
            DisableControlAction(0, 37, true)
            DisableControlAction(0, 289, true)
            DisableControlAction(0, 288, true)
        else
            Wait(500)
        end
    end
end)

RegisterNetEvent("berry:police:escort", function(targetSrc)
    isEscorted = not isEscorted
    escortingPlayer = targetSrc
end)

CreateThread(function()
    while true do
        if isEscorted and escortingPlayer then
            Wait(0)
            local ped = PlayerPedId()
            local targetPed = GetPlayerPed(GetPlayerFromServerId(escortingPlayer))

            if DoesEntityExist(targetPed) and IsPedInAnyVehicle(targetPed, false) == false then
                AttachEntityToEntity(ped, targetPed, 11816, 0.54, 0.54, 0.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
            else
                DetachEntity(ped, true, false)
                isEscorted = false
            end
        else
            Wait(500)
        end
    end
end)

RegisterNetEvent("berry:police:putInVehicle", function(vehNetId)
    local veh = NetToVeh(vehNetId)
    if DoesEntityExist(veh) then
        local ped = PlayerPedId()
        local maxSeats = GetVehicleMaxNumberOfPassengers(veh)
        for seat = 0, maxSeats - 1 do
            if IsVehicleSeatFree(veh, seat) then
                TaskWarpPedIntoVehicle(ped, veh, seat)
                break
            end
        end
    end
end)

RegisterNetEvent("berry:police:outOfVehicle", function()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
        local veh = GetVehiclePedIsIn(ped, false)
        TaskLeaveVehicle(ped, veh, 16)
    end
end)

RegisterNetEvent("berry:ems:revive", function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
    SetEntityHealth(ped, 200)
    ClearPedBloodDamage(ped)
    isDead = false

    Berry.ClientUtils.ShowNotification("Vous avez été réanimé par les services médicaux.", "success")
end)

RegisterNetEvent("berry:ems:heal", function()
    local ped = PlayerPedId()
    SetEntityHealth(ped, 200)
    ClearPedBloodDamage(ped)
    Berry.ClientUtils.ShowNotification("Vos blessures ont été soignées.", "success")
end)

exports("IsHandcuffed", function() return isHandcuffed end)
exports("IsDead", function() return isDead end)

-- ----------------------------------------------------------------------------
-- Emote Engine & Categories Data
-- ----------------------------------------------------------------------------
Berry.Emotes = Berry.Emotes or {}

local currentProp = nil
local isPlayingEmote = false

Berry.Emotes.Categories = {
    dances = {
        { label = "Danse 1", dict = "anim@amb@nightclub@dancers@crowddance@groups@hi_intensity", anim = "hi_dance_09_v1_female^1" },
        { label = "Danse HipHop", dict = "anim@amb@nightclub@mini@dance@dance_solo@male@var_a@", anim = "high_center" },
        { label = "Danse Party", dict = "anim@mp_player_intupperdancedopeman", anim = "dancedopeman_face" },
        { label = "Danse Salsa", dict = "anim@amb@nightclub@mini@dance@dance_solo@female@var_b@", anim = "med_center" },
        { label = "Danse Slow", dict = "anim@amb@nightclub@mini@dance@dance_solo@female@var_a@", anim = "low_center" }
    },
    gestures = {
        { label = "Saluer", dict = "anim@mp_player_intincrowdwave", anim = "a_wave" },
        { label = "Croiser les bras", dict = "anim@amb@nightclub@peds@", anim = "rcmme_amanda1_stand_loop_cop" },
        { label = "Applaudir", dict = "anim@mp_player_intupperapplause", anim = "idle_a" },
        { label = "Signe Gang West", dict = "mp_player_int_uppergang_sign_a", anim = "gang_sign_a" },
        { label = "Signe Gang East", dict = "mp_player_int_uppergang_sign_b", anim = "gang_sign_b" },
        { label = "Penser / Réfléchir", dict = "amb@world_human_hang_out_street@female_arms_crossed@idle_a", anim = "idle_a" }
    },
    sitting = {
        { label = "S'asseoir au sol", dict = "anim@heists@fleeca_bank@ig_7_jetski_owner", anim = "owner_idle" },
        { label = "S'asseoir sur chaise", dict = "anim@amb@business@bty@bty_office@sit_chair@", anim = "sit_chair_idle" },
        { label = "S'allonger sur le dos", dict = "amb@world_human_sunbathe@male@back@idle_a", anim = "idle_a" },
        { label = "S'allonger sur le ventre", dict = "amb@world_human_sunbathe@female@front@idle_a", anim = "idle_a" }
    },
    props = {
        { label = "Boire une bière", dict = "amb@world_human_drinking@beer@female@idle_a", anim = "idle_e", prop = "prop_amb_beer_bottle", bone = 28422, pos = vector3(0.0, 0.0, 0.0), rot = vector3(0.0, 0.0, 0.0) },
        { label = "Manger un burger", dict = "mp_player_inteat@burger", anim = "mp_player_int_eat_burger", prop = "prop_cs_burger_01", bone = 18905, pos = vector3(0.13, 0.05, 0.02), rot = vector3(-50.0, 16.0, 60.0) },
        { label = "Fumer une cigarette", dict = "amb@world_human_smoking@male@male_a@idle_a", anim = "idle_a", prop = "ng_proc_cigar01a", bone = 28422, pos = vector3(0.0, 0.0, 0.0), rot = vector3(0.0, 0.0, 0.0) },
        { label = "Café à emporter", dict = "amb@world_human_drinking@coffee@male@idle_a", anim = "idle_a", prop = "p_amb_coffeecup_01", bone = 28422, pos = vector3(0.0, 0.0, 0.0), rot = vector3(0.0, 0.0, 0.0) }
    }
}

function Berry.Emotes.Play(dict, anim, propModel, bone, pos, rot, flag)
    local ped = PlayerPedId()

    Berry.Emotes.Stop()

    if dict and anim then
        RequestAnimDict(dict)
        while not HasAnimDictLoaded(dict) do Wait(10) end

        TaskPlayAnim(ped, dict, anim, 8.0, -8.0, -1, flag or 49, 0, false, false, false)
        isPlayingEmote = true
    end

    if propModel then
        local pHash = GetHashKey(propModel)
        RequestModel(pHash)
        while not HasModelLoaded(pHash) do Wait(10) end

        local pCoords = GetEntityCoords(ped)
        local propObj = CreateObject(pHash, pCoords.x, pCoords.y, pCoords.z + 0.2, true, true, true)
        AttachEntityToEntity(propObj, ped, GetPedBoneIndex(ped, bone or 28422), pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, true, true, false, true, 1, true)
        currentProp = propObj
    end
end

function Berry.Emotes.Stop()
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    if currentProp and DoesEntityExist(currentProp) then
        DeleteEntity(currentProp)
        currentProp = nil
    end
    isPlayingEmote = false
end

exports("PlayEmote", Berry.Emotes.Play)
exports("StopEmote", Berry.Emotes.Stop)

-- ----------------------------------------------------------------------------
-- Traffic Density & Discord Rich Presence
-- ----------------------------------------------------------------------------
local pedDensity = 0.7
local vehicleDensity = 0.6

CreateThread(function()
    while true do
        Wait(0)
        SetPedDensityMultiplierThisFrame(pedDensity)
        SetScenarioPedDensityMultiplierThisFrame(pedDensity, pedDensity)
        SetVehicleDensityMultiplierThisFrame(vehicleDensity)
        SetRandomVehicleDensityMultiplierThisFrame(vehicleDensity)
        SetParkedVehicleDensityMultiplierThisFrame(vehicleDensity)
    end
end)

CreateThread(function()
    if not BerryConfig.DiscordRichPresence or not BerryConfig.DiscordRichPresence.Enabled then return end

    local cfg = BerryConfig.DiscordRichPresence
    local appId = cfg.AppId or "1234567890123456789"

    SetDiscordAppId(appId)
    SetDiscordRichPresenceAsset(cfg.AssetLogo or "berry_logo")
    SetDiscordRichPresenceAssetText(cfg.AssetLogoText or "Berry Framework")

    if cfg.AssetSmall and cfg.AssetSmall ~= "" then
        SetDiscordRichPresenceAssetSmall(cfg.AssetSmall)
        SetDiscordRichPresenceAssetSmallText(cfg.AssetSmallText or "Roleplay")
    end

    if cfg.Buttons and #cfg.Buttons > 0 then
        for i, btn in ipairs(cfg.Buttons) do
            if i <= 2 and btn.label and btn.url then
                SetDiscordRichPresenceAction(i - 1, btn.label, btn.url)
            end
        end
    end

    while true do
        Wait(cfg.UpdateIntervalMs or 15000)

        local pData = Berry.GetPlayerData() or {}
        local charName = pData.firstname and (pData.firstname .. " " .. (pData.lastname or "")) or GetPlayerName(PlayerId())
        local jobName = pData.job and pData.job.label or "Citoyen"
        local serverId = GetPlayerServerId(PlayerId())

        local statusText = string.format("Joueur: %s [ID: %d] | %s", charName, serverId, jobName)
        SetRichPresence(statusText)
    end
end)

-- ----------------------------------------------------------------------------
-- Spatial Markers Engine
-- ----------------------------------------------------------------------------
Berry.Markers = {}

local registeredMarkers = {}
local spatialChunks = {}
local activeMarker = nil

local function GetChunkKey(x, y)
    local chunkX = math.floor(x / 100.0)
    local chunkY = math.floor(y / 100.0)
    return string.format("%d_%d", chunkX, chunkY)
end

function Berry.Markers.Add(id, coords, options)
    if not coords then return end
    options = options or {}

    local vec
    if type(coords) == "vector3" then
        vec = coords
    elseif type(coords) == "table" then
        vec = vector3(
            tonumber(coords.x or coords[1]) or 0.0,
            tonumber(coords.y or coords[2]) or 0.0,
            tonumber(coords.z or coords[3]) or 0.0
        )
    else
        return
    end

    local sizeVec = options.size or vector3(1.0, 1.0, 1.0)
    if type(sizeVec) == "table" then
        sizeVec = vector3(
            tonumber(sizeVec.x or sizeVec[1]) or 1.0,
            tonumber(sizeVec.y or sizeVec[2]) or 1.0,
            tonumber(sizeVec.z or sizeVec[3]) or 1.0
        )
    end

    local markerData = {
        id = id,
        coords = vec,
        type = options.type or 1,
        size = sizeVec,
        color = options.color or { r = 192, g = 132, b = 252, a = 180 },
        drawDistance = options.drawDistance or 15.0,
        interactDistance = options.interactDistance or 1.5,
        label = options.label or "Interaction",
        onInteract = options.onInteract
    }

    registeredMarkers[id] = markerData

    local chunkKey = GetChunkKey(vec.x, vec.y)
    spatialChunks[chunkKey] = spatialChunks[chunkKey] or {}
    table.insert(spatialChunks[chunkKey], markerData)
end

function Berry.Markers.Remove(id)
    if registeredMarkers[id] then
        local coords = registeredMarkers[id].coords
        local chunkKey = GetChunkKey(coords.x, coords.y)
        if spatialChunks[chunkKey] then
            for i, m in ipairs(spatialChunks[chunkKey]) do
                if m.id == id then
                    table.remove(spatialChunks[chunkKey], i)
                    break
                end
            end
        end
        registeredMarkers[id] = nil
    end
end

Berry.ClientUtils.AddMarker = Berry.Markers.Add
Berry.ClientUtils.RemoveMarker = Berry.Markers.Remove

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local pCoords = GetEntityCoords(ped)
        local currentChunkKey = GetChunkKey(pCoords.x, pCoords.y)
        local nearbyMarkers = spatialChunks[currentChunkKey]

        if nearbyMarkers and #nearbyMarkers > 0 then
            local sleep = 500
            local closestDist = 9999.0
            local currentClosest = nil

            for _, marker in ipairs(nearbyMarkers) do
                local distSqr = #(pCoords - marker.coords)
                if distSqr < (marker.drawDistance * marker.drawDistance) then
                    sleep = 0
                    DrawMarker(
                        marker.type,
                        marker.coords.x, marker.coords.y, marker.coords.z,
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        marker.size.x, marker.size.y, marker.size.z,
                        marker.color.r, marker.color.g, marker.color.b, marker.color.a,
                        false, true, 2, false, nil, nil, false
                    )

                    if distSqr < (marker.interactDistance * marker.interactDistance) then
                        if distSqr < closestDist then
                            closestDist = distSqr
                            currentClosest = marker
                        end
                    end
                end
            end

            if currentClosest then
                activeMarker = currentClosest
                BeginTextCommandDisplayHelp("STRING")
                AddTextComponentSubstringPlayerName("Appuyez sur ~INPUT_CONTEXT~ pour ~purple~" .. currentClosest.label .. "~s~")
                EndTextCommandDisplayHelp(0, false, true, -1)

                if IsControlJustReleased(0, 38) then
                    if currentClosest.onInteract then
                        currentClosest.onInteract(currentClosest)
                    end
                end
            else
                activeMarker = nil
            end

            Wait(sleep)
        else
            Wait(1000)
        end
    end
end)

exports("AddMarker", Berry.Markers.Add)
exports("RemoveMarker", Berry.Markers.Remove)

-- ----------------------------------------------------------------------------
-- Minigames Engine
-- ----------------------------------------------------------------------------
Berry.Minigames = {}

function Berry.Minigames.StartSafeCrack(combination, cb)
    local targetCombination = combination or { math.random(10, 99), math.random(10, 99), math.random(10, 99) }
    local currentStep = 1
    local currentVal = 50
    local isCracking = true

    Berry.UI.Notify({ message = "Crack de coffre-fort démarré...", type = "info", duration = 3000, title = "MINIGAME" })

    CreateThread(function()
        while isCracking do
            Wait(0)
            DisableControlAction(0, 32, true)
            DisableControlAction(0, 33, true)

            BeginTextCommandDisplayHelp("STRING")
            AddTextComponentSubstringPlayerName(string.format("Combinaison [%d/%d] | Tournez la molette ~g~[Gauche/Droite]~s~ | ~y~ENTREE~s~ pour valider", currentStep, #targetCombination))
            EndTextCommandDisplayHelp(0, false, true, -1)

            if IsControlJustReleased(0, 174) or IsControlJustReleased(0, 34) then
                currentVal = (currentVal - 1) % 100
                PlaySoundFrontend(-1, "NAV_UP_DOWN", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
            elseif IsControlJustReleased(0, 175) or IsControlJustReleased(0, 35) then
                currentVal = (currentVal + 1) % 100
                PlaySoundFrontend(-1, "NAV_UP_DOWN", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
            elseif IsControlJustReleased(0, 18) then
                if currentVal == targetCombination[currentStep] then
                    PlaySoundFrontend(-1, "MATCH_POINT", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
                    currentStep = currentStep + 1
                    if currentStep > #targetCombination then
                        isCracking = false
                        Berry.UI.Notify({ message = "Coffre déverrouillé avec succès !", type = "success", duration = 4000, title = "SUCCÈS" })
                        if cb then cb(true) end
                        return
                    else
                        Berry.UI.Notify({ message = "Verrou " .. (currentStep - 1) .. " débloqué !", type = "success", duration = 2000 })
                    end
                else
                    PlaySoundFrontend(-1, "ERROR", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
                    Berry.UI.Notify({ message = "Erreur de combinaison ! Échec du crochetage.", type = "error", duration = 4000, title = "ÉCHEC" })
                    isCracking = false
                    if cb then cb(false) end
                    return
                end
            end
        end
    end)
end

function Berry.Minigames.StartHotwire(vehicle, cb)
    if not vehicle or vehicle == 0 then return end

    Berry.UI.Notify({ message = "Connexion des fils du démarreur...", type = "info", duration = 3000, title = "HOTWIRE" })
    TaskStartScenarioInPlace(PlayerPedId(), "WORLD_HUMAN_WELDING", 0, true)

    local successRate = math.random(1, 100)
    Wait(4000)

    ClearPedTasks(PlayerPedId())
    if successRate > 30 then
        SetVehicleEngineOn(vehicle, true, true, false)
        Berry.UI.Notify({ message = "Moteur démarré !", type = "success", duration = 4000, title = "VÉHICULE" })
        if cb then cb(true) end
    else
        Berry.UI.Notify({ message = "Échec du démarrage par câbles.", type = "error", duration = 4000, title = "ÉCHEC" })
        if cb then cb(false) end
    end
end

exports("StartSafeCrack", Berry.Minigames.StartSafeCrack)
exports("StartHotwire", Berry.Minigames.StartHotwire)

-- ============================================================================
-- SECTION 3: F1 NUI Menu, Client AntiCheat & Lifecycle Bootstrap
-- ============================================================================

local isMenuOpen = false
local currentMenuStack = {}
local currentMenuItems = {}
local isNoclipActive = false

local function PlayMenuSound(soundName)
    PlaySoundFrontend(-1, soundName or "NAV_UP_DOWN", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
end

local function CloseNuiMenu()
    if not isMenuOpen then return end
    isMenuOpen = false
    currentMenuStack = {}
    currentMenuItems = {}
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ action = "close" })
end

local function OpenNuiMenu(title, subtitle, items)
    TriggerEvent("ox_inventory:closeInventory")
    TriggerEvent("berry:ui:closeAll", "f1menu")
    isMenuOpen = true
    currentMenuItems = items
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({
        action = "open",
        title = title or "BERRY",
        subtitle = subtitle or "Actions",
        items = items
    })
end

local ShowMainMenu, OpenSubMenu

OpenSubMenu = function(menuKey)
    local pData = Berry.GetPlayerData() or {}
    local ped = PlayerPedId()

    if menuKey == "info" then
        local cash = pData.money and pData.money.cash or 0
        local bank = pData.money and pData.money.bank or 0
        local jobName = pData.job and pData.job.label or "Sans emploi"
        local jobGrade = pData.job and pData.job.grade_label or "Rien"

        local items = {
            { label = "Nom & Prénom", value = pData.firstname and (pData.firstname .. " " .. (pData.lastname or "")) or "Joueur" },
            { label = "Emploi Principal", value = jobName .. " (" .. jobGrade .. ")" },
            { label = "Portefeuille", value = cash .. "$" },
            { label = "Banque", value = bank .. "$" },
            { label = "Identifiant Serveur", value = "[" .. tostring(GetPlayerServerId(PlayerId())) .. "]" }
        }
        table.insert(currentMenuStack, { title = "INFORMATIONS", subtitle = "Profil Joueur", items = items })
        OpenNuiMenu("INFORMATIONS", "Profil Joueur", items)

    elseif menuKey == "company" then
        local jobName = pData.job and pData.job.label or "Sans emploi"
        local jobGrade = pData.job and pData.job.grade_label or "Rien"
        local salary = pData.job and pData.job.salary or 0

        local items = {
            { label = "Entreprise / Faction", value = jobName },
            { label = "Grade", value = jobGrade },
            { label = "Salaire Horaire", value = salary .. "$" },
            { label = "Consulter mes Factures", action = "cmd_mybills" },
            { label = "Créer une Facture (Clients)", action = "cmd_createbill" }
        }
        table.insert(currentMenuStack, { title = "ENTREPRISE", subtitle = "Gestion Métier", items = items })
        OpenNuiMenu("ENTREPRISE", "Gestion Métier", items)

    elseif menuKey == "vehicle" then
        local veh = GetVehiclePedIsIn(ped, false)
        if veh == 0 then
            Berry.ClientUtils.ShowNotification("Vous devez être dans un véhicule.", "warn")
            return
        end
        local engineState = GetIsVehicleEngineRunning(veh) and "ON" or "OFF"
        local lockState = GetVehicleDoorLockStatus(veh) == 2 and "Verrouillé" or "Déverrouillé"

        local items = {
            { label = "État Moteur", action = "veh_engine", value = engineState },
            { label = "Verrouillage Portes", action = "veh_lock", value = lockState },
            { label = "Ouvrir / Fermer Capot", action = "veh_hood" },
            { label = "Ouvrir / Fermer Coffre", action = "veh_trunk" },
            { label = "Limiteur de Vitesse", type = "submenu", menuKey = "veh_speedlimiter" }
        }
        table.insert(currentMenuStack, { title = "VÉHICULE", subtitle = "Gestion Véhicule", items = items })
        OpenNuiMenu("VÉHICULE", "Gestion Véhicule", items)

    elseif menuKey == "veh_speedlimiter" then
        local items = {
            { label = "Désactiver limiteur", action = "limiter_off" },
            { label = "50 km/h (Ville)", action = "limiter_50" },
            { label = "80 km/h (Route)", action = "limiter_80" },
            { label = "130 km/h (Autoroute)", action = "limiter_130" }
        }
        table.insert(currentMenuStack, { title = "LIMITEUR", subtitle = "Vitesse", items = items })
        OpenNuiMenu("LIMITEUR", "Vitesse", items)

    elseif menuKey == "properties" then
        local items = {
            { label = "Mes Logements possédés", action = "property_list" },
            { label = "Verrouiller / Déverrouiller Porte", action = "property_lock" },
            { label = "Accéder au Coffre de la maison", action = "property_storage" }
        }
        table.insert(currentMenuStack, { title = "PROPRIÉTÉS", subtitle = "Logements", items = items })
        OpenNuiMenu("PROPRIÉTÉS", "Logements", items)

    elseif menuKey == "emotes" then
        local items = {
            { label = "Danses & Fête", type = "submenu", menuKey = "emotes_dances" },
            { label = "Gestes & Gangs", type = "submenu", menuKey = "emotes_gestures" },
            { label = "Assis & Allongé", type = "submenu", menuKey = "emotes_sitting" },
            { label = "Boissons & Objets (Props)", type = "submenu", menuKey = "emotes_props" },
            { label = "Styles de Marche / Démarches", type = "submenu", menuKey = "walks" },
            { label = "Annuler l'animation en cours", action = "emote_cancel" }
        }
        table.insert(currentMenuStack, { title = "ANIMATIONS", subtitle = "Menu Emotes & Props", items = items })
        OpenNuiMenu("ANIMATIONS", "Menu Emotes & Props", items)

    elseif menuKey == "emotes_dances" then
        local items = {}
        if Berry.Emotes and Berry.Emotes.Categories then
            for idx, item in ipairs(Berry.Emotes.Categories.dances) do
                table.insert(items, { label = item.label, action = "play_dance_" .. idx })
            end
        end
        table.insert(currentMenuStack, { title = "DANSES", subtitle = "Fête & Nuit", items = items })
        OpenNuiMenu("DANSES", "Fête & Nuit", items)

    elseif menuKey == "emotes_gestures" then
        local items = {}
        if Berry.Emotes and Berry.Emotes.Categories then
            for idx, item in ipairs(Berry.Emotes.Categories.gestures) do
                table.insert(items, { label = item.label, action = "play_gesture_" .. idx })
            end
        end
        table.insert(currentMenuStack, { title = "GESTES", subtitle = "Gangs & Saluts", items = items })
        OpenNuiMenu("GESTES", "Gangs & Saluts", items)

    elseif menuKey == "emotes_sitting" then
        local items = {}
        if Berry.Emotes and Berry.Emotes.Categories then
            for idx, item in ipairs(Berry.Emotes.Categories.sitting) do
                table.insert(items, { label = item.label, action = "play_sit_" .. idx })
            end
        end
        table.insert(currentMenuStack, { title = "POSITIONS", subtitle = "Assis & Allongé", items = items })
        OpenNuiMenu("POSITIONS", "Assis & Allongé", items)

    elseif menuKey == "emotes_props" then
        local items = {}
        if Berry.Emotes and Berry.Emotes.Categories then
            for idx, item in ipairs(Berry.Emotes.Categories.props) do
                table.insert(items, { label = item.label, action = "play_prop_" .. idx })
            end
        end
        table.insert(currentMenuStack, { title = "OBJETS", subtitle = "Boissons & Repas", items = items })
        OpenNuiMenu("OBJETS", "Boissons & Repas", items)

    elseif menuKey == "walks" then
        local items = {
            { label = "Normal", action = "walk_normal" },
            { label = "Bravado / Fier", action = "walk_brave" },
            { label = "Confident / Confiant", action = "walk_confident" },
            { label = "Presse / Rapide", action = "walk_hurry" },
            { label = "Fatigue / Épuisé", action = "walk_tired" },
            { label = "Tueur / Sombre", action = "walk_gangster" }
        }
        table.insert(currentMenuStack, { title = "DÉMARCHES", subtitle = "Style de Marche", items = items })
        OpenNuiMenu("DÉMARCHES", "Style de Marche", items)

    elseif menuKey == "keys" then
        local items = {
            { label = "Menu Principal F1", value = "[F1]" },
            { label = "Inventaire Sac & Objets", value = "[F2]" },
            { label = "Tchat Serveur", value = "[T]" },
            { label = "Interaction / Ramasser", value = "[E]" },
            { label = "Téléphone Mobile", value = "[F3]" }
        }
        table.insert(currentMenuStack, { title = "TOUCHES", subtitle = "Guide Clavier", items = items })
        OpenNuiMenu("TOUCHES", "Guide Clavier", items)

    elseif menuKey == "commands" then
        local items = {
            { label = "Liste de mes véhicules", action = "cmd_myveh", value = "/myvehicles" },
            { label = "Action Roleplay (/me)", action = "cmd_me", value = "/me" },
            { label = "Description Environnement (/do)", action = "cmd_do", value = "/do" },
            { label = "Signaler un problème au Staff", action = "cmd_report", value = "/report" }
        }
        table.insert(currentMenuStack, { title = "COMMANDES", subtitle = "Serveur RP", items = items })
        OpenNuiMenu("COMMANDES", "Serveur RP", items)

    elseif menuKey == "admin" then
        local items = {
            { label = "Gestion Mode Noclip", action = "admin_noclip", value = isNoclipActive and "ON" or "OFF" },
            { label = "Se Soigner / Revive", action = "admin_heal" },
            { label = "Faire Apparaître un Véhicule", action = "admin_spawnveh" },
            { label = "Réparer & Nettoyer Véhicule", action = "admin_fixveh" },
            { label = "Supprimer le Véhicule le plus proche", action = "admin_delveh" },
            { label = "Liste des Joueurs Connectés", action = "admin_players" },
            { label = "Statistiques CPU & RAM Serveur", action = "admin_stats" }
        }
        table.insert(currentMenuStack, { title = "ADMINISTRATION", subtitle = "Menu Staff", items = items })
        OpenNuiMenu("ADMINISTRATION", "Menu Staff", items)
    end
end

ShowMainMenu = function()
    local mainItems = {
        { label = "Informations", type = "submenu", menuKey = "info" },
        { label = "Entreprise & Métier", type = "submenu", menuKey = "company" },
        { label = "Gestion Véhicule", type = "submenu", menuKey = "vehicle" },
        { label = "Propriétés & Logements", type = "submenu", menuKey = "properties" },
        { label = "Animations & Démarches", type = "submenu", menuKey = "emotes" },
        { label = "Touches du Serveur", type = "submenu", menuKey = "keys" },
        { label = "Commandes RP", type = "submenu", menuKey = "commands" }
    }

    local pData = Berry.GetPlayerData() or {}
    local group = tostring(pData.group or pData.permission or "citoyen"):lower()
    if group == "fondateur" or group == "co_fondateur" or group == "administrateur" or group == "moderateur" or group == "helper" or group == "admin" or group == "superadmin" or group == "owner" then
        table.insert(mainItems, { label = "Menu Staff & Modération", type = "submenu", menuKey = "admin" })
    end

    table.insert(currentMenuStack, { title = "BERRY", subtitle = "Menu Principal", items = mainItems })
    OpenNuiMenu("BERRY", "Menu Principal", mainItems)
end

RegisterNetEvent("berry:ui:closeAll", function(exceptSource)
    if exceptSource ~= "f1menu" then
        CloseNuiMenu()
    end
end)

RegisterNUICallback("selectItem", function(data, cb)
    local idx = data.index + 1
    local item = currentMenuItems[idx]
    if not item then return cb("ok") end

    PlayMenuSound("SELECT")

    if item.type == "submenu" then
        OpenSubMenu(item.menuKey)
    elseif item.action then
        local ped = PlayerPedId()

        if string.find(item.action, "play_dance_") then
            local id = tonumber(string.sub(item.action, 12))
            local e = Berry.Emotes and Berry.Emotes.Categories and Berry.Emotes.Categories.dances[id]
            if e then Berry.Emotes.Play(e.dict, e.anim) end
        elseif string.find(item.action, "play_gesture_") then
            local id = tonumber(string.sub(item.action, 14))
            local e = Berry.Emotes and Berry.Emotes.Categories and Berry.Emotes.Categories.gestures[id]
            if e then Berry.Emotes.Play(e.dict, e.anim) end
        elseif string.find(item.action, "play_sit_") then
            local id = tonumber(string.sub(item.action, 10))
            local e = Berry.Emotes and Berry.Emotes.Categories and Berry.Emotes.Categories.sitting[id]
            if e then Berry.Emotes.Play(e.dict, e.anim) end
        elseif string.find(item.action, "play_prop_") then
            local id = tonumber(string.sub(item.action, 11))
            local e = Berry.Emotes and Berry.Emotes.Categories and Berry.Emotes.Categories.props[id]
            if e then Berry.Emotes.Play(e.dict, e.anim, e.prop, e.bone, e.pos, e.rot) end
        elseif item.action == "emote_cancel" then
            if Berry.Emotes then Berry.Emotes.Stop() end

        elseif item.action == "veh_engine" then
            local veh = GetVehiclePedIsIn(ped, false)
            if veh ~= 0 then
                local running = GetIsVehicleEngineRunning(veh)
                SetVehicleEngineOn(veh, not running, false, true)
                Berry.ClientUtils.ShowNotification("Moteur " .. (running and "éteint" or "allumé") .. ".", "info")
            end
        elseif item.action == "veh_lock" then
            local veh = GetVehiclePedIsIn(ped, false)
            if veh ~= 0 then
                local locked = GetVehicleDoorLockStatus(veh) == 2
                SetVehicleDoorsLocked(veh, locked and 1 or 2)
                Berry.ClientUtils.ShowNotification("Portes " .. (locked and "déverrouillées" or "verrouillées") .. ".", "info")
            end
        elseif item.action == "veh_hood" then
            local veh = GetVehiclePedIsIn(ped, false)
            if veh ~= 0 then if GetVehicleDoorAngleRatio(veh, 4) > 0.0 then SetVehicleDoorShut(veh, 4, false) else SetVehicleDoorOpen(veh, 4, false, false) end end
        elseif item.action == "veh_trunk" then
            local veh = GetVehiclePedIsIn(ped, false)
            if veh ~= 0 then if GetVehicleDoorAngleRatio(veh, 5) > 0.0 then SetVehicleDoorShut(veh, 5, false) else SetVehicleDoorOpen(veh, 5, false, false) end end
        elseif item.action == "limiter_50" then local veh = GetVehiclePedIsIn(ped, false) if veh ~= 0 then SetVehicleMaxSpeed(veh, 50.0 / 3.6) Berry.ClientUtils.ShowNotification("Limiteur à 50 km/h.", "info") end
        elseif item.action == "limiter_80" then local veh = GetVehiclePedIsIn(ped, false) if veh ~= 0 then SetVehicleMaxSpeed(veh, 80.0 / 3.6) Berry.ClientUtils.ShowNotification("Limiteur à 80 km/h.", "info") end
        elseif item.action == "limiter_130" then local veh = GetVehiclePedIsIn(ped, false) if veh ~= 0 then SetVehicleMaxSpeed(veh, 130.0 / 3.6) Berry.ClientUtils.ShowNotification("Limiteur à 130 km/h.", "info") end
        elseif item.action == "limiter_off" then local veh = GetVehiclePedIsIn(ped, false) if veh ~= 0 then SetVehicleMaxSpeed(veh, 0.0) Berry.ClientUtils.ShowNotification("Limiteur désactivé.", "info") end

        elseif item.action == "walk_normal" then ResetPedMovementClipset(ped, 0.2)
        elseif item.action == "walk_brave" then RequestAnimSet("move_m@brave") while not HasAnimSetLoaded("move_m@brave") do Wait(10) end SetPedMovementClipset(ped, "move_m@brave", 0.2)
        elseif item.action == "walk_confident" then RequestAnimSet("move_m@confident") while not HasAnimSetLoaded("move_m@confident") do Wait(10) end SetPedMovementClipset(ped, "move_m@confident", 0.2)
        elseif item.action == "walk_hurry" then RequestAnimSet("move_m@hurry@a") while not HasAnimSetLoaded("move_m@hurry@a") do Wait(10) end SetPedMovementClipset(ped, "move_m@hurry@a", 0.2)
        elseif item.action == "walk_tired" then RequestAnimSet("move_m@tired") while not HasAnimSetLoaded("move_m@tired") do Wait(10) end SetPedMovementClipset(ped, "move_m@tired", 0.2)
        elseif item.action == "walk_gangster" then RequestAnimSet("move_m@gangster@var_e") while not HasAnimSetLoaded("move_m@gangster@var_e") do Wait(10) end SetPedMovementClipset(ped, "move_m@gangster@var_e", 0.2)

        elseif item.action == "cmd_myveh" then ExecuteCommand("myvehicles") CloseNuiMenu()
        elseif item.action == "cmd_me" then ExecuteCommand("me") CloseNuiMenu()
        elseif item.action == "cmd_do" then ExecuteCommand("do") CloseNuiMenu()
        elseif item.action == "cmd_report" then ExecuteCommand("report") CloseNuiMenu()

        elseif item.action == "admin_noclip" then
            isNoclipActive = not isNoclipActive
            SetEntityVisible(ped, not isNoclipActive, false)
            SetEntityInvincible(ped, isNoclipActive)
            Berry.ClientUtils.ShowNotification("Noclip " .. (isNoclipActive and "activé" or "désactivé") .. ".", "info")
        elseif item.action == "admin_heal" then
            SetEntityHealth(ped, 200)
            AddArmourToPed(ped, 100)
            Berry.ClientUtils.ShowNotification("Soin et armure max appliqués.", "success")
        elseif item.action == "admin_fixveh" then
            local veh = GetVehiclePedIsIn(ped, false)
            if veh ~= 0 then SetVehicleFixed(veh) SetVehicleDirtLevel(veh, 0.0) Berry.ClientUtils.ShowNotification("Véhicule réparé.", "success") end
        elseif item.action == "admin_delveh" then
            local veh = GetVehiclePedIsIn(ped, false)
            if veh ~= 0 then DeleteVehicle(veh) else
                local coords = GetEntityCoords(ped)
                local closeVeh = GetClosestVehicle(coords.x, coords.y, coords.z, 5.0, 0, 71)
                if DoesEntityExist(closeVeh) then DeleteVehicle(closeVeh) end
            end
            Berry.ClientUtils.ShowNotification("Véhicule supprimé.", "info")
        elseif item.action == "admin_stats" then
            ExecuteCommand("berrystats")
            CloseNuiMenu()
        end
    end

    cb("ok")
end)

RegisterNUICallback("backMenu", function(data, cb)
    PlayMenuSound("BACK")
    if #currentMenuStack > 1 then
        table.remove(currentMenuStack)
        local prev = currentMenuStack[#currentMenuStack]
        OpenNuiMenu(prev.title, prev.subtitle, prev.items)
    else
        CloseNuiMenu()
    end
    cb("ok")
end)

RegisterNUICallback("closeMenu", function(data, cb)
    CloseNuiMenu()
    cb("ok")
end)

RegisterNUICallback("playSound", function(data, cb)
    PlayMenuSound(data.name)
    cb("ok")
end)

RegisterCommand("berryf1menu", function()
    if isMenuOpen then
        CloseNuiMenu()
    else
        ShowMainMenu()
    end
end, false)

RegisterKeyMapping("berryf1menu", "Ouvrir le menu F1 Berry", "keyboard", "F1")

exports("CloseF1Menu", CloseNuiMenu)

-- ----------------------------------------------------------------------------
-- Client AntiCheat Engine
-- ----------------------------------------------------------------------------
local acGraceUntil = GetGameTimer() + 10000

local function ExtendAcGrace(ms)
    acGraceUntil = math.max(acGraceUntil, GetGameTimer() + (ms or 8000))
    TriggerServerEvent("berry:ac:extendGrace", ms or 8000)
end

local function IsGameplaySettled(ped)
    if GetGameTimer() < acGraceUntil then return false end
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end
    if IsPlayerSwitchInProgress() or IsPauseMenuActive() then return false end
    if IsScreenFadedOut() or IsScreenFadingOut() or IsScreenFadingIn() then return false end
    if not HasCollisionLoadedAroundEntity(ped) then return false end
    return true
end

CreateThread(function()
    while true do
        Wait(4000)
        local ped = PlayerPedId()

        TriggerServerEvent("berry:ac:heartbeat")

        if IsGameplaySettled(ped) then
            if GetUsingseethrough() or GetUsingnightvision() then
                TriggerServerEvent("berry:ac:violation", "Vision Thermique / Nocturne non autorisée")
            end

            if IsPedUsingActionMode(ped) and IsControlPressed(0, 22) then
                if GetEntitySpeed(ped) > 25.0 and not IsPedInAnyVehicle(ped, false) then
                    TriggerServerEvent("berry:ac:violation", "Super Jump / Speed Hack à pied")
                end
            end

            if NetworkIsInSpectatorMode() then
                TriggerServerEvent("berry:ac:violation", "Mode Spectateur non autorisé")
            end
        end
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        TriggerServerEvent("berry:ac:resourceStopped", "Tentative de désactivation / arrêt du Core détectée")
    end
end)

RegisterNetEvent("berry:ac:extendGrace", function(ms)
    ExtendAcGrace(ms)
end)

exports("ExtendGrace", ExtendAcGrace)

-- ----------------------------------------------------------------------------
-- Client Bootstrap Lifecycle Signal
-- ----------------------------------------------------------------------------
CreateThread(function()
    TriggerEvent("berry:clientCoreReady")
end)
