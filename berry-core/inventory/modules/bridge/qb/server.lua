local Inventory = require 'modules.inventory.server'

local QBCore

local function getCoreObject()
    if QBCore then return QBCore end

    local ok, core = pcall(function()
        return exports['qb-core']:GetCoreObject()
    end)

    if ok and core then
        QBCore = core
        return QBCore
    end

    error('qb-core is required when inventory:framework is set to qb', 0)
end

local function getGradeLevel(grade)
    if type(grade) == 'number' then return grade end
    if type(grade) == 'table' then
        if type(grade.level) == 'number' then return grade.level end
        if type(grade.grade) == 'number' then return grade.grade end
        if type(grade.value) == 'number' then return grade.value end
    end
    return 0
end

local function buildGroups(playerData)
    local groups = {}

    local job = playerData.job
    if job and job.name then
        groups[job.name] = getGradeLevel(job.grade)
    end

    local gang = playerData.gang
    if gang and gang.name then
        groups[gang.name] = getGradeLevel(gang.grade)
    end

    return groups
end

local function setupPlayer(source)
    local core = getCoreObject()
    local player = core.Functions.GetPlayer(source)
    if not player or not player.PlayerData then return end

    local playerData = player.PlayerData
    local charinfo = playerData.charinfo or {}

    local firstname = charinfo.firstname or ''
    local lastname = charinfo.lastname or ''
    local fullname = ('%s %s'):format(firstname, lastname):gsub('^%s*(.-)%s*$', '%1')

    server.setPlayerInventory({
        source = source,
        identifier = playerData.citizenid,
        name = fullname ~= '' and fullname or (playerData.name or GetPlayerName(source) or tostring(source)),
        groups = buildGroups(playerData),
        sex = charinfo.gender,
        dateofbirth = charinfo.birthdate,
        firstname = firstname,
        lastname = lastname,
    })

    local accounts = Inventory.GetAccountItemCounts(source)
    if not accounts then return end

    local money = playerData.money or {}

    for account in pairs(accounts) do
        local playerAccount = account == 'money' and 'cash' or account
        Inventory.SetItem(source, account, money[playerAccount] or 0)
    end
end

AddEventHandler('QBCore:Server:OnPlayerLoaded', function(source)
    setupPlayer(source)
end)

AddEventHandler('QBCore:Server:OnPlayerUnload', server.playerDropped)

AddEventHandler('QBCore:Server:OnJobUpdate', function(source, job)
    local inventory = Inventory(source)
    if not inventory or not inventory.player then return end

    local player = getCoreObject().Functions.GetPlayer(source)
    local playerData = player and player.PlayerData or {}

    if job then
        playerData.job = job
    end

    inventory.player.groups = buildGroups(playerData)
end)

AddEventHandler('QBCore:Server:OnGangUpdate', function(source, gang)
    local inventory = Inventory(source)
    if not inventory or not inventory.player then return end

    local player = getCoreObject().Functions.GetPlayer(source)
    local playerData = player and player.PlayerData or {}

    if gang then
        playerData.gang = gang
    end

    inventory.player.groups = buildGroups(playerData)
end)

SetTimeout(500, function()
    local players = getCoreObject().Functions.GetQBPlayers()

    for src in pairs(players) do
        setupPlayer(src)
    end
end)

function server.UseItem(source, itemName, data)
    local core = getCoreObject()
    local cb = core.Functions.CanUseItem(itemName)
    return cb and cb(source, data)
end

