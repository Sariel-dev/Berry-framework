if not lib then return end

local Items = require 'modules.items.shared' --[[@as table<string, OxClientItem>]]

local function sendDisplayMetadata(data)
    SendNUIMessage({
		action = 'displayMetadata',
		data = data
	})
end

--- use array of single key value pairs to dictate order
---@param metadata string | table<string, string> | table<string, string>[]
---@param value? string
local function displayMetadata(metadata, value)
	local data = {}

	if type(metadata) == 'string' then
        if not value then return end

        data = { { metadata = metadata, value = value } }
	elseif table.type(metadata) == 'array' then
		for i = 1, #metadata do
			for k, v in pairs(metadata[i]) do
				data[i] = {
					metadata = k,
					value = v,
				}
			end
		end
	else
		for k, v in pairs(metadata) do
			data[#data + 1] = {
				metadata = k,
				value = v,
			}
		end
	end

    if client.uiLoaded then
        return sendDisplayMetadata(data)
    end

    CreateThread(function()
        repeat Wait(100) until client.uiLoaded

        sendDisplayMetadata(data)
    end)
end

exports('displayMetadata', displayMetadata)

---@param _ table?
---@param name string?
---@return table?
local function getItem(_, name)
    if not name then return Items end

	if type(name) ~= 'string' then return end

    name = name:lower()

    if name:sub(0, 7) == 'weapon_' then
        name = name:upper()
    end

    return Items[name]
end

setmetatable(Items --[[@as table]], {
	__call = getItem
})

---@cast Items +fun(itemName: string): OxClientItem
---@cast Items +fun(): table<string, OxClientItem>

local function Item(name, cb)
	local item = Items[name]
	if item then
		if not item.client?.export and not item.client?.event then
			item.effect = cb
		end
	end
end

local ox_inventory = exports[shared.resource]
-----------------------------------------------------------------------------------------------
-- Clientside item use functions
-----------------------------------------------------------------------------------------------

Item('bandage', function(data, slot)
	local maxHealth = GetEntityMaxHealth(cache.ped)
	local health = GetEntityHealth(cache.ped)
	ox_inventory:useItem(data, function(data)
		if data then
			SetEntityHealth(cache.ped, math.min(maxHealth, math.floor(health + maxHealth / 16)))
			lib.notify({ title = 'Information', description = 'You feel better already' })
		end
	end)
end)

Item('armour', function(data, slot)
	if GetPedArmour(cache.ped) < 100 then
		ox_inventory:useItem(data, function(data)
			if data then
				SetPlayerMaxArmour(PlayerData.id, 100)
				SetPedArmour(cache.ped, 100)
			end
		end)
	end
end)

client.parachute = false
Item('parachute', function(data, slot)
	if not client.parachute then
		ox_inventory:useItem(data, function(data)
			if data then
				local chute = `GADGET_PARACHUTE`
				SetPlayerParachuteTintIndex(PlayerData.id, -1)
				GiveWeaponToPed(cache.ped, chute, 0, true, false)
				SetPedGadget(cache.ped, chute, true)
				lib.requestModel(1269906701)
				client.parachute = {CreateParachuteBagObject(cache.ped, true, true), slot?.metadata?.type or -1}
				if slot.metadata.type then
					SetPlayerParachuteTintIndex(PlayerData.id, slot.metadata.type)
				end
			end
		end)
	end
end)

Item('phone', function(data, slot)
	local success, result = pcall(function()
		return exports.npwd:isPhoneVisible()
	end)

	if success then
		exports.npwd:setPhoneVisible(not result)
	end
end)

-- Clothing System Detection & Compatibility
local detectedClothingSystem = nil

local function getClothingSystem()
	if detectedClothingSystem then return detectedClothingSystem end
	
	local configSystem = Config.ClothingSystem or 'auto'
	
	if configSystem ~= 'auto' then
		if configSystem == 'none' then
			detectedClothingSystem = 'none'
		elseif configSystem == 'illenium-appearance' and GetResourceState('illenium-appearance') == 'started' then
			detectedClothingSystem = 'illenium-appearance'
		elseif configSystem == 'rcore_clothing' and GetResourceState('rcore_clothing') == 'started' then
			detectedClothingSystem = 'rcore_clothing'
		elseif configSystem == '17mov_CharacterSystem' and GetResourceState('17mov_CharacterSystem') == 'started' then
			detectedClothingSystem = '17mov_CharacterSystem'
		else
			configSystem = 'auto'
		end
	end
	
	if configSystem == 'auto' then
		if GetResourceState('illenium-appearance') == 'started' then
			detectedClothingSystem = 'illenium-appearance'
		elseif GetResourceState('rcore_clothing') == 'started' then
			detectedClothingSystem = 'rcore_clothing'
		elseif GetResourceState('17mov_CharacterSystem') == 'started' then
			detectedClothingSystem = '17mov_CharacterSystem'
		else
			detectedClothingSystem = 'none'
		end
	end
	
	return detectedClothingSystem
end

local function saveClothingAppearance()
	SetTimeout(100, function()
		if GetResourceState('lpCharacter') == 'started' then
			TriggerEvent('lpCharacter:saveCurrentAppearanceState')
			return
		end

		local system = getClothingSystem()
		
		if system == 'illenium-appearance' or system == '17mov_CharacterSystem' then
			-- illenium-appearance and 17mov both use the same API (17mov provides illenium bridge)
			local appearance = exports['illenium-appearance']:getPedAppearance(cache.ped)
			if appearance then
				TriggerServerEvent('illenium-appearance:server:saveAppearance', appearance)
			end
		elseif system == 'rcore_clothing' then
			-- rcore_clothing uses event to save current skin (per official API documentation)
			local success, err = pcall(function()
				TriggerEvent('rcore_clothing:saveCurrentSkin')
			end)
		end
		-- 'none' = do nothing
	end)
end

