if not lib then return end

require 'modules.bridge.server'
require 'modules.crafting.server'
require 'modules.shops.server'
require 'modules.pefcl.server'
require 'modules.multichest.server'
require 'modules.ammunition.server'
local LockerModule = require 'modules.locker.server'
local Locker = LockerModule

if GetConvar('inventory:versioncheck', 'true') == 'true' then
	lib.versionCheck('overextended/ox_inventory')
end

local TriggerEventHooks = require 'modules.hooks.server'
local db = require 'modules.mysql.server'
local Items = require 'modules.items.server'
local Inventory = require 'modules.inventory.server'
local placedItems = {}

local function SendPlacedItemsToPlayer(target)
	if not target or not next(placedItems) then return end

	for placedItemId, placedItem in pairs(placedItems) do
		TriggerClientEvent('ox_inventory:itemPlaced', target, placedItemId, placedItem.itemName, placedItem.propModel, placedItem.coords, placedItem.heading)
	end
end

local function NotifyPlacement(source, notifType, localeKey, ...)
	TriggerClientEvent('esx:showNotification', source, locale(localeKey, ...))
end

local function CanPlayerPickupPlacedItem(inventory, placedItem)
	local placedItemsConfig = Config and Config.PlacedItems or {}
	if placedItemsConfig.AllowAnyPlayerPickup == false and placedItem.owner and placedItem.owner ~= inventory.owner then
		return false
	end
	return true
end

---@param player table
---@param data table?
--- player requires source, identifier, and name
--- optionally, it should contain jobs/groups, sex, and dateofbirth
function server.setPlayerInventory(player, data)
	while not shared.ready do Wait(0) end

	if not data then
		data = db.loadPlayer(player.identifier)
	end

	local inventory = {}
	local totalWeight = 0

	if type(data) == 'table' then
		local ostime = os.time()

		for _, v in pairs(data) do
			if type(v) == 'number' or not v.count or not v.slot then
				if server.convertInventory then
					inventory, totalWeight = server.convertInventory(player.source, data)
					break
				else
					return error(('Inventory for player.%s (%s) contains invalid data. Ensure you have converted inventories to the correct format.'):format(player.source, GetPlayerName(player.source)))
				end
			else
				local item = Items(v.name)

				if item then
					v.metadata = Items.CheckMetadata(v.metadata or {}, item, v.name, ostime)
					local weight = Inventory.SlotWeight(item, v)
					totalWeight = totalWeight + weight

					inventory[v.slot] = {name = item.name, label = item.label, weight = weight, slot = v.slot, count = v.count, description = item.description, metadata = v.metadata, stack = item.stack, close = item.close}
				end
			end
		end
	end

	player.source = tonumber(player.source)
	local inv = Inventory.Create(player.source, player.name, 'player', shared.playerslots, totalWeight, shared.playerweight, player.identifier, inventory)

	if inv then
		inv.player = server.setPlayerData(player)
		inv.player.ped = GetPlayerPed(player.source)

		if server.syncInventory then server.syncInventory(inv) end
		TriggerClientEvent('ox_inventory:setPlayerInventory', player.source, Inventory.Drops, inventory, totalWeight, inv.player)
		SendPlacedItemsToPlayer(player.source)
	end
end
exports('setPlayerInventory', server.setPlayerInventory)
AddEventHandler('ox_inventory:setPlayerInventory', server.setPlayerInventory)

local registeredDumpsters = {}

local function normalizeVehiclePlate(value)
	if value == nil then return nil end
	local plate = tostring(value):match('^%s*(.-)%s*$')
	if not plate or plate == '' then return nil end
	return string.upper(plate)
end

local function playerHasVehicleKey(inv, entity, plate, source)
	if GetResourceState and GetResourceState('lpCore') == 'started' and exports and exports['lpCore'] and exports['lpCore'].HasVehicleKey and source then
		local ok, hasKey = pcall(function()
			local state = entity and entity > 0 and DoesEntityExist(entity) and Entity(entity).state or nil
			local vehicleId = state and state.vehicleId or nil
			return exports['lpCore']:HasVehicleKey(source, plate, vehicleId)
		end)
		if ok and hasKey == true then
			return true
		end
	end

	if not inv then return false end

	local keySlots = Inventory.Search(inv, 'slots', 'car_key')
	if not keySlots or keySlots == false or #keySlots == 0 then
		return false
	end

	local normalizedPlate = normalizeVehiclePlate(plate)
	local shortPlate = normalizedPlate and normalizedPlate:sub(1, 8) or nil
	local entityVehicleId = nil
	if entity and entity > 0 and DoesEntityExist(entity) then
		local state = Entity(entity).state
		if state and state.vehicleId then
			entityVehicleId = tostring(state.vehicleId)
		end
	end

	for i = 1, #keySlots do
		local slot = keySlots[i]
		local metadata = slot and slot.metadata or {}
		local keyPlate = normalizeVehiclePlate(metadata.plate)
		local keyShortPlate = keyPlate and keyPlate:sub(1, 8) or nil
		if normalizedPlate and keyPlate and (normalizedPlate == keyPlate or shortPlate == keyShortPlate) then
			return true
		end
		if entityVehicleId and metadata.vehicleId and tostring(metadata.vehicleId) == entityVehicleId then
			return true
		end
	end

	return false
end

---@param coords vector3
---@return string?
local function getDumpsterFromCoords(coords)
	local found

	for i = 1, #registeredDumpsters do
		local distance = #(coords - registeredDumpsters[i])

		if distance < 0.1 then
			found = i
			break
		end
	end

	return found
end

---@param playerPed number
---@param stash OxInventory
---@return vector3?
local function getClosestStashCoords(playerPed, stash)
	local playerCoords = GetEntityCoords(playerPed)
	local distance = stash.distance or 10
    local coordinates = stash.coords

    if not coordinates then return end

	if type(coordinates) == 'table' then
		for i = 1, #coordinates do
			local coords = coordinates[i] --[[@as vector3]]

			if #(coords - playerCoords) < distance then
				return coords
			end
		end

		return
	end

	return #(coordinates - playerCoords) < distance and coordinates or nil
end

---@param source number
---@param invType string
---@param data? string|number|table
---@param ignoreSecurityChecks boolean?
---@return table | false | nil, table | false | nil, string?
local function openInventory(source, invType, data, ignoreSecurityChecks)
	if Inventory.Lock then return false end

	local left = Inventory(source)
	local right, closestCoords

    if not left then return end

    if invType == 'player' and data == source then
        data = nil
    end

    local playerPed = left.player.ped

	if data then
        local isDataTable = type(data) == 'table'

		if invType == 'locker' then
			local lockerId = tonumber(data)
			if lockerId and Locker and Locker.Data then
				local lockerData = Locker.Data[lockerId]
				if lockerData then
					right = Inventory.Create(('locker_%s'):format(lockerId), lockerData.label or ('Locker #%s'):format(lockerId), 'locker', 0, 0, 0, nil, {})
					if right then
						right.id = tostring(lockerId)
					end
				end
			end
			if not right then return false end
		elseif invType == 'stash' then
			right = Inventory(data, left, ignoreSecurityChecks)
			if right == false then return false end
		elseif isDataTable then
			if data.netid then
                local entity = NetworkGetEntityFromNetworkId(data.netid)

                if not (entity > 0 and DoesEntityExist(entity)) then return end

                if not ignoreSecurityChecks then
                    if #(GetEntityCoords(playerPed) - GetEntityCoords(entity)) > 16 then return end
                end

                if invType == 'glovebox' then
                    if not ignoreSecurityChecks and GetVehiclePedIsIn(playerPed, false) ~= entity then
                        return
                    end
                end

                if invType == 'trunk' then
                    local lockStatus = ignoreSecurityChecks and 0 or GetVehicleDoorLockStatus(entity)

                    -- 0: no lock; 1: unlocked; 8: boot unlocked
                    if lockStatus > 1 and lockStatus ~= 8 then
						local plate = GetVehicleNumberPlateText(entity)
						if not playerHasVehicleKey(left, entity, plate, source) then
							return false, false, 'vehicle_locked'
						end
                    end
                end

                local plate = (invType == 'glovebox' or invType == 'trunk') and GetVehicleNumberPlateText(entity)

                if plate then
                    if server.trimplate then plate = string.strtrim(plate) end

                    if not data.id  then
                        data.id = (invType == 'glovebox' and 'glove' or 'trunk') .. plate
                    end
                end

				data.type = invType
				right = Inventory(data)

				if right and data.netid ~= right.netid then
					local invEntity = NetworkGetEntityFromNetworkId(right.netid)

					if not (invEntity > 0 and DoesEntityExist(invEntity)) or (plate and not string.match(GetVehicleNumberPlateText(invEntity) or '', plate)) then
						Inventory.Remove(right)
						right = Inventory(data)
					end
				end
			elseif invType == 'drop' then
				right = Inventory(data.id)
			else
				return
			end
		elseif invType == 'policeevidence' then
			if ignoreSecurityChecks or server.hasGroup(left, shared.police) then
				right = Inventory(('evidence-%s'):format(data))
			end
		elseif invType == 'dumpster' then
			if shared.networkdumpsters then
				local dumpsterId = getDumpsterFromCoords(data)
				right = dumpsterId and Inventory(('dumpster-%s'):format(dumpsterId))

				if not right then
					dumpsterId = #registeredDumpsters + 1
					right = Inventory.Create(('dumpster-%s'):format(dumpsterId), locale('dumpster'), invType, 15, 0, 100000, false)
					registeredDumpsters[dumpsterId] = data
				end
			else
				---@cast data string
				right = Inventory(data)

				if not right then
					local netid = tonumber(data:sub(9))

					if netid and NetworkGetEntityFromNetworkId(netid) > 0 then
						right = Inventory.Create(data, locale('dumpster'), invType, 15, 0, 100000, false)
					end
				end
			end
		elseif invType == 'container' then
			left.containerSlot = data --[[@as number]]
			data = left.items[data]

			if data then
				right = Inventory(data.metadata.container)

				if not right then
					right = Inventory.Create(data.metadata.container, data.label, invType, data.metadata.size[1], 0, data.metadata.size[2], false)
				end
			else left.containerSlot = nil end
		else right = Inventory(data) end

		if not right then return end

		if not ignoreSecurityChecks and right.groups and not server.hasGroup(left, right.groups) then return end

		local hookPayload = {
			source = source,
			inventoryId = right.id,
			inventoryType = right.type,
		}

		if invType == 'container' then hookPayload.slot = left.containerSlot end
		if isDataTable and data.netid then hookPayload.netId = data.netid end

		if not TriggerEventHooks('openInventory', hookPayload) then return end

        if left == right then return end

		if right.player then
			if right.open then return end

			right.coords = not ignoreSecurityChecks and GetEntityCoords(right.player.ped) or nil
		end

		if not ignoreSecurityChecks and right.coords then
			closestCoords = getClosestStashCoords(playerPed, right)

			if not closestCoords then return end
		end

		left:closeInventory(true)
		Inventory.CloseAll(left, source)
		left:openInventory(right)
	else
		left:closeInventory(true)
		Inventory.CloseAll(left, source)
		left:openInventory(left)
	end

	return {
		id = left.id,
		label = left.label,
		type = left.type,
		slots = left.slots,
		weight = left.weight,
		maxWeight = left.maxWeight
	}, right and {
		id = right.id,
		label = right.player and '' or right.label,
		type = right.player and 'otherplayer' or right.type,
		slots = right.slots,
		weight = right.weight,
		maxWeight = right.maxWeight,
		items = right.items,
		coords = closestCoords or right.coords,
		distance = right.distance
	}
