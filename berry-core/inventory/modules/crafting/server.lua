if not lib then return end

local CraftingBenches = {}
local Items = require 'modules.items.server'
local Inventory = require 'modules.inventory.server'

-- Système de crafts persistants
local ActiveCrafts = {}
local finishCraft

local function craftDebug(fmt, ...)
	return
end

local function deliverCraft(source, craftData)
	craftDebug('deliverCraft start src=%s recipe=%s qty=%s', tostring(source), tostring(craftData?.recipe?.name), tostring(craftData?.quantity))
	local success, err = finishCraft(source, craftData)

	if success then
		craftDebug('deliverCraft success src=%s recipe=%s qty=%s', tostring(source), tostring(craftData.recipe.name), tostring(craftData.quantity))
		TriggerClientEvent('ox_inventory:craftFinished', source, craftData.recipe.name, craftData.quantity)
	elseif err then
		craftDebug('deliverCraft failed src=%s recipe=%s err=%s', tostring(source), tostring(craftData?.recipe?.name), tostring(err))
		TriggerClientEvent('ox_inventory:craftFailed', source, err)
	end

	return success, err
end

finishCraft = function(source, craftData)
	craftDebug('finishCraft start src=%s recipe=%s qty=%s', tostring(source), tostring(craftData?.recipe?.name), tostring(craftData?.quantity))
	local left = Inventory(source)
	if not left then 
		craftDebug('finishCraft invalid_inventory src=%s', tostring(source))
		return false, 'invalid_inventory'
	end

	local recipe = craftData.recipe
	local craftedItem = Items(recipe.name)
	if not craftedItem then
		craftDebug('finishCraft invalid_item src=%s recipe=%s', tostring(source), tostring(recipe.name))
		return false, 'invalid_item'
	end

	local craftCount = craftData.craftCount or ((type(recipe.count) == 'number' and recipe.count) or (table.type(recipe.count) == 'array' and math.random(recipe.count[1], recipe.count[2])) or 1)
	local success = Inventory.AddItem(left, craftedItem, craftCount * craftData.quantity, recipe.metadata or {})

	if not success then
		craftDebug('finishCraft failed_add_crafted_item src=%s recipe=%s', tostring(source), tostring(recipe.name))
		if recipe.ingredients then
			for name, needs in pairs(recipe.ingredients) do
				local ingredientCount = needs * craftData.quantity
				if ingredientCount > 0 then
					craftDebug('finishCraft refund ingredient src=%s item=%s count=%s', tostring(source), tostring(name), tostring(ingredientCount))
					Inventory.AddItem(left, name, ingredientCount)
				end
			end
		end

		return false, 'failed_add_crafted_item'
	end

	craftDebug('finishCraft success src=%s recipe=%s craftCount=%s qty=%s', tostring(source), tostring(recipe.name), tostring(craftCount), tostring(craftData.quantity))
	
	return true
end

CreateThread(function()
	while true do
		Wait(1000)
		local currentTime = os.time()
		
		for source, craftData in pairs(ActiveCrafts) do
			if currentTime >= craftData.endTime then
				craftDebug('timer completed src=%s recipe=%s now=%s end=%s', tostring(source), tostring(craftData?.recipe?.name), tostring(currentTime), tostring(craftData.endTime))
				ActiveCrafts[source] = nil
				local ok, err = pcall(deliverCraft, source, craftData)
				if not ok then
					craftDebug('timer deliverCraft runtime error src=%s err=%s', tostring(source), tostring(err))
					TriggerClientEvent('ox_inventory:craftFailed', source, 'craft_failed')
				end
			end
		end
	end
end)

lib.callback.register('ox_inventory:getActiveCraft', function(source)
	local craftData = ActiveCrafts[source]
	if craftData then
		local remaining = craftData.endTime - os.time()
		return {
			recipe = craftData.recipe.name,
			quantity = craftData.quantity,
			timeLeft = remaining,
			totalDuration = craftData.duration
		}
	end
	return nil
end)

---@param id number
---@param data table
local function createCraftingBench(id, data)
	CraftingBenches[id] = {}
	local recipes = data.items

	if recipes then
		for i = 1, #recipes do
			local recipe = recipes[i]
			local item = Items(recipe.name)

			if item then
				recipe.weight = item.weight
				recipe.slot = i
			else
			end

			for ingredient, needs in pairs(recipe.ingredients) do
				if needs < 1 then
					item = Items(ingredient)

					if item and not item.durability then
						item.durability = true
					end
				end
			end
		end

		if shared.target then
			data.points = nil
		else
			data.zones = nil
		end

		CraftingBenches[id] = data
	end