local function getInventoryStyle()
	local defaultStyle = 'normal'
	if Config.DefaultStyle and Config.DefaultStyle.Inventory and type(Config.DefaultStyle.Inventory.Style) == 'string' then
		defaultStyle = Config.DefaultStyle.Inventory.Style
	end

	if Config.DefaultStyle and Config.DefaultStyle.ForceDefaults then
		return defaultStyle
	end

	local prefs = LocalPlayer.state.inventoryPreferences
	if prefs and type(prefs) == 'table' and prefs.inventoryStyle == defaultStyle then
		return prefs.inventoryStyle
	end

	return defaultStyle
end

-- Mapping unifié des vêtements vers les slots (identique pour tous les styles)
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

local function getClothingSlotForItem(itemName, isFlashback)
	local lowerName = string.lower(itemName)
	
	-- Utiliser le même mapping pour tous les styles (unifié)
	for key, slotId in pairs(clothingItemToSlot) do
		if string.find(lowerName, key, 1, true) then
			return slotId
		end
	end
	return nil
end

local function playClothingRemoveAnim(itemName, metadata)
	if not metadata or metadata.prop ~= 0 then return end -- Hat only

	local dict = 'missfbi4'
	local anim = 'takeoff_mask'

	if lib.requestAnimDict(dict, 1000) then
		TaskPlayAnim(cache.ped, dict, anim, 8.0, 1.0, 600, 49, 0.0, false, false, false)
		Wait(450)
		StopAnimTask(cache.ped, dict, anim, 1.0)
	end
end

local function clothingHandler(data, slot)
	local metadata = slot.metadata

	if not metadata.drawable then return end
	if not metadata.texture then return end

	if metadata.prop then
		if not SetPedPreloadPropData(cache.ped, metadata.prop, metadata.drawable, metadata.texture) then
			return
		end
	elseif metadata.component then
		if not IsPedComponentVariationValid(cache.ped, metadata.component, metadata.drawable, metadata.texture) then
			return
		end
	else
		return
	end

	ox_inventory:useItem(data, function(data)
		if data then
			metadata = data.metadata
			local isFlashback = getInventoryStyle() == 'flashback'
			local slotId = getClothingSlotForItem(data.name, isFlashback)
			local system = getClothingSystem()

			if metadata.prop then
				local prop = GetPedPropIndex(cache.ped, metadata.prop)
				local texture = GetPedPropTextureIndex(cache.ped, metadata.prop)

				if metadata.drawable == prop and metadata.texture == texture then
					playClothingRemoveAnim(data.name, metadata)
					ClearPedProp(cache.ped, metadata.prop)
					if slotId then
						TriggerServerEvent('ox_inventory:saveClothingSlot', slotId, nil)
					end
					saveClothingAppearance()
					return
				end

				SetPedPropIndex(cache.ped, metadata.prop, metadata.drawable, metadata.texture, false);
			elseif metadata.component then
				local drawable = GetPedDrawableVariation(cache.ped, metadata.component)
				local texture = GetPedTextureVariation(cache.ped, metadata.component)

				if metadata.drawable == drawable and metadata.texture == texture then
					return
				end

				SetPedComponentVariation(cache.ped, metadata.component, metadata.drawable, metadata.texture, 0);
			end
			
			if slotId then
				TriggerServerEvent('ox_inventory:saveClothingSlot', slotId, data)
			end
			
			-- For rcore_clothing, we need to wait a bit longer for the ped variation to be set before saving
			if system == 'rcore_clothing' then
				SetTimeout(200, function()
					saveClothingAppearance()
				end)
			else
				saveClothingAppearance()
			end
		end
	end)
end

Item('clothing', clothingHandler)

local clothingItems = {
	'mask', 'hat', 'tshirt', 'torso', 'jacket', 'bulletproof', 'bodyarmor',
	'pants', 'shoes', 'glasses', 'earrings', 'chain', 'gloves', 'watch',
	'bag', 'bracelet'
}

for _, itemName in ipairs(clothingItems) do
	Item(itemName, clothingHandler)
end

local outfitComponentToItem = {
	[1] = 'mask',
	[3] = 'gloves',
	[4] = 'pants',
	[5] = 'bag',
	[6] = 'shoes',
	[7] = 'chain',
	[8] = 'tshirt',
	[9] = 'bulletproof',
	[11] = 'torso'
}

local outfitPropToItem = {
	[0] = 'hat',
	[1] = 'glasses',
	[2] = 'earrings',
	[6] = 'watch',
	[7] = 'bracelet'
}

local function outfitDebug(fmt, ...)
	return
end

local function getOutfitDataFromMetadata(metadata)
	if not metadata or type(metadata) ~= 'table' then return nil end

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
		if candidate then
			if type(candidate) == 'string' then
				local ok, decoded = pcall(json.decode, candidate)
				if ok and type(decoded) == 'table' then
					candidate = decoded
				else
					candidate = nil
				end
			end
			if type(candidate) == 'table' then
				if candidate.components or candidate.props then
					return candidate
				end
				if candidate['pants'] or candidate['arms'] or candidate['t-shirt'] or candidate['torso2'] or candidate['mask'] or candidate['hat'] or candidate['glass'] or candidate['ear'] then
					return candidate
				end
			end
		end
	end

	return nil
end

local function applyOutfitComponent(component, isFlashback)
	if type(component) ~= 'table' then return end
	local componentId = component.component_id or component.component
	local drawable = component.drawable
	if componentId == nil or drawable == nil then return end
	if drawable < 0 then return end
	local texture = component.texture or 0

	local itemName = outfitComponentToItem[componentId]
	if not itemName then return end

	outfitDebug('apply component: compId=%s drawable=%s texture=%s item=%s', tostring(componentId), tostring(drawable), tostring(texture), tostring(itemName))

	if not IsPedComponentVariationValid(cache.ped, componentId, drawable, texture) then
		return
	end

	SetPedComponentVariation(cache.ped, componentId, drawable, texture, 0)

	local slotId = getClothingSlotForItem(itemName, isFlashback)
	if not slotId then return end

	outfitDebug('apply component -> slot=%s isFlashback=%s', tostring(slotId), tostring(isFlashback))

	local metadata = {
		component = componentId,
		drawable = drawable,
		texture = texture
	}

	TriggerServerEvent('ox_inventory:saveClothingSlot', slotId, {
		name = itemName,
		count = 1,
		metadata = metadata
	})
