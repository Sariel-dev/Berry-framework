local Berry = exports["berry-core"]:GetCoreObject()

RegisterCommand("berrystats", function(source)
    if source > 0 and not Berry.Permissions.Has(source, "administrator") then
        return
    end

    local count = 0
    for _ in pairs(Berry.PlayersBySource) do count = count + 1 end

    local msg = string.format("[BERRY METRICS] Active Players: %d | Memory Usage: %.2f KB", count, collectgarbage("count"))
    if source > 0 then
        TriggerClientEvent("berry:notify", source, msg, "info")
    else
        print("^2" .. msg .. "^7")
    end
end, false)
