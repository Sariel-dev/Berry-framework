local Berry = exports["berry-core"]:GetCoreObject()

RegisterNetEvent("berry:interim:completeDelivery", function()
    local src = source
    local player = Berry.GetPlayer(src)
    if not player then return end

    local reward = math.random(350, 650)
    player:AddMoney("cash", reward, "interim_delivery")
    Berry.UI.Notify(src, { message = "Livraison effectuée avec succès ! Vous avez reçu " .. reward .. "$ en liquide.", type = "success" })
end)
