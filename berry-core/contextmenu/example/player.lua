local ECM = exports["ContextMenuV6"]

ECM:Register(function(screenPosition, hitSomething, worldPosition, hitEntity, normalDirection)
    local ped = PlayerPedId()

    -- 1. Self Interaction (Clicked on Myself)
    if hitEntity == ped then
        local btn_inv = ECM:AddItem(0, "Ouvrir mon Sac & Inventaire")
        ECM:LeftIcon(btn_inv, "fa-solid fa-briefcase")
        ECM:OnActivate(btn_inv, function()
            TriggerEvent("ox_inventory:openInventory")
        end)

        local btn_cancel = ECM:AddItem(0, "Arrêter l'animation")
        ECM:LeftIcon(btn_cancel, "fa-solid fa-ban")
        ECM:OnActivate(btn_cancel, function()
            exports["berry-core"]:StopEmote()
        end)

        return
    end

    -- 2. Other Player Interaction
    if DoesEntityExist(hitEntity) and IsPedAPlayer(hitEntity) then
        local targetPlayer = NetworkGetPlayerIndexFromPed(hitEntity)
        local targetServerId = GetPlayerServerId(targetPlayer)

        if targetServerId and targetServerId > 0 then
            -- Fouiller
            local btn_search = ECM:AddItem(0, "Fouiller le personnage")
            ECM:LeftIcon(btn_search, "fa-solid fa-magnifying-glass")
            ECM:OnActivate(btn_search, function()
                exports["berry-core"]:OpenInventory("otherplayer_" .. targetServerId)
            end)

            -- Menotter / Démenotter
            local btn_cuff = ECM:AddItem(0, "Menotter / Démenotter")
            ECM:LeftIcon(btn_cuff, "fa-solid fa-handcuffs")
            ECM:OnActivate(btn_cuff, function()
                ExecuteCommand("cuff " .. targetServerId)
            end)

            -- Escorter
            local btn_escort = ECM:AddItem(0, "Escorter le personnage")
            ECM:LeftIcon(btn_escort, "fa-solid fa-person-walking-luggage")
            ECM:OnActivate(btn_escort, function()
                ExecuteCommand("escort " .. targetServerId)
            end)

            -- Véhicule Actions
            local sub_veh, sub_veh_item = ECM:AddSubmenu(0, "Interaction Véhicule")
            ECM:LeftIcon(sub_veh_item, "fa-solid fa-car")

            local btn_putin = ECM:AddItem(sub_veh, "Mettre dans le véhicule")
            ECM:OnActivate(btn_putin, function()
                ExecuteCommand("putinveh " .. targetServerId)
            end)

            local btn_outveh = ECM:AddItem(sub_veh, "Faire sortir du véhicule")
            ECM:OnActivate(btn_outveh, function()
                ExecuteCommand("outveh " .. targetServerId)
            end)

            -- Soigner / Revive (Admin / EMS)
            local btn_heal = ECM:AddItem(0, "Réanimer / Soigner")
            ECM:LeftIcon(btn_heal, "fa-solid fa-kit-medical")
            ECM:OnActivate(btn_heal, function()
                ExecuteCommand("revive " .. targetServerId)
            end)
        end
    end
end)
