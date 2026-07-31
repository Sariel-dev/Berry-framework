-- ============================================================================
-- Berry Framework — Server Gameplay Systems & Lifecycle Kernel
-- ============================================================================

Berry = Berry or {}

-- Enable Lua 5.4 Generational Garbage Collector for maximum throughput
if collectgarbage then
    pcall(function()
        collectgarbage("generational")
        collectgarbage("setpause", 110)
        collectgarbage("setstepmul", 300)
    end)
end

-- ----------------------------------------------------------------------------
-- 1. Player Manager Engine
-- ----------------------------------------------------------------------------
Berry.PlayersBySource = {}
Berry.PlayersByIdentifier = {}
Berry.PlayersByCharacterId = {}

local Player = {}
Player.__index = Player

function Berry.CreatePlayerObject(data)
    local self = setmetatable({}, Player)

    self.source = data.source
    self.identifier = data.identifier
    self.identifiers = data.identifiers or {}
    self.accountId = data.accountId or 0
    self.characterId = data.characterId or 0
    self.name = data.name or GetPlayerName(data.source) or "Unknown"

    self.position = data.position or BerryConfig.Player.DefaultSpawn
    self.money = data.money or Berry.Utils.DeepCopy(BerryConfig.Player.DefaultMoney)
    self.job = data.job or { name = "unemployed", grade = 0, label = "Unemployed", grade_name = "Unemployed", grade_salary = 0 }
    self.organization = data.organization or { name = "none", grade = 0, label = "None" }
    self.metadata = data.metadata or {}
    self.dirtyFields = {}

    return self
end

function Player:GetSource()
    return self.source
end

function Player:GetIdentifier()
    return self.identifier
end

function Player:GetCharacterId()
    return self.characterId
end

function Player:GetName()
    return self.name
end

function Player:GetPosition()
    local ped = GetPlayerPed(self.source)
    if DoesEntityExist(ped) then
        local coords = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)
        return { x = coords.x, y = coords.y, z = coords.z, heading = heading }
    end
    return self.position
end

function Player:GetMoney(account)
    account = account or "cash"
    return self.money[account] or 0
end

function Player:AddMoney(account, amount, reason)
    if not BerryTypes.IsPositiveNumber(amount) then
        Berry.Logger.Warn("PLAYER", "AddMoney failed for player %s: invalid amount %s", tostring(self.source), tostring(amount))
        return false
    end

    account = account or "cash"
    self.money[account] = (self.money[account] or 0) + amount
    self:MarkDirty("money")

    Berry.Logger.Info("PLAYER", "Added %s %.2f to account '%s' (Reason: %s)", self.name, amount, account, tostring(reason))
    TriggerClientEvent("berry:moneyChanged", self.source, account, self.money[account], amount, "add")
    return true
end

function Player:RemoveMoney(account, amount, reason)
    if not BerryTypes.IsPositiveNumber(amount) then
        Berry.Logger.Warn("PLAYER", "RemoveMoney failed for player %s: invalid amount %s", tostring(self.source), tostring(amount))
        return false
    end

    account = account or "cash"
    local current = self.money[account] or 0
    if current < amount then
        Berry.Logger.Warn("PLAYER", "RemoveMoney failed for player %s: insufficient funds in '%s' (Has: %.2f, Needs: %.2f)", tostring(self.source), account, current, amount)
        return false
    end

    self.money[account] = current - amount
    self:MarkDirty("money")

    Berry.Logger.Info("PLAYER", "Removed %s %.2f from account '%s' (Reason: %s)", self.name, amount, account, tostring(reason))
    TriggerClientEvent("berry:moneyChanged", self.source, account, self.money[account], amount, "remove")
    return true
end

function Player:GetJob()
    return self.job
end

function Player:SetJob(jobName, grade)
    self.job = {
        name = jobName,
        grade = grade or 0,
        label = jobName,
        grade_name = tostring(grade or 0),
        grade_salary = 0
    }
    self:MarkDirty("job")
    TriggerClientEvent("berry:jobChanged", self.source, self.job)
    return true
end

function Player:GetMetadata(key)
    if not key then return self.metadata end
    return self.metadata[key]
end

function Player:SetMetadata(key, value)
    if not key then return end
    self.metadata[key] = value
    self:MarkDirty("metadata")
    TriggerClientEvent("berry:metadataChanged", self.source, key, value)