end

---@param source number
---@param invType string
---@param data string|number|table
lib.callback.register('ox_inventory:openInventory', function(source, invType, data)
    if invType == 'player' and source ~= data then
        local serverId = type(data) == 'table' and data.id or data

        if source == serverId or type(serverId) ~= 'number' or not Player(serverId).state.canSteal then return end
    end

	return openInventory(source, invType, data)
end)

---@param netId number
lib.callback.register('ox_inventory:isVehicleATrailer', function(source, netId)
	local entity = NetworkGetEntityFromNetworkId(netId)
	local retval = GetVehicleType(entity)
	return retval == 'trailer'
end)

local function hasLpF1StaffAction(source, sectionKey, actionKey)
	if source == 0 then
		return true
	end

	if GetResourceState('lpF1') ~= 'started' or not exports.lpF1 or not exports.lpF1.HasStaffActionAccess then
		return false
	end

	local ok, allowed = pcall(function()
		return exports.lpF1:HasStaffActionAccess(source, sectionKey, actionKey)
	end)

	return ok and allowed == true
end

---@param playerId number
---@param invType string
---@param data string|number|table
function server.forceOpenInventory(playerId, invType, data, actorSource)
	local actingSource = tonumber(actorSource)
	if actingSource and actingSource > 0 and not hasLpF1StaffAction(actingSource, 'AdminItems', 'force_open_inventory') then
		return
	end

	local left, right = openInventory(playerId, invType, data, true)

	if left and right then
		TriggerClientEvent('ox_inventory:forceOpenInventory', playerId, left, right)
		return right.id
	end
end

exports('forceOpenInventory', server.forceOpenInventory)

local Licenses = lib.load('data.licenses')

lib.callback.register('ox_inventory:buyLicense', function(source, id)
	local license = Licenses[id]
	if not license then return end

	local inventory = Inventory(source)
	if not inventory then return end

	return server.buyLicense(inventory, license)
end)

lib.callback.register('ox_inventory:getItemCount', function(source, item, metadata, target)
	local inventory = target and Inventory(target) or Inventory(source)
	return (inventory and Inventory.GetItemCount(inventory, item, metadata, true))
end)

lib.callback.register('ox_inventory:getInventory', function(source, id)
	local playerInv = Inventory(source)
	if not playerInv then return end
	
	if id then
		if type(id) == 'number' then
			if id ~= source then
				local targetInv = Inventory(id)
				if not targetInv or not targetInv.player then return end
				if #(GetEntityCoords(GetPlayerPed(source)) - GetEntityCoords(GetPlayerPed(id))) > 15 then return end
			end
		elseif type(id) == 'string' then
			if not playerInv.open or Inventory(playerInv.open).id ~= id then return end
		end
	end
	
	local inventory = Inventory(id or source)
	if not inventory then return end
	
	if inventory.player and inventory.id ~= source then
		if #(GetEntityCoords(GetPlayerPed(source)) - GetEntityCoords(GetPlayerPed(inventory.id))) > 15 then return end
	end
	
	return inventory and {
		id = inventory.id,
		label = inventory.label,
		type = inventory.type,
		slots = inventory.slots,
		weight = inventory.weight,
		maxWeight = inventory.maxWeight,
		owned = inventory.owner and true or false,
		items = inventory.items
	}
end)

RegisterNetEvent('ox_inventory:usedItemInternal', function(slot)
    local inventory = Inventory(source)

    if not inventory then return end

    local item = inventory.usingItem

    if not item or item.slot ~= slot then
        ---@todo
        DropPlayer(inventory.id, 'sussy')

        return
    end

    TriggerEvent('ox_inventory:usedItem', inventory.id, item.name, item.slot, next(item.metadata) and item.metadata)

    inventory.usingItem = nil
end)

---@param source number
---@param itemName string
---@param slot number?
---@param metadata { [string]: any }?
---@return table | boolean | nil
lib.callback.register('ox_inventory:useItem', function(source, itemName, slot, metadata, noAnim)
	local inventory = Inventory(source) --[[@as OxInventory]]

	if not inventory then return end
	
	if type(itemName) ~= 'string' then return end
	if slot and (type(slot) ~= 'number' or slot < 1 or slot > inventory.slots) then return end
	if metadata and type(metadata) ~= 'table' then return end

	if inventory.player then
		local item = Items(itemName)
		if not item then return end
		
		local data = item and (slot and inventory.items[slot] or Inventory.GetSlotWithItem(inventory, item.name, metadata, true))

		if not data then return end
		
		if data.name ~= itemName then return end

		slot = data.slot
		local consume = item.consume
		if consume == nil and item.prop then
			consume = 1
		end
		if type(consume) == 'number' and consume > 0 and consume < 1 then
			consume = 0
		end
		local label = data.metadata.label or item.label

		if item and data and data.count > 0 and data.name == item.name then
			data = {name=data.name, label=label, count=data.count, slot=slot, metadata=data.metadata, weight=data.weight}

			if item.ammo then
				if inventory.weapon then
					local weapon = inventory.items[inventory.weapon]

					if weapon and weapon.metadata then
						consume = nil
					end
				else return false end
			elseif item.component or item.tint then
				consume = 1
				data.component = true
			elseif consume then
				if data.count >= consume then
					local result = item.cb and item.cb('usingItem', item, inventory, slot)

					if result == false then return end

					if result ~= nil then
						data.server = result
					end
				else
					return TriggerClientEvent('esx:showNotification', source, locale('item_not_enough', item.name))
				end
			elseif not item.weapon and server.UseItem then
                inventory.usingItem = data
				-- This is used to call an external useItem function, i.e. ESX.UseItem
				-- If an error is being thrown on item use there is no internal solution. We previously kept a list
				-- of usable items which led to issues when restarting resources (for obvious reasons), but config
				-- developers complained the inventory broke their items. Safely invoking registered item callbacks
				-- should resolve issues, i.e. https://github.com/esx-framework/esx-legacy/commit/9fc382bbe0f5b96ff102dace73c424a53458c96e
				return pcall(server.UseItem, source, data.name, data)
			end

			data.consume = consume

            if not TriggerEventHooks('usingItem', {
				source = source,
                inventoryId = inventory and inventory.id,
                item = inventory.items[slot],
                consume = consume
			}) then return false end

            ---@type boolean
			local success = lib.callback.await('ox_inventory:usingItem', source, data, noAnim)

			if item.weapon then
				inventory.weapon = success and slot or nil
			end

			if not success then return end

            inventory.usingItem = data

			if consume and consume ~= 0 and not data.component then
				data = inventory.items[data.slot]

				if not data then return end
				Inventory.RemoveItem(inventory.id, data.name, consume, nil, data.slot)

				if item and item.cb then
					item.cb('usedItem', item, inventory, data.slot)
				end
			end

			return true
		end
	end
end)

local function conversionScript()
	shared.ready = false

	local file = 'setup/convert.lua'
	local import = LoadResourceFile(shared.resource, file)
	local func = load(import, ('@@%s/%s'):format(shared.resource, file)) --[[@as function]]

	conversionScript = func()
end

RegisterCommand('convertinventory', function(source, args)
	if source ~= 0 then return end
	if type(conversionScript) == 'function' then conversionScript() end
	local arg = args[1]

	local convert = arg and conversionScript[arg]

	if not convert then
		return
	end

	CreateThread(convert)
end, true)


lib.addCommand({'additem', 'giveitem'}, {
	help = 'Gives an item to a player with the given id',
	params = {
		{ name = 'target', type = 'playerId', help = 'The player to receive the item' },
		{ name = 'item', type = 'string', help = 'The name of the item' },
		{ name = 'count', type = 'number', help = 'The amount of the item to give', optional = true },
		{ name = 'type', help = 'Sets the "type" metadata to the value', optional = true },
	},
}, function(source, args)
	if not hasLpF1StaffAction(source, 'AdminItems', 'give_item') then
		return
	end

	local item = Items(args.item)

	if item then
		local inventory = Inventory(args.target) --[[@as OxInventory]]
		local count = args.count or 1
		local success, response = Inventory.AddItem(inventory, item.name, count, args.type and { type = tonumber(args.type) or args.type })

		if not success then
			return Citizen.Trace(('Failed to give %sx %s to player %s (%s)'):format(count, item.name, args.target, response))
		end

		source = Inventory(source) or { label = 'console', owner = 'console' }

		if server.loglevel > 0 then
			lib.logger(source.owner, 'admin', ('"%s" gave %sx %s to "%s"'):format(source.label, count, item.name, inventory.label))
		end
	end
end)

