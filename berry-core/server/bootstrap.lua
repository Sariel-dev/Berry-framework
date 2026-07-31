-- Enable Lua 5.4 Generational Garbage Collector for maximum throughput
if collectgarbage then
    pcall(function()
        collectgarbage("generational")
        collectgarbage("setpause", 110)
        collectgarbage("setstepmul", 300)
    end)
end

local function PrintBanner()
    print([[
^5
  ____                        _____                                             _    
 |  _ \                      |  ___|                                           | |   
 | |_) | ___ _ __ _ __ _   _ | |_ _ __ __ _ _ __ ___   _____      _____  _ __| | __
 |  _ < / _ \ '__| '__| | | ||  _| '__/ _` | '_ ` _ \ / _ \ \ /\ / / _ \| '__| |/ /
 | |_) |  __/ |  | |  | |_| || | | | | (_| | | | | | |  __/\ V  V / (_) | |  |   < 
 |____/ \___|_|  |_|   \__, ||_| |_|  \__,_|_| |_| |_|\___| \_/\_/ \___/|_|  |_|\_\
                        __/ |                                                        
                       |___/    v1.0.0 — Ultimate Modern Roleplay Engine
^7]])
end

CreateThread(function()
    PrintBanner()
    Berry.Logger.Info("CORE", "Initializing Berry Framework core kernel (Lua 5.4 Generational GC Enabled)...")

    -- Check database ready state
    local dbReady = false
    local checkCount = 0
    while not dbReady and checkCount < 50 do
        if Berry.Database.Ready() then
            dbReady = true
        else
            Wait(100)
            checkCount = checkCount + 1
        end
    end

    if dbReady then
        Berry.Logger.Info("CORE", "Database connection verified via oxmysql.")
    else
        Berry.Logger.Warn("CORE", "Database connection pending or oxmysql not ready yet.")
    end

    -- Load registered modules
    Berry.ModuleManager.LoadAll()

    -- Start periodic auto-save thread
    local saveInterval = (BerryConfig.Player.SaveIntervalSeconds or 300) * 1000
    CreateThread(function()
        while true do
            Wait(saveInterval)
            Berry.Logger.Debug("CORE", "Running periodic auto-save for online players...")
            for _, player in pairs(Berry.PlayersBySource) do
                player:Save()
            end
        end
    end)

    -- Start cache cleanup thread
    CreateThread(function()
        while true do
            Wait(60000) -- Every 60 seconds
            Berry.Cache.Cleanup()
            collectgarbage("step", 100)
        end
    end)

    Berry.Logger.Info("CORE", "Berry Framework core kernel running at maximum performance.")
    TriggerEvent("berry:coreReady")
end)

AddEventHandler("playerDropped", function(reason)
    local src = source
    Berry.Logger.Info("CORE", "Player dropped (Source: %d, Reason: %s)", src, tostring(reason))
    Berry.UnregisterPlayer(src)
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        Berry.Logger.Info("CORE", "Resource stopping, saving all active players...")
        for _, player in pairs(Berry.PlayersBySource) do
            player:Save()
        end
    end
end)