---@diagnostic disable-next-line: duplicate-set-field
function server.setPlayerData(player)
    local core = getCoreObject()
    local qbPlayer = core.Functions.GetPlayer(player.source)
    local playerData = qbPlayer and qbPlayer.PlayerData or {}
    local charinfo = playerData.charinfo or {}

    local firstname = charinfo.firstname or player.firstname or ''
    local lastname = charinfo.lastname or player.lastname or ''

    local name = player.name
    if not name or name == '' then
        name = ('%s %s'):format(firstname, lastname):gsub('^%s*(.-)%s*$', '%1')
        if name == '' then
            name = GetPlayerName(player.source) or tostring(player.source)
        end
    end

    return {
        source = player.source,
        name = name,
        groups = buildGroups(playerData),
        sex = charinfo.gender or player.sex,
        dateofbirth = charinfo.birthdate or player.dateofbirth,
        firstname = firstname,
        lastname = lastname,
    }
end

local function setMoneyExact(player, account, amount)
    local current = (player.PlayerData.money and player.PlayerData.money[account]) or 0
    if current == amount then return end

    if player.Functions.SetMoney then
        player.Functions.SetMoney(account, amount, ('Sync %s with inventory'):format(account))
        return
    end

    local difference = amount - current

    if difference > 0 then
        player.Functions.AddMoney(account, difference, ('Sync %s with inventory'):format(account))
    elseif difference < 0 then
        player.Functions.RemoveMoney(account, -difference, ('Sync %s with inventory'):format(account))
    end
end

---@diagnostic disable-next-line: duplicate-set-field
function server.syncInventory(inv)
    local player = getCoreObject().Functions.GetPlayer(inv.id)
    if not player then return end

    local accounts = Inventory.GetAccountItemCounts(inv)

    if accounts then
        for account, amount in pairs(accounts) do
            local playerAccount = account == 'money' and 'cash' or account
            setMoneyExact(player, playerAccount, amount)
        end
    end

    if player.Functions.SetPlayerData then
        player.Functions.SetPlayerData('items', inv.items)
    end
end

---@diagnostic disable-next-line: duplicate-set-field
function server.hasLicense(inv, license)
    local player = getCoreObject().Functions.GetPlayer(inv.id)
    if not player then return end

    local metadata = player.PlayerData.metadata or {}
    local licenses = metadata.licences or metadata.licenses
    if type(licenses) ~= 'table' then return end

    return licenses[license] and true or nil
end

---@diagnostic disable-next-line: duplicate-set-field
function server.buyLicense(inv, license)
    local player = getCoreObject().Functions.GetPlayer(inv.id)
    if not player then return end

    local metadata = player.PlayerData.metadata or {}
    local key = type(metadata.licences) == 'table' and 'licences' or 'licenses'
    local licenses = metadata[key]

    if type(licenses) ~= 'table' then
        licenses = {}
    end

    if licenses[license.name] then
        return false, 'already_have'
    elseif Inventory.GetItem(inv, 'money', false, true) < license.price then
        return false, 'can_not_afford'
    end

    Inventory.RemoveItem(inv, 'money', license.price)

    licenses[license.name] = true
    player.Functions.SetMetaData(key, licenses)

    return true, 'have_purchased'
end

---@diagnostic disable-next-line: duplicate-set-field
function server.isPlayerBoss(playerId, group)
    local player = getCoreObject().Functions.GetPlayer(playerId)
    if not player then return false end

    local job = player.PlayerData.job
    if not job then return false end
    if group and job.name ~= group then return false end

    if type(job.isboss) == 'boolean' then
        return job.isboss
    end

    local grade = job.grade
    if type(grade) == 'table' and type(grade.isboss) == 'boolean' then
        return grade.isboss
    end

    local sharedJobs = getCoreObject().Shared and getCoreObject().Shared.Jobs
    if sharedJobs and sharedJobs[job.name] then
        local gradeLevel = getGradeLevel(grade)
        local gradeData = sharedJobs[job.name].grades and sharedJobs[job.name].grades[tostring(gradeLevel)]
        if gradeData and type(gradeData.isboss) == 'boolean' then
            return gradeData.isboss
        end
    end

    return false
end

---@param entityId number
---@return number | string
---@diagnostic disable-next-line: duplicate-set-field
function server.getOwnedVehicleId(entityId)
    return GetVehicleNumberPlateText(entityId)
end