lib.addCommand('giveitemperm', {
	help = locale('cmd_giveitemperm_help'),
	params = {
		{ name = 'target', type = 'playerId', help = locale('cmd_giveitemperm_target_help') },
		{ name = 'item', type = 'string', help = locale('cmd_giveitemperm_item_help') },
		{ name = 'count', type = 'number', help = locale('cmd_giveitemperm_count_help'), optional = true },
	},
}, function(source, args)
	if not hasLpF1StaffAction(source, 'AdminItems', 'give_permanent_item') then
		return
	end

	local item = Items(args.item)

	if item then
		local inventory = Inventory(args.target) --[[@as OxInventory]]
		local count = args.count or 1
		local metadata = { permanent = true }
		local success, response = Inventory.AddItem(inventory, item.name, count, metadata)

		if success then
			source = Inventory(source) or { label = 'console', owner = 'console' }

			if server.loglevel > 0 then
				lib.logger(source.owner, 'admin', locale('cmd_giveitemperm_log', source.label, count, item.name, inventory.label))
			end

			TriggerClientEvent('esx:showNotification', args.target, locale('cmd_giveitemperm_received', count, item.label or item.name))
		else
			return Citizen.Trace(locale('cmd_giveitemperm_fail', count, item.name, args.target, response))
		end
	end
end)

lib.addCommand('removeitem', {
	help = 'Removes an item to a player with the given id',
	params = {
		{ name = 'target', type = 'playerId', help = 'The player to remove the item from' },
		{ name = 'item', type = 'string', help = 'The name of the item' },
		{ name = 'count', type = 'number', help = 'The amount of the item to take' },
		{ name = 'type', help = 'Only remove items with a matching metadata "type"', optional = true },
	},
}, function(source, args)
	if not hasLpF1StaffAction(source, 'AdminItems', 'remove_item') then
		return
	end

	local item = Items(args.item)

	if item and args.count > 0 then
		local inventory = Inventory(args.target) --[[@as OxInventory]]
		local success, response = Inventory.RemoveItem(inventory, item.name, args.count, args.type and { type = tonumber(args.type) or args.type }, nil, true)

		if not success then
			return Citizen.Trace(('Failed to remove %sx %s from player %s (%s)'):format(args.count, item.name, args.target, response))
		end

		source = Inventory(source) or {label = 'console', owner = 'console'}

		if server.loglevel > 0 then
			lib.logger(source.owner, 'admin', ('"%s" removed %sx %s from "%s"'):format(source.label, args.count, item.name, inventory.label))
		end
	end
end)

lib.addCommand('setitem', {
	help = 'Sets the item count for a player, removing or adding as needed',
	params = {
		{ name = 'target', type = 'playerId', help = 'The player to set the items for' },
		{ name = 'item', type = 'string', help = 'The name of the item' },
		{ name = 'count', type = 'number', help = 'The amount of items to set', optional = true },
		{ name = 'type', help = 'Add or remove items with the metadata "type"', optional = true },
	},
}, function(source, args)
	if not hasLpF1StaffAction(source, 'AdminItems', 'set_item_count') then
		return
	end

	local item = Items(args.item)

	if item then
		local inventory = Inventory(args.target) --[[@as OxInventory]]
		local success, response = Inventory.SetItem(inventory, item.name, args.count or 0, args.type and { type = tonumber(args.type) or args.type })

		if not success then
			return Citizen.Trace(('Failed to set %s count to %sx for player %s (%s)'):format(item.name, args.count, args.target, response))
		end

		source = Inventory(source) or {label = 'console', owner = 'console'}

		if server.loglevel > 0 then
			lib.logger(source.owner, 'admin', ('"%s" set "%s" %s count to %sx'):format(source.label, inventory.label, item.name, args.count))
		end
	end
end)

lib.addCommand('clearevidence', {
	help = 'Clears a police evidence locker with the given id',
	params = {
		{ name = 'locker', type = 'number', help = 'The locker id to clear' },
	},
}, function(source, args)
	if not server.isPlayerBoss then return end

	local inventory = Inventory(source)
	local group, grade = server.hasGroup(inventory, shared.police)
	local hasPermission = group and server.isPlayerBoss(source, group, grade)

	if hasPermission then
		MySQL.query('DELETE FROM ox_inventory WHERE name = ?', {('evidence-%s'):format(args.locker)})
	end
end)

lib.addCommand('takeinv', {
	help = 'Confiscates the target inventory, to restore with /restoreinv',
	params = {
		{ name = 'target', type = 'playerId', help = 'The player to confiscate items from' },
	},
}, function(source, args)
	if not hasLpF1StaffAction(source, 'AdminItems', 'force_open_inventory') then
		return
	end

	Inventory.Confiscate(args.target)
end)

lib.addCommand({'restoreinv', 'returninv'}, {
	help = 'Restores a previously confiscated inventory for the target',
	params = {
		{ name = 'target', type = 'playerId', help = 'The player to restore items to' },
	},
}, function(source, args)
	if not hasLpF1StaffAction(source, 'AdminItems', 'force_open_inventory') then
		return
	end

	Inventory.Return(args.target)
end)

lib.addCommand('clearinv', {
	help = 'Wipes all items from the target inventory',
	params = {
		{ name = 'invId', help = 'The inventory to wipe items from' },
	},
}, function(source, args)
	if not hasLpF1StaffAction(source, 'AdminItems', 'remove_item') then
		return
	end

	Inventory.Clear(tonumber(args.invId) or args.invId == 'me' and source or args.invId)
end)

lib.addCommand('saveinv', {
	help = 'Save all pending inventory changes to the database',
	params = {
		{ name = 'lock', help = 'Lock inventory access, until restart or saved without a lock', optional = true },
	},
}, function(source, args)
	if not hasLpF1StaffAction(source, 'AdminItems', 'manage_definitions') then
		return
	end

	Inventory.SaveInventories(args.lock == 'true', false)
end)

lib.addCommand('viewinv', {
	help = 'Inspect the target inventory without allowing interactions',
	params = {
		{ name = 'invId', help = 'The inventory to inspect' },
	},
}, function(source, args)
	if not hasLpF1StaffAction(source, 'AdminItems', 'inspect_inventory') then
		return
	end

	Inventory.InspectInventory(source, tonumber(args.invId) or args.invId)
end)

lib.addCommand('allitems', {
	help = 'Ouvrir un stash avec tous les items',
}, function(source, args, rawCommand)
	if not hasLpF1StaffAction(source, 'AdminItems', 'open_all_stash') then
		return
	end

	local allitems = exports.ox_inventory:Items()
	local itemsTable = {}
	local maxWeight = 0

	for name, item in pairs(allitems) do
		if name and item then
			table.insert(itemsTable, {name, 9999999})
			maxWeight = maxWeight + (item.weight * 500000000000000000)
		end
	end

	local stash = exports.ox_inventory:CreateTemporaryStash({
		label = 'Items:',
		slots = #itemsTable,
		maxWeight = maxWeight,
		items = itemsTable
	})

	TriggerClientEvent('ox_inventory:openInventory', source, 'stash', stash)
end)

lib.addCommand('searchitem', {
	help = 'Rechercher des items',
	params = {
		{ name = 'term', help = 'Terme de recherche', type = 'string' },
	},
}, function(source, args)
	if not hasLpF1StaffAction(source, 'AdminItems', 'search_stash') then
		return
	end

	local term = (args.term or ''):lower()
	if term == '' then
		return TriggerClientEvent('esx:showNotification', source, 'Vous devez indiquer un terme de recherche.')
	end

	local allitems = exports.ox_inventory:Items()
	local itemsTable = {}
	local maxWeight = 0

	for name, data in pairs(allitems) do
		local label = (data.label or name):lower()
		-- on cherche soit dans la clé, soit dans le label
		if name:lower():find(term, 1, true) or label:find(term, 1, true) then
			-- stock illimité comme avec allitems
			table.insert(itemsTable, { name, 9999999 })
			maxWeight = maxWeight + ((data.weight or 0) * 500000000000000000)
		end
	end

	if #itemsTable == 0 then
		return TriggerClientEvent('esx:showNotification', source, ('Aucun item trouvé pour « %s »'):format(term))
	end

	local stash = exports.ox_inventory:CreateTemporaryStash({
		label = ('Résultats pour « %s »'):format(term),
		slots = #itemsTable,
		maxWeight = maxWeight,
		items = itemsTable
	})

	if not stash then
		return TriggerClientEvent('esx:showNotification', source, 'Échec de la création du stash.')
	end

	TriggerClientEvent('ox_inventory:openInventory', source, 'stash', stash)
end)

RegisterNetEvent('ox_inventory:renameItem', function(slot, newName)
	local source = source
	if not hasLpF1StaffAction(source, 'AdminItems', 'rename_item_metadata') then return end
	local inventory = Inventory(source)
	
	if not inventory then return end
	
	if type(slot) ~= 'number' or slot < 1 or slot > inventory.slots then return end
	if type(newName) ~= 'string' or #newName > 100 or #newName < 1 then return end
	
	local item = inventory.items[slot]
	
	if not item then return end
	
	if not item.metadata then
		item.metadata = {}
	end
	
	item.metadata.label = newName
	inventory.changed = true
	
	if server.syncInventory then 
		server.syncInventory(inventory) 
	end
	
	TriggerClientEvent('esx:showNotification', source, locale('item_renamed_success'))
	
	TriggerClientEvent('ox_inventory:updateSlots', source, {
		{
			item = item,
			inventory = inventory.id
		}
	}, inventory.weight)
end)

local playerClothingSlots = {}
local CLOTHING_SLOT_OFFSET = 69