end

local function applyOutfitProp(prop, isFlashback)
	if type(prop) ~= 'table' then return end
	local propId = prop.prop_id or prop.prop
	local drawable = prop.drawable
	if propId == nil or drawable == nil then return end
	local texture = prop.texture or 0

	local itemName = outfitPropToItem[propId]
	local slotId = itemName and getClothingSlotForItem(itemName, isFlashback) or nil

	outfitDebug('apply prop: propId=%s drawable=%s texture=%s item=%s', tostring(propId), tostring(drawable), tostring(texture), tostring(itemName))

	if drawable < 0 then
		ClearPedProp(cache.ped, propId)
		if slotId then
			TriggerServerEvent('ox_inventory:saveClothingSlot', slotId, nil)
		end
		return
	end

	SetPedPropIndex(cache.ped, propId, drawable, texture, false)
	if not itemName or not slotId then return end

	outfitDebug('apply prop -> slot=%s isFlashback=%s', tostring(slotId), tostring(isFlashback))

	local metadata = {
		prop = propId,
		drawable = drawable,
		texture = texture
	}

	TriggerServerEvent('ox_inventory:saveClothingSlot', slotId, {
		name = itemName,
		count = 1,
		metadata = metadata
	})
end

Item('outfit', function()
	return
end)

-- Backpack handler for dynamic backpacks from Config.BackpackWeights
local CLOTHING_SLOT_OFFSET = 69
local function slotNum(n) return n + CLOTHING_SLOT_OFFSET end

local function backpackHandler(data, slot)
	if not Config.BackpackWeights then return end
	
	local backpackConfig = Config.BackpackWeights[data.name]
	if not backpackConfig then return end
	
	-- Build metadata from config based on player sex
	local drawable = PlayerData.sex == 'm' and backpackConfig.male or backpackConfig.female
	local metadata = {
		drawable = drawable,
		texture = backpackConfig.texture,
		component = backpackConfig.component
	}
	
	-- Validate component
	if not IsPedComponentVariationValid(cache.ped, metadata.component, metadata.drawable, metadata.texture) then
		return
	end
	
	ox_inventory:useItem(data, function(data)
		if data then
			local oldDrawable = GetPedDrawableVariation(cache.ped, metadata.component)
			local oldTexture = GetPedTextureVariation(cache.ped, metadata.component)
			local isFlashback = getInventoryStyle() == 'flashback'
			local slotId = isFlashback and 79 or slotNum(12)  -- Slot 79 en flashback (bags), slot 81 en mode normal
			
			if metadata.drawable == oldDrawable and metadata.texture == oldTexture then
				TriggerServerEvent('ox_inventory:saveClothingSlot', slotId, nil)
				saveClothingAppearance()
				return
			end
			
			SetPedComponentVariation(cache.ped, metadata.component, metadata.drawable, metadata.texture, 0)
			TriggerServerEvent('ox_inventory:saveClothingSlot', slotId, data)
			saveClothingAppearance()
		end
	end)
end

-- Dynamically register all backpacks from Config.BackpackWeights
if Config and Config.BackpackWeights then
	for backpackName, _ in pairs(Config.BackpackWeights) do
		Item(backpackName, backpackHandler)
	end
end

-----------------------------------------------------------------------------------------------

local animations = require 'data.animations'

local function useConsumable(itemName, animType, propType, hunger, thirst)
	Item(itemName, function(data)
		local ped = cache.ped
		local animData = animations.anim[animType]
		local propData = animations.prop[propType]
		
		if animData then
			lib.requestAnimDict(animData.dict)
			TaskPlayAnim(ped, animData.dict, animData.clip, 8.0, 8.0, -1, 49, 0, false, false, false)
		end
		
		local prop = nil
		if propData then
			local model = propData.model
			if type(model) == 'string' then
				model = joaat(model)
			end
			if type(model) == 'number' and IsModelInCdimage(model) and IsModelValid(model) then
				lib.requestModel(model)
				prop = CreateObject(model, 0, 0, 0, true, true, true)
				AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, 60309), propData.pos.x, propData.pos.y, propData.pos.z, propData.rot.x, propData.rot.y, propData.rot.z, true, true, false, true, 1, true)
			end
		end
		
		Wait(3000)
		
		if prop then
			DeleteObject(prop)
		end
		
		ClearPedTasks(ped)
		TriggerServerEvent('ox_inventory:removeConsumable', data.name, data.slot, hunger, thirst)
	end)
end

