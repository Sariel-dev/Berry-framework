local Berry = exports["berry-core"]:GetCoreObject()

-- Command Register Wrappers
RegisterCommand("kick", function(source, args)
    if source > 0 and not Berry.Permissions.Has(source, "moderator") then
        return TriggerClientEvent("berry:notify", source, "Permission refusée.", "error")
    end

    local targetSrc = tonumber(args[1])
    local reason = args[2] or "Expulsé par un modérateur."
    if targetSrc then
        DropPlayer(targetSrc, reason)
        Berry.Logger.Info("ADMIN", "Player source %d kicked by source %d", targetSrc, source)
    end
end, false)

RegisterCommand("givemoney", function(source, args)
    if source > 0 and not Berry.Permissions.Has(source, "administrator") then
        return TriggerClientEvent("berry:notify", source, "Permission refusée.", "error")
    end

    local targetSrc = tonumber(args[1])
    local account = args[2] or "cash"
    local amount = tonumber(args[3])

    local targetPlayer = Berry.GetPlayer(targetSrc)
    if targetPlayer and amount then
        targetPlayer:AddMoney(account, amount, "admin_grant")
        if source > 0 then
            TriggerClientEvent("berry:notify", source, string.format("Donné %.2f$ à %s", amount, targetPlayer:GetName()), "success")
        end
    end
end, false)
