-- ============================================================================
-- Berry Framework — Client UI (F1 Menu), AntiCheat & Lifecycle Bootstrap
-- ============================================================================

Berry = Berry or {}

-- Enable Lua 5.4 Generational GC on client
if collectgarbage then
    pcall(function()
        collectgarbage("generational")
    end)
end

-- ----------------------------------------------------------------------------
-- 1. F1 Master NUI Menu Engine
-- ----------------------------------------------------------------------------
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
-- 2. Client AntiCheat Engine
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
-- 3. Client Bootstrap Lifecycle Signal
-- ----------------------------------------------------------------------------
CreateThread(function()
    TriggerEvent("berry:clientCoreReady")
end)
