if not lib then return end

local Query = {
    SELECT_STASH = 'SELECT data FROM ox_inventory WHERE owner = ? AND name = ?',
    UPDATE_STASH = 'UPDATE ox_inventory SET data = ? WHERE owner = ? AND name = ?',
    UPSERT_STASH =
    'INSERT INTO ox_inventory (data, owner, name) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data)',
    INSERT_STASH = 'INSERT INTO ox_inventory (owner, name) VALUES (?, ?)',
    SELECT_GLOVEBOX = 'SELECT plate, glovebox FROM `{vehicle_table}` WHERE `{vehicle_column}` = ?',
    SELECT_TRUNK = 'SELECT plate, trunk FROM `{vehicle_table}` WHERE `{vehicle_column}` = ?',
    SELECT_PLAYER = 'SELECT inventory FROM `{user_table}` WHERE `{user_column}` = ?',
    UPDATE_TRUNK = 'UPDATE `{vehicle_table}` SET trunk = ? WHERE `{vehicle_column}` = ?',
    UPDATE_GLOVEBOX = 'UPDATE `{vehicle_table}` SET glovebox = ? WHERE `{vehicle_column}` = ?',
    UPDATE_PLAYER = 'UPDATE `{user_table}` SET inventory = ? WHERE `{user_column}` = ?',
    SELECT_CLOTHING = 'SELECT slots FROM ox_inventory_clothing WHERE owner = ?',
    UPSERT_CLOTHING = 'INSERT INTO ox_inventory_clothing (owner, slots) VALUES (?, ?) ON DUPLICATE KEY UPDATE slots = VALUES(slots)',
    DELETE_CLOTHING = 'DELETE FROM ox_inventory_clothing WHERE owner = ?',
}

