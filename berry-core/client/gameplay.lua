-- ============================================================================
-- Berry Framework — Client Gameplay Systems Engine
-- ============================================================================

Berry = Berry or {}

-- ----------------------------------------------------------------------------
-- 1. Player Data & State Listeners
-- ----------------------------------------------------------------------------
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
-- 2. Character Selector Loader
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
-- 3. Vehicle Commands & Realism Engine
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
-- 4. Properties Markers & Sync Engine
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
-- 5. Police & EMS Engine
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
-- 6. Emote Engine & Categories Data
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
-- 7. Traffic Density & Discord Rich Presence Threads
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
-- 8. Spatial Markers Engine
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
    options = options or {}
    local markerData = {
        id = id,
        coords = vector3(coords.x, coords.y, coords.z),
        type = options.type or 1,
        size = options.size or vector3(1.0, 1.0, 1.0),
        color = options.color or { r = 192, g = 132, b = 252, a = 180 },
        drawDistance = options.drawDistance or 15.0,
        interactDistance = options.interactDistance or 1.5,
        label = options.label or "Interaction",
        onInteract = options.onInteract
    }

    registeredMarkers[id] = markerData

    local chunkKey = GetChunkKey(coords.x, coords.y)
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
-- 9. Minigames Engine
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