-- Mapping unifié item name -> slot ID (70-86) pour tous les styles
local clothingItemToSlot = {
	hat = 70, hats = 70,
	mask = 71, masks = 71,
	glasses = 72, glasse = 72, goggles = 72,
	chain = 73, chains = 73, accessory = 73, accessories = 73, neck = 73, necks = 73,
	hands = 74, gloves = 74, torso = 75, torsos = 75,
	jacket = 75, jackets = 75, undershirt = 75, undershirts = 75,
	watch = 76, watches = 76,
	pants = 77, legs = 77,
	earring = 78, earings = 78, earrings = 78,
	bag = 79, bags = 79, backpack = 79, backpacks = 79,
	tshirt = 80, tshirts = 80, debardeur = 80,
	vest = 81, vests = 81, bulletproof = 81, bodyarmor = 81, keville = 81, kevlar = 81,
	bracelet = 82, bracelets = 82,
	shoes = 83, shoe = 83,
	outfit = 86,
	tenue = 86
}

local clothingItemExactExclusions = {
	key_chain = true,
}

local function isExcludedClothingItemName(itemName)
	if type(itemName) ~= 'string' or itemName == '' then return false end
	return clothingItemExactExclusions[string.lower(itemName)] == true
end

local function getClothingSlotForItem(itemName)
	if not itemName then return nil end
	local lowerName = string.lower(itemName)
	if isExcludedClothingItemName(lowerName) then
		return nil
	end
	for key, slot in pairs(clothingItemToSlot) do
		if string.find(lowerName, key, 1, true) then
			return slot
		end
	end
	return nil
end

local function normalizeClothingSlot(slot)
	if type(slot) ~= 'number' then return nil end
	if slot >= 70 and slot <= 86 then return slot end
	if slot >= 1 and slot <= 17 then return slot + CLOTHING_SLOT_OFFSET end
	return nil
end

local function clothingSlotIndex(slot)
	return slot and (slot - CLOTHING_SLOT_OFFSET) or nil
end

local function getClothingOwner(inventory)
	return inventory and inventory.owner or nil
end

local function generateClothingUid()
	return ('c-%d-%06d-%06d'):format(os.time(), math.random(0, 999999), math.random(0, 999999))
end

local function ensureClothingUid(metadata)
	if type(metadata) ~= 'table' then return end
	if type(metadata.uid) ~= 'string' or metadata.uid == '' then
		metadata.uid = generateClothingUid()
	end
end

local function clearDuplicateClothingUid(source, inventory, uid, keepSlot)
	if not uid or not inventory or not inventory.items then return end
	for slot, item in pairs(inventory.items) do
		if slot ~= keepSlot and item and item.metadata and item.metadata.uid == uid then
			Inventory.RemoveItem(inventory, item.name, item.count or 1, item.metadata, slot)
			if slot >= 70 and slot <= 86 and playerClothingSlots[source] then
				playerClothingSlots[source][slot] = nil
			end
			break
		end
	end
end

local function loadClothingSlots(source, inventory)
	if playerClothingSlots[source] and next(playerClothingSlots[source]) then return end

	if not inventory then return end
	if not playerClothingSlots[source] then
		playerClothingSlots[source] = {}
	end

	local function decodeOutfitCandidate(value)
		if type(value) == 'string' then
			local ok, decoded = pcall(json.decode, value)
			if ok and type(decoded) == 'table' then
				return decoded
			end
			return nil
		end
		if type(value) == 'table' then
			return value
		end
		return nil
	end

	local function extractOutfitData(metadata)
		if type(metadata) ~= 'table' then return nil end
		local candidates = {
			metadata.outfitData,
			metadata.outfit,
			metadata.appearance,
			metadata.appearanceData,
			metadata.data,
			metadata.skin,
			metadata.clothes,
			metadata
		}
		for _, candidate in ipairs(candidates) do
			local decoded = decodeOutfitCandidate(candidate)
			if decoded and (decoded.components or decoded.props
				or decoded['pants'] or decoded['arms'] or decoded['t-shirt'] or decoded['torso2']
				or decoded['mask'] or decoded['hat'] or decoded['glass'] or decoded['ear']) then
				return decoded
			end
		end
		return nil
	end

	local function buildOutfitItems(metadata)
		local outfit = extractOutfitData(metadata)
		if not outfit then return nil end
		local itemsBySlot = {}

		local function addComponent(slotId, name, componentId, drawable, texture)
			if drawable == nil then return end
			if componentId == 1 and (drawable == 0 or drawable == -1) and (texture == nil or texture == 0) then
				return
			end
			itemsBySlot[slotId] = {
				name = name,
				count = 1,
				metadata = {
					component = componentId,
					drawable = drawable,
					texture = texture or 0,
					fromOutfit = true,
					outfitSlot = 86
				}
			}
		end

		local function addProp(slotId, name, propId, drawable, texture)
			if drawable == nil or drawable == -1 or drawable == 0 then return end
			itemsBySlot[slotId] = {
				name = name,
				count = 1,
				metadata = {
					prop = propId,
					drawable = drawable,
					texture = texture or 0,
					fromOutfit = true,
					outfitSlot = 86
				}
			}
		end

		if outfit['pants'] then addComponent(77, 'pants', 4, outfit['pants'].item, outfit['pants'].texture) end
		if outfit['arms'] then addComponent(74, 'gloves', 3, outfit['arms'].item, outfit['arms'].texture) end
		if outfit['t-shirt'] then addComponent(80, 'tshirt', 8, outfit['t-shirt'].item, outfit['t-shirt'].texture) end
		if outfit['vest'] then addComponent(81, 'vest', 9, outfit['vest'].item, outfit['vest'].texture) end
		if outfit['torso2'] then addComponent(75, 'jacket', 11, outfit['torso2'].item, outfit['torso2'].texture) end
		if outfit['shoes'] then addComponent(83, 'shoes', 6, outfit['shoes'].item, outfit['shoes'].texture) end
		if outfit['accessory'] then addComponent(73, 'chain', 7, outfit['accessory'].item, outfit['accessory'].texture) end
		if outfit['mask'] then addComponent(71, 'mask', 1, outfit['mask'].item, outfit['mask'].texture) end
		if outfit['bag'] then addComponent(79, 'bag', 5, outfit['bag'].item, outfit['bag'].texture) end
		if outfit['hat'] then addProp(70, 'hat', 0, outfit['hat'].item, outfit['hat'].texture) end
		if outfit['glass'] then addProp(72, 'glasses', 1, outfit['glass'].item, outfit['glass'].texture) end
		if outfit['ear'] then addProp(78, 'earring', 2, outfit['ear'].item, outfit['ear'].texture) end

		if outfit.components or outfit.props then
			local function findById(list, id, keys)
				if type(list) ~= 'table' then return nil end
				for _, entry in pairs(list) do
					if type(entry) == 'table' then
						for _, keyName in ipairs(keys) do
							if entry[keyName] == id then return entry end
						end
					end
				end
				return nil
			end

			local compMap = { [1] = 71, [3] = 74, [11] = 75, [8] = 80, [4] = 77, [6] = 83, [9] = 81, [5] = 79, [7] = 73 }
			for compId, slotId in pairs(compMap) do
				local comp = findById(outfit.components, compId, { 'component_id', 'componentId', 'component', 'id' })
				if comp then
					addComponent(slotId, 'outfit_component', compId, comp.drawable or comp.item, comp.texture)
				end
			end

			local propMap = { [0] = 70, [1] = 72, [2] = 78, [6] = 76, [7] = 82 }
			for propId, slotId in pairs(propMap) do
				local prop = findById(outfit.props, propId, { 'prop_id', 'propId', 'prop', 'id' })
				if prop then
					addProp(slotId, 'outfit_prop', propId, prop.drawable or prop.item, prop.texture)
				end
			end
		end

		return next(itemsBySlot) and itemsBySlot or nil
	end

	for slotId = 70, 86 do
		local item = inventory.items and inventory.items[slotId]
		if item and item.name then
			local metaCopy = type(item.metadata) == 'table' and table.clone(item.metadata) or {}
			metaCopy.equippedInClothingSlot = nil
			ensureClothingUid(metaCopy)
			clearDuplicateClothingUid(source, inventory, metaCopy.uid, slotId)
			playerClothingSlots[source][slotId] = {
				name = item.name,
				count = item.count or 1,
				metadata = metaCopy,
				weight = item.weight or 0
			}
		end
	end

	local function expandOutfitIfNeeded(outfitItem)
		if not outfitItem or type(outfitItem.metadata) ~= 'table' then return end
		local hasOther = false
		for slotId = 70, 83 do
			local existing = inventory.items and inventory.items[slotId]
			if existing and existing.name then
				hasOther = true
				break
			end
		end
		if hasOther then return end

		local itemsBySlot = buildOutfitItems(outfitItem.metadata)
		if not itemsBySlot then return end
		for slotId, item in pairs(itemsBySlot) do
			if not (inventory.items and inventory.items[slotId]) then
				local itemDef = Items(item.name)
				if itemDef then
					local metaCopy = type(item.metadata) == 'table' and table.clone(item.metadata) or {}
					metaCopy.equippedInClothingSlot = slotId
					ensureClothingUid(metaCopy)
					clearDuplicateClothingUid(source, inventory, metaCopy.uid, slotId)
					local count = item.count or 1
					local slotWeight = Inventory.SlotWeight(itemDef, { count = count, metadata = metaCopy })
					inventory.items = inventory.items or {}
					inventory.items[slotId] = {
						name = itemDef.name,
						label = itemDef.label,
						weight = slotWeight,
						slot = slotId,
						count = count,
						description = itemDef.description,
						metadata = metaCopy,
						stack = itemDef.stack,
						close = itemDef.close,
						rarity = itemDef.rarity
					}
					inventory.weight = (inventory.weight or 0) + slotWeight
					inventory.changed = true

					local cacheMeta = table.clone(metaCopy)
					cacheMeta.equippedInClothingSlot = nil
					playerClothingSlots[source][slotId] = {
						name = itemDef.name,
						count = count,
						metadata = cacheMeta,
						weight = slotWeight
					}
				end
			end
		end
	end

	local owner = getClothingOwner(inventory)
	if not owner then return end

	local stored = db.loadClothing(owner)
	if not stored then return end

	for slotId, item in pairs(stored) do
		if type(slotId) == 'number' and item and item.name and not (inventory.items and inventory.items[slotId]) then
			local itemDef = Items(item.name)
			if itemDef then
				local metaCopy = type(item.metadata) == 'table' and table.clone(item.metadata) or {}
				metaCopy.equippedInClothingSlot = slotId
				ensureClothingUid(metaCopy)
				clearDuplicateClothingUid(source, inventory, metaCopy.uid, slotId)
				local count = item.count or 1
				local slotWeight = Inventory.SlotWeight(itemDef, { count = count, metadata = metaCopy })
				inventory.items = inventory.items or {}
				inventory.items[slotId] = {
					name = itemDef.name,
					label = itemDef.label,
					weight = slotWeight,
					slot = slotId,
					count = count,
					description = itemDef.description,
					metadata = metaCopy,
					stack = itemDef.stack,
					close = itemDef.close,
					rarity = itemDef.rarity
				}
				inventory.weight = (inventory.weight or 0) + slotWeight
				inventory.changed = true

				local cacheMeta = table.clone(metaCopy)
				cacheMeta.equippedInClothingSlot = nil
				playerClothingSlots[source][slotId] = {
					name = itemDef.name,
					count = count,
					metadata = cacheMeta,
					weight = slotWeight
				}
			end
		end
	end

	local outfitSlotItem = inventory.items and inventory.items[86]
	if outfitSlotItem and outfitSlotItem.name == 'outfit' then
		expandOutfitIfNeeded(outfitSlotItem)
	end