Citizen.CreateThreadNow(function()
    local playerTable, playerColumn, vehicleTable, vehicleColumn

    if shared.framework == 'ox' then
        playerTable = 'character_inventory'
        playerColumn = 'charid'
        vehicleTable = 'vehicles'
        vehicleColumn = 'id'
    elseif shared.framework == 'esx' then
        playerTable = 'users'
        playerColumn = 'identifier'
        vehicleTable = 'owned_vehicles'
        vehicleColumn = 'plate'
    elseif shared.framework == 'loop' then
        playerTable = 'users'
        playerColumn = 'identifier'
        vehicleTable = 'owned_vehicles'
        vehicleColumn = 'plate'
    elseif shared.framework == 'nd' then
        playerTable = 'nd_characters'
        playerColumn = 'charid'
        vehicleTable = 'nd_vehicles'
        vehicleColumn = 'id'
    elseif shared.framework == 'qb' then
        playerTable = 'players'
        playerColumn = 'citizenid'
        vehicleTable = 'player_vehicles'
        vehicleColumn = 'plate'
    elseif shared.framework == 'qbx' then
        playerTable = 'players'
        playerColumn = 'citizenid'
        vehicleTable = 'player_vehicles'
        vehicleColumn = 'id'
    else
        return
    end

    for k, v in pairs(Query) do
        Query[k] = v:gsub('{user_table}', playerTable):gsub('{user_column}', playerColumn):gsub('{vehicle_table}',
            vehicleTable):gsub('{vehicle_column}', vehicleColumn)
    end

    Wait(0)

    local success, result = pcall(MySQL.scalar.await, 'SELECT 1 FROM ox_inventory')

    if not success then
        MySQL.query([[CREATE TABLE `ox_inventory` (
			`owner` varchar(60) DEFAULT NULL,
			`name` varchar(100) NOT NULL,
			`data` longtext DEFAULT NULL,
			`lastupdated` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
			UNIQUE KEY `owner` (`owner`,`name`)
		)]])
    else
        -- Shouldn't be needed anymore; was used for some data conversion for v2.5.0 (back in March 2022)
        -- result = MySQL.query.await("SELECT owner, name FROM ox_inventory WHERE NOT owner = ''")

        -- if result and next(result) then
        -- 	local parameters = {}
        -- 	local count = 0

        -- 	for i = 1, #result do
        -- 		local data = result[i]
        -- 		local snip = data.name:sub(-#data.owner, #data.name)

        -- 		if data.owner == snip then
        -- 			local name = data.name:sub(0, #data.name - #snip)

        -- 			count += 1
        -- 			parameters[count] = { query = 'UPDATE ox_inventory SET `name` = ? WHERE `owner` = ? AND `name` = ?', values = { name, data.owner, data.name } }
        -- 		end
        -- 	end

        -- 	if #parameters > 0 then
        -- 		MySQL.transaction(parameters)
        -- 	end
        -- end
    end

    local successPlaced = pcall(MySQL.scalar.await, 'SELECT 1 FROM ox_inventory_placed_items')
    if not successPlaced then
        MySQL.query([[CREATE TABLE IF NOT EXISTS `ox_inventory_placed_items` (
			`id` int(11) NOT NULL AUTO_INCREMENT,
			`owner` varchar(60) NOT NULL,
			`item_name` varchar(100) NOT NULL,
			`prop_model` varchar(100) NOT NULL,
			`coords_x` float NOT NULL,
			`coords_y` float NOT NULL,
			`coords_z` float NOT NULL,
			`heading` float NOT NULL,
			`slot` int(11) NOT NULL,
			`metadata` longtext DEFAULT NULL,
			`created_at` timestamp NULL DEFAULT current_timestamp(),
			PRIMARY KEY (`id`),
			KEY `owner` (`owner`)
		)]])
    end

        local successClothing = pcall(MySQL.scalar.await, 'SELECT 1 FROM ox_inventory_clothing')
        if not successClothing then
            MySQL.query([[CREATE TABLE IF NOT EXISTS `ox_inventory_clothing` (
            `owner` varchar(60) NOT NULL,
            `slots` longtext DEFAULT NULL,
            `updated_at` timestamp NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
            PRIMARY KEY (`owner`)
        )]])
        end

        local clothingColumns = MySQL.query.await('SHOW COLUMNS FROM `ox_inventory_clothing`')
        if clothingColumns then
            for i = 1, #clothingColumns do
                local col = clothingColumns[i]
                if col.Field == 'owner' then
                    local length = tonumber(col.Type:match('varchar%((%d+)%)'))
                    if length and length < 100 then
                        MySQL.query('ALTER TABLE `ox_inventory_clothing` MODIFY COLUMN `owner` varchar(100) NOT NULL')
                    end
                    break
                end
            end
        end

    result = MySQL.query.await(('SHOW COLUMNS FROM `%s`'):format(vehicleTable))

    if result then
        local glovebox, trunk

        for i = 1, #result do
            local column = result[i]
            if column.Field == 'glovebox' then
                glovebox = true
            elseif column.Field == 'trunk' then
                trunk = true
            end
        end

        if not glovebox then
            MySQL.query(('ALTER TABLE `%s` ADD COLUMN `glovebox` LONGTEXT NULL'):format(vehicleTable))
        end

        if not trunk then
            MySQL.query(('ALTER TABLE `%s` ADD COLUMN `trunk` LONGTEXT NULL'):format(vehicleTable))
        end
    end

    success, result = pcall(MySQL.scalar.await, ('SELECT inventory FROM `%s`'):format(playerTable))

    if not success then
        MySQL.query(('ALTER TABLE `%s` ADD COLUMN `inventory` LONGTEXT NULL'):format(playerTable))
    end

    local clearStashes = GetConvar('inventory:clearstashes', '6 MONTH')

    if clearStashes ~= '' then
        pcall(MySQL.query.await, ('DELETE FROM ox_inventory WHERE lastupdated < (NOW() - INTERVAL %s)'):format(clearStashes))
    end
end)

db = {}

function db.loadPlayer(identifier)
    local inventory = MySQL.prepare.await(Query.SELECT_PLAYER, { identifier }) --[[@as string?]]
    return inventory and json.decode(inventory)
end

function db.savePlayer(owner, inventory)
    return MySQL.prepare(Query.UPDATE_PLAYER, { inventory, owner })
end

function db.saveStash(owner, dbId, inventory)
    return MySQL.prepare(Query.UPSERT_STASH, { inventory, owner and tostring(owner) or '', dbId })
end

function db.loadStash(owner, name)
    return MySQL.prepare.await(Query.SELECT_STASH, { owner and tostring(owner) or '', name })
end

function db.saveGlovebox(id, inventory)
    return MySQL.prepare(Query.UPDATE_GLOVEBOX, { inventory, id })
end

function db.loadGlovebox(id)
    return MySQL.prepare.await(Query.SELECT_GLOVEBOX, { id })
end

function db.saveTrunk(id, inventory)
    return MySQL.prepare(Query.UPDATE_TRUNK, { inventory, id })
end

function db.loadTrunk(id)
    return MySQL.prepare.await(Query.SELECT_TRUNK, { id })
end

local function normalizeClothingSlots(data)
    if type(data) ~= 'table' then return nil end

    local normalized = {}

    for slotId, item in pairs(data) do
        local numericId = tonumber(slotId)

        if numericId and item then
            normalized[numericId] = item
        end
    end

    return next(normalized) and normalized or nil
end

function db.loadClothing(owner)
    if not owner then return nil end

    local slots = MySQL.prepare.await(Query.SELECT_CLOTHING, { owner })
    if not slots then return nil end

    local decoded = json.decode(slots)
    return normalizeClothingSlots(decoded)
end

function db.saveClothing(owner, slots)
    if not owner then return end

    local payload

    if slots then
        for slotId, item in pairs(slots) do
            if item then
                payload = payload or {}
                payload[slotId] = item
            end
        end
    end

    local ownerLen = type(owner) == 'string' and #owner or 0

    if not payload then
        local ok, resp = pcall(MySQL.query.await, Query.DELETE_CLOTHING, { owner })
        return ok and resp or nil
    end

    local ok, resp = pcall(MySQL.query.await, Query.UPSERT_CLOTHING, { json.encode(payload), owner })
    return ok and resp or nil
end

---@param rows number | MySQLQuery | MySQLQuery[]
local function countRows(rows)
    if type(rows) == 'number' then return rows end

    local n = 0

    for i = 1, #rows do
        if rows[i] == 1 then n += 1 end
    end

    return n
end

local function safeQuery(...)
    local ok, resp = pcall(...)

    if not ok then
        return nil
    end

    return resp
end

---@param players InventorySaveData[]
---@param trunks InventorySaveData[]
---@param gloveboxes InventorySaveData[]
---@param stashes (InventorySaveData | string | number)[]
---@param total number[]
function db.saveInventories(players, trunks, gloveboxes, stashes, total)
    local start = os.nanotime()
    local saveStr = 'Saved %d/%d %s (%.4f ms)'
    local pending = 0

    if total[1] > 0 then
        pending += 1

        Citizen.CreateThreadNow(function()
            local resp = safeQuery(MySQL.prepare.await, Query.UPDATE_PLAYER, players)
            pending -= 1
        end)
    end

    if total[2] > 0 then
        pending += 1

        Citizen.CreateThreadNow(function()
            local resp = safeQuery(MySQL.prepare.await, Query.UPDATE_TRUNK, trunks)
            pending -= 1
        end)
    end

    if total[3] > 0 then
        pending += 1

        Citizen.CreateThreadNow(function()
            local resp = safeQuery(MySQL.prepare.await, Query.UPDATE_GLOVEBOX, gloveboxes)
            pending -= 1
        end)
    end

    if total[4] > 0 then
        pending += 1

        if server.bulkstashsave then
            total[4] /= 3

            Citizen.CreateThreadNow(function()
                local query = Query.UPSERT_STASH:gsub('%(%?, %?, %?%)', string.rep('(?, ?, ?)', total[4], ', '))
                local resp = safeQuery(MySQL.query.await, query, stashes)
                pending -= 1

                if resp then
                    local affectedRows = resp.affectedRows

                    if total[4] == 1 then
                        if affectedRows == 2 then affectedRows = 1 end
                    else
                        affectedRows -= tonumber(resp.info:match('Duplicates: (%d+)'), 10) or 0
                    end
                end
            end)
        else
            Citizen.CreateThreadNow(function()
                local resp = safeQuery(MySQL.rawExecute.await, Query.UPSERT_STASH, stashes)
                pending -= 1

                if resp then
                    local affectedRows = 0

                    if table.type(resp) == 'hash' then
                        if resp.affectedRows > 0 then affectedRows = 1 end
                    else
                        for i = 1, #resp do
                            if resp[i].affectedRows > 0 then affectedRows += 1 end
                        end
                    end
                end
            end)
        end
    end

    repeat Wait(0) until pending == 0
end

return db
