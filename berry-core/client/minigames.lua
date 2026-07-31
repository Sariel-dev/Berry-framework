local Berry = exports["berry-core"]:GetCoreObject()
Berry.Minigames = {}

-- 1. Safe Cracking Minigame
function Berry.Minigames.StartSafeCrack(combination, cb)
    local targetCombination = combination or { math.random(10, 99), math.random(10, 99), math.random(10, 99) }
    local currentStep = 1
    local currentVal = 50
    local isCracking = true

    Berry.UI.Notify({ message = "Crack de coffre-fort démarré...", type = "info", duration = 3000, title = "MINIGAME" })

    CreateThread(function()
        while isCracking do
            Wait(0)
            DisableControlAction(0, 32, true) -- W
            DisableControlAction(0, 33, true) -- S

            BeginTextCommandDisplayHelp("STRING")
            AddTextComponentSubstringPlayerName(string.format("Combinaison [%d/%d] | Tournez la molette ~g~[Gauche/Droite]~s~ | ~y~ENTREE~s~ pour valider", currentStep, #targetCombination))
            EndTextCommandDisplayHelp(0, false, true, -1)

            if IsControlJustReleased(0, 174) or IsControlJustReleased(0, 34) then -- Left / A
                currentVal = (currentVal - 1) % 100
                PlaySoundFrontend(-1, "NAV_UP_DOWN", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
            elseif IsControlJustReleased(0, 175) or IsControlJustReleased(0, 35) then -- Right / D
                currentVal = (currentVal + 1) % 100
                PlaySoundFrontend(-1, "NAV_UP_DOWN", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
            elseif IsControlJustReleased(0, 18) then -- Enter
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

-- 2. Hotwire Minigame
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