end

local function saveClothingSlots(source, inventory)
	if not inventory then return end
	local owner = getClothingOwner(inventory)
	if not owner then return end

	local slots = playerClothingSlots[source]
	if not slots then
		return db.saveClothing(owner, nil)
	end

	local payload
	for slotId, item in pairs(slots) do
		if item and item.name then
			local metaCopy = type(item.metadata) == 'table' and table.clone(item.metadata) or {}
			metaCopy.equippedInClothingSlot = nil
			payload = payload or {}
			payload[slotId] = {
				name = item.name,
				count = item.count or 1,
				metadata = metaCopy,
				weight = item.weight or 0
			}
		end
	end

	return db.saveClothing(owner, payload)
end

lib.callback.register('ox_inventory:getClothingSlots', function(source)
	local slots = {}
	local inventory = Inventory(source)
	loadClothingSlots(source, inventory)

	for i = 1, 17 do
		local slotId = 69 + i
		local item = inventory and inventory.items and inventory.items[slotId]
		if item and item.name and isExcludedClothingItemName(item.name) then
			applyClothingSlot(source, slotId, nil, true)
			item = inventory and inventory.items and inventory.items[slotId]
		end
		slots[i] = item and {
			slot = slotId,
			name = item.name,
			weight = item.weight,
			count = item.count or 1,
			metadata = item.metadata
		} or nil
	end

	for i = 1, 17 do
		slots[i] = slots[i] or { slot = 69 + i }
	end

	return slots
end)

local function metaMatches(a, b)
	if not a or not b then return false end
	return a.component == b.component
		and a.prop == b.prop
		and a.drawable == b.drawable
		and (a.texture or 0) == (b.texture or 0)
end

local function outfitDebug(fmt, ...)
	return
end

local function outfitMetaEquals(a, b)
	if type(a) ~= 'table' or type(b) ~= 'table' then return false end
	local aCopy = table.clone(a)
	local bCopy = table.clone(b)
	aCopy.equippedInClothingSlot = nil
	bCopy.equippedInClothingSlot = nil
	local okA, encA = pcall(json.encode, aCopy)
	local okB, encB = pcall(json.encode, bCopy)
	if not okA or not okB then return false end
	return encA == encB
end

local function addToMainInventory(inventory, itemName, count, metadata)
	outfitDebug('addToMainInventory: item=%s count=%s', tostring(itemName), tostring(count))
	local itemDef = Items(itemName)
	if not itemDef then return false end

	local maxSlot = math.min(69, inventory.slots or 69)
	local targetSlot

	if itemDef.stack then
		local slots = Inventory.GetItemSlots(inventory, itemName, metadata, true)
		if slots then
			for slotId in pairs(slots) do
				if slotId <= maxSlot then
					targetSlot = slotId
					break
				end
			end
		end
	end

	if not targetSlot then
		for i = 1, maxSlot do
			if not inventory.items[i] then
				targetSlot = i
				break
			end
		end
	end

	if targetSlot then
		outfitDebug('addToMainInventory: targetSlot=%s', tostring(targetSlot))
		return Inventory.AddItem(inventory, itemName, count, metadata, targetSlot)
	end

	outfitDebug('addToMainInventory: fallback add')
	return Inventory.AddItem(inventory, itemName, count, metadata)
end

local function applyClothingSlot(source, slotId, itemData, returnToInventory)
	local inventory = Inventory(source)
	if not inventory then return false end

	local slotNum = normalizeClothingSlot(slotId)
	if not slotNum then return false end

	-- Slot 86 is reserved for outfit items.
	-- - Slot 86: allow only 'outfit' or 'tenue'
	-- - Other clothing slots: disallow placing 'outfit'/'tenue'
	if slotNum == 86 then
		if itemData and type(itemData) == 'table' and type(itemData.name) == 'string' then
			local n = string.lower(itemData.name)
			if n ~= 'outfit' and n ~= 'tenue' then
				return false
			end
		end
	else
		if itemData and type(itemData) == 'table' and type(itemData.name) == 'string' then
			local n = string.lower(itemData.name)
			if n == 'outfit' or n == 'tenue' then
				return false
			end
		end
	end

	if itemData and type(itemData) == 'table' and isExcludedClothingItemName(itemData.name) then
		return false
	end


	if itemData and type(itemData) == 'table' then
		if itemData.name and type(itemData.name) ~= 'string' then return end
		if itemData.metadata and type(itemData.metadata) ~= 'table' then return end
	end

	outfitDebug('applyClothingSlot: slotNum=%s returnToInventory=%s item=%s', tostring(slotNum), tostring(returnToInventory), tostring(itemData and itemData.name))

	if inventory.slots and inventory.slots < slotNum and not (slotNum >= 70 and slotNum <= 86) then
		return false
	end

	loadClothingSlots(source, inventory)
	local storedSlots = playerClothingSlots[source] or {}
	local storedSlot = storedSlots[slotNum]

	local oldClothing = inventory.items and inventory.items[slotNum]
	if not oldClothing and storedSlot and storedSlot.name then
		oldClothing = {
			name = storedSlot.name,
			count = storedSlot.count or 1,
			metadata = table.clone(storedSlot.metadata or {})
		}
		outfitDebug('applyClothingSlot: using stored slot cache for slot=%s item=%s', tostring(slotNum), tostring(oldClothing.name))
	end

	if slotNum == 81 then
		local backpackConfig = Config.BackpackWeights or {}
		local weightChanged = false

		if oldClothing and oldClothing.name then
			local oldBackpackWeight = backpackConfig[oldClothing.name]
			if oldBackpackWeight then
				inventory.maxWeight = inventory.maxWeight - oldBackpackWeight.weight
				weightChanged = true
			end
		end

		if itemData and itemData.name then
			local newBackpackWeight = backpackConfig[itemData.name]
			if newBackpackWeight then
				inventory.maxWeight = inventory.maxWeight + newBackpackWeight.weight
				weightChanged = true
			end
		end

		if weightChanged then
			TriggerClientEvent('ox_inventory:refreshMaxWeight', source, { inventoryId = source, maxWeight = inventory.maxWeight })
		end
	end

	if not itemData then
		if oldClothing and oldClothing.name then
			if oldClothing.metadata then
				ensureClothingUid(oldClothing.metadata)
			end
			if oldClothing.metadata and (oldClothing.metadata.fromOutfit or oldClothing.metadata.outfitSlot == 86) and returnToInventory ~= true then
				returnToInventory = false
			end
			outfitDebug('applyClothingSlot: clearing slot=%s oldItem=%s', tostring(slotNum), tostring(oldClothing.name))
			if returnToInventory ~= false then
				local metaCopy = table.clone(oldClothing.metadata or {})
				metaCopy.equippedInClothingSlot = nil
				metaCopy.fromOutfit = nil
				metaCopy.outfitSlot = nil
				local added = addToMainInventory(inventory, oldClothing.name, oldClothing.count or 1, metaCopy)
				outfitDebug('applyClothingSlot: returned to inventory=%s', tostring(added))
			end
			Inventory.RemoveItem(inventory, oldClothing.name, oldClothing.count or 1, oldClothing.metadata, slotNum)
		end
		playerClothingSlots[source][slotNum] = nil
		saveClothingSlots(source, inventory)
		return true
	end

	if not oldClothing or not oldClothing.name then
		outfitDebug('applyClothingSlot: slot=%s has no existing item', tostring(slotNum))
	end

	local metaCopy = table.clone(itemData.metadata or {})
	metaCopy._skipOutfitClear = nil
	ensureClothingUid(metaCopy)
	clearDuplicateClothingUid(source, inventory, metaCopy.uid, slotNum)
	metaCopy.equippedInClothingSlot = slotNum

	if oldClothing and oldClothing.name then
		outfitDebug('applyClothingSlot: replacing slot=%s oldItem=%s newItem=%s', tostring(slotNum), tostring(oldClothing.name), tostring(itemData.name))
		if returnToInventory ~= false then
			local oldMeta = table.clone(oldClothing.metadata or {})
			oldMeta.equippedInClothingSlot = nil
			local added = addToMainInventory(inventory, oldClothing.name, oldClothing.count or 1, oldMeta)
			outfitDebug('applyClothingSlot: old item returned=%s', tostring(added))
		end
		Inventory.RemoveItem(inventory, oldClothing.name, oldClothing.count or 1, oldClothing.metadata, slotNum)
	end

	local removeSlot = nil
	if not metaCopy.fromOutfit then
		for slot, item in pairs(inventory.items) do
			if item and item.name == itemData.name and item.metadata then
				if itemData.name == 'outfit' then
					if outfitMetaEquals(item.metadata, metaCopy) then
						removeSlot = slot
						break
					end
				elseif metaMatches(item.metadata, metaCopy) then
					removeSlot = slot
					break
				end
			end
		end

		if not removeSlot then
			local hintedSlot = tonumber(itemData.slot or itemData.sourceSlot or itemData.fromSlot)
			if hintedSlot and hintedSlot ~= slotNum then
				local hintedItem = inventory.items[hintedSlot]
				if hintedItem and hintedItem.name == itemData.name then
					removeSlot = hintedSlot
				end
			end
		end

		if not removeSlot then
			for slot, item in pairs(inventory.items) do
				if slot ~= slotNum and item and item.name == itemData.name then
					if itemData.name == 'outfit' then
						if outfitMetaEquals(item.metadata or {}, itemData.metadata or {}) then
							removeSlot = slot
							break
						end
					elseif metaMatches(item.metadata or {}, itemData.metadata or {}) then
						removeSlot = slot
						break
					end
				end
			end
		end

		if not removeSlot then
			for slot, item in pairs(inventory.items) do
				if slot ~= slotNum and item and item.name == itemData.name and slot <= 69 then
					removeSlot = slot
					break
				end
			end
		end
	end

	if not removeSlot and itemData and itemData.name == 'outfit' and itemData.slot and tonumber(itemData.slot) then
		local sourceSlot = tonumber(itemData.slot)
		if sourceSlot ~= slotNum and inventory.items[sourceSlot] and inventory.items[sourceSlot].name == 'outfit' then
			removeSlot = sourceSlot
			outfitDebug('applyClothingSlot: fallback remove sourceSlot=%s', tostring(sourceSlot))
		end
	end

	if removeSlot and removeSlot ~= slotNum then
		outfitDebug('applyClothingSlot: remove source item slot=%s', tostring(removeSlot))
		Inventory.RemoveItem(inventory, itemData.name, 1, inventory.items[removeSlot].metadata, removeSlot)
	end

	local added = Inventory.AddItem(inventory, itemData.name, 1, metaCopy, slotNum)
	outfitDebug('applyClothingSlot: add to slot=%s result=%s', tostring(slotNum), tostring(added))

	if itemData.name == 'outfit' and slotNum == 86 then
		for invSlot, invItem in pairs(inventory.items) do
			if invSlot ~= slotNum and invItem and invItem.name == 'outfit' and outfitMetaEquals(invItem.metadata or {}, itemData.metadata or {}) then
				Inventory.RemoveItem(inventory, 'outfit', 1, invItem.metadata, invSlot)
				outfitDebug('applyClothingSlot: removed outfit duplicate from slot=%s', tostring(invSlot))
				break
			end
		end
	end

	local itemDef = Items(itemData.name)
	local count = itemData.count or 1
	local weight = itemDef and Inventory.SlotWeight(itemDef, { count = count, metadata = metaCopy }) or 0

	playerClothingSlots[source][slotNum] = {
		name = itemData.name,
		count = count,
		metadata = metaCopy,
		weight = weight
	}

	saveClothingSlots(source, inventory)
	return inventory.items[slotNum] and inventory.items[slotNum].name == itemData.name or false
