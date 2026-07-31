local Berry = exports["berry-core"]:GetCoreObject()

local graceUntil = GetGameTimer() + 10000

local function ExtendGrace(ms)
    graceUntil = math.max(graceUntil, GetGameTimer() + (ms or 8000))
    TriggerServerEvent("berry:ac:extendGrace", ms or 8000)
end

local function IsGameplaySettled(ped)
    if GetGameTimer() < graceUntil then return false end
    if not ped or ped == 0 or not DoesEntityExist(ped) then return false end
    if IsPlayerSwitchInProgress() or IsPauseMenuActive() then return false end
    if IsScreenFadedOut() or IsScreenFadingOut() or IsScreenFadingIn() then return false end
    if not HasCollisionLoadedAroundEntity(ped) then return false end
    return true
end

-- Client Anti-Cheat Loop & Heartbeat (Runs every 4 seconds)
CreateThread(function()
    while true do
        Wait(4000)
        local ped = PlayerPedId()

        -- Send Heartbeat to Server (Anti-Core Stop / Freeze Protection)
        TriggerServerEvent("berry:ac:heartbeat")

        if IsGameplaySettled(ped) then
            -- 1. Thermal / Night Vision Detection
            if GetUsingseethrough() or GetUsingnightvision() then
                TriggerServerEvent("berry:ac:violation", "Vision Thermique / Nocturne non autorisée")
            end

            -- 2. Super Jump / Speed Hack Detection
            if IsPedUsingActionMode(ped) and IsControlPressed(0, 22) then
                if GetEntitySpeed(ped) > 25.0 and not IsPedInAnyVehicle(ped, false) then
                    TriggerServerEvent("berry:ac:violation", "Super Jump / Speed Hack à pied")
                end
            end

            -- 3. Spectate Mode Detection
            if NetworkIsInSpectatorMode() then
                TriggerServerEvent("berry:ac:violation", "Mode Spectateur non autorisé")
            end
        end
    end
end)

-- Anti-Resource Stop / Anti-Core Disable Protection
AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        TriggerServerEvent("berry:ac:resourceStopped", "Tentative de désactivation / arrêt du Core détectée")
    end
end)

-- Event Listeners for Grace Periods (e.g. Teleport, Spawn, Hospital)
RegisterNetEvent("berry:ac:extendGrace", function(ms)
    ExtendGrace(ms)
end)

exports("ExtendGrace", ExtendGrace)