useConsumable('water', 'drinking', 'water_bottle', nil, 350000)
useConsumable('water_bottle', 'drinking', 'water_bottle', nil, 350000)
useConsumable('bread', 'eating', 'burger', 200000, nil)
useConsumable('burger', 'eating', 'burger', 300000, nil)
useConsumable('sandwich', 'eating', 'sandwich', 250000, nil)
useConsumable('cola', 'drinking', 'ecola', nil, 200000)
useConsumable('coffee', 'drinking_coffee', 'coffee', nil, 150000)
useConsumable('beer', 'drinking_beer', 'beer', nil, 180000)
useConsumable('wine', 'drinking', 'wine', nil, 200000)
useConsumable('champagne', 'drinking', 'champagne', nil, 200000)
useConsumable('whisky', 'drinking', 'whisky', nil, 180000)
useConsumable('vodka', 'drinking', 'bottle', nil, 180000)
useConsumable('tequila', 'drinking', 'bottle', nil, 180000)
useConsumable('rhum', 'drinking', 'bottle', nil, 180000)
useConsumable('alcool', 'drinking', 'bottle', nil, 180000)
useConsumable('donut', 'eating', 'donut', 150000, nil)
useConsumable('pizza', 'eating', 'pizza', 300000, nil)
useConsumable('hotdog', 'eating', 'hotdog', 250000, nil)
useConsumable('chips', 'eating', 'chips', 100000, nil)
useConsumable('taco', 'eating', 'taco', 220000, nil)
useConsumable('cupcake', 'eating', 'donut', 120000, nil)
useConsumable('chocolate', 'eating', 'burger', 100000, nil)
useConsumable('icecream', 'eating', 'burger', 130000, nil)
useConsumable('milk', 'drinking', 'bottle', nil, 200000)
useConsumable('juice', 'drinking', 'bottle', nil, 180000)
useConsumable('icetea', 'drinking', 'bottle', nil, 180000)
useConsumable('energydrink', 'drinking', 'ecola', nil, 150000)
useConsumable('lemonade', 'drinking', 'bottle', nil, 180000)
useConsumable('soda', 'drinking', 'ecola', nil, 150000)
useConsumable('sprunk', 'drinking', 'sprunk', nil, 150000)
useConsumable('tea', 'drinking_coffee', 'coffee', nil, 150000)
useConsumable('apple', 'eating', 'burger', 100000, nil)
useConsumable('banana', 'eating', 'burger', 100000, nil)
useConsumable('orange', 'eating', 'burger', 100000, nil)
useConsumable('peach', 'eating', 'burger', 100000, nil)
useConsumable('grape', 'eating', 'burger', 80000, nil)
useConsumable('strawberry', 'eating', 'burger', 80000, nil)
useConsumable('watermelon', 'eating', 'burger', 150000, nil)
useConsumable('steak', 'eating', 'burger', 350000, nil)
useConsumable('chicken', 'eating', 'burger', 300000, nil)
useConsumable('fish', 'eating', 'burger', 280000, nil)
useConsumable('salad', 'eating', 'burger', 180000, nil)
useConsumable('soup', 'eating', 'burger', 200000, nil)
useConsumable('pasta', 'eating', 'burger', 320000, nil)
useConsumable('rice', 'eating', 'burger', 250000, nil)
useConsumable('fries', 'eating', 'chips', 180000, nil)
useConsumable('nuggets', 'eating', 'burger', 220000, nil)
useConsumable('kebab', 'eating', 'burger', 320000, nil)
useConsumable('burrito', 'eating', 'taco', 300000, nil)
useConsumable('sushi', 'eating', 'burger', 280000, nil)
useConsumable('ramen', 'eating', 'burger', 300000, nil)
useConsumable('croissant', 'eating', 'burger', 180000, nil)
useConsumable('baguette', 'eating', 'burger', 220000, nil)
useConsumable('muffin', 'eating', 'donut', 150000, nil)
useConsumable('cookie', 'eating', 'donut', 100000, nil)
useConsumable('cake', 'eating', 'burger', 200000, nil)
useConsumable('pie', 'eating', 'burger', 220000, nil)
useConsumable('pancake', 'eating', 'burger', 200000, nil)
useConsumable('waffle', 'eating', 'burger', 200000, nil)
useConsumable('cheese', 'eating', 'burger', 150000, nil)
useConsumable('ham', 'eating', 'burger', 180000, nil)
useConsumable('bacon', 'eating', 'burger', 160000, nil)
useConsumable('egg', 'eating', 'burger', 120000, nil)
useConsumable('yogurt', 'eating', 'burger', 100000, nil)
useConsumable('cereals', 'eating', 'burger', 180000, nil)
useConsumable('popcorn', 'eating', 'chips', 100000, nil)
useConsumable('pretzel', 'eating', 'burger', 120000, nil)
useConsumable('nachos', 'eating', 'chips', 150000, nil)
useConsumable('wrap', 'eating', 'taco', 280000, nil)
useConsumable('pita', 'eating', 'burger', 240000, nil)
useConsumable('3ballsicecream', 'eating', 'burger', 180000, nil)
useConsumable('911', 'eating', 'pizza', 320000, nil)
useConsumable('4fromage', 'eating', 'pizza', 320000, nil)
useConsumable('abricot', 'eating', 'burger', 100000, nil)
useConsumable('aguavalencia', 'drinking', 'wine', nil, 200000)
useConsumable('accras_crevettes', 'eating', 'burger', 220000, nil)
useConsumable('apperitif', 'drinking', 'whisky', nil, 180000)
useConsumable('adios', 'drinking_beer', 'beer', nil, 180000)
useConsumable('ananas', 'eating', 'burger', 150000, nil)
useConsumable('avocado', 'eating', 'burger', 120000, nil)
useConsumable('b52', 'drinking', 'whisky', nil, 150000)
useConsumable('baguette', 'eating', 'burger', 220000, nil)
useConsumable('banane', 'eating', 'burger', 100000, nil)
useConsumable('banana', 'eating', 'burger', 100000, nil)
useConsumable('bananes_plantains', 'eating', 'burger', 100000, nil)
useConsumable('baosucre', 'eating', 'burger', 150000, nil)
useConsumable('bar', 'eating', 'donut', 100000, nil)
useConsumable('barbamilk', 'drinking', 'bottle', nil, 200000)
useConsumable('barbie', 'drinking', 'wine', nil, 200000)
useConsumable('barbeapapa', 'eating', 'burger', 120000, nil)
useConsumable('barrecereale', 'eating', 'burger', 130000, nil)
useConsumable('batonspoulet_hornys', 'eating', 'burger', 240000, nil)
useConsumable('bayviewbeer', 'drinking_beer', 'beer', nil, 180000)
useConsumable('beef', 'eating', 'burger', 350000, nil)
useConsumable('ambree', 'drinking_beer', 'beer', nil, 180000)
useConsumable('bieresorciere', 'drinking_beer', 'beer', nil, 180000)
useConsumable('beignet', 'eating', 'donut', 140000, nil)
useConsumable('betterave', 'eating', 'burger', 90000, nil)
useConsumable('ben&jerrys', 'eating', 'burger', 180000, nil)
useConsumable('biscuit', 'eating', 'donut', 100000, nil)
useConsumable('biscuitbaton', 'eating', 'donut', 100000, nil)
useConsumable('biscuitchat', 'eating', 'donut', 100000, nil)
useConsumable('biscuithi', 'eating', 'donut', 100000, nil)
useConsumable('biscuitlapin', 'eating', 'donut', 100000, nil)
useConsumable('black_burger', 'eating', 'burger', 300000, nil)
useConsumable('blancdoeuf', 'eating', 'burger', 80000, nil)
useConsumable('bleederburger', 'eating', 'burger', 300000, nil)
useConsumable('blonde', 'drinking_beer', 'beer', nil, 180000)
useConsumable('bloodymary', 'drinking', 'wine', nil, 200000)
useConsumable('blue-mamas', 'drinking', 'wine', nil, 200000)
useConsumable('bluelagoon', 'drinking', 'wine', nil, 200000)
useConsumable('bluehawaiian', 'drinking', 'wine', nil, 200000)
useConsumable('bluedevil', 'drinking', 'wine', nil, 200000)
useConsumable('boeufseche', 'eating', 'burger', 280000, nil)
useConsumable('bokit_bocane', 'eating', 'sandwich', 260000, nil)
useConsumable('bokit_morue', 'eating', 'sandwich', 260000, nil)
useConsumable('bokit_poulet', 'eating', 'sandwich', 260000, nil)
useConsumable('bonbon', 'eating', 'burger', 80000, nil)
useConsumable('bonbonenfleur', 'eating', 'burger', 80000, nil)
useConsumable('bouteillechampagne', 'drinking', 'champagne', nil, 300000)
useConsumable('bouteillebordeaux', 'drinking', 'wine', nil, 300000)
useConsumable('bretzel', 'eating', 'donut', 120000, nil)
useConsumable('brune', 'drinking_beer', 'beer', nil, 180000)
useConsumable('bssoda', 'drinking', 'ecola', nil, 150000)
useConsumable('bubbletea', 'drinking', 'bottle', nil, 180000)
useConsumable('bubbleteauwu', 'drinking', 'bottle', nil, 180000)
useConsumable('bucket', 'eating', 'burger', 350000, nil)
useConsumable('burger_earth', 'eating', 'burger', 300000, nil)
useConsumable('burger_uranus', 'eating', 'burger', 300000, nil)
useConsumable('burgerpoulet_hornys', 'eating', 'burger', 280000, nil)
useConsumable('burrata', 'eating', 'burger', 150000, nil)
useConsumable('butter', 'eating', 'burger', 100000, nil)
useConsumable('cacahuetes', 'eating', 'chips', 90000, nil)
useConsumable('cacahuetescmrd', 'eating', 'chips', 90000, nil)
useConsumable('cafeaulait', 'drinking_coffee', 'coffee', nil, 150000)
useConsumable('cafefrappe', 'drinking_coffee', 'coffee', nil, 150000)
useConsumable('cafepraline', 'drinking_coffee', 'coffee', nil, 150000)
useConsumable('calamar', 'eating', 'burger', 200000, nil)
useConsumable('calypso', 'drinking', 'wine', nil, 200000)
useConsumable('camarade', 'drinking_beer', 'beer', nil, 180000)
useConsumable('cappuccino', 'drinking_coffee', 'coffee', nil, 150000)
useConsumable('caprisun', 'drinking', 'bottle', nil, 150000)
useConsumable('caramel', 'eating', 'burger', 90000, nil)
useConsumable('caramelmacchiato', 'drinking_coffee', 'coffee', nil, 150000)
useConsumable('carpe', 'eating', 'burger', 220000, nil)
useConsumable('catpat', 'eating', 'burger', 180000, nil)
useConsumable('catnuts', 'eating', 'chips', 90000, nil)
useConsumable('caviar', 'eating', 'burger', 250000, nil)
useConsumable('cesar', 'eating', 'burger', 240000, nil)
useConsumable('cereale', 'eating', 'burger', 180000, nil)
useConsumable('champ', 'drinking', 'champagne', nil, 200000)
useConsumable('cannelle', 'eating', 'burger', 50000, nil)
useConsumable('canneberge', 'eating', 'burger', 80000, nil)
useConsumable('chantilly', 'drinking', 'bottle', nil, 100000)
useConsumable('chatgourmand', 'eating', 'burger', 150000, nil)
useConsumable('chatmallow', 'eating', 'burger', 100000, nil)
useConsumable('cheddar', 'eating', 'burger', 150000, nil)
useConsumable('cheesecake', 'eating', 'burger', 200000, nil)
useConsumable('cheesestick', 'eating', 'burger', 130000, nil)
useConsumable('chevre', 'eating', 'burger', 140000, nil)
useConsumable('chickenwrap', 'eating', 'sandwich', 280000, nil)
useConsumable('chipscmrd', 'eating', 'chips', 100000, nil)
useConsumable('choco', 'eating', 'donut', 100000, nil)
useConsumable('chocolatchaud', 'drinking_coffee', 'coffee', nil, 150000)
useConsumable('chocolatecake', 'eating', 'burger', 220000, nil)
useConsumable('chocolateicecream', 'eating', 'burger', 180000, nil)
useConsumable('chocolatviennois', 'drinking_coffee', 'coffee', nil, 150000)
useConsumable('chocoguimauve', 'eating', 'burger', 110000, nil)
useConsumable('chorizo', 'eating', 'burger', 180000, nil)
useConsumable('chou', 'eating', 'burger', 90000, nil)
useConsumable('churros', 'eating', 'donut', 140000, nil)
useConsumable('ciboulette', 'eating', 'burger', 50000, nil)
useConsumable('cinnamonrolls', 'eating', 'donut', 160000, nil)
useConsumable('cocktail', 'drinking', 'wine', nil, 200000)
useConsumable('cofeecup', 'drinking_coffee', 'coffee', nil, 150000)
useConsumable('coffee_hornys', 'drinking_coffee', 'coffee', nil, 150000)
useConsumable('coffeelate', 'drinking_coffee', 'coffee', nil, 150000)
useConsumable('cognac', 'drinking', 'whisky', nil, 200000)
useConsumable('colombo_poulet', 'eating', 'burger', 320000, nil)
useConsumable('confettiscomestible', 'eating', 'burger', 80000, nil)
useConsumable('coolgranny', 'drinking', 'wine', nil, 200000)
useConsumable('coriandre', 'eating', 'burger', 50000, nil)
useConsumable('cornetdeglace', 'eating', 'burger', 160000, nil)
useConsumable('cornet', 'eating', 'burger', 160000, nil)
useConsumable('cornichon', 'eating', 'burger', 70000, nil)
useConsumable('coyote', 'eating', 'burger', 280000, nil)
useConsumable('crabe', 'eating', 'burger', 220000, nil)
useConsumable('crackers', 'eating', 'donut', 100000, nil)
useConsumable('cremebrulee', 'eating', 'burger', 180000, nil)
useConsumable('crepe', 'eating', 'burger', 190000, nil)
useConsumable('crevettes', 'eating', 'burger', 200000, nil)
useConsumable('crostini', 'eating', 'burger', 140000, nil)
useConsumable('cucumber', 'eating', 'burger', 80000, nil)
useConsumable('diabolored', 'drinking', 'bottle', nil, 150000)
useConsumable('donnut', 'eating', 'donut', 140000, nil)
useConsumable('donut_hornys', 'eating', 'donut', 140000, nil)
useConsumable('donutc', 'eating', 'donut', 140000, nil)
useConsumable('donutsp', 'eating', 'donut', 140000, nil)
useConsumable('donutm', 'eating', 'donut', 140000, nil)
useConsumable('donutvermi', 'eating', 'donut', 140000, nil)
useConsumable('donutv', 'eating', 'donut', 140000, nil)
useConsumable('donutf', 'eating', 'donut', 140000, nil)
useConsumable('donutcaramel', 'eating', 'donut', 140000, nil)
useConsumable('donutcitron', 'eating', 'donut', 140000, nil)
useConsumable('donutn', 'eating', 'donut', 140000, nil)
useConsumable('doubleshotburger', 'eating', 'burger', 330000, nil)
useConsumable('duffbeer', 'drinking_beer', 'beer', nil, 180000)
useConsumable('eau', 'drinking', 'water_bottle', nil, 350000)
useConsumable('eaumineral', 'drinking', 'water_bottle', nil, 350000)
useConsumable('eaupetillante', 'drinking', 'water_bottle', nil, 350000)
useConsumable('echalotte', 'eating', 'burger', 50000, nil)
useConsumable('ecola', 'drinking', 'ecola', nil, 150000)
useConsumable('e-cola', 'drinking', 'ecola', nil, 150000)
useConsumable('eggs_muffin', 'eating', 'burger', 200000, nil)
useConsumable('elmordjene', 'drinking', 'wine', nil, 200000)
useConsumable('entrecote', 'eating', 'burger', 350000, nil)
useConsumable('escalope', 'eating', 'burger', 280000, nil)
useConsumable('esturgeon', 'eating', 'burger', 240000, nil)
useConsumable('esturgeons', 'eating', 'burger', 240000, nil)
useConsumable('etepurple', 'drinking', 'wine', nil, 200000)
useConsumable('expresso', 'drinking_coffee', 'coffee', nil, 150000)
useConsumable('fajitas', 'eating', 'burger', 280000, nil)
useConsumable('fishbowl', 'drinking', 'wine', nil, 200000)
useConsumable('fishburger', 'eating', 'burger', 280000, nil)
useConsumable('flamantrose', 'drinking', 'wine', nil, 200000)
useConsumable('foiegras', 'eating', 'burger', 250000, nil)
useConsumable('fgras', 'eating', 'burger', 250000, nil)
useConsumable('fondantchocolat', 'eating', 'burger', 220000, nil)
useConsumable('fraise', 'eating', 'burger', 80000, nil)
useConsumable('framboise', 'eating', 'burger', 80000, nil)
useConsumable('french75', 'drinking', 'wine', nil, 200000)
useConsumable('frenchkiss', 'drinking', 'wine', nil, 200000)
useConsumable('frenchmule', 'drinking', 'wine', nil, 200000)
useConsumable('friesbox', 'eating', 'chips', 180000, nil)
useConsumable('frites_hornys', 'eating', 'chips', 180000, nil)
useConsumable('frites_zigzag', 'eating', 'chips', 180000, nil)
useConsumable('fromage', 'eating', 'burger', 150000, nil)
useConsumable('fromageblanc', 'eating', 'burger', 150000, nil)
useConsumable('fromagesdes', 'eating', 'burger', 140000, nil)
useConsumable('galette', 'eating', 'burger', 200000, nil)
useConsumable('gaspachocc', 'drinking', 'bottle', nil, 180000)
useConsumable('gauffre', 'eating', 'burger', 190000, nil)
useConsumable('gin', 'drinking', 'bottle', nil, 180000)
useConsumable('gingerflower', 'drinking', 'wine', nil, 200000)
useConsumable('gingembre', 'eating', 'burger', 50000, nil)
useConsumable('glace', 'eating', 'burger', 160000, nil)
useConsumable('glace_coco', 'eating', 'burger', 160000, nil)
useConsumable('glace_framboise', 'eating', 'burger', 160000, nil)
useConsumable('glace_mangue', 'eating', 'burger', 160000, nil)
useConsumable('glacechocolat', 'eating', 'burger', 160000, nil)
useConsumable('glaceitalienne', 'eating', 'burger', 160000, nil)
useConsumable('glacevanille', 'eating', 'burger', 160000, nil)
useConsumable('gncluckinbucket', 'eating', 'burger', 350000, nil)
useConsumable('gncluckinburg', 'eating', 'burger', 300000, nil)
useConsumable('gncluckincup', 'drinking', 'ecola', nil, 150000)
useConsumable('gncluckinfowl', 'eating', 'burger', 280000, nil)
useConsumable('gncluckinfries', 'eating', 'chips', 180000, nil)
useConsumable('gncluckinkids', 'eating', 'burger', 250000, nil)
useConsumable('gncluckinrings', 'eating', 'chips', 160000, nil)
useConsumable('gncluckinsalad', 'eating', 'burger', 180000, nil)
useConsumable('gncluckinsoup', 'eating', 'burger', 200000, nil)
useConsumable('goatcheesewrap', 'eating', 'sandwich', 270000, nil)
useConsumable('goyave', 'eating', 'burger', 100000, nil)
useConsumable('granita', 'drinking', 'bottle', nil, 150000)
useConsumable('granita_upnatom', 'drinking', 'bottle', nil, 150000)
useConsumable('greenlemon', 'drinking', 'wine', nil, 200000)
useConsumable('gum', 'eating', 'burger', 60000, nil)
useConsumable('huitres', 'eating', 'burger', 200000, nil)
useConsumable('hydromel', 'drinking', 'bottle', nil, 200000)
useConsumable('ice_cup', 'eating', 'burger', 140000, nil)
useConsumable('icecoffee', 'drinking_coffee', 'coffee', nil, 150000)
useConsumable('icecoffeeuwu', 'drinking_coffee', 'coffee', nil, 150000)
useConsumable('icecreamcat', 'eating', 'burger', 160000, nil)
useConsumable('imperatrice', 'drinking', 'wine', nil, 200000)
useConsumable('irishc', 'drinking_coffee', 'coffee', nil, 150000)
useConsumable('irishcoffee', 'drinking_coffee', 'coffee', nil, 150000)
useConsumable('jaeger', 'drinking', 'bottle', nil, 180000)
useConsumable('jaggerbomb', 'drinking', 'wine', nil, 200000)
useConsumable('jambon', 'eating', 'burger', 180000, nil)
useConsumable('jambonbayonne', 'eating', 'burger', 200000, nil)
useConsumable('jaunedoeuf', 'eating', 'burger', 80000, nil)
useConsumable('jet27', 'drinking', 'wine', nil, 200000)
useConsumable('juicep', 'drinking', 'bottle', nil, 180000)
useConsumable('juiceg', 'drinking', 'bottle', nil, 180000)
useConsumable('jusdananas', 'drinking', 'bottle', nil, 180000)
useConsumable('jusdecanne', 'drinking', 'bottle', nil, 180000)
useConsumable('jusdecitron', 'drinking', 'bottle', nil, 160000)
useConsumable('jusdefruits', 'drinking', 'bottle', nil, 180000)
useConsumable('jusdekiwi', 'drinking', 'bottle', nil, 180000)
useConsumable('jusdepomme', 'drinking', 'bottle', nil, 180000)
useConsumable('jusderaisin', 'drinking', 'bottle', nil, 180000)
useConsumable('jusdorange', 'drinking', 'bottle', nil, 180000)
useConsumable('kiwi', 'eating', 'burger', 100000, nil)
useConsumable('lailaitchaud', 'drinking_coffee', 'coffee', nil, 150000)
useConsumable('laitchoco', 'drinking', 'bottle', nil, 200000)
useConsumable('laitentier', 'drinking', 'bottle', nil, 200000)
useConsumable('laitlaitchaud', 'drinking_coffee', 'coffee', nil, 150000)
useConsumable('lapinut', 'eating', 'burger', 160000, nil)
useConsumable('latte', 'drinking_coffee', 'coffee', nil, 150000)
useConsumable('lattematcha', 'drinking_coffee', 'coffee', nil, 150000)
useConsumable('lemon', 'eating', 'burger', 70000, nil)
useConsumable('lime', 'eating', 'burger', 70000, nil)
useConsumable('limonade', 'drinking', 'bottle', nil, 180000)
useConsumable('limonaderose', 'drinking', 'bottle', nil, 180000)
useConsumable('liqueurdeframbroise', 'drinking', 'bottle', nil, 180000)
useConsumable('liqueurdepeche', 'drinking', 'bottle', nil, 180000)
useConsumable('liqueurfleurdesureau', 'drinking', 'bottle', nil, 180000)
useConsumable('litchi', 'eating', 'burger', 90000, nil)
useConsumable('lollipop', 'eating', 'burger', 80000, nil)
useConsumable('mac&cheese', 'eating', 'burger', 280000, nil)
useConsumable('magnumicecream', 'eating', 'burger', 180000, nil)
useConsumable('magret', 'eating', 'burger', 350000, nil)
useConsumable('magretdecanard', 'eating', 'burger', 350000, nil)
useConsumable('mais', 'eating', 'burger', 120000, nil)
useConsumable('maki', 'eating', 'burger', 220000, nil)
useConsumable('mangue', 'eating', 'burger', 110000, nil)
useConsumable('margarita', 'drinking', 'wine', nil, 200000)
useConsumable('marmelade', 'eating', 'burger', 130000, nil)
useConsumable('mascarpone', 'eating', 'burger', 150000, nil)
useConsumable('matcha', 'drinking_coffee', 'coffee', nil, 150000)
useConsumable('maxiplanche', 'eating', 'chips', 200000, nil)
useConsumable('melto', 'drinking', 'bottle', nil, 180000)
useConsumable('menthe', 'eating', 'burger', 50000, nil)
useConsumable('merlan', 'eating', 'burger', 220000, nil)
useConsumable('meteoriteicecream', 'eating', 'burger', 180000, nil)
useConsumable('miel', 'eating', 'burger', 120000, nil)
useConsumable('milkshake', 'drinking', 'bottle', nil, 200000)
useConsumable('milkshakefraise', 'drinking', 'bottle', nil, 200000)
useConsumable('milkshake_hornys', 'drinking', 'bottle', nil, 200000)
useConsumable('mint', 'eating', 'burger', 50000, nil)
useConsumable('misterfreeze', 'eating', 'burger', 150000, nil)
useConsumable('mochi', 'eating', 'burger', 140000, nil)
useConsumable('mochiuwu', 'eating', 'burger', 140000, nil)
useConsumable('mojito', 'drinking', 'wine', nil, 200000)
useConsumable('moulefrite', 'eating', 'burger', 320000, nil)
useConsumable('moules', 'eating', 'burger', 220000, nil)
useConsumable('moulesfrites', 'eating', 'burger', 320000, nil)
useConsumable('mozza', 'eating', 'burger', 150000, nil)
useConsumable('mozzasticks', 'eating', 'chips', 180000, nil)
useConsumable('mozzasticks_rex', 'eating', 'chips', 180000, nil)
useConsumable('muffinchoco', 'eating', 'burger', 160000, nil)
useConsumable('murene', 'eating', 'burger', 220000, nil)
useConsumable('myrtille', 'eating', 'burger', 80000, nil)
useConsumable('nemb', 'eating', 'burger', 240000, nil)
useConsumable('nemp', 'eating', 'burger', 240000, nil)
useConsumable('nougat', 'eating', 'burger', 110000, nil)
useConsumable('nouille', 'eating', 'burger', 250000, nil)
useConsumable('noixmuscade', 'eating', 'chips', 70000, nil)
useConsumable('oeufsbacon', 'eating', 'burger', 250000, nil)
useConsumable('oeufsdecabillaud', 'eating', 'burger', 200000, nil)
useConsumable('oignon', 'eating', 'burger', 70000, nil)
useConsumable('olive', 'eating', 'burger', 70000, nil)
useConsumable('onion_rings', 'eating', 'chips', 160000, nil)
useConsumable('orangotangicecream', 'eating', 'burger', 180000, nil)
useConsumable('orc_v', 'eating', 'burger', 320000, nil)
useConsumable('painahotdog', 'eating', 'burger', 150000, nil)
useConsumable('painburger', 'eating', 'burger', 150000, nil)
useConsumable('paindemie', 'eating', 'burger', 150000, nil)
useConsumable('paillettescomestible', 'eating', 'burger', 80000, nil)
useConsumable('pannacotta', 'eating', 'burger', 190000, nil)
useConsumable('panini', 'eating', 'sandwich', 270000, nil)
useConsumable('pasteque', 'eating', 'burger', 150000, nil)
useConsumable('patate', 'eating', 'burger', 110000, nil)
useConsumable('persil', 'eating', 'burger', 50000, nil)
useConsumable('pignonpoulet_hornys', 'eating', 'burger', 240000, nil)
useConsumable('pilon', 'eating', 'burger', 220000, nil)
useConsumable('pinacolada', 'drinking', 'wine', nil, 200000)
useConsumable('pissedane', 'drinking', 'water_bottle', nil, 150000)
useConsumable('pistacheicecream', 'eating', 'burger', 180000, nil)
useConsumable('pizza-7945', 'eating', 'pizza', 320000, nil)
useConsumable('pizza4fromage', 'eating', 'pizza', 320000, nil)
useConsumable('pizzaburata', 'eating', 'pizza', 320000, nil)
useConsumable('pizzachevre', 'eating', 'pizza', 320000, nil)
useConsumable('pizzamarghe', 'eating', 'pizza', 320000, nil)
useConsumable('pizzanutella', 'eating', 'pizza', 280000, nil)
useConsumable('plateaudecharcuterie', 'eating', 'burger', 300000, nil)
useConsumable('planchesaucisson', 'eating', 'burger', 250000, nil)
useConsumable('pocky', 'eating', 'burger', 120000, nil)
useConsumable('poissonpane', 'eating', 'burger', 260000, nil)
useConsumable('poissonnapoleon', 'eating', 'burger', 230000, nil)
useConsumable('poissonscie', 'eating', 'burger', 230000, nil)
useConsumable('poivron', 'eating', 'burger', 80000, nil)
useConsumable('pomme', 'eating', 'burger', 100000, nil)
useConsumable('pommeamour', 'eating', 'burger', 120000, nil)
useConsumable('porto', 'drinking', 'wine', nil, 200000)
useConsumable('poulet', 'eating', 'burger', 300000, nil)
useConsumable('pouletpanefrit', 'eating', 'burger', 300000, nil)
useConsumable('poutine', 'eating', 'burger', 320000, nil)
useConsumable('pricklyburger', 'eating', 'burger', 300000, nil)
useConsumable('pulledpork', 'eating', 'burger', 330000, nil)
useConsumable('pulledpork_rex', 'eating', 'burger', 330000, nil)
useConsumable('punch', 'drinking', 'wine', nil, 200000)
useConsumable('punchdefete', 'drinking', 'wine', nil, 200000)
useConsumable('punch_coco', 'drinking', 'wine', nil, 200000)
useConsumable('punch_planteur', 'drinking', 'wine', nil, 200000)
useConsumable('purplerain', 'drinking', 'wine', nil, 200000)
useConsumable('piment', 'eating', 'burger', 60000, nil)
useConsumable('quesadillas', 'eating', 'burger', 280000, nil)

