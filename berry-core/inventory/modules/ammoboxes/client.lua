if not lib then return end

local Items = require 'modules.items.client'
local AmmoBoxes = lib.load('config.ammoboxes') or {}
local ox_inventory = exports[shared.resource]

local function Item(name, cb)
	local item = Items[name]
	if item then
		if not item.client?.export and not item.client?.event then
			item.effect = cb
		end
	end
end

for boxName, boxData in pairs(AmmoBoxes) do
	Item(boxName, function(data, slot)
		local ped = cache.ped
		local anim = boxData.animation
		local progress = boxData.progress
		
		if anim then
			lib.requestAnimDict(anim.dict)
			TaskPlayAnim(ped, anim.dict, anim.clip, 8.0, 8.0, -1, anim.flag or 49, 0, false, false, false)
		end
		
		if progress then
			local duration = progress.duration or 5000
			local hasRProgress = pcall(function() return exports.rprogress end)
			
			if hasRProgress and exports.rprogress then
				exports.rprogress._DOLI_PROGRESSBAR_START(duration)
			end
			
			Wait(duration)
			
			if hasRProgress and exports.rprogress then
				exports.rprogress._DOLI_PROGRESSBAR_CANCEL()
			end
		end
		
		ClearPedTasks(ped)
		
		ox_inventory:useItem(data, function(success)
			if success then
				TriggerServerEvent('ox_inventory:openAmmoBox', boxName, slot.slot)
			end
		end)
	end)
end