end

function Player:MarkDirty(field)
    self.dirtyFields[field] = true
end

function Player:Save()
    if not self.characterId or self.characterId == 0 then return false end

    if self.dirtyFields["money"] or self.dirtyFields["job"] or self.dirtyFields["metadata"] or self.dirtyFields["position"] then
        local currentPos = self:GetPosition()
        local posJson = json.encode(currentPos)
        local metaJson = json.encode(self.metadata)

        Berry.Database.Update([[
            UPDATE berry_characters 
            SET position = ?, metadata = ? 
            WHERE id = ?
        ]], { posJson, metaJson, self.characterId })

        self.dirtyFields = {}
        Berry.Logger.Debug("PLAYER", "Saved player data for character ID %d (%s)", self.characterId, self.name)
        return true
    end

    return true
end

function Berry.GetPlayer(source)
    local src = tonumber(source)
    if not src then return nil end
    return Berry.PlayersBySource[src]
end

function Berry.GetPlayerByIdentifier(identifier)
    if not identifier then return nil end
    return Berry.PlayersByIdentifier[identifier]
end

function Berry.GetPlayerByCharacterId(characterId)
    local charId = tonumber(characterId)
    if not charId then return nil end
    return Berry.PlayersByCharacterId[charId]
end

function Berry.RegisterPlayer(playerObj)
    Berry.PlayersBySource[playerObj.source] = playerObj
    if playerObj.identifier then
        Berry.PlayersByIdentifier[playerObj.identifier] = playerObj
    end
    if playerObj.characterId and playerObj.characterId > 0 then
        Berry.PlayersByCharacterId[playerObj.characterId] = playerObj
    end
    Berry.Logger.Info("PLAYER", "Registered player %s (Source: %d, CharID: %d)", playerObj.name, playerObj.source, playerObj.characterId)
end

function Berry.UnregisterPlayer(source)
    local player = Berry.PlayersBySource[source]
    if player then
        player:Save()
        if player.identifier then
            Berry.PlayersByIdentifier[player.identifier] = nil
        end
        if player.characterId then
            Berry.PlayersByCharacterId[player.characterId] = nil
        end
        Berry.PlayersBySource[source] = nil
        Berry.Logger.Info("PLAYER", "Unregistered player source %d", source)
    end
end

exports("GetPlayer", Berry.GetPlayer)
exports("GetPlayerByIdentifier", Berry.GetPlayerByIdentifier)
exports("GetPlayerByCharacterId", Berry.GetPlayerByCharacterId)

-- ----------------------------------------------------------------------------
-- 2. Character System & Callbacks
-- ----------------------------------------------------------------------------
BerryCharacters = BerryCharacters or {}
BerryCharacters.MaxCharacters = BerryConfig.Player.MaxCharacters or 4

local function GetPlayerLicenseIdentifier(src)
    local license = nil
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local id = GetPlayerIdentifier(src, i)
        if id and string.sub(id, 1, 8) == "license:" then
            license = id
            break
        end
    end
    return license or GetPlayerIdentifier(src, 0)
end

local function GetOrCreateAccountId(src, identifier)
    local row = MySQL.single.await("SELECT id FROM berry_accounts WHERE identifier = ?", { identifier })
    if row then return row.id end

    local insertId = MySQL.insert.await("INSERT INTO berry_accounts (identifier) VALUES (?)", { identifier })
    return insertId
end

Berry.Callbacks.Register("berry:characters:getCharacters", function(source, cb)
    local identifier = GetPlayerLicenseIdentifier(source)
    local accountId = GetOrCreateAccountId(source, identifier)

    local chars = MySQL.query.await("SELECT * FROM berry_characters WHERE account_id = ?", { accountId })
    for i = 1, #chars do
        if chars[i].position then
            chars[i].position = json.decode(chars[i].position)
        end
        if chars[i].metadata then
            chars[i].metadata = json.decode(chars[i].metadata)
        end
    end

    cb(chars)
end)

