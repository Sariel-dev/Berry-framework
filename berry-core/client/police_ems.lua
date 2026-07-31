local Berry = exports["berry-core"]:GetCoreObject()

local isHandcuffed = false
local isEscorted = false
local escortingPlayer = nil
local isDead = false

-- Handcuff Handling
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

-- Disable Controls when Handcuffed or Dead
CreateThread(function()
    while true do
        if isHandcuffed or isDead then
            Wait(0)
            DisableControlAction(0, 24, true) -- Attack
            DisableControlAction(0, 257, true) -- Attack 2
            DisableControlAction(0, 25, true) -- Aim
            DisableControlAction(0, 45, true) -- Reload
            DisableControlAction(0, 22, true) -- Jump
            DisableControlAction(0, 23, true) -- Enter vehicle
            DisableControlAction(0, 37, true) -- Select Weapon
            DisableControlAction(0, 289, true) -- F2 Inventory
            DisableControlAction(0, 288, true) -- F1 Menu
        else
            Wait(500)
        end
    end
end)

-- Escort Handling
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

-- Vehicle Put In / Out
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

-- EMS Revive & Heal
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