end

RegisterNetEvent('ox_inventory:saveClothingSlot', function(slotId, itemData)
	applyClothingSlot(source, slotId, itemData, true)
end)

RegisterNetEvent('ox_inventory:clearClothingSlot', function(slotId, returnToInventory)
	applyClothingSlot(source, slotId, nil, returnToInventory)
end)

exports('SetClothingSlot', function(target, slotId, itemData)
	return applyClothingSlot(target, slotId, itemData, true)
end)

RegisterNetEvent('ox_inventory:markOutfitEquipped', function(sourceSlot, itemData)
	local source = source
	local inventory = Inventory(source)
	if not inventory then return end

	local slot = tonumber(sourceSlot)
	if not slot then return end

	local item = inventory.items[slot]
	if not item then return end
	if itemData and itemData.name and item.name ~= itemData.name then return end

	outfitDebug('markOutfitEquipped: source=%s sourceSlot=%s item=%s', tostring(source), tostring(slot), tostring(item.name))

	local changed = false
	for _, entry in pairs(inventory.items) do
		if entry and entry.metadata and entry.metadata.equippedInClothingSlot == 86 then
			entry.metadata.equippedInClothingSlot = nil
			changed = true
		end
	end

	if slot == 86 then
		item.metadata = item.metadata or {}
		if itemData and itemData.metadata and type(itemData.metadata) == 'table' then
			item.metadata = table.clone(itemData.metadata)
		end
		item.metadata.equippedInClothingSlot = 86
		outfitDebug('markOutfitEquipped: already in slot 86, metadata updated')
		changed = true
	else
		local meta = itemData and itemData.metadata and type(itemData.metadata) == 'table' and table.clone(itemData.metadata) or table.clone(item.metadata or {})
		meta.equippedInClothingSlot = 86
		local applied = applyClothingSlot(source, 86, {
			name = item.name,
			count = item.count or 1,
			metadata = meta
		}, true)
		outfitDebug('markOutfitEquipped: moved to slot 86 applied=%s', tostring(applied))

		local sourceItem = inventory.items[slot]
		if sourceItem and sourceItem.name == item.name then
			Inventory.RemoveItem(inventory, item.name, 1, sourceItem.metadata, slot)
			outfitDebug('markOutfitEquipped: removed from sourceSlot=%s', tostring(slot))
		end

		for invSlot, invItem in pairs(inventory.items) do
			if invSlot ~= 86 and invItem and invItem.name == item.name and outfitMetaEquals(invItem.metadata or {}, meta) then
				Inventory.RemoveItem(inventory, item.name, 1, invItem.metadata, invSlot)
				outfitDebug('markOutfitEquipped: removed duplicate from slot=%s', tostring(invSlot))
				break
			end
		end
		changed = true
	end

	if changed then
		inventory.changed = true
		if server.syncInventory then
			server.syncInventory(inventory)
		end
	end
end)

RegisterNetEvent('ox_inventory:clearOutfitEquipped', function()
	local source = source
	local inventory = Inventory(source)
	if not inventory then return end

	local changed = false
	for _, entry in pairs(inventory.items) do
		if entry and entry.metadata and entry.metadata.equippedInClothingSlot == 86 then
			entry.metadata.equippedInClothingSlot = nil
			changed = true
		end
	end

	if changed then
		inventory.changed = true
		if server.syncInventory then
			server.syncInventory(inventory)
		end
	end
end)

RegisterNetEvent('ox_inventory:removeKevlar', function(slotId, itemName)
	local source = source
	local inventory = Inventory(source)

	if not inventory then return end

	local slotNum = normalizeClothingSlot(slotId)
	if not slotNum then return end

	local metadataChanged = false
	local storedSlots = playerClothingSlots[source]
	local storedItem = storedSlots and storedSlots[slotNum]

	if storedItem then
		if slotNum == (12 + CLOTHING_SLOT_OFFSET) then
			local backpackConfig = Config.BackpackWeights or {}
			local backpackWeight = storedItem.name and backpackConfig[storedItem.name]

			if backpackWeight then
				inventory.maxWeight = inventory.maxWeight - backpackWeight.weight
				TriggerClientEvent('ox_inventory:refreshMaxWeight', source, { inventoryId = source, maxWeight = inventory.maxWeight })
			end
		end

		for slot, item in pairs(inventory.items) do
			if item and item.name == storedItem.name and item.metadata and item.metadata.equippedInClothingSlot == slotNum then
				item.metadata.equippedInClothingSlot = nil
				metadataChanged = true
				break
			end
		end

		storedSlots[slotNum] = nil

		TriggerClientEvent('ox_inventory:updateSlots', source, {
			{
				item = { slot = slotNum },
				inventory = 'clothing'
			}
		})
	end

	if itemName and type(itemName) == 'string' then
		local itemData = Items(itemName)
		if not itemData then return end

		for slot, item in pairs(inventory.items) do
			if item and item.name == itemName then
				Inventory.RemoveItem(inventory, itemName, 1, nil, slot)
				break
			end
		end
	end

	if metadataChanged then
		inventory.changed = true
		if server.syncInventory then
			server.syncInventory(inventory)
		end
	end
end)

RegisterNetEvent('ox_inventory:addOutfitClothingItem', function(data)
	local source = source
	local inventory = Inventory(source)
	if not inventory then return end

	if not data or type(data) ~= 'table' then return end
	local itemName = data.name
	local metadata = data.metadata
	local slotId = tonumber(data.slotId)

	outfitDebug('addOutfitClothingItem: source=%s item=%s slotId=%s drawable=%s texture=%s component=%s prop=%s', tostring(source), tostring(itemName), tostring(slotId), tostring(metadata and metadata.drawable), tostring(metadata and metadata.texture), tostring(metadata and metadata.component), tostring(metadata and metadata.prop))

	if type(itemName) ~= 'string' or type(metadata) ~= 'table' then
		outfitDebug('addOutfitClothingItem: invalid payload')
		return
	end
	if not slotId or slotId < 70 or slotId > 86 then
		outfitDebug('addOutfitClothingItem: invalid slotId=%s', tostring(slotId))
		return
	end

	local expectedSlot = getClothingSlotForItem(itemName)
	if not expectedSlot or expectedSlot ~= slotId then
		outfitDebug('addOutfitClothingItem: slot mismatch expected=%s got=%s', tostring(expectedSlot), tostring(slotId))
		return
	end

	if metadata.component == nil and metadata.prop == nil and metadata.drawable == nil then
		outfitDebug('addOutfitClothingItem: missing metadata fields')
		return
	end

	local function metaMatches(a, b)
		if not a or not b then return false end
		return a.component == b.component
			and a.prop == b.prop
			and a.drawable == b.drawable
			and (a.texture or 0) == (b.texture or 0)
	end

	for _, item in pairs(inventory.items) do
		if item and item.name == itemName and item.metadata and metaMatches(item.metadata, metadata) then
			if item.metadata.equippedInClothingSlot == slotId then
				item.metadata.equippedInClothingSlot = nil
				inventory.changed = true
				if server.syncInventory then
					server.syncInventory(inventory)
				end
			end
			outfitDebug('addOutfitClothingItem: already exists in inventory')
			return
		end
	end

	metadata.fromOutfit = nil
	metadata.outfitSlot = nil
	metadata.equippedInClothingSlot = nil

	addToMainInventory(inventory, itemName, 1, metadata)
	outfitDebug('addOutfitClothingItem: added to inventory')
end)

