local Berry = exports["berry-core"]:GetCoreObject()

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
