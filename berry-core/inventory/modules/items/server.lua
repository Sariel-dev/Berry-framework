if not lib then return end

local Items = {}
local ItemList = require 'modules.items.shared' --[[@as table<string, OxServerItem>]]
local Utils = require 'modules.utils.server'

TriggerEvent('ox_inventory:itemList', ItemList)

Items.containers = require 'modules.items.containers'

-- Possible metadata when creating garbage
local trash = {
	{description = 'A discarded burger carton.', weight = 50, image = 'trash_burger'},
	{description = 'An empty soda can.', weight = 20, image = 'trash_can'},
	{description = 'A mouldy piece of bread.', weight = 70, image = 'trash_bread'},
	{description = 'An empty chips bag.', weight = 5, image = 'trash_chips'},
	{description = 'A slightly used pair of panties.', weight = 20, image = 'panties'},
	{description = 'An old rolled up newspaper.', weight = 200, image = 'WEAPON_ACIDPACKAGE'},
}

---@param _ table?
---@param name string?
---@return table?
local function getItem(_, name)
    if not name then return ItemList end

	if type(name) ~= 'string' then return end

    name = name:lower()

    if name:sub(0, 7) == 'weapon_' then
        name = name:upper()
    end

    return ItemList[name]
end

setmetatable(Items --[[@as table]], {
	__call = getItem
})

---@cast Items +fun(itemName: string): OxServerItem
---@cast Items +fun(): table<string, OxServerItem>

-- Support both names
exports('Items', function(item) return getItem(nil, item) end)
exports('ItemList', function(item) return getItem(nil, item) end)

local Inventory

CreateThread(function()
	Inventory = require 'modules.inventory.server'

    if not lib then return end

	if shared.framework == 'esx' then
		local success, items = pcall(MySQL.query.await, 'SELECT * FROM items')

		if success and items and next(items) then
			local dump = {}
			local count = 0

			for i = 1, #items do
				local item = items[i]

				if not ItemList[item.name] then
					item.close = item.closeonuse == nil and true or item.closeonuse
					item.stack = item.stackable == nil and true or item.stackable
					item.description = item.description
					item.weight = item.weight or 0
					dump[i] = item
					count += 1
				end
			end

			if table.type(dump) ~= "empty" then
				local file = {string.strtrim(LoadResourceFile(shared.resource, 'data/items.lua'))}
				file[1] = file[1]:gsub('}$', '')

				---@todo separate into functions for reusability, properly handle nil values
				local itemFormat = [[

	[%q] = {
		label = %q,
		weight = %s,
		stack = %s,
		close = %s,
		description = %q
	},
]]
				local fileSize = #file

				for _, item in pairs(dump) do
					if not ItemList[item.name] then
						fileSize += 1

						local itemStr = itemFormat:format(item.name, item.label, item.weight, item.stack, item.close, item.description and json.encode(item.description) or 'nil')
						-- temporary solution for nil values
						itemStr = itemStr:gsub('[%s]-[%w]+ = "?nil"?,?', '')
						file[fileSize] = itemStr
						ItemList[item.name] = item
					end
				end

				file[fileSize+1] = '}'

				SaveResourceFile(shared.resource, 'data/items.lua', table.concat(file), -1)
			end
		end

		Wait(500)
	end

	local count = 0

	Wait(1000)

	for _ in pairs(ItemList) do
		count += 1
	end

	collectgarbage('collect') -- clean up from initialisation
	shared.ready = true
end)

local function GenerateText(num)
	local str
	repeat str = {}
		for i = 1, num do str[i] = string.char(math.random(65, 90)) end
		str = table.concat(str)
	until str ~= 'POL' and str ~= 'EMS'
	return str
end

local function GenerateSerial(text)
	if text and text:len() > 3 then
		return text
	end

	return ('%s%s%s'):format(math.random(100000,999999), text == nil and GenerateText(3) or text, math.random(100000,999999))
end

local clothingKeywords = {
	'hat', 'mask', 'glasses', 'glasse', 'goggles',
	'chain', 'accessory', 'neck', 'hands', 'gloves',
	'torso', 'jacket', 'undershirt', 'watch',
	'pants', 'legs', 'earring', 'earings', 'earrings',
	'bag', 'bags', 'backpack', 'backpacks',
	'tshirt', 'tshirts', 'debardeur',
	'vest', 'vests', 'bulletproof', 'bodyarmor', 'keville', 'kevlar',
	'bracelet', 'bracelets', 'shoes', 'shoe',
	'outfit', 'tenue'
}