RegisterNetEvent('ox_inventory:addOutfitClothingAndEquip', function(data)
	local source = source
	local inventory = Inventory(source)
	if not inventory then return end

	if not data or type(data) ~= 'table' then return end
	local itemName = data.name
	local metadata = data.metadata
	local slotId = tonumber(data.slotId)

	outfitDebug('addOutfitClothingAndEquip: source=%s item=%s slotId=%s drawable=%s texture=%s component=%s prop=%s', tostring(source), tostring(itemName), tostring(slotId), tostring(metadata and metadata.drawable), tostring(metadata and metadata.texture), tostring(metadata and metadata.component), tostring(metadata and metadata.prop))

	if type(itemName) ~= 'string' or type(metadata) ~= 'table' then
		outfitDebug('addOutfitClothingAndEquip: invalid payload')
		return
	end
	if not slotId or slotId < 70 or slotId > 86 then
		outfitDebug('addOutfitClothingAndEquip: invalid slotId=%s', tostring(slotId))
		return
	end

	local expectedSlot = getClothingSlotForItem(itemName)
	if not expectedSlot or expectedSlot ~= slotId then
		outfitDebug('addOutfitClothingAndEquip: slot mismatch expected=%s got=%s', tostring(expectedSlot), tostring(slotId))
		return
	end

	if metadata.component == nil and metadata.prop == nil and metadata.drawable == nil then
		outfitDebug('addOutfitClothingAndEquip: missing metadata fields')
		return
	end

	metadata.fromOutfit = nil
	metadata.outfitSlot = nil
	metadata.equippedInClothingSlot = nil

	addToMainInventory(inventory, itemName, 1, metadata)
	local applied = applyClothingSlot(source, slotId, {
		name = itemName,
		count = 1,
		metadata = metadata
	}, true)

	local slotNum = normalizeClothingSlot(slotId)
	if slotNum then
		for slot, item in pairs(inventory.items) do
			if slot ~= slotNum and item and item.name == itemName and item.metadata and metaMatches(item.metadata, metadata) then
				Inventory.RemoveItem(inventory, itemName, 1, item.metadata, slot)
				outfitDebug('addOutfitClothingAndEquip: removed duplicate from slot=%s', tostring(slot))
				break
			end
		end
	end
	outfitDebug('addOutfitClothingAndEquip: applied=%s', tostring(applied))
end)


RegisterNetEvent('ox_inventory:consumeOutfitItem', function(data)
	local source = source
	local inventory = Inventory(source)
	if not inventory then return end
	if not data or type(data) ~= 'table' then return end

	local slot = tonumber(data.slot)
	local itemName = data.name
	if not slot or type(itemName) ~= 'string' then return end

	local slotItem = inventory.items[slot]
	if not slotItem or slotItem.name ~= itemName then return end

	Inventory.RemoveItem(inventory, itemName, 1, nil, slot)
end)

RegisterNetEvent('ox_inventory:server:toggleClothLock', function(slotId)
	local source = source
	local inventory = Inventory(source)
	if not inventory then return end

	local slotNum = normalizeClothingSlot(tonumber(slotId))
	if not slotNum then return end
	if slotNum == 86 then return end

	local itemData = inventory.items and inventory.items[slotNum]
	if not itemData or not itemData.name then return end
	itemData.metadata = itemData.metadata or {}
	itemData.metadata.lockedCloth = not itemData.metadata.lockedCloth

	Inventory.SetMetadata(inventory, slotNum, itemData.metadata)

	TriggerClientEvent('ox_inventory:updateClothLock', source, slotNum, itemData)
end)

RegisterNetEvent('ox_inventory:addClothingItemToInventory', function(data)
	local source = source
	local inventory = Inventory(source)
	if not inventory then return end
	if not data or type(data) ~= 'table' then return end

	local itemName = data.name
	local metadata = data.metadata
	local slotId = tonumber(data.slotId)

	if type(itemName) ~= 'string' or type(metadata) ~= 'table' then return end
	if not slotId or slotId < 70 or slotId > 86 then return end

	local expectedSlot = getClothingSlotForItem(itemName)
	if not expectedSlot or expectedSlot ~= slotId then return end

	if metadata.component == nil and metadata.prop == nil and metadata.drawable == nil then return end

	local function metaMatches(a, b)
		if not a or not b then return false end
		return a.component == b.component
			and a.prop == b.prop
			and a.drawable == b.drawable
			and (a.texture or 0) == (b.texture or 0)
	end

	for _, item in pairs(inventory.items) do
		if item and item.name == itemName and item.metadata and metaMatches(item.metadata, metadata) then
			return
		end
	end

	metadata.fromOutfit = nil
	metadata.outfitSlot = nil
	metadata.equippedInClothingSlot = nil

	addToMainInventory(inventory, itemName, 1, metadata)
end)

RegisterNetEvent('ox_inventory:addEquippedClothingItem', function(data)
	local source = source
	local inventory = Inventory(source)
	if not inventory then return end
	if not data or type(data) ~= 'table' then return end

	local itemName = data.name
	local metadata = data.metadata
	local slotId = tonumber(data.slotId)

	if type(itemName) ~= 'string' or type(metadata) ~= 'table' then return end
	if not slotId or slotId < 70 or slotId > 86 then return end

	local expectedSlot = getClothingSlotForItem(itemName)
	if not expectedSlot or expectedSlot ~= slotId then return end

	if metadata.component == nil and metadata.prop == nil and metadata.drawable == nil then return end

	local function metaMatches(a, b)
		if not a or not b then return false end
		return a.component == b.component
			and a.prop == b.prop
			and a.drawable == b.drawable
			and (a.texture or 0) == (b.texture or 0)
	end

	for _, item in pairs(inventory.items) do
		if item and item.name == itemName and item.metadata and metaMatches(item.metadata, metadata) then
			item.metadata.equippedInClothingSlot = slotId
			inventory.changed = true
			if server.syncInventory then
				server.syncInventory(inventory)
			end
			return
		end
	end

	metadata.equippedInClothingSlot = slotId
	Inventory.AddItem(inventory, itemName, 1, metadata)
end)

RegisterNetEvent('ox_inventory:clearEquippedClothingItem', function(data)
	local source = source
	local inventory = Inventory(source)
	if not inventory then return end
	if not data or type(data) ~= 'table' then return end

	local itemName = data.name
	local metadata = data.metadata
	local slotId = tonumber(data.slotId)

	if type(itemName) ~= 'string' or type(metadata) ~= 'table' then return end
	if not slotId or slotId < 70 or slotId > 86 then return end

	local function metaMatches(a, b)
		if not a or not b then return false end
		return a.component == b.component
			and a.prop == b.prop
			and a.drawable == b.drawable
			and (a.texture or 0) == (b.texture or 0)
	end

	for _, item in pairs(inventory.items) do
		if item and item.name == itemName and item.metadata and metaMatches(item.metadata, metadata) then
			if item.metadata.equippedInClothingSlot == slotId then
				item.metadata.equippedInClothingSlot = nil
				inventory.changed = true
				if server.syncInventory then
					server.syncInventory(inventory)
				end
			end
			return
		end
	end
end)

AddEventHandler('playerDropped', function()
	local source = source
	if playerClothingSlots[source] then
		playerClothingSlots[source] = nil
	end
end)

local function GetItemProp(itemName)
	local item = Items(itemName)
	if not item then return 'prop_money_bag_01' end
	
	if item.prop then
		local prop = item.prop
		if type(prop) == 'string' then
			return prop
		else
			return prop
		end
	end
	
	if item.weapon then
		local weaponData = lib.load('data.weapons')
		if weaponData and weaponData.Weapons and weaponData.Weapons[itemName] and weaponData.Weapons[itemName].prop then
			local prop = weaponData.Weapons[itemName].prop
			if type(prop) == 'string' then
				return prop
			else
				return prop
			end
		end
		
		return 'w_pi_pistol'
	end
	
	return 'prop_money_bag_01'
end

lib.callback.register('ox_inventory:placeItem', function(source, slot, coords, heading)
	local inventory = Inventory(source)
	if not inventory then return false end
	
	if type(slot) ~= 'number' or slot < 1 or slot > inventory.slots then return false end
	if type(coords) ~= 'vector3' then return false end
	if type(heading) ~= 'number' or heading < 0 or heading > 360 then return false end
	
	local playerCoords = GetEntityCoords(GetPlayerPed(source))
	local distance = #(playerCoords - coords)
	if distance > 5.0 then return false end
	
	local slotData = inventory.items[slot]
	if not slotData then return false end
	if slotData.metadata and slotData.metadata.permanent then return false end
	
	local item = Items(slotData.name)
	if not item then return false end
	
	if slotData.count < 1 then return false end
	
	local ownerIdentifier = inventory.owner or inventory.id
	if not ownerIdentifier then return false end
	local metadata = slotData.metadata or {}
	local metadataJson = json.encode(metadata)
	
	local propModel = GetItemProp(slotData.name)
	local propModelStr = type(propModel) == 'string' and propModel or tostring(propModel)
	
	local success, placedItemId = pcall(function()
		return MySQL.insert.await('INSERT INTO ox_inventory_placed_items (owner, item_name, prop_model, coords_x, coords_y, coords_z, heading, slot, metadata) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)', {
			ownerIdentifier,
			slotData.name,
			propModelStr,
			coords.x,
			coords.y,
			coords.z,
			heading,
			slot,
			metadataJson
		})
	end)
	
	if success and placedItemId and placedItemId > 0 then
		Inventory.RemoveItem(inventory, slotData.name, 1, nil, slot)
		
		placedItems[placedItemId] = {
			owner = ownerIdentifier,
			itemName = slotData.name,
			propModel = propModelStr,
			coords = coords,
			heading = heading,
			slot = slot,
			metadata = metadata
		}
		
		TriggerClientEvent('ox_inventory:itemPlaced', -1, placedItemId, slotData.name, propModelStr, coords, heading)
		
		return true
	end
	
	return false
end)