end

local function applyCraftingBenches(benches)
	for benchId in pairs(CraftingBenches) do
		CraftingBenches[benchId] = nil
	end

	for id, data in pairs(benches or {}) do
		createCraftingBench(data.name or id, data)
	end
end

for id, data in pairs(lib.load('data.crafting') or {}) do createCraftingBench(data.name or id, data) end

RegisterNetEvent('ox_inventory:applyCraftingBenches', function(benches)
	if type(source) == 'number' and source > 0 then return end
	if type(benches) ~= 'table' then return end

	applyCraftingBenches(benches)
	TriggerClientEvent('ox_inventory:syncCraftingBenches', -1, CraftingBenches)
end)

---falls back to player coords if zones and points are both nil
---@param source number
---@param bench table
---@param index number
---@return vector3
local function getCraftingCoords(source, bench, index)
	if not bench.zones and not bench.points then
		return GetEntityCoords(GetPlayerPed(source))
	else
		if shared.target then
			return bench.zones and bench.zones[index] and bench.zones[index].coords or GetEntityCoords(GetPlayerPed(source))
		else
			return bench.points and bench.points[index] or GetEntityCoords(GetPlayerPed(source))
		end
	end
end

lib.callback.register('ox_inventory:openCraftingBench', function(source, id, index)
	local left, bench = Inventory(source), CraftingBenches[id]

	if not left then return end

	if bench then
		local groups = bench.groups
		local coords = getCraftingCoords(source, bench, index)

		if not coords then return end

		if groups and not server.hasGroup(left, groups) then return end
		if #(GetEntityCoords(GetPlayerPed(source)) - coords) > 10 then return end

		if left.open and left.open ~= source then
			local inv = Inventory(left.open) --[[@as OxInventory]]

			-- Why would the player inventory open with an invalid target? Can't repro but whatever.
			if inv?.player then
				inv:closeInventory()
			end
		end

		left:openInventory(left)
	end

	return { label = left.label, type = left.type, slots = left.slots, weight = left.weight, maxWeight = left.maxWeight }
end)

local TriggerEventHooks = require 'modules.hooks.server'

