local ECM = exports["ContextMenuV6"]

ECM:Register(function(screenPosition, hitSomething, worldPosition, hitEntity, normalDirection)
    if not DoesEntityExist(hitEntity) or not IsEntityAVehicle(hitEntity) then
        return
    end

    local vehicle = hitEntity
    local plate = GetVehicleNumberPlateText(vehicle)

    -- 1. Lock / Unlock Doors
    local btn_lock = ECM:AddItem(0, "Verrouiller / Déverrouiller")
    ECM:LeftIcon(btn_lock, "fa-solid fa-lock")
    ECM:OnActivate(btn_lock, function()
        local locked = GetVehicleDoorLockStatus(vehicle) == 2
        SetVehicleDoorsLocked(vehicle, locked and 1 or 2)
        exports["berry-core"]:Notify("Portes " .. (locked and "déverrouillées" or "verrouillées") .. ".", "info")
    end)

    -- 2. Toggle Engine
    local btn_engine = ECM:AddItem(0, "Allumer / Éteindre Moteur")
    ECM:LeftIcon(btn_engine, "fa-solid fa-power-off")
    ECM:OnActivate(btn_engine, function()
        local running = GetIsVehicleEngineRunning(vehicle)
        SetVehicleEngineOn(vehicle, not running, false, true)
    end)

    -- 3. Open Trunk & Access Trunk Inventory
    local btn_trunk = ECM:AddItem(0, "Ouvrir Coffre & Stockage")
    ECM:LeftIcon(btn_trunk, "fa-solid fa-box-archive")
    ECM:OnActivate(btn_trunk, function()
        if GetVehicleDoorAngleRatio(vehicle, 5) < 0.1 then
            SetVehicleDoorOpen(vehicle, 5, false, false)
        end
        exports["berry-core"]:OpenInventory("trunk_" .. plate)
    end)

    -- 4. Open Hood
    local btn_hood = ECM:AddItem(0, "Ouvrir / Fermer Capot")
    ECM:LeftIcon(btn_hood, "fa-solid fa-car-battery")
    ECM:OnActivate(btn_hood, function()
        if GetVehicleDoorAngleRatio(vehicle, 4) < 0.1 then
            SetVehicleDoorOpen(vehicle, 4, false, false)
        else
            SetVehicleDoorShut(vehicle, 4, false)
        end
    end)

    -- 5. Hotwire / Lockpick Vehicle
    local btn_hotwire = ECM:AddItem(0, "Démarrer aux Câbles")
    ECM:LeftIcon(btn_hotwire, "fa-solid fa-bolt")
    ECM:OnActivate(btn_hotwire, function()
        exports["berry-core"]:StartHotwire(function(success)
            if success then
                SetVehicleEngineOn(vehicle, true, true, false)
                exports["berry-core"]:Notify("Véhicule démarré aux câbles avec succès !", "success")
            else
                exports["berry-core"]:Notify("Échec du démarrage aux câbles.", "error")
            end
        end)
    end)

    -- 6. Delete Vehicle (Admin)
    local btn_delete = ECM:AddItem(0, "Supprimer le véhicule (Admin)")
    ECM:LeftIcon(btn_delete, "fa-solid fa-trash-can")
    ECM:OnActivate(btn_delete, function()
        SetEntityAsMissionEntity(vehicle, true, true)
        DeleteVehicle(vehicle)
        exports["berry-core"]:Notify("Véhicule supprimé.", "info")
    end)
end)
