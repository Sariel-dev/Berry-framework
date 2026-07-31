if not lib then return end

local CraftingBenches = {}
local ActiveBenchEntities = {}
local Items = require 'modules.items.client'
local createBlip = require 'modules.utils.client'.CreateBlip
local Utils = require 'modules.utils.client'
local prompt = {
    options = { icon = 'fa-wrench' },
    message = ('**%s**  \n%s'):format(locale('open_crafting_bench'), locale('interact_prompt', GetControlInstructionalButton(0, 38, true):sub(3)))
}

local function toVector3(value)
	if not value then
		return nil
	end

	if type(value) == 'vector3' then
		return value
	end

	if type(value) == 'table' then
		if value.x and value.y and value.z then
			return vec3(value.x, value.y, value.z)
		end

		if value[1] and value[2] and value[3] then
			return vec3(value[1], value[2], value[3])
		end
	end

	return nil
end

local function removeBenchEntities(id)
	local entities = ActiveBenchEntities[id]
	if not entities then return end

	if entities.points then
		for i = 1, #entities.points do
			local point = entities.points[i]
			if point and point.remove then
				point:remove()
			end
		end
	end

	ActiveBenchEntities[id] = nil
end

---@param id number
---@param data table
local function createCraftingBench(id, data)
	if not data then return end

	removeBenchEntities(id)
	CraftingBenches[id] = {}
	local recipes = data.items

	if recipes then
		data.slots = #recipes

		for i = 1, data.slots do
			local recipe = recipes[i]
			local item = Items[recipe.name]

			if item then
				recipe.weight = item.weight
				recipe.slot = i
			else
			end
		end

		local blip = data.blip

		if blip then
			blip.name = blip.name or ('ox_crafting_%s'):format(data.label and id or 0)
			AddTextEntry(blip.name, data.label or locale('crafting_bench'))
		end

		local pointHandles = {}
		local promptData = {
			options = { icon = 'fa-wrench' },
			message = ('**%s**  \n%s'):format(locale('open_crafting_bench'), locale('interact_prompt', GetControlInstructionalButton(0, 38, true):sub(3)))
		}

		local function addBenchPoint(coords, index, distance, marker)
			if not coords then return end

			local point = lib.points.new({
				coords = coords,
				distance = distance or 16,
				benchid = id,
				index = index,
				inv = 'crafting',
				prompt = promptData,
				marker = marker or client.craftingmarker,
				nearby = Utils.nearbyMarker
			})

			if point then
				pointHandles[#pointHandles + 1] = point
			end

			if blip then
				createBlip(blip, coords)
			end
		end

		if data.zones then
			for i = 1, #data.zones do
				local zone = data.zones[i]
				if zone then
					local coords = toVector3(zone.coords or zone.loc)
					if coords then
						addBenchPoint(coords, i, zone.drawDistance or zone.distance or 16, zone.marker)
					end
				end
			end
		end

		if data.points then
			for i = 1, #data.points do
				local coords = toVector3(data.points[i])
				if coords then
					addBenchPoint(coords, i, 16, nil)
				end
			end
		end

		if #pointHandles > 0 then
			ActiveBenchEntities[id] = {
				points = pointHandles,
			}
		end

		CraftingBenches[id] = data
	end
end

for id, data in pairs(lib.load('data.crafting') or {}) do createCraftingBench(data.name or id, data) end

local function syncCraftingBenches(benches)
	if type(benches) ~= 'table' then return end

	local validKeys = {}

	for benchId, benchData in pairs(benches) do
		local key = benchData.name or benchId
		validKeys[key] = true
		createCraftingBench(key, benchData)
	end

	for existingId in pairs(CraftingBenches) do
		if not validKeys[existingId] then
			removeBenchEntities(existingId)
			CraftingBenches[existingId] = nil
		end
	end
end

RegisterNetEvent('ox_inventory:syncCraftingBenches', syncCraftingBenches)

RegisterNetEvent('craftmanager:reloadBench', function(benchId, benchData)
	if not benchId or not benchData then return end
	createCraftingBench(benchId, benchData)
end)

RegisterNetEvent('craftmanager:benchDeleted', function(benchId)
	if not benchId then return end
	removeBenchEntities(benchId)
	CraftingBenches[benchId] = nil
end)

local function requestCraftingSync()
	TriggerServerEvent('ox_inventory:requestCraftingSync')
end

CreateThread(function()
	Wait(1000)
	requestCraftingSync()
end)

AddEventHandler('onClientResourceStart', function(resource)
	if resource == cache.resource then
		requestCraftingSync()
	end
end)

return CraftingBenches