Berry.Callbacks.Register("berry:characters:createCharacter", function(source, cb, data)
    local identifier = GetPlayerLicenseIdentifier(source)
    local accountId = GetOrCreateAccountId(source, identifier)

    local countRow = MySQL.single.await("SELECT COUNT(*) as count FROM berry_characters WHERE account_id = ?", { accountId })
    if countRow and countRow.count >= BerryCharacters.MaxCharacters then
        return cb(false, "Max characters reached.")
    end

    local defaultPos = json.encode(BerryConfig.Player.DefaultSpawn)
    local defaultMeta = json.encode({ hunger = 100, thirst = 100 })

    local charId = MySQL.insert.await([[
        INSERT INTO berry_characters (account_id, firstname, lastname, dateofbirth, sex, position, metadata)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], { accountId, data.firstname, data.lastname, data.dateofbirth, data.sex or "m", defaultPos, defaultMeta })

    Berry.Logger.Info("CHARACTERS", "Created character ID %d for player source %d", charId, source)
    cb(true, charId)
end)

Berry.Callbacks.Register("berry:characters:selectCharacter", function(source, cb, charId)
    local identifier = GetPlayerLicenseIdentifier(source)
    local accountId = GetOrCreateAccountId(source, identifier)

    local charRow = MySQL.single.await("SELECT * FROM berry_characters WHERE id = ? AND account_id = ?", { charId, accountId })
    if not charRow then
        return cb(false, "Character not found.")
    end

    local pos = charRow.position and json.decode(charRow.position) or BerryConfig.Player.DefaultSpawn
    local meta = charRow.metadata and json.decode(charRow.metadata) or { hunger = 100, thirst = 100 }

    local playerObj = Berry.CreatePlayerObject({
        source = source,
        identifier = identifier,
        accountId = accountId,
        characterId = charId,
        name = string.format("%s %s", charRow.firstname, charRow.lastname),
        position = pos,
        metadata = meta
    })

    Berry.RegisterPlayer(playerObj)
    TriggerClientEvent("berry:playerLoaded", source, {
        characterId = charId,
        firstname = charRow.firstname,
        lastname = charRow.lastname,
        position = pos,
        metadata = meta,
        money = playerObj.money,
        job = playerObj.job
    })

    Berry.Logger.Info("CHARACTERS", "Player %s (source %d) loaded character %d", playerObj.name, source, charId)
    cb(true)
end)

-- ----------------------------------------------------------------------------
-- 3. Economy Engine
-- ----------------------------------------------------------------------------
BerryEconomy = BerryEconomy or {}

function BerryEconomy.Transfer(source, targetSource, account, amount, reason)
    if not BerryTypes.IsPositiveNumber(amount) then
        return false, "Invalid amount."
    end

    local sender = Berry.GetPlayer(source)
    local receiver = Berry.GetPlayer(targetSource)

    if not sender then return false, "Sender not found." end
    if not receiver then return false, "Receiver not found." end

    account = account or "bank"
    reason = reason or "p2p_transfer"

    if sender:GetMoney(account) < amount then
        return false, "Insufficient funds."
    end

    if sender:RemoveMoney(account, amount, reason) then
        if receiver:AddMoney(account, amount, reason) then
            MySQL.insert.await([[
                INSERT INTO berry_transactions (source_id, target_id, amount, account_type, reason)
                VALUES (?, ?, ?, ?, ?)
            ]], { tostring(sender:GetCharacterId()), tostring(receiver:GetCharacterId()), amount, account, reason })

            Berry.Logger.Info("ECONOMY", "Transfer of %.2f (%s) from char %d to char %d succeeded.", amount, account, sender:GetCharacterId(), receiver:GetCharacterId())
            return true, "Transfer successful."
        else
            sender:AddMoney(account, amount, "transfer_rollback")
            return false, "Receiver transaction failed."
        end
    end

    return false, "Sender transaction failed."
end

Berry.Callbacks.Register("berry:economy:transfer", function(source, cb, targetSource, account, amount, reason)
    local success, msg = BerryEconomy.Transfer(source, targetSource, account, amount, reason)
    cb(success, msg)
end)

-- ----------------------------------------------------------------------------
-- 4. Jobs & Paycheck Thread
-- ----------------------------------------------------------------------------
BerryJobs = BerryJobs or {}

function BerryJobs.SetPlayerJob(source, jobName, grade)
    local player = Berry.GetPlayer(source)
    if not player then return false, "Player not found." end

    local jobRow = MySQL.single.await("SELECT * FROM berry_jobs WHERE name = ?", { jobName })
    if not jobRow then return false, "Job does not exist." end

    local gradeRow = MySQL.single.await("SELECT * FROM berry_job_grades WHERE job_name = ? AND grade = ?", { jobName, grade or 0 })
    if not gradeRow then return false, "Job grade does not exist." end

    player.job = {
        name = jobName,
        label = jobRow.label,
        grade = gradeRow.grade,
        grade_name = gradeRow.name,
        grade_label = gradeRow.label,
        grade_salary = gradeRow.salary
    }

    player:MarkDirty("job")
    TriggerClientEvent("berry:jobChanged", source, player.job)
    Berry.Logger.Info("JOBS", "Set player %s job to %s (%s)", player:GetName(), jobName, gradeRow.label)
    return true
end

CreateThread(function()
    while true do
        Wait(15 * 60 * 1000)
        Berry.Logger.Info("JOBS", "Processing paychecks...")
        for _, player in pairs(Berry.PlayersBySource) do
            local job = player:GetJob()
            local salary = job.grade_salary or 200
            if salary > 0 then
                player:AddMoney("bank", salary, "paycheck")
                TriggerClientEvent("berry:notify", player:GetSource(), string.format("Salaire reçu : %d$ (%s)", salary, job.label or job.name))
            end
        end
    end
end)

-- ----------------------------------------------------------------------------
-- 5. Organizations Engine
-- ----------------------------------------------------------------------------
BerryOrganizations = BerryOrganizations or {}

function BerryOrganizations.Create(id, label, orgType)
    MySQL.insert.await([[
        INSERT INTO berry_organizations (id, label, type, balance)
        VALUES (?, ?, ?, 0.00)
    ]], { id, label, orgType or "gang" })
    Berry.Logger.Info("ORGANIZATIONS", "Created organization '%s' (%s)", label, id)
    return true
end

function BerryOrganizations.AddMember(orgId, characterId, grade)
    MySQL.insert.await([[
        INSERT INTO berry_organization_members (organization_id, character_id, grade)
        VALUES (?, ?, ?)
    ]], { orgId, characterId, grade or 0 })
    return true
end

-- ----------------------------------------------------------------------------
-- 6. Vehicles Manager
-- ----------------------------------------------------------------------------
BerryVehicles = BerryVehicles or {}

local function GeneratePlate()
    local plate
    local isUnique = false
    while not isUnique do
        plate = string.format("%s%03d%s", Berry.Utils.RandomString(3):upper(), math.random(100, 999), Berry.Utils.RandomString(2):upper())
        local existing = MySQL.single.await("SELECT plate FROM berry_vehicles WHERE plate = ?", { plate })
        if not existing then
            isUnique = true
        end
    end
    return plate
end

function BerryVehicles.GiveVehicle(source, model, garage)
    local player = Berry.GetPlayer(source)
    if not player then return false, "Player not loaded." end

    local plate = GeneratePlate()
    local charId = player:GetCharacterId()

    MySQL.insert.await([[
        INSERT INTO berry_vehicles (plate, owner_id, model, garage, state)
        VALUES (?, ?, ?, ?, 1)
    ]], { plate, charId, model, garage or "pillbox" })

    Berry.Logger.Info("VEHICLES", "Gave vehicle %s (Plate: %s) to character ID %d", model, plate, charId)
    return true, plate
end

Berry.Callbacks.Register("berry:vehicles:getOwned", function(source, cb)
    local player = Berry.GetPlayer(source)
    if not player then return cb({}) end

    local charId = player:GetCharacterId()
    local vehicles = MySQL.query.await("SELECT * FROM berry_vehicles WHERE owner_id = ?", { charId })
    cb(vehicles)
end)

-- ----------------------------------------------------------------------------
-- 7. Properties Engine
-- ----------------------------------------------------------------------------
BerryProperties = BerryProperties or {}

function BerryProperties.GetAll()
    if not Berry.Database.Ready() then return {} end
    return MySQL.query.await("SELECT * FROM berry_properties") or {}
end

function BerryProperties.BuyProperty(source, propertyId)
    local player = Berry.GetPlayer(source)
    if not player then return false, "Joueur non chargé." end

    local propRow = MySQL.single.await("SELECT * FROM berry_properties WHERE id = ?", { propertyId })
    if not propRow then return false, "Propriété introuvable." end
    if propRow.owner_id ~= nil then return false, "Cette propriété appartient déjà à quelqu'un." end

    if player:GetMoney("bank") < propRow.price then
        return false, "Fonds insuffisants sur votre compte bancaire."
    end

    if player:RemoveMoney("bank", propRow.price, "property_purchase") then
        local charId = player:GetCharacterId()
        local storageId = "property_" .. propertyId

        MySQL.update.await("UPDATE berry_properties SET owner_id = ?, storage_id = ? WHERE id = ?", { charId, storageId, propertyId })

        MySQL.insert.await("INSERT INTO berry_inventories (id, owner_type, owner_id, max_weight, max_slots) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE id=id", {
            storageId, "property", tostring(propertyId), 100000, 80
        })

        Berry.Logger.Info("PROPERTIES", "Personnage %d a acheté la propriété '%s' (%d) pour %d$", charId, propRow.name, propertyId, propRow.price)
        TriggerClientEvent("berry:properties:sync", -1)
        return true, "Félicitations ! Vous êtes le nouveau propriétaire."
    end

    return false, "Échec de la transaction."
end

function BerryProperties.ToggleLock(source, propertyId)
    local player = Berry.GetPlayer(source)
    if not player then return false, "Joueur non chargé." end

    local propRow = MySQL.single.await("SELECT * FROM berry_properties WHERE id = ?", { propertyId })
    if not propRow then return false, "Propriété introuvable." end

    local charId = player:GetCharacterId()
    local isAdmin = Berry.Permissions.Has(source, "admin")
    if propRow.owner_id ~= charId and not isAdmin then
        return false, "Vous n'avez pas les clés de ce logement."
    end

    local newLockState = (propRow.is_locked == 1) and 0 or 1
    MySQL.update.await("UPDATE berry_properties SET is_locked = ? WHERE id = ?", { newLockState, propertyId })

    TriggerClientEvent("berry:properties:sync", -1)
    return true, newLockState == 1 and "Logement verrouillé." or "Logement déverrouillé."
end

Berry.Callbacks.Register("berry:properties:getProperties", function(source, cb)
    cb(BerryProperties.GetAll())
end)

RegisterNetEvent("berry:properties:buy", function(propertyId)
    local src = source
    local ok, msg = BerryProperties.BuyProperty(src, propertyId)
    Berry.UI.Notify(src, { message = msg, type = ok and "success" or "error" })
end)

RegisterNetEvent("berry:properties:toggleLock", function(propertyId)
    local src = source
    local ok, msg = BerryProperties.ToggleLock(src, propertyId)
    Berry.UI.Notify(src, { message = msg, type = ok and "info" or "error" })
end)

RegisterNetEvent("berry:properties:enter", function(propertyId, exitCoords)
    local src = source
    SetPlayerRoutingBucket(src, tonumber(propertyId) or 1)
    if exitCoords then
        local ped = GetPlayerPed(src)
        SetEntityCoords(ped, exitCoords.x, exitCoords.y, exitCoords.z, false, false, false, false)
    end
    Berry.UI.Notify(src, { message = "Vous êtes entré dans le logement.", type = "info" })
end)

RegisterNetEvent("berry:properties:exit", function(entryCoords)
    local src = source
    SetPlayerRoutingBucket(src, 0)
    if entryCoords then
        local ped = GetPlayerPed(src)
        SetEntityCoords(ped, entryCoords.x, entryCoords.y, entryCoords.z, false, false, false, false)
    end
    Berry.UI.Notify(src, { message = "Vous êtes sorti du logement.", type = "info" })
end)

exports("BuyProperty", BerryProperties.BuyProperty)

-- ----------------------------------------------------------------------------
-- 8. Police & EMS Commands
-- ----------------------------------------------------------------------------
RegisterCommand("cuff", function(source, args)
    local src = source
    local targetId = tonumber(args[1])

    if not targetId then
        Berry.UI.Notify(src, { message = "Usage: /cuff [ID_Joueur]", type = "warn" })
        return
    end

    if Berry.Security.ValidateDistance(src, GetEntityCoords(GetPlayerPed(targetId)), 5.0) then
        TriggerClientEvent("berry:police:cuffToggle", targetId)
        Berry.UI.Notify(src, { message = "Action de menottage effectuée.", type = "info" })
    else
        Berry.UI.Notify(src, { message = "Joueur trop éloigné.", type = "error" })
    end
end, false)

RegisterCommand("escort", function(source, args)
    local src = source
    local targetId = tonumber(args[1])

    if not targetId then
        Berry.UI.Notify(src, { message = "Usage: /escort [ID_Joueur]", type = "warn" })
        return
    end

    if Berry.Security.ValidateDistance(src, GetEntityCoords(GetPlayerPed(targetId)), 5.0) then
        TriggerClientEvent("berry:police:escort", targetId, src)
        Berry.UI.Notify(src, { message = "Action d'escorte effectuée.", type = "info" })
    end
end, false)

RegisterCommand("putinveh", function(source, args)
    local src = source
    local targetId = tonumber(args[1])
    if not targetId then return end

    local ped = GetPlayerPed(src)
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then
        TriggerClientEvent("berry:police:putInVehicle", targetId, VehToNet(veh))
    end
end, false)

RegisterCommand("outveh", function(source, args)
    local src = source
    local targetId = tonumber(args[1])
    if not targetId then return end

    TriggerClientEvent("berry:police:outOfVehicle", targetId)
end, false)

RegisterCommand("revive", function(source, args)
    local src = source
    local targetId = tonumber(args[1]) or src

    if src > 0 and not Berry.Permissions.Has(source, "admin") then
        local pData = Berry.GetPlayer(src)
        if not pData or (pData.job and pData.job.name ~= "ambulance") then
            Berry.UI.Notify(src, { message = "Action réservée aux EMS et Administrateurs.", type = "error" })
            return
        end
    end

    TriggerClientEvent("berry:ems:revive", targetId)
    Berry.UI.Notify(src, { message = "Joueur " .. targetId .. " réanimé.", type = "success" })
end, false)

RegisterCommand("heal", function(source, args)
    local src = source
    local targetId = tonumber(args[1]) or src

    if src > 0 and not Berry.Permissions.Has(source, "admin") then
        local pData = Berry.GetPlayer(src)
        if not pData or (pData.job and pData.job.name ~= "ambulance") then
            Berry.UI.Notify(src, { message = "Action réservée aux EMS et Administrateurs.", type = "error" })
            return
        end
    end

    TriggerClientEvent("berry:ems:heal", targetId)
    Berry.UI.Notify(src, { message = "Joueur " .. targetId .. " soigné.", type = "success" })
end, false)

-- ----------------------------------------------------------------------------
-- 9. Bootstrap & Kernel Lifecycle Threads
-- ----------------------------------------------------------------------------
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

    local dbReady = false
    local checkCount = 0
    while not dbReady and checkCount < 50 do
        if Berry.Database and Berry.Database.Ready() then
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

    if Berry.ModuleManager then
        Berry.ModuleManager.LoadAll()
    end

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

    CreateThread(function()
        while true do
            Wait(60000)
            if Berry.Cache then Berry.Cache.Cleanup() end
            collectgarbage("step", 100)
        end
    end)

    Berry.Logger.Info("CORE", "Berry Framework core kernel running at maximum performance.")
    TriggerEvent("berry:coreReady")
end)

