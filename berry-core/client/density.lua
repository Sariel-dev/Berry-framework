local Berry = exports["berry-core"]:GetCoreObject()

-- Ped & Traffic Density Tuning (0.00ms CPU)
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
