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

-- Class Methods
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

-- Core Player Lookup functions
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
