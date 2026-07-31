local function loadConfigToShared()
    if not Config then return end
    
    local framework = 'esx'
    if Config.Framework and type(Config.Framework) == 'string' then
        local validFrameworks = {esx = true, qb = true, qbx = true, nd = true, ox = true, standalone = true}
        if validFrameworks[Config.Framework:lower()] then
            framework = Config.Framework:lower()
        end
    else
        framework = GetConvar('inventory:framework', 'esx')
    end
    
    local playerslots = 50
    if Config.Inventory and Config.Inventory.Slots and type(Config.Inventory.Slots) == 'number' then
        playerslots = math.max(1, math.min(Config.Inventory.Slots, 200))
    else
        playerslots = GetConvarInt('inventory:slots', 50)
    end
    
    local playerweight = 30000
    if Config.Inventory and Config.Inventory.Weight and type(Config.Inventory.Weight) == 'number' then
        playerweight = math.max(1000, Config.Inventory.Weight)
    else
        playerweight = GetConvarInt('inventory:weight', 30000)
    end
    
    local rarityEnabled = true
    if Config.RarityEnabled ~= nil then
        rarityEnabled = Config.RarityEnabled
    end
    
    shared = {
        resource = GetCurrentResourceName(),
        framework = framework,
        playerslots = playerslots,
        playerweight = playerweight,
        target = Config.Target and Config.Target.Enabled or (GetConvarInt('inventory:target', 0) == 1),
        police = {},
        networkdumpsters = Config.Server and Config.Server.NetworkDumpsters or (GetConvarInt('inventory:networkdumpsters', 0) == 1),
        rarity = Config.Rarity or {},
        rarityEnabled = rarityEnabled
    }
    
    local dropslots = 50
    if Config.Inventory and Config.Inventory.DropSlots and type(Config.Inventory.DropSlots) == 'number' then
        dropslots = math.max(1, math.min(Config.Inventory.DropSlots, 200))
    else
        dropslots = GetConvarInt('inventory:dropslots', playerslots)
    end
    
    local dropweight = playerweight
    if Config.Inventory and Config.Inventory.DropWeight and type(Config.Inventory.DropWeight) == 'number' then
        dropweight = math.max(1000, Config.Inventory.DropWeight)
    else
        dropweight = GetConvarInt('inventory:dropweight', playerweight)
    end
    
    shared.dropslots = dropslots
    shared.dropweight = dropweight
    
    if Config.Police and Config.Police.Jobs and type(Config.Police.Jobs) == 'table' then
        local police = table.create(0, #Config.Police.Jobs)
        for i = 1, #Config.Police.Jobs do
            if type(Config.Police.Jobs[i]) == 'string' and Config.Police.Jobs[i] ~= '' then
                police[Config.Police.Jobs[i]] = 0
            end
        end
        shared.police = police
    else
        local success, policeJobs = pcall(json.decode, GetConvar('inventory:police', '["police", "sheriff"]'))
        if not success or not policeJobs then
            policeJobs = {'police', 'sheriff'}
        end
        if type(policeJobs) == 'string' then
            policeJobs = { policeJobs }
        end
        local police = table.create(0, #policeJobs)
        for i = 1, #policeJobs do
            if type(policeJobs[i]) == 'string' and policeJobs[i] ~= '' then
                police[policeJobs[i]] = 0
            end
        end
        shared.police = police
    end
end

local function loadConfigToServer()
    if not Config or not Config.Server then return end
    
    local loglevel = 1
    if Config.Server.LogLevel and type(Config.Server.LogLevel) == 'number' then
        loglevel = math.max(0, math.min(Config.Server.LogLevel, 3))
    else
        loglevel = GetConvarInt('inventory:loglevel', 1)
    end
    
    local evidencegrade = 2
    if Config.Server.EvidenceGrade and type(Config.Server.EvidenceGrade) == 'number' then
        evidencegrade = math.max(0, math.min(Config.Server.EvidenceGrade, 4))
    else
        evidencegrade = GetConvarInt('inventory:evidencegrade', 2)
    end
    
    server = {
        bulkstashsave = Config.Server.BulkStashSave ~= nil and Config.Server.BulkStashSave or (GetConvarInt('inventory:bulkstashsave', 1) == 1),
        loglevel = loglevel,
        randomprices = Config.Server.RandomPrices ~= nil and Config.Server.RandomPrices or (GetConvarInt('inventory:randomprices', 0) == 1),
        randomloot = Config.Server.RandomLoot ~= nil and Config.Server.RandomLoot or (GetConvarInt('inventory:randomloot', 1) == 1),
        evidencegrade = evidencegrade,
        trimplate = Config.Server.TrimPlate ~= nil and Config.Server.TrimPlate or (GetConvarInt('inventory:trimplate', 1) == 1),
    }
    
    if Config.Server.VehicleLoot and type(Config.Server.VehicleLoot) == 'table' then
        local loot = {}
        for i = 1, #Config.Server.VehicleLoot do
            local item = Config.Server.VehicleLoot[i]
            if type(item) == 'table' and type(item.name) == 'string' and item.name ~= '' then
                local min = tonumber(item.min) or 1
                local max = tonumber(item.max) or min
                local chance = tonumber(item.chance) or 100
                chance = math.max(0, math.min(chance, 100))
                table.insert(loot, {item.name, min, max, chance})
            end
        end
        server.vehicleloot = loot
    else
        local success, loot = pcall(json.decode, GetConvar('inventory:vehicleloot', '[]'))
        server.vehicleloot = success and loot or {}
    end
    
    if Config.Server.DumpsterLoot and type(Config.Server.DumpsterLoot) == 'table' then
        local loot = {}
        for i = 1, #Config.Server.DumpsterLoot do
            local item = Config.Server.DumpsterLoot[i]
            if type(item) == 'table' and type(item.name) == 'string' and item.name ~= '' then
                local min = tonumber(item.min) or 1
                local max = tonumber(item.max) or min
                local chance = tonumber(item.chance) or 100
                chance = math.max(0, math.min(chance, 100))
                table.insert(loot, {item.name, min, max, chance})
            end
        end
        server.dumpsterloot = loot
    else
        local success, loot = pcall(json.decode, GetConvar('inventory:dumpsterloot', '[]'))
        server.dumpsterloot = success and loot or {}
    end
    
    if Config.Accounts and type(Config.Accounts) == 'table' then
        local accounts = table.create(0, #Config.Accounts)
        for i = 1, #Config.Accounts do
            if type(Config.Accounts[i]) == 'string' and Config.Accounts[i] ~= '' then
                accounts[Config.Accounts[i]] = 0
            end
        end
        server.accounts = accounts
    else
        local success, accounts = pcall(json.decode, GetConvar('inventory:accounts', '["money"]'))
        if not success or not accounts or type(accounts) ~= 'table' then
            accounts = {'money'}
        end
        server.accounts = table.create(0, #accounts)
        for i = 1, #accounts do
            if type(accounts[i]) == 'string' and accounts[i] ~= '' then
                server.accounts[accounts[i]] = 0
            end
        end
    end
end

local function loadConfigToClient()
    if not Config or not Config.Client then return end
    
    PlayerData = {}
    
    local keys = { 'F2', 'K', 'TAB' }
    if Config.Client.Keys and type(Config.Client.Keys) == 'table' then
        keys = {
            type(Config.Client.Keys.Primary) == 'string' and Config.Client.Keys.Primary or 'F2',
            type(Config.Client.Keys.Secondary) == 'string' and Config.Client.Keys.Secondary or 'K',
            type(Config.Client.Keys.Tertiary) == 'string' and Config.Client.Keys.Tertiary or 'TAB'
        }
    else
        local success, decodedKeys = pcall(json.decode, GetConvar('inventory:keys', ''))
        if success and decodedKeys and type(decodedKeys) == 'table' then
            keys = decodedKeys
        end
    end
    
    local enablekeys = {249}
    if Config.Client.EnableKeys and type(Config.Client.EnableKeys) == 'table' then
        enablekeys = Config.Client.EnableKeys
    else
        local success, decoded = pcall(json.decode, GetConvar('inventory:enablekeys', '[249]'))
        enablekeys = (success and decoded) or {249}
    end
    
    local ignoreweapons = {}
    if Config.Client.IgnoreWeapons and type(Config.Client.IgnoreWeapons) == 'table' then
        ignoreweapons = Config.Client.IgnoreWeapons
    else
        local success, decoded = pcall(json.decode, GetConvar('inventory:ignoreweapons', '[]'))
        ignoreweapons = (success and decoded) or {}
    end
    
    local imagepath = 'nui://ox_inventory/web/images'
    if Config.Client.ImagePath and type(Config.Client.ImagePath) == 'string' then
        imagepath = Config.Client.ImagePath
    else
        imagepath = GetConvar('inventory:imagepath', 'nui://ox_inventory/web/images')
    end
    
    local dropmodel = 'prop_med_bag_01b'
    if Config.Client.DropModel and type(Config.Client.DropModel) == 'string' then
        dropmodel = Config.Client.DropModel
    else
        dropmodel = GetConvar('inventory:dropmodel', 'prop_med_bag_01b')
    end
    
    client = {
        autoreload = Config.Client.AutoReload ~= nil and Config.Client.AutoReload or (GetConvarInt('inventory:autoreload', 0) == 1),
        screenblur = Config.Client.ScreenBlur ~= nil and Config.Client.ScreenBlur or (GetConvarInt('inventory:screenblur', 1) == 1),
        keys = keys,
        enablekeys = enablekeys,
        aimedfiring = Config.Client.AimedFiring ~= nil and Config.Client.AimedFiring or (GetConvarInt('inventory:aimedfiring', 0) == 1),
        giveplayerlist = Config.Client.GivePlayerList ~= nil and Config.Client.GivePlayerList or (GetConvarInt('inventory:giveplayerlist', 0) == 1),
        weaponanims = Config.Client.WeaponAnims or false,
        itemnotify = Config.Client.ItemNotify ~= nil and Config.Client.ItemNotify or (GetConvarInt('inventory:itemnotify', 1) == 1),
        weaponnotify = Config.Client.WeaponNotify ~= nil and Config.Client.WeaponNotify or (GetConvarInt('inventory:weaponnotify', 1) == 1),
        imagepath = imagepath,
        dropprops = Config.Client.DropProps ~= nil and Config.Client.DropProps or (GetConvarInt('inventory:dropprops', 0) == 1),
        dropmodel = joaat(dropmodel),
        weaponmismatch = Config.Client.WeaponMismatch ~= nil and Config.Client.WeaponMismatch or (GetConvarInt('inventory:weaponmismatch', 1) == 1),
        ignoreweapons = ignoreweapons,
        suppresspickups = Config.Client.SuppressPickups ~= nil and Config.Client.SuppressPickups or (GetConvarInt('inventory:suppresspickups', 1) == 1),
        disableweapons = Config.Client.DisableWeapons ~= nil and Config.Client.DisableWeapons or (GetConvarInt('inventory:disableweapons', 0) == 1),
    }
    
    local ignoreweapons = table.create(0, (client.ignoreweapons and #client.ignoreweapons or 0) + 5)
    
    for i = 1, #client.ignoreweapons do
        local weapon = client.ignoreweapons[i]
        ignoreweapons[tonumber(weapon) or joaat(weapon)] = true
    end
    
    ignoreweapons[`WEAPON_UNARMED`] = true
    ignoreweapons[`WEAPON_HANDCUFFS`] = true
    ignoreweapons[`WEAPON_GARBAGEBAG`] = true
    ignoreweapons[`OBJECT`] = true
    ignoreweapons[`WEAPON_HOSE`] = true
    
    client.ignoreweapons = ignoreweapons
    
    local fallbackmarker = {
        type = 0,
        colour = {150, 150, 150},
        scale = {0.5, 0.5, 0.5}
    }
    
    local function validateMarker(marker, fallback)
        if not marker or type(marker) ~= 'table' then
            return fallback
        end
        
        return {
            type = type(marker.Type) == 'number' and marker.Type or fallback.type,
            colour = type(marker.Colour) == 'table' and marker.Colour or fallback.colour,
            scale = type(marker.Scale) == 'table' and marker.Scale or fallback.scale
        }
    end
    
    if Config.Client.Markers and type(Config.Client.Markers) == 'table' then
        client.shopmarker = validateMarker(Config.Client.Markers.Shop, {type = 29, colour = {30, 150, 30}, scale = {0.5, 0.5, 0.5}})
        client.evidencemarker = validateMarker(Config.Client.Markers.Evidence, {type = 2, colour = {30, 30, 150}, scale = {0.3, 0.2, 0.15}})
        client.craftingmarker = validateMarker(Config.Client.Markers.Crafting, {type = 2, colour = {150, 150, 30}, scale = {0.3, 0.2, 0.15}})
        client.dropmarker = validateMarker(Config.Client.Markers.Drop, {type = 2, colour = {150, 30, 30}, scale = {0.3, 0.2, 0.15}})
    else
        local function safeDecodeMarker(convar, default)
            local success, decoded = pcall(json.decode, GetConvar(convar, ''))
            return (success and decoded) or default
        end
        
        client.shopmarker = safeDecodeMarker('inventory:shopmarker', {type = 29, colour = {30, 150, 30}, scale = {0.5, 0.5, 0.5}})
        client.evidencemarker = safeDecodeMarker('inventory:evidencemarker', {type = 2, colour = {30, 30, 150}, scale = {0.3, 0.2, 0.15}})
        client.craftingmarker = safeDecodeMarker('inventory:craftingmarker', {type = 2, colour = {150, 150, 30}, scale = {0.3, 0.2, 0.15}})
        client.dropmarker = safeDecodeMarker('inventory:dropmarker', {type = 2, colour = {150, 30, 30}, scale = {0.3, 0.2, 0.15}})
    end
end

if IsDuplicityVersion() then
    loadConfigToShared()
    loadConfigToServer()
else
    loadConfigToShared()
    loadConfigToClient()
end

