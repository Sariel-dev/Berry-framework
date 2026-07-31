-- Enable Lua 5.4 Generational GC on client
if collectgarbage then
    pcall(function()
        collectgarbage("generational")
    end)
end

CreateThread(function()
    TriggerEvent("berry:clientCoreReady")
end)