local function isClothingItemName(name)
	if type(name) ~= 'string' then return false end
	local lowerName = string.lower(name)
	for i = 1, #clothingKeywords do
		if lowerName:find(clothingKeywords[i], 1, true) then
			return true
		end
	end
	return false
end

local function GenerateClothingUid()
	return ('c-%d-%06d-%06d'):format(os.time(), math.random(0, 999999), math.random(0, 999999))
end

local function setItemDurability(item, metadata)
	metadata.durability = nil
	metadata.degrade = nil
	metadata.expirationDate = nil
	metadata.createdDate = nil
	return metadata
end

local TriggerEventHooks = require 'modules.hooks.server'

---@param inv inventory
---@param item OxServerItem
---@param metadata any
---@param count number
---@return table, number
---Generates metadata for new items being created through AddItem, buyItem, etc.
function Items.Metadata(inv, item, metadata, count)
	if type(inv) ~= 'table' then inv = Inventory(inv) end
	if not item.weapon then metadata = not metadata and {} or type(metadata) == 'string' and {type=metadata} or metadata end
	if not count then count = 1 end

	---@cast metadata table<string, any>

	if item.weapon then
		if type(metadata) ~= 'table' then metadata = {} end
		if not metadata.ammo and item.ammoname then metadata.ammo = 0 end
		if not metadata.ammo and (item.hash == `WEAPON_PETROLCAN` or item.hash == `WEAPON_HAZARDCAN` or item.hash == `WEAPON_FERTILIZERCAN` or item.hash == `WEAPON_FIREEXTINGUISHER`) then metadata.ammo = 100 end
		if not metadata.components then metadata.components = {} end

		if metadata.registered ~= false and (metadata.ammo or item.name == 'WEAPON_STUNGUN') then
			local registered = type(metadata.registered) == 'string' and metadata.registered or inv?.player?.name
			metadata.registered = registered
			metadata.serial = GenerateSerial(metadata.serial)
		end

		metadata.durability = nil
		metadata.degrade = nil
		metadata.expirationDate = nil
		metadata.createdDate = nil
	else
		local container = Items.containers[item.name]

		if container then
			count = 1
			metadata.container = metadata.container or GenerateText(3)..os.time()
			metadata.size = container.size
		elseif not next(metadata) then
			if item.name == 'identification' then
				count = 1
				metadata = {
					type = inv.player.name,
					description = locale('identification', (inv.player.sex) and locale('male') or locale('female'), inv.player.dateofbirth)
				}
			elseif item.name == 'garbage' then
				local trashType = trash[math.random(1, #trash)]
				metadata.image = trashType.image
				metadata.weight = trashType.weight
				metadata.description = trashType.description
			end
		end

		metadata = setItemDurability(ItemList[item.name], metadata)
	end

	if isClothingItemName(item.name) and not metadata.uid then
		metadata.uid = GenerateClothingUid()
	end

	if count > 1 and not item.stack then
		count = 1
	end

	local response = TriggerEventHooks('createItem', {
		inventoryId = inv and inv.id,
		metadata = metadata,
		item = item,
		count = count,
	})

	if type(response) == 'table' then
		metadata = response
	end

	if metadata.imageurl and Utils.IsValidImageUrl then
		if Utils.IsValidImageUrl(metadata.imageurl) then
			Utils.DiscordEmbed('Valid image URL', ('Created item "%s" (%s) with valid url in "%s".\n%s\nid: %s\nowner: %s'):format(metadata.label or item.label, item.name, inv.label, metadata.imageurl, inv.id, inv.owner, metadata.imageurl), metadata.imageurl, 65280)
		else
			Utils.DiscordEmbed('Invalid image URL', ('Created item "%s" (%s) with invalid url in "%s".\n%s\nid: %s\nowner: %s'):format(metadata.label or item.label, item.name, inv.label, metadata.imageurl, inv.id, inv.owner, metadata.imageurl), metadata.imageurl, 16711680)
			metadata.imageurl = nil
		end
	end

	return metadata, count
end

---@param metadata table<string, any>
---@param item OxServerItem
---@param name string
---@param ostime number
---Validate (and in some cases convert) item metadata when an inventory is being loaded.
function Items.CheckMetadata(metadata, item, name, ostime)
	if isClothingItemName(name) and (not metadata.uid or type(metadata.uid) ~= 'string') then
		metadata.uid = GenerateClothingUid()
	end

	if metadata.bag then
		metadata.container = metadata.bag
		metadata.size = Items.containers[name]?.size or {5, 1000}
		metadata.bag = nil
	end

	metadata = setItemDurability(item, metadata)

	if item.weapon then
		if metadata.components then
			if table.type(metadata.components) == 'array' then
				for i = #metadata.components, 1, -1 do
					if not ItemList[metadata.components[i]] then
						table.remove(metadata.components, i)
					end
				end
			else
				local components = {}
				local size = 0

				for _, component in pairs(metadata.components) do
					if component and ItemList[component] then
						size += 1
						components[size] = component
					end
				end

				metadata.components = components
			end
		end

		if metadata.serial and item.throwable then
			metadata.serial = nil
		end

		if metadata.specialAmmo and type(metadata.specialAmmo) ~= 'string' then
			metadata.specialAmmo = nil
		end
	end

	return metadata
end

---Update item durability, and call `Inventory.RemoveItem` if it was removed from decay.
---@param inv OxInventory
---@param slot SlotWithItem
---@param item OxServerItem
---@param value? number
---@param ostime? number
---@return boolean? removed
function Items.UpdateDurability(inv, slot, item, value, ostime)
	if not slot.metadata then return true end
	slot.metadata.durability = nil
	slot.metadata.degrade = nil
	slot.metadata.expirationDate = nil
	slot.metadata.createdDate = nil
	return true
end

---@deprecated
---Use the 'ox_inventory:usedItem' event or the 'usingItem' or 'buyItem' hooks
local function Item(name, cb)
	local item = ItemList[name]

	if item and not item.cb then
		item.cb = cb
	end
end

-----------------------------------------------------------------------------------------------
-- Serverside item functions
-----------------------------------------------------------------------------------------------



-----------------------------------------------------------------------------------------------

RegisterServerEvent('ox_inventory:removeConsumable')
AddEventHandler('ox_inventory:removeConsumable', function(itemName, slot, hunger, thirst)
	local src = source
	if not Inventory then
		Inventory = require 'modules.inventory.server'
	end
	local inventory = Inventory(src)
	if not inventory then
		return
	end
	
	if not inventory then return end
	
	if type(itemName) ~= 'string' then
		return
	end
	if type(slot) ~= 'number' or slot < 1 or slot > inventory.slots then
		return
	end
	if hunger and type(hunger) ~= 'number' then
		return
	end
	if thirst and type(thirst) ~= 'number' then
		return
	end
	
	local item = inventory.items[slot]
	if not item or item.name ~= itemName then return end
	
	-- Vérifier si l'item est périmé
	local isExpired = false
	local expiredDamage = 20
	
	if item.metadata and item.metadata.expirationDate then
		local currentTime = os.time()
		if currentTime >= item.metadata.expirationDate then
			isExpired = true
			
			-- Configurer le dégât en fonction de la configuration
			if Config.Durability and Config.Durability.expiredDamage then
				expiredDamage = Config.Durability.expiredDamage
			end
		end
	end
	
	local removed = exports.ox_inventory:RemoveItem(src, itemName, 1, nil, slot)
	if not removed then
		removed = Inventory.RemoveItem(inventory, itemName, 1, nil, slot)
	end
	
	if removed then
		if isExpired then
			TriggerClientEvent('ox_inventory:client:applyExpiredDamage', src, expiredDamage)
			TriggerClientEvent('esx:showNotification', src, locale('ui_expired_food_consumed'))
			
			-- Réduire les effets de faim/soif
			if hunger then hunger = math.floor(hunger * 0.3) end
			if thirst then thirst = math.floor(thirst * 0.3) end
		end
		
		if hunger or thirst then
			TriggerClientEvent('esx_status:add', src, 'hunger', hunger or 0)
			TriggerClientEvent('esx_status:add', src, 'thirst', thirst or 0)
		end
	end
end)

-----------------------------------------------------------------------------------------------

return Items