-----------------------------------------------------------------------------------------------

local function SwapClothingToInventory(outfitItems)
	local clothingInv = Inventories and Inventories.clothing
	if not clothingInv or not clothingInv.items then return end
	
	for slotIndex, item in pairs(clothingInv.items) do
		if item and item.name then
			local shouldSwap = false
			local itemSlot = slotIndex
			
			for _, outfitItem in pairs(outfitItems) do
				local targetSlot = Config.ItemSlotMapping[outfitItem.itemName]
				if targetSlot and targetSlot == itemSlot then
					shouldSwap = true
					break
				end
			end
			
			if shouldSwap then
				TriggerServerEvent('ox_inventory:swapClothingToPlayer', itemSlot)
			end
		end
	end
end

-- Event pour appliquer les dégâts des items périmés
RegisterNetEvent('ox_inventory:client:applyExpiredDamage', function(damage)
	local playerPed = cache.ped
	local currentHealth = GetEntityHealth(playerPed)
	local newHealth = math.max(100, currentHealth - damage)
	
	SetEntityHealth(playerPed, newHealth)
	
	-- Effet visuel d'intoxication
	SetTimecycleModifier('damage')
	SetTimeout(3000, function()
		ClearTimecycleModifier()
	end)
	
	-- Effet de tremblement de caméra
	ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.5)
end)

-----------------------------------------------------------------------------------------------

exports('Items', function(item) return getItem(nil, item) end)
exports('ItemList', function(item) return getItem(nil, item) end)

return Items