lib.addCommand('trash', {
    help = "Retirer un item de l'inventaire",
    restricted = 'group.admin',
}, function(source, args)
    local xPlayer = ESX.GetPlayerFromId(source)

    if xPlayer.getGroup() == 'admin' then
        local trashInventoryId = 'trash' .. source
        exports.ox_inventory:RegisterStash(trashInventoryId, 'trash-' .. source, 1, 9999999)

        TriggerClientEvent('ox_inventory:openInventory', source, 'stash', trashInventoryId)

        CreateThread(function()
            local isOpen = true
            
            -- Surveiller la fermeture de l'inventaire
            local closeHandler = AddEventHandler('ox_inventory:closedInventory', function(playerId, invId)
                if playerId == source and invId == trashInventoryId then
                    isOpen = false
                end
            end)

            while isOpen do
                Wait(500)

                local items = exports.ox_inventory:GetInventoryItems(trashInventoryId)
                if items and next(items) ~= nil then
                    for _, item in pairs(items) do
                        if item and item.name and item.count then
                            exports.ox_inventory:RemoveItem(trashInventoryId, item.name, item.count)
                        end
                    end

                    exports.ox_inventory:ClearInventory(trashInventoryId)
                end
            end

            -- Nettoyer l'event handler
            RemoveEventHandler(closeHandler)
        end)

    else
        TriggerClientEvent('esx:showNotification', source, "Vous n'avez pas la permission d'utiliser cette commande.")
    end
end)

RegisterNetEvent('ox_inventory:pickupPlacedItem', function(placedItemId)
	local source = source
	local inventory = Inventory(source)
	if not inventory then return end
	
	if type(placedItemId) ~= 'number' or placedItemId < 1 then return end
	
	local placedItem = placedItems[placedItemId]
	
	if not placedItem then
		local result = MySQL.query.await('SELECT * FROM ox_inventory_placed_items WHERE id = ?', { placedItemId })
		if result and result[1] then
			placedItem = {
				owner = result[1].owner,
				itemName = result[1].item_name,
				propModel = result[1].prop_model,
				coords = vector3(result[1].coords_x, result[1].coords_y, result[1].coords_z),
				heading = result[1].heading,
				slot = result[1].slot,
				metadata = result[1].metadata and json.decode(result[1].metadata) or {}
			}
			placedItems[placedItemId] = placedItem
		else
			NotifyPlacement(source, 'error', 'placed_item_pickup_missing')
			return
		end
	end
	
	local playerPed = GetPlayerPed(source)
	if not playerPed then return end
	local playerCoords = GetEntityCoords(playerPed)
	local distance = #(playerCoords - placedItem.coords)
	
	if distance > 3.0 then
		NotifyPlacement(source, 'error', 'placed_item_pickup_too_far')
		return
	end
	
	if not CanPlayerPickupPlacedItem(inventory, placedItem) then
		NotifyPlacement(source, 'error', 'placed_item_pickup_not_owner')
		return
	end
	
	local canAdd = Inventory.CanCarryItem(inventory, placedItem.itemName, 1, placedItem.metadata)
	if not canAdd then
		TriggerClientEvent('esx:showNotification', source, locale('cannot_carry'))
		return
	end
	
	Inventory.AddItem(inventory, placedItem.itemName, 1, placedItem.metadata)
	
	MySQL.query('DELETE FROM ox_inventory_placed_items WHERE id = ?', { placedItemId })
	placedItems[placedItemId] = nil

	local itemData = Items(placedItem.itemName)
	local label = itemData and itemData.label or placedItem.itemName
	NotifyPlacement(source, 'success', 'placed_item_pickup_success', label)
	
	TriggerClientEvent('ox_inventory:itemPickedUp', -1, placedItemId)
end)

lib.callback.register('ox_inventory:removeWeaponComponent', function(source, weaponSlot, componentName)
	if type(weaponSlot) ~= 'number' or type(componentName) ~= 'string' then
		return false
	end
	
	local playerInv = Inventory(source)
	if not playerInv then
		return false
	end
	
	local weaponItem = playerInv.items[weaponSlot]
	
	if not weaponItem or not weaponItem.metadata or not weaponItem.metadata.components then
		return false
	end
	
	local componentIndex = nil
	for i, comp in ipairs(weaponItem.metadata.components) do
		local compName = type(comp) == 'table' and comp.name or comp
		if compName and (compName == componentName or string.lower(compName) == string.lower(componentName)) then
			componentIndex = i
			break
		end
	end
	
	if not componentIndex then
		return false
	end
	
	table.remove(weaponItem.metadata.components, componentIndex)
	
	local emptySlot = Inventory.GetEmptySlot(playerInv)
	if emptySlot then
		playerInv.items[emptySlot] = {
			name = componentName,
			slot = emptySlot,
			count = 1,
			weight = Items(componentName).weight or 0,
			metadata = {}
		}
	end
	
	if server.syncInventory then
		server.syncInventory(playerInv)
	end
	return true, { items = playerInv.items, weight = playerInv.weight }
end)

lib.callback.register('ox_inventory:addWeaponComponent', function(source, componentSlot, weaponSlot)
	if type(componentSlot) ~= 'number' or type(weaponSlot) ~= 'number' then
		return false
	end
	
	local playerInv = Inventory(source)
	if not playerInv then
		return false
	end
	
	local weaponItem = playerInv.items[weaponSlot]
	local componentItem = playerInv.items[componentSlot]
	
	if not weaponItem or not componentItem then
		return false
	end
	
	local componentName = componentItem.name
	local componentData = componentName and Items(componentName)
	
	-- Check if component already installed
	if weaponItem.metadata and weaponItem.metadata.components then
		for i = 1, #weaponItem.metadata.components do
			local installedComponent = weaponItem.metadata.components[i]
			local installedComponentName = type(installedComponent) == 'table' and installedComponent.name or installedComponent
			if installedComponentName == componentName then
				return false, 'component_has'
			end
			if componentData and componentData.type then
				local installedComponentData = installedComponentName and Items(installedComponentName)
				if installedComponentData and installedComponentData.type == componentData.type then
					return false, 'component_has'
				end
			end
		end
	end
	
	if not weaponItem.metadata then
		weaponItem.metadata = {}
	end
	
	if weaponItem.metadata.components then
		weaponItem.metadata.components[#weaponItem.metadata.components + 1] = componentName
	else
		weaponItem.metadata.components = { componentName }
	end
	
	playerInv.items[componentSlot] = nil
	
	if server.syncInventory then
		server.syncInventory(playerInv)
	end
	
	return true, { items = playerInv.items, weight = playerInv.weight }
end)

AddEventHandler('onResourceStart', function(resourceName)
	if resourceName == GetCurrentResourceName() then
		CreateThread(function()
			Wait(2000)
			local results = MySQL.query.await('SELECT * FROM ox_inventory_placed_items')
			if results then
				for _, result in ipairs(results) do
					local coords = vector3(result.coords_x, result.coords_y, result.coords_z)
					local metadata = result.metadata and json.decode(result.metadata) or {}
					
					placedItems[result.id] = {
						owner = result.owner,
						itemName = result.item_name,
						propModel = result.prop_model,
						coords = coords,
						heading = result.heading,
						slot = result.slot,
						metadata = metadata
					}
					
					TriggerClientEvent('ox_inventory:itemPlaced', -1, result.id, result.item_name, result.prop_model, coords, result.heading)
				end
			end
		end)
	end
end)

AddEventHandler('onResourceStop', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then return end

	for _, playerId in ipairs(GetPlayers()) do
		local source = tonumber(playerId)
		local inventory = source and Inventory(source)
		if inventory and playerClothingSlots[source] then
			saveClothingSlots(source, inventory)
		end
	end
end)

AddEventHandler('playerDropped', function()
	local source = source
	local inventory = Inventory(source)
	if playerClothingSlots[source] and inventory then
		saveClothingSlots(source, inventory)
	end
	playerClothingSlots[source] = nil
end)

local medicalItemLabels = {
	bandage = 'bandage',
	medikit = 'trousse de soins',
	icebag = 'sac de glace',
	pommade = 'pommade'
}

RegisterNetEvent('ox_inventory:applyMedicalItemOnTarget', function(targetServerId, itemName)
	local source = source
	targetServerId = tonumber(targetServerId)

	if not targetServerId or targetServerId <= 0 then
		return
	end

	if type(itemName) ~= 'string' or not medicalItemLabels[itemName] then
		return
	end

	local sourcePed = GetPlayerPed(source)
	local targetPed = GetPlayerPed(targetServerId)
	if not sourcePed or sourcePed == 0 or not targetPed or targetPed == 0 then
		return
	end

	local sourceCoords = GetEntityCoords(sourcePed)
	local targetCoords = GetEntityCoords(targetPed)
	if #(sourceCoords - targetCoords) > 3.0 then
		TriggerClientEvent('ox_inventory:medicalItemFeedback', source, 'La cible est trop loin')
		return
	end

	TriggerClientEvent('ox_inventory:medicalItemEffect', targetServerId, itemName)
	TriggerClientEvent('ox_inventory:medicalItemFeedback', source, ('Vous utilisez %s sur la personne'):format(medicalItemLabels[itemName]))
end)