lib.callback.register('ox_inventory:craftItem', function(source, id, index, recipeId, quantity)
	craftDebug('craftItem request src=%s bench=%s index=%s recipeId=%s qty=%s', tostring(source), tostring(id), tostring(index), tostring(recipeId), tostring(quantity))
	local left, bench = Inventory(source), CraftingBenches[id]

	if not left then return end

	local existingCraft = ActiveCrafts[source]
	if existingCraft then
		if os.time() >= existingCraft.endTime then
			craftDebug('craftItem existing craft completed before new request src=%s', tostring(source))
			ActiveCrafts[source] = nil
			deliverCraft(source, existingCraft)
		else
			craftDebug('craftItem rejected in progress src=%s recipe=%s', tostring(source), tostring(existingCraft?.recipe?.name))
			return false, locale('ui_craft_in_progress')
		end
	end

	if type(id) ~= 'string' and type(id) ~= 'number' then return end
	if type(index) ~= 'number' or index < 1 then return end
	if type(recipeId) ~= 'number' and type(recipeId) ~= 'string' then
		craftDebug('craftItem invalid recipeId type src=%s type=%s value=%s', tostring(source), type(recipeId), tostring(recipeId))
		return false, 'invalid_recipe'
	end
	quantity = quantity or 1

	if bench then
		local groups = bench.groups
		local coords = getCraftingCoords(source, bench, index)

		if groups and not server.hasGroup(left, groups) then return end
		if #(GetEntityCoords(GetPlayerPed(source)) - coords) > 10 then return end

		local recipe
		local resolvedRecipeId = recipeId

		if type(recipeId) == 'number' then
			recipe = bench.items[recipeId]
		else
			local requestedName = string.upper(recipeId)
			for i = 1, #(bench.items or {}) do
				local candidate = bench.items[i]
				if candidate and candidate.name and string.upper(candidate.name) == requestedName then
					recipe = candidate
					resolvedRecipeId = i
					break
				end
			end
		end

		if not recipe then
			craftDebug('craftItem recipe not found src=%s bench=%s recipeId=%s', tostring(source), tostring(id), tostring(recipeId))
			return false, 'invalid_recipe'
		end

		craftDebug('craftItem resolved recipe src=%s recipeSlot=%s recipeName=%s', tostring(source), tostring(resolvedRecipeId), tostring(recipe.name))

		if recipe then
			local tbl, num = {}, 0

			for name in pairs(recipe.ingredients) do
				num += 1
				tbl[num] = name
			end

			local craftedItem = Items(recipe.name)
			local craftCount = (type(recipe.count) == 'number' and recipe.count) or (table.type(recipe.count) == 'array' and math.random(recipe.count[1], recipe.count[2])) or 1
			if not craftedItem then return false, 'invalid_item' end

			-- Check if player has ingredients
			for name, needs in pairs(recipe.ingredients) do
				if Inventory.GetItemCount(left, name) < needs * quantity then 
					craftDebug('craftItem missing ingredient src=%s item=%s need=%s have=%s', tostring(source), tostring(name), tostring(needs * quantity), tostring(Inventory.GetItemCount(left, name)))
					return false, 'missing_ingredients'
				end
			end

			-- Modified weight calculation
			local newWeight = left.weight
			local items = Inventory.Search(left, 'slots', tbl) or {}
			
			-- First subtract weight of ingredients that will be removed
			for name, needs in pairs(recipe.ingredients) do
				if needs > 0 then
					local item = Items(name)
					if item then
						newWeight -= (item.weight * needs * quantity)
					end
				end
			end

			-- Add weight of crafted item
			newWeight += (craftedItem.weight + ((recipe.metadata and recipe.metadata.weight) or 0)) * craftCount * quantity

			if newWeight > left.maxWeight then return false, 'cannot_carry' end
			craftDebug('craftItem weight check src=%s current=%s projected=%s max=%s', tostring(source), tostring(left.weight), tostring(newWeight), tostring(left.maxWeight))

			if not TriggerEventHooks('craftItem', {
				source = source,
				benchId = id,
				benchIndex = index,
				recipe = recipe,
				toInventory = left.id,
				quantity = quantity,
			}) then return false end

			-- Remove ingredients immediately (reserve inputs), with rollback on partial failure
			local consumedIngredients = {}
			for name, needs in pairs(recipe.ingredients) do
				local ingredientCount = needs * quantity
				if ingredientCount > 0 then
					local removed = Inventory.RemoveItem(left, name, ingredientCount)
					if not removed then
						craftDebug('craftItem failed remove ingredient src=%s item=%s count=%s', tostring(source), tostring(name), tostring(ingredientCount))
						for consumedName, consumedCount in pairs(consumedIngredients) do
							craftDebug('craftItem rollback ingredient src=%s item=%s count=%s', tostring(source), tostring(consumedName), tostring(consumedCount))
							Inventory.AddItem(left, consumedName, consumedCount)
						end
						return false, 'failed_remove_ingredients'
					end

					craftDebug('craftItem removed ingredient src=%s item=%s count=%s', tostring(source), tostring(name), tostring(ingredientCount))

					consumedIngredients[name] = ingredientCount
				end
			end

			-- Démarrer le craft persistant
			local duration = (recipe.duration or 3000) * quantity
			ActiveCrafts[source] = {
				recipe = recipe,
				quantity = quantity,
				craftCount = craftCount,
				duration = duration,
				startTime = os.time(),
				endTime = os.time() + math.ceil(duration / 1000)
			}
			craftDebug('craftItem queued src=%s recipe=%s qty=%s durationMs=%s endAt=%s', tostring(source), tostring(recipe.name), tostring(quantity), tostring(duration), tostring(ActiveCrafts[source].endTime))

			-- Notifier le client pour démarrer l'animation/UI
			TriggerClientEvent('ox_inventory:craftStarted', source, {
				recipe = recipe.name,
				quantity = quantity,
				duration = duration
			})

			return true
		end
	end

	return false
end)

lib.callback.register('ox_inventory:cancelCraft', function(source)
	if ActiveCrafts[source] then
		ActiveCrafts[source] = nil
		return true
	end
	return false
end)

RegisterNetEvent('ox_inventory:recoverCraftedItem', function()
	local src = source
	local craftData = ActiveCrafts[src]

	if not craftData then
		return TriggerClientEvent('esx:showNotification', src, locale('ui_no_craft_in_progress'))
	end

	if os.time() < craftData.endTime then
		return TriggerClientEvent('esx:showNotification', src, locale('ui_craft_in_progress'))
	end

	ActiveCrafts[src] = nil
	deliverCraft(src, craftData)
end)

RegisterNetEvent('ox_inventory:requestCraftingSync', function()
	local src = source
	if not src or src <= 0 then return end

	TriggerClientEvent('ox_inventory:syncCraftingBenches', src, CraftingBenches)
end)