AddEventHandler("playerConnecting", function(playerName, setKickReason, deferrals)
    local src = source
    local maxClients = GetConvarInt("sv_maxclients", 32)
    local currentCount = #GetPlayers()
    local identifier = GetPlayerIdentifierByType and GetPlayerIdentifierByType(src, "license") or GetPlayerIdentifier(src, 0) or "N/A"

    print(string.format("^6[BERRY] ^2[+ CONNEXION] ^7Joueur: ^3%s ^7| ^5ID: [%d] ^7| ^4Licence: [%s] ^7| ^2Joueurs: [%d/%d]^7",
        tostring(playerName or "Inconnu"),
        src,
        tostring(identifier),
        currentCount + 1,
        maxClients
    ))
end)

AddEventHandler("playerDropped", function(reason)
    local src = source
    local playerName = GetPlayerName(src) or "Inconnu"
    local maxClients = GetConvarInt("sv_maxclients", 32)
    local currentCount = math.max(0, #GetPlayers() - 1)

    print(string.format("^6[BERRY] ^1[- DÉCONNEXION] ^7Joueur: ^3%s ^7| ^5ID: [%d] ^7| ^1Raison: [%s] ^7| ^3Joueurs: [%d/%d]^7",
        tostring(playerName),
        src,
        tostring(reason or "Déconnexion normale"),
        currentCount,
        maxClients
    ))

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
