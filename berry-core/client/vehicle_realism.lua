local Berry = exports["berry-core"]:GetCoreObject()

-- Vehicle Realism Engine
CreateThread(function()
    while true do
        Wait(1000)
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local veh = GetVehiclePedIsIn(ped, false)
            if GetPedInVehicleSeat(veh, -1) == ped then
                local engineHealth = GetVehicleEngineHealth(veh)

                -- Damage Threshold Engine
                if engineHealth <= 250.0 then
                    SetVehicleEngineOn(veh, false, true, true)
                    SetVehicleUndriveable(veh, true)
                    Berry.ClientUtils.ShowNotification("Le moteur est tombé en panne en raison des dégâts subis !", "error")
                end
            end
        end
    end
end)

-- Repair Kit Event
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
