local Berry = exports["berry-core"]:GetCoreObject()

ESX = ESX or {}

function ESX.GetPlayerFromId(source)
    local berryPlayer = Berry.GetPlayer(source)
    if not berryPlayer then return nil end

    return {
        source = berryPlayer:GetSource(),
        identifier = berryPlayer:GetIdentifier(),
        getName = function() return berryPlayer:GetName() end,
        getMoney = function() return berryPlayer:GetMoney("cash") end,
        addMoney = function(amount) return berryPlayer:AddMoney("cash", amount, "esx_bridge") end,
        removeMoney = function(amount) return berryPlayer:RemoveMoney("cash", amount, "esx_bridge") end,
        getAccount = function(name) return { name = name, money = berryPlayer:GetMoney(name) } end,
        addAccountMoney = function(name, amount) return berryPlayer:AddMoney(name, amount, "esx_bridge") end,
        removeAccountMoney = function(name, amount) return berryPlayer:RemoveMoney(name, amount, "esx_bridge") end,
        getJob = function() return berryPlayer:GetJob() end,
        setJob = function(job, grade) return berryPlayer:SetJob(job, grade) end
    }
end

function ESX.RegisterServerCallback(name, cb)
    Berry.Callbacks.Register(name, cb)
end

AddEventHandler("esx:getSharedObject", function(cb)
    cb(ESX)
end)

exports("getSharedObject", function()
    return ESX
end)
