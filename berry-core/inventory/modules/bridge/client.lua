if not lib then return end

---@diagnostic disable-next-line: duplicate-set-field
function client.setPlayerData(key, value)
	PlayerData[key] = value
	OnPlayerData(key, value)
end

function client.hasGroup(group)
	if not PlayerData.loaded then return end

	if type(group) == 'table' then
		for name, rank in pairs(group) do
			local groupRank = PlayerData.groups[name]
			if groupRank and groupRank >= (rank or 0) then
				return name, groupRank
			end
		end
	else
		local groupRank = PlayerData.groups[group]
		if groupRank then
			return group, groupRank
		end
	end
end

local Shops = require 'modules.shops.client'
local Utils = require 'modules.utils.client'
local Weapon = require 'modules.weapon.client'
local Items = require 'modules.items.client'

function client.onLogout()
	if not PlayerData.loaded then return end

	if client.parachute then
		Utils.DeleteEntity(client.parachute[1])
		client.parachute = false
	end

	for _, point in pairs(client.drops) do
		if point.entity then
			Utils.DeleteEntity(point.entity)
		end

		point:remove()
	end

    for _, v in pairs(Items --[[@as table]]) do
        v.count = 0
    end

	PlayerData.inventory = {}
	PlayerData.weight = 0
	PlayerData.groups = {}

	PlayerData.loaded = false
	client.drops = nil

	client.closeInventory()
	Shops.wipeShops()

	local intervalId = client.interval
	local tickId = client.tick
	client.interval = nil
	client.tick = nil

	if intervalId then
		pcall(ClearInterval, intervalId)
	end

	if tickId then
		pcall(ClearInterval, tickId)
	end

	Weapon.Disarm()

	SendNUIMessage({
		action = 'refreshSlots',
		data = {
			items = {},
			itemCount = {}
		}
	})
end

local success, result = pcall(lib.load, ('modules.bridge.%s.client'):format(shared.framework))

if not success then
    lib = nil
    return
end
