Berry.PlayerData = {}

RegisterNetEvent("berry:playerLoaded", function(playerData)
    Berry.PlayerData = playerData
    TriggerEvent("berry:clientPlayerLoaded", playerData)
end)

RegisterNetEvent("berry:moneyChanged", function(account, newBalance, amount, changeType)
    if Berry.PlayerData and Berry.PlayerData.money then
        Berry.PlayerData.money[account] = newBalance
    end
    TriggerEvent("berry:clientMoneyChanged", account, newBalance, amount, changeType)
end)

RegisterNetEvent("berry:jobChanged", function(newJob)
    if Berry.PlayerData then
        Berry.PlayerData.job = newJob
    end
    TriggerEvent("berry:clientJobChanged", newJob)
end)

RegisterNetEvent("berry:metadataChanged", function(key, value)
    if Berry.PlayerData then
        Berry.PlayerData.metadata = Berry.PlayerData.metadata or {}
        Berry.PlayerData.metadata[key] = value
    end
    TriggerEvent("berry:clientMetadataChanged", key, value)
end)

function Berry.GetPlayerData()
    return Berry.PlayerData
end
