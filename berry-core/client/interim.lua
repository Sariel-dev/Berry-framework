local Berry = exports["berry-core"]:GetCoreObject()

local isWorkingInterim = false
local currentDeliveryBlip = nil
local currentDeliveryMarker = nil

local deliveryPoints = {
    vector3(145.4, -1045.2, 29.3),
    vector3(-708.5, -914.2, 19.2),
    vector3(380.7, -825.1, 29.3),
    vector3(1159.8, -325.2, 69.2),
    vector3(-1222.8, -907.2, 12.3)
}

local function StartDeliveryJob()
    if isWorkingInterim then
        Berry.ClientUtils.ShowNotification("Vous avez déjà une mission de livraison en cours.", "warn")
        return
    end

    isWorkingInterim = true
    local targetCoords = deliveryPoints[math.random(1, #deliveryPoints)]

    Berry.ClientUtils.ShowNotification("Mission de livraison débutée ! Rendez-vous au point GPS.", "info")

    currentDeliveryBlip = AddBlipForCoord(targetCoords.x, targetCoords.y, targetCoords.z)
    SetBlipSprite(currentDeliveryBlip, 1)
    SetBlipColour(currentDeliveryBlip, 5)
    SetBlipRoute(currentDeliveryBlip, true)

    Berry.ClientUtils.AddMarker("interim_delivery", {
        coords = targetCoords,
        text = "Livraison de Colis\nAppuyez sur ~g~[E]~s~ pour livrer",
        drawDistance = 20.0,
        interactDistance = 2.5,
        onInteract = function()
            Berry.UI.ProgressBar("Livraison du colis en cours...", 4000, function()
                TriggerServerEvent("berry:interim:completeDelivery")
                RemoveBlip(currentDeliveryBlip)
                Berry.ClientUtils.RemoveMarker("interim_delivery")
                isWorkingInterim = false
            end)
        end
    })
end

-- Register Job Center Marker at City Hall
RegisterNetEvent("berry:clientCoreReady", function()
    Wait(3000)
    Berry.ClientUtils.AddMarker("job_center_interim", {
        coords = vector3(-266.3, -961.1, 31.2),
        text = "Pôle Emploi Intérim\nAppuyez sur ~g~[E]~s~ pour lancer une mission de livraison",
        drawDistance = 15.0,
        interactDistance = 2.0,
        onInteract = function()
            StartDeliveryJob()
        end
    })
end)
