if not lib then return end

local Items = require 'modules.items.server'
local Inventory = require 'modules.inventory.server'
local AmmoBoxes = lib.load('config.ammoboxes') or {}

RegisterNetEvent('ox_inventory:openAmmoBox', function(boxName, slot)
	local source = source
	local left = Inventory(source)
	
	if not left then return end
	
	local boxData = AmmoBoxes[boxName]
	if not boxData then return end
	
	local slotData = left.items[slot]
	if not slotData or slotData.name ~= boxName then return end
	
	local rewards = boxData.rewards
	if not rewards or #rewards == 0 then return end
	
	for _, reward in ipairs(rewards) do
		local itemName = reward.item
		local count = reward.count
		
		if type(count) == 'table' and #count == 2 then
			count = math.random(count[1], count[2])
		elseif type(count) == 'number' then
			count = count
		else
			count = 1
		end
		
		local item = Items(itemName)
		if item then
			Inventory.AddItem(left, item, count, {}, nil)
		end
	end
	
	Inventory.RemoveItem(left, boxName, 1, nil, slot)
end)









