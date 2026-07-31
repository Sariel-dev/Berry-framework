local Berry = exports["berry-core"]:GetCoreObject()

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
