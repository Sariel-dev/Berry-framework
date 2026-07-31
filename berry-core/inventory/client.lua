if not lib then return end

local function sendEsxNotification(data)
	local message

	if type(data) == 'table' then
		message = data.description or data.message or data.text or data.title
	elseif data ~= nil then
		message = tostring(data)
	end

	if not message or message == '' then return end

	TriggerEvent('esx:showNotification', message)
end

lib.notify = sendEsxNotification

require 'modules.bridge.client'
require 'modules.interface.client'
require 'modules.multichest.client'
require 'modules.locker.client'
require 'modules.ammunition.client'

local Utils = require 'modules.utils.client'
local Weapon = require 'modules.weapon.client'
local ItemList = require 'modules.items.shared'
local currentWeapon

local UtilPeds = {
	start = function() end,
	stop = function() end,
	refresh = function() end
}

local function isEquippedClothingItem(item)
	return item
		and item.metadata
		and item.metadata.equippedInClothingSlot ~= nil
end

local function filterPlayerInventoryForUi(inventory)
	local filtered = {}
	for slot, item in pairs(inventory) do
		if item and isEquippedClothingItem(item) then
			filtered[slot] = nil
		else
			filtered[slot] = item
		end
	end
	return filtered
end

local function sanitizeUiUpdateItems(items)
	if not items then return items end
	local sanitized = {}
	for i = 1, #items do
		local entry = items[i]
		if entry and (entry.inventory == 'player' or entry.inventory == cache.serverId) and entry.item then
			local item = entry.item
			if item and isEquippedClothingItem(item) then
				sanitized[i] = {
					inventory = entry.inventory,
					item = { slot = item.slot }
				}
			else
				sanitized[i] = entry
			end
		else
			sanitized[i] = entry
		end
	end
	return sanitized
end

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
	SetTimeout(150, function()
		if GetResourceState('lpCharacter') == 'started' then
			TriggerEvent('lpCharacter:saveCurrentAppearanceState')
			return
		end

		local system = getClothingSystem()
		
		if system == 'illenium-appearance' or system == '17mov_CharacterSystem' then
			local appearance = exports['illenium-appearance']:getPedAppearance(cache.ped)
			if appearance then
				TriggerServerEvent('illenium-appearance:server:saveAppearance', appearance)
			end
		elseif system == 'rcore_clothing' then
			-- Get current player clothing and save it via export
			local success, err = pcall(function()
				-- Use the event to save current skin (this is the correct way per rcore API)
				TriggerEvent('rcore_clothing:saveCurrentSkin')
			end)
		end
	end)
end

local function waitForClothingSystemReady()
	local system = getClothingSystem()
	
	if system == 'illenium-appearance' or system == '17mov_CharacterSystem' then
		local attempts = 0
		while attempts < 50 do
			local success, appearance = pcall(function()
				return exports['illenium-appearance']:getPedAppearance(cache.ped)
			end)
			if success and appearance then break end
			attempts = attempts + 1
			Wait(100)
		end
	elseif system == 'rcore_clothing' then
		local attempts = 0
		while attempts < 50 do
			local success, skin = pcall(function()
				return exports['rcore_clothing']:getPlayerSkin(true)
			end)
			if success and skin then break end
			attempts = attempts + 1
			Wait(100)
		end
	else
		Wait(1000)
	end
end

local localeStorageKey = 'ox_inventory:locale'
local currentLocale = GetResourceKvpString(localeStorageKey)
local forcedLocale = 'fr'

local function applySavedLocale()
	local ok = pcall(lib.locale, forcedLocale)

	if ok then
		currentLocale = forcedLocale
		pcall(SetResourceKvp, localeStorageKey, forcedLocale)
		return
	end

	if currentLocale and currentLocale ~= '' then
		ok = pcall(lib.locale, currentLocale)

		if ok then
			return
		end
	end

	currentLocale = (lib.getLocaleKey and lib.getLocaleKey()) or 'fr'
end

applySavedLocale()

local function getLocaleOptions()
	local options = GlobalState['ox_lib:locales']

	if type(options) == 'table' then
		return options
	end

	return {}
end

local function buildUiLocales()
	local locales = lib.getLocales()
	local uiLocales = {}

	for key, value in pairs(locales) do
		if key:find('^ui_') or key:find('^notification_') then
			uiLocales[key] = value
		end
	end

	uiLocales['$'] = locales['$']
	uiLocales.ammo_type = locales.ammo_type

	return uiLocales
end

local function sendLocaleUpdate()
	SendNUIMessage({
		action = 'setLocale',
		data = {
			locale = buildUiLocales(),
			key = currentLocale
		}
	})
end

local function clampThemeChannel(value)
	local number = tonumber(value)
	if not number then return nil end

	number = math.floor(number + 0.5)

	if number < 0 then
		return 0
	end

	if number > 255 then
		return 255
	end

	return number
end

local function sanitizeServerThemeColor(value)
	if type(value) ~= 'table' then return nil end

	local red = clampThemeChannel(value.r or value.R or value[1])
	local green = clampThemeChannel(value.g or value.G or value[2])
	local blue = clampThemeChannel(value.b or value.B or value[3])

	if red == nil or green == nil or blue == nil then
		return nil
	end

	return {
		r = red,
		g = green,
		b = blue
	}
end

local function formatServerThemeHex(color)
	local safeColor = sanitizeServerThemeColor(color)
	if not safeColor then return nil end

	return ('#%02X%02X%02X'):format(safeColor.r, safeColor.g, safeColor.b)
end

local function sendServerThemeUpdate(payload)
	local state = type(payload) == 'table' and payload or GlobalState.LP_ServerMenuConfig
	if type(state) ~= 'table' then return end

	local color = sanitizeServerThemeColor(state.primaryColor or state.color)
	if not color then return end

	SendNUIMessage({
		action = 'theme:apply',
		color = color,
		hex = state.hex or formatServerThemeHex(color)
	})
end

AddStateBagChangeHandler('LP_ServerMenuConfig', 'global', function(_, _, value)
	if type(value) == 'table' then
		sendServerThemeUpdate(value)
	end
end)

CreateThread(function()
	local payload = GlobalState.LP_ServerMenuConfig
	if type(payload) == 'table' then
		sendServerThemeUpdate(payload)
	end
end)

exports('getCurrentWeapon', function()
	return currentWeapon
end)

local PedCreate, startPedScreen, clonedPed = {}, false, nil
local lastPedVisibility = nil
local currentPedScreenConfig = nil
local lastClothingPreviewSignature = nil
local PedScreenCreate

local function buildClothingPreviewSignature(itemData)
	if type(itemData) ~= 'table' then return nil end

	local ok, encoded = pcall(json.encode, {
		name = itemData.name,
		metadata = itemData.metadata
	})

	if ok then
		return encoded
	end

	return tostring(itemData.name)
end

local function ensureClothingPreviewPed()
	if clonedPed and DoesEntityExist(clonedPed) and startPedScreen then
		return clonedPed
	end

	return PedScreenCreate(cache.ped, {
		dict = "anim@amb@nightclub@peds@",
		anim = "rcmme_amanda1_stand_loop_cop"
	})
end

local function buildPedScreenConfig(playerPedArg, animation, control, screenType, data)
	local animDict = animation and animation.dict or nil
	local animName = animation and animation.anim or nil
	local model = playerPedArg and GetEntityModel(playerPedArg) or nil

	return {
		model = model,
		control = control == true,
		type = screenType or 'default',
		animDict = animDict,
		animName = animName,
		depth = data and data.depth or nil,
		bufferSize = data and data.bufferSize or nil,
		scaleWidth = data and data.scaleWidth or nil,
		upTempOffset = data and data.upTempOffset or nil,
		screenX = data and data.screenX or nil,
		screenY = data and data.screenY or nil
	}
end

local function isSamePedScreenConfig(nextConfig)
	local current = currentPedScreenConfig
	if not current or not nextConfig then return false end

	return current.model == nextConfig.model
		and current.control == nextConfig.control
		and current.type == nextConfig.type
		and current.animDict == nextConfig.animDict
		and current.animName == nextConfig.animName
		and current.depth == nextConfig.depth
		and current.bufferSize == nextConfig.bufferSize
		and current.scaleWidth == nextConfig.scaleWidth
		and current.upTempOffset == nextConfig.upTempOffset
		and current.screenX == nextConfig.screenX
		and current.screenY == nextConfig.screenY
end

local function ensureCloneAnimation(animation)
	if not clonedPed or not DoesEntityExist(clonedPed) or not animation or not animation.dict or not animation.anim then
		return
	end

	if not IsEntityPlayingAnim(clonedPed, animation.dict, animation.anim, 3) then
		lib.requestAnimDict(animation.dict)
		TaskPlayAnim(clonedPed, animation.dict, animation.anim, 8.0, 1.0, -1, 1, 0, false, false, false)
	end
end

local function refreshClonedPedFromSource(playerPedArg, animation)
	if not clonedPed or not DoesEntityExist(clonedPed) or not playerPedArg or not DoesEntityExist(playerPedArg) then
		return false
	end

	ClonePedToTarget(playerPedArg, clonedPed)
	ClearPedTasksImmediately(clonedPed)
	ensureCloneAnimation(animation)
	return true
end

local function createPed(model, locationx, locationy, locationz)
    lib.requestModel(model, 1)
	if not locationx or not locationy or not locationz then
		local coords = GetEntityCoords(cache.ped)
		locationx, locationy, locationz = coords.x, coords.y, coords.z
	end
	return CreatePed(26, model, locationx, locationy, locationz, 0, false, false)
end

local function PedScreenDelete()
    for k,v in pairs(PedCreate) do 
        DeleteEntity(v)
    end

    clonedPed = nil 
    PedCreate = {} 
    startPedScreen = false 
    previewedClothing = {}
    lastPedVisibility = nil
	currentPedScreenConfig = nil
	lastClothingPreviewSignature = nil
end

local function RenderCam(playerPedArg)
    local totalTime = 1000 
    local elapsed = 0
    local startingPitch = GetGameplayCamRelativePitch() 
    local targetPitch = 0.0
    local rate = 1.0
    local pitchThreshold = 30.00  
    
    if math.abs(startingPitch + 7.0) < pitchThreshold then
        return
    end

    if LocalPlayer.state.invOpen then 
        if math.abs(startingPitch - targetPitch) > 0.01 then
            CreateThread(function()
                while elapsed < totalTime and startPedScreen do
                    Wait(0) -- ~60fps instead of 333fps
                    elapsed = elapsed + 32 
                    local progress = elapsed / totalTime
                    local currentPitch = (1.0 - progress) * startingPitch + progress * targetPitch
                    SetGameplayCamRelativePitch(currentPitch, rate)
                end
            end)
        end
    end
end

PedScreenCreate = function(playerPedArg, animation, control, type, data)
    if not control then 
        local vehicle = GetVehiclePedIsIn(playerPedArg, false)
        if vehicle and vehicle ~= 0 and GetEntitySpeed(vehicle) * 3.5 > 80 then 
            return
        end
    end

	local nextConfig = buildPedScreenConfig(playerPedArg, animation, control, type, data)
	if clonedPed and DoesEntityExist(clonedPed) and isSamePedScreenConfig(nextConfig) then
		startPedScreen = true
		refreshClonedPedFromSource(playerPedArg, animation)
		RenderCam(playerPedArg)
		return clonedPed
	end

    SetGameplayCamRelativePitch(1.0, 1.0)
    PedScreenDelete()
    RenderCam(playerPedArg)

    local screenX = GetDisabledControlNormal(0, 239)
    local screenY = GetDisabledControlNormal(0, 240)
    clonedPed = createPed(GetEntityModel(playerPedArg), nil, nil, nil)

    SetEntityCollision(clonedPed, false, true)
    SetEntityInvincible(clonedPed, true)
    NetworkSetEntityInvisibleToNetwork(clonedPed, false)
    ClonePedToTarget(playerPedArg, clonedPed)
    SetEntityCanBeDamaged(clonedPed, false)
    SetBlockingOfNonTemporaryEvents(clonedPed, true)
	FreezeEntityPosition(clonedPed, true)
	ClearPedTasksImmediately(clonedPed)
	SetEntityCollision(clonedPed, false, false)
	SetPedCanRagdoll(clonedPed, false)
	SetPedCanPlayAmbientAnims(clonedPed, false)
	SetPedCanPlayAmbientBaseAnims(clonedPed, false)
	SetPedCanEvasiveDive(clonedPed, false)
	SetPedFleeAttributes(clonedPed, 0, false)
	SetPedCombatAttributes(clonedPed, 17, true) -- always flee: false
	SetPedKeepTask(clonedPed, true)
    SetPedAsNoLongerNeeded(clonedPed)
    SetForcePedFootstepsTracks(false)

    if animation.dict and animation.anim then
        lib.requestAnimDict(animation.dict)
        TaskPlayAnim(clonedPed, animation.dict, animation.anim, 8.0, 1.0, -1, 1, 0, false, false, false)
    end

    table.insert(PedCreate, clonedPed)
	currentPedScreenConfig = nextConfig

    startPedScreen = true 
    CreateThread(function()
		local smoothedTarget = nil
        -- Cache values outside loop
        local GetWorldCoordFromScreenCoord = GetWorldCoordFromScreenCoord
        local GetGameplayCamRot = GetGameplayCamRot
        local SetEntityCoords = SetEntityCoords
        local SetEntityHeading = SetEntityHeading
        local GetEntityMatrix = GetEntityMatrix
        local SetEntityMatrix = SetEntityMatrix
        local DisableIdleCamera = DisableIdleCamera
        local DisableAllControlActions = DisableAllControlActions
		local depth = 1.5
		local bufferSize = 2
		local scaleWidth = 0.50
		local upTempOffset = -0.55
		local screenX = 0.50300000000000
		local screenY = 0.4500000000000

		if type == "animation" then
			depth = data.depth
			bufferSize = data.bufferSize
			scaleWidth = data.scaleWidth
			upTempOffset = data.upTempOffset
			screenX = data.screenX or 0.70035417461395
			screenY = data.screenY or 0.2587036895752
		end

		local smoothingFactor = 1 / math.max(1, bufferSize)
        
		while startPedScreen do 
			local world, normal = GetWorldCoordFromScreenCoord(screenX, screenY)

            local target = world + normal * depth
            local camRot = GetGameplayCamRot(2)

			if smoothedTarget then
				smoothedTarget = smoothedTarget + (target - smoothedTarget) * smoothingFactor
			else
				smoothedTarget = target
			end

            DisableIdleCamera(true)
			SetEntityCoords(clonedPed, smoothedTarget.x, smoothedTarget.y, smoothedTarget.z, false, false, false, true)

			local heading = camRot.z + 180.0
			if medicModeActive and medicHumanTabActive then
				heading = heading + medicPedHeadingOffset
			end

            SetEntityHeading(clonedPed, heading)

            if control then 
                DisableAllControlActions(0)
            end

            local forward, right, up, position = GetEntityMatrix(clonedPed)
            right = right * scaleWidth 
            local upAdjusted = up + vector3(0, 0, upTempOffset)

			SetEntityMatrix(clonedPed, forward.x, forward.y, forward.z, right.x, right.y, right.z, upAdjusted.x, upAdjusted.y, upAdjusted.z, smoothedTarget.x, smoothedTarget.y, smoothedTarget.z)
            Wait(0)
        end
    end)

	return clonedPed
end

local previewedClothing = {}

local function SaveCurrentClothingState()
    if not clonedPed or not DoesEntityExist(clonedPed) then
        return false
    end
    
    local success = pcall(function()
        previewedClothing = {}
        
        for slotId = 70, 86 do
            local mapping = flashbackSlotMapping[slotId]
            if mapping and mapping.type and type(mapping.id) == 'number' then
                if mapping.type == 'component' then
                    local drawable = GetPedDrawableVariation(clonedPed, mapping.id)
                    local texture = GetPedTextureVariation(clonedPed, mapping.id)
                    if drawable and texture then
                        previewedClothing[slotId] = {
                            type = 'component',
                            drawable = drawable,
                            texture = texture
                        }
                    end
                elseif mapping.type == 'prop' then
                    local drawable = GetPedPropIndex(clonedPed, mapping.id)
                    local texture = GetPedPropTextureIndex(clonedPed, mapping.id)
                    if drawable ~= nil and texture then
                        previewedClothing[slotId] = {
                            type = 'prop',
                            drawable = drawable,
                            texture = texture
                        }
                    end
                end
            end
        end
    end)
    
    return success
end

local function RestoreClothingState()
    if not clonedPed or not DoesEntityExist(clonedPed) or not next(previewedClothing) then
        return false
    end
    
    local success = pcall(function()
        for slotId, clothingData in pairs(previewedClothing) do
            if not clothingData or not clothingData.type then
                goto continue
            end
            
            local mapping = flashbackSlotMapping[slotId]
            if mapping and mapping.type and type(mapping.id) == 'number' then
                if clothingData.type == 'component' and clothingData.drawable ~= nil and clothingData.texture ~= nil then
                    SetPedComponentVariation(clonedPed, mapping.id, clothingData.drawable, clothingData.texture, 0)
                elseif clothingData.type == 'prop' and clothingData.drawable ~= nil and clothingData.texture ~= nil then
                    if clothingData.drawable == -1 then
                        ClearPedProp(clonedPed, mapping.id)
                    else
                        SetPedPropIndex(clonedPed, mapping.id, clothingData.drawable, clothingData.texture, false)
                    end
                end
            end
            
            ::continue::
        end
        
        previewedClothing = {}
		lastClothingPreviewSignature = nil
    end)
    
    return success
end

local function UpdateClonedPedClothing(slotId, itemMetadata)
    if not clonedPed or not DoesEntityExist(clonedPed) or not startPedScreen then
        return false
    end
    
    -- Slots unifiés 70-86 pour tous les styles
    if type(slotId) ~= 'number' or slotId < 70 or slotId > 86 then
        return false
    end
    
    local success = pcall(function()
        local mapping = clothingSlotMapping[slotId]
        
		if not mapping or not mapping.type or type(mapping.id) ~= 'number' then 
            return 
        end

		if itemMetadata and type(itemMetadata) == 'table' and itemMetadata.name then
			local metadata = itemMetadata.metadata
			if type(metadata) ~= 'table' then
				metadata = {}
			end
            local kevlarConfig = Config and Config.Kevlar or kevlarDrawables
            local kevlarInfo = kevlarConfig and kevlarConfig[itemMetadata.name]
            
            if slotId == 81 then
                local drawable = nil
                local texture = 0
                
				if metadata.component ~= nil then
					drawable = tonumber(metadata.drawable) or 0
					texture = tonumber(metadata.texture) or 0
				elseif metadata.drawable ~= nil then
					drawable = tonumber(metadata.drawable)
					texture = tonumber(metadata.texture) or 0
                end
                
                if not drawable and kevlarInfo and kevlarInfo.drawable then
                    drawable = kevlarInfo.drawable
                    texture = 0
                end
                
                if drawable and type(drawable) == 'number' and type(texture) == 'number' then
                    SetPedComponentVariation(clonedPed, 9, drawable, texture, 0)
                end
			elseif mapping.type == 'component' and metadata.drawable ~= nil then
                local drawable = tonumber(metadata.drawable) or 0
                local texture = tonumber(metadata.texture) or 0
                
				if type(drawable) == 'number' and type(texture) == 'number' then
					if IsPedComponentVariationValid(clonedPed, mapping.id, drawable, texture) then
						SetPedComponentVariation(clonedPed, mapping.id, drawable, texture, 0)
					else
						SetPedComponentVariation(clonedPed, mapping.id, drawable, texture, 0)
					end
				end
            elseif mapping.type == 'prop' and metadata.drawable ~= nil then
                local drawable = tonumber(metadata.drawable)
                local texture = tonumber(metadata.texture) or 0
                
                if type(drawable) == 'number' and type(texture) == 'number' then
					if drawable == -1 then
						ClearPedProp(clonedPed, mapping.id)
					elseif SetPedPreloadPropData(clonedPed, mapping.id, drawable, texture) then
						SetPedPropIndex(clonedPed, mapping.id, drawable, texture, false)
					else
						SetPedPropIndex(clonedPed, mapping.id, drawable, texture, false)
					end
                end
            end
        else
            if slotId == 81 then
                SetPedComponentVariation(clonedPed, 9, 0, 0, 0)
            elseif mapping.type == 'component' then
                local emptyDrawable = tonumber(mapping.emptyDrawable) or 0
                local emptyTexture = tonumber(mapping.emptyTexture) or 0
                SetPedComponentVariation(clonedPed, mapping.id, emptyDrawable, emptyTexture, 0)
            elseif mapping.type == 'prop' then
                if mapping.emptyDrawable == -1 then
                    ClearPedProp(clonedPed, mapping.id)
                else
                    local emptyDrawable = tonumber(mapping.emptyDrawable) or 0
                    local emptyTexture = tonumber(mapping.emptyTexture) or 0
                    SetPedPropIndex(clonedPed, mapping.id, emptyDrawable, emptyTexture, false)
                end
            end
        end
    end)
    
    return success
end

local function PreviewClothingOnClone(itemData)
    if not clonedPed or not DoesEntityExist(clonedPed) or not startPedScreen then
        return false
    end

	if not itemData or type(itemData) ~= 'table' then
        return false
    end

	local itemName = type(itemData.name) == 'string' and itemData.name or 'preview_clothing'

	local componentIdToSlot = {
		[1] = 71,  -- mask
		[3] = 74,  -- hands/gloves
		[11] = 75, -- torso/jacket/undershirt
		[8] = 80,  -- tshirt
		[4] = 77,  -- pants
		[6] = 83,  -- shoes
		[9] = 81,  -- vest
		[5] = 79,  -- bags
		[7] = 73,  -- chain/neck
		[10] = 86, -- decals -> outfit slot
		[2] = 85   -- hair (placeholder)
	}

	local propIdToSlot = {
		[0] = 70,  -- hat
		[1] = 72,  -- glasses
		[2] = 78,  -- earrings
		[6] = 76,  -- watch
		[7] = 82   -- bracelet
	}
    
	local success = pcall(function()
		-- Outfit preview (apply all pieces from metadata)
		if itemData.metadata and type(itemData.metadata) == 'table' then
			local function getOutfitMeta(metadata)
				local candidates = { metadata.outfitData, metadata.outfit, metadata.appearance, metadata.appearanceData, metadata.data, metadata.skin, metadata.clothes }
				local candidateNames = { 'outfitData', 'outfit', 'appearance', 'appearanceData', 'data', 'skin', 'clothes' }
				for _, value in ipairs(candidates) do
					local candidateName = candidateNames[_]
					if value then
						if type(value) == 'string' then
							local ok, decoded = pcall(json.decode, value)
							if ok and type(decoded) == 'table' then
								value = decoded
							else
								value = nil
							end
						end
						if type(value) == 'table' then
							return value
						end
					end
				end
				return nil
			end

			local outfit = getOutfitMeta(itemData.metadata)
			if outfit then
				if not next(previewedClothing) then
					SaveCurrentClothingState()
				end

				local function applyComponent(componentId, drawable, texture)
					if drawable == nil then return end

					local slotId = componentIdToSlot[componentId]
					if not slotId then
						return
					end

					local resolvedDrawable = tonumber(drawable) or 0
					local resolvedTexture = tonumber(texture) or 0

					SetPedComponentVariation(clonedPed, componentId, resolvedDrawable, resolvedTexture, 0)
				end

				local function applyProp(propId, drawable, texture)
					if drawable == nil then return end

					local slotId = propIdToSlot[propId]
					if not slotId then
						return
					end

					local resolvedDrawable = tonumber(drawable)
					local resolvedTexture = tonumber(texture) or 0

					if resolvedDrawable == -1 then
						ClearPedProp(clonedPed, propId)
						return
					end

					SetPedPropIndex(clonedPed, propId, resolvedDrawable or 0, resolvedTexture, false)
				end

				if outfit['pants'] then applyComponent(4, outfit['pants'].item, outfit['pants'].texture) end
				if outfit['arms'] then applyComponent(3, outfit['arms'].item, outfit['arms'].texture) end
				if outfit['t-shirt'] then applyComponent(8, outfit['t-shirt'].item, outfit['t-shirt'].texture) end
				if outfit['vest'] then applyComponent(9, outfit['vest'].item, outfit['vest'].texture) end
				if outfit['torso2'] then applyComponent(11, outfit['torso2'].item, outfit['torso2'].texture) end
				if outfit['shoes'] then applyComponent(6, outfit['shoes'].item, outfit['shoes'].texture) end
				if outfit['accessory'] then applyComponent(7, outfit['accessory'].item, outfit['accessory'].texture) end
				if outfit['mask'] then applyComponent(1, outfit['mask'].item, outfit['mask'].texture) end
				if outfit['bag'] then applyComponent(5, outfit['bag'].item, outfit['bag'].texture) end
				if outfit['hat'] then applyProp(0, outfit['hat'].item, outfit['hat'].texture) end
				if outfit['glass'] then applyProp(1, outfit['glass'].item, outfit['glass'].texture) end
				if outfit['ear'] then applyProp(2, outfit['ear'].item, outfit['ear'].texture) end

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

					local compMap = { [1] = 1, [3] = 3, [11] = 11, [8] = 8, [4] = 4, [6] = 6, [9] = 9, [5] = 5, [7] = 7 }
					for compId in pairs(compMap) do
						local comp = findById(outfit.components, compId, { 'component_id', 'componentId', 'component', 'id' })
						if comp then
							applyComponent(compId, comp.drawable or comp.item, comp.texture)
						end
					end

					local propMap = { [0] = 0, [1] = 1, [2] = 2, [6] = 6, [7] = 7 }
					for propId in pairs(propMap) do
						local prop = findById(outfit.props, propId, { 'prop_id', 'propId', 'prop', 'id' })
						if prop then
							applyProp(propId, prop.drawable or prop.item, prop.texture)
						end
					end
				end

				return
			end
		end

		if itemData.metadata and type(itemData.metadata) == 'table' then
			local componentId = tonumber(itemData.metadata.component)
			local propId = tonumber(itemData.metadata.prop)
			local drawable = tonumber(itemData.metadata.drawable)
			local texture = tonumber(itemData.metadata.texture) or 0

			if (componentId or propId) and drawable ~= nil then
				if not next(previewedClothing) then
					SaveCurrentClothingState()
				end

				if componentId then
					SetPedComponentVariation(clonedPed, componentId, drawable, texture, 0)
					return
				elseif propId then
					SetPedPropIndex(clonedPed, propId, drawable, texture, false)
					return
				end
			end
		end

		local itemNameMapping = itemNameToSlotMapping
		if Config and Config.Clothing and type(Config.Clothing.ItemNameMapping) == 'table' then
			local isUnified = true
			for _, mappedSlot in pairs(Config.Clothing.ItemNameMapping) do
				if type(mappedSlot) ~= 'number' or mappedSlot < 70 or mappedSlot > 86 then
					isUnified = false
					break
				end
			end
			if isUnified then
				itemNameMapping = Config.Clothing.ItemNameMapping
			end
		end
        
		local slotId = itemNameMapping[itemData.name]
		if not slotId then
			slotId = itemNameMapping[itemName]
		end
		if not slotId then
			local lowerName = string.lower(itemName)

			if not clothingNameExclusions[lowerName] then
				for key, mappedSlot in pairs(itemNameMapping) do
					if string.find(lowerName, key, 1, true) then
						slotId = mappedSlot
						break
					end
				end
			end
		end
        
		if not slotId then
            local kevlarConfig = Config and Config.Kevlar or kevlarDrawables
            if kevlarConfig and type(kevlarConfig) == 'table' and kevlarConfig[itemData.name] then
                slotId = 81 -- vest slot unifié
            end
        end

		if not slotId and itemData.metadata and type(itemData.metadata) == 'table' then
			if type(itemData.metadata.slot) == 'number' and itemData.metadata.slot >= 70 and itemData.metadata.slot <= 86 then
				slotId = itemData.metadata.slot
			else
				local componentId = tonumber(itemData.metadata.component)
				local propId = tonumber(itemData.metadata.prop)
				if componentId and componentIdToSlot[componentId] then
					slotId = componentIdToSlot[componentId]
				elseif propId and propIdToSlot[propId] then
					slotId = propIdToSlot[propId]
				end
			end
		end
        
        -- Slots unifiés 70-86 pour tous les styles
			if not slotId or type(slotId) ~= 'number' or slotId < 70 or slotId > 86 then
            return
        end
        
        if not next(previewedClothing) then
            SaveCurrentClothingState()
        end
        
        UpdateClonedPedClothing(slotId, itemData)
    end)
    
    return success
end

exports('PedScreenDelete', PedScreenDelete)
exports('PedScreenCreate', PedScreenCreate)
exports('UpdateClonedPedClothing', UpdateClonedPedClothing)
exports('PreviewClothingOnClone', PreviewClothingOnClone)
exports('RestoreClothingState', RestoreClothingState)
exports('getCurrentClonedPed', function()
    return clonedPed
end)

RegisterNetEvent('ox_inventory:disarm', function(noAnim)
	currentWeapon = Weapon.Disarm(currentWeapon, noAnim)
end)

RegisterNetEvent('ox_inventory:clearWeapons', function()
	Weapon.ClearAll(currentWeapon)
end)

local StashTarget

exports('setStashTarget', function(id, owner)
	StashTarget = id and {id=id, owner=owner}
end)

---@type boolean | number
local invBusy = true

---@type boolean?
local invOpen = false
local plyState = LocalPlayer.state
local IsPedCuffed = IsPedCuffed
local playerPed = cache.ped

lib.onCache('ped', function(ped)
	playerPed = ped
	Utils.WeaponWheel()
end)

plyState:set('invBusy', true, true)
plyState:set('invHotkeys', false, false)
plyState:set('canUseWeapons', false, false)

local function canOpenInventory()
    if not PlayerData.loaded then
		return false
    end

    if IsPauseMenuActive() then return end

    if invBusy or invOpen == nil or (currentWeapon and currentWeapon.timer or 0) > 0 then
		return false
    end

    if PlayerData.dead or IsPedFatallyInjured(playerPed) then
		return false
    end

    if PlayerData.cuffed or IsPedCuffed(playerPed) then
		return false
    end

    return true
end

---@param reason? string
local function notifyCannotPerform(reason)
	local description = locale('cannot_perform')

	if reason and reason ~= '' then
		description = ('%s (%s)'):format(description, reason)
	end

	return lib.notify({ id = 'cannot_perform', type = 'error', title = locale('notification_action_impossible'), description = description })
end

---@param isAmmo? boolean
---@return string
local function getCannotPerformReason(isAmmo)
	local ped = cache.ped

	if usingItem then return 'action en cours' end
	if isAmmo and not currentWeapon then return 'aucune arme équipée' end
	if not PlayerData.loaded then return 'joueur non chargé' end
	if PlayerData.dead then return 'joueur mort' end
	if invBusy then return 'inventaire occupé' end
	if lib.progressActive() then return 'progression active' end
	if IsPedRagdoll(ped) then return 'joueur au sol' end
	if IsPedFalling(ped) then return 'joueur en chute' end
	if IsPedShooting(playerPed) then return 'tir en cours' end

	return 'condition invalide'
end

---@param ped number
---@return boolean
local function canOpenTarget(ped)
	return IsPedFatallyInjured(ped)
	or IsEntityPlayingAnim(ped, 'dead', 'dead_a', 3)
	or IsPedCuffed(ped)
	or IsEntityPlayingAnim(ped, 'mp_arresting', 'idle', 3)
	or IsEntityPlayingAnim(ped, 'missminuteman_1ig_2', 'handsup_base', 3)
	or IsEntityPlayingAnim(ped, 'missminuteman_1ig_2', 'handsup_enter', 3)
	or IsEntityPlayingAnim(ped, 'random@mugging3', 'handsup_standing_base', 3)
end

local defaultInventory = {
	type = 'newdrop',
	slots = shared.playerslots,
	weight = 0,
	maxWeight = shared.playerweight,
	items = {}
}

local currentInventory = defaultInventory

local playerStatus = {
	hunger = 100,
	thirst = 100,
	sleep = 100
}

local function updateHUDStats()
	if Config.DefaultStyle and Config.DefaultStyle.Hud and Config.DefaultStyle.Hud.Enabled == false then
		return
	end

	SendNUIMessage({
		type = 'updateHUDStats',
		stats = playerStatus
	})
end

local savedWeapon = nil

local function closeTrunk()
	if currentInventory and currentInventory.type == 'trunk' then
		local coords = GetEntityCoords(playerPed, true)
		---@todo animation for vans?
		Utils.PlayAnimAdvanced(0, 'anim@heists@fleeca_bank@scope_out@return_case', 'trevor_action', coords.x, coords.y, coords.z, 0.0, 0.0, GetEntityHeading(playerPed), 2.0, 2.0, 1000, 49, 0.25)

		CreateThread(function()
			local entity = currentInventory.entity
			local door = currentInventory.door
			Wait(900)

			if type(door) == 'table' then
				for i = 1, #door do
					SetVehicleDoorShut(entity, door[i], false)
				end
			else
				SetVehicleDoorShut(entity, door, false)
			end
		end)
	end
end

local CraftingBenches = require 'modules.crafting.client'
local Vehicles = lib.load('data.vehicles')
local Inventory = require 'modules.inventory.client'

---@param inv string?
---@param data any?
---@return boolean?
function client.openInventory(inv, data)
	-- Supprimer l'objet arme preview si il existe
	weaponPreviewThread = false
	if weaponPreviewObject and DoesEntityExist(weaponPreviewObject) then
		DeleteObject(weaponPreviewObject)
		weaponPreviewObject = nil
		weaponPreviewCoords = nil
	end
	
	if invOpen then
		if not inv and currentInventory.type == 'newdrop' then
			return client.closeInventory()
		end

		if IsNuiFocused() then
			if inv == 'container' and currentInventory.id == PlayerData.inventory[data].metadata.container then
				return client.closeInventory()
			end

			if currentInventory.type == 'drop' and (not data or currentInventory.id == (type(data) == 'table' and data.id or data)) then
				return client.closeInventory()
			end

			if inv ~= 'drop' and inv ~= 'container' then
				if (data and data.id or data) == (currentInventory and currentInventory.id) then
					-- Triggering exports.ox_inventory:openInventory('stash', 'mystash') twice in rapid succession is weird behaviour
					return
				elseif not (currentInventory.type == 'locker' and inv == 'stash') then
					-- Allow opening a stash when a locker is open (for casier access)
					return client.closeInventory()
				end
			end
		end
	elseif IsNuiFocused() then
		-- If triggering from another nui, may need to wait for focus to end.
		Wait(100)

        -- People still complain about this being an "error" and ask "how fix" despite being a warning
        -- for people with above room-temperature iqs to look into resource conflicts on their own.
		-- if IsNuiFocused() then
		-- end
	end

	if inv == 'dumpster' and cache.vehicle then
		return lib.notify({ id = 'inventory_right_access', type = 'error', title = locale('notification_access_denied'), description = locale('inventory_right_access') })
	end

	if not canOpenInventory() then
        return lib.notify({ id = 'inventory_player_access', type = 'error', title = locale('notification_access_denied'), description = locale('inventory_player_access') })
    end

    local left, right, accessError

    if inv == 'player' and data ~= cache.serverId then
        local targetId, targetPed, serverId


        if not data then
            targetId, targetPed = Utils.GetClosestPlayer()
            serverId = targetId and GetPlayerServerId(targetId)
            data = serverId
        else
            serverId = type(data) == 'table' and data.id or data
            targetId = serverId and GetPlayerFromServerId(serverId)
            targetPed = targetId and GetPlayerPed(targetId)
        end


        if serverId == cache.serverId then return end

		local targetCoords = targetPed and GetEntityCoords(targetPed)
		local distance = targetCoords and #(targetCoords - GetEntityCoords(playerPed))
		if targetCoords then
		else
		end

		if not targetCoords or distance > 1.8 or not (client.hasGroup(shared.police) or not Player(serverId).state.canSteal) then
            return lib.notify({ id = 'inventory_right_access', type = 'error', title = locale('notification_access_denied'), description = locale('inventory_right_access') })
        end
    end

    if inv == 'shop' and invOpen == false then
        if cache.vehicle then
			return notifyCannotPerform('en véhicule')
        end

        left, right, accessError = lib.callback.await('ox_inventory:openShop', 200, data)
    elseif inv == 'crafting' then
        if cache.vehicle then
			return notifyCannotPerform('en véhicule')
        end

        left, right, accessError = lib.callback.await('ox_inventory:openCraftingBench', 200, data.id, data.index)

        if left then
            right = CraftingBenches[data.id]

            if not right or not right.items then return end

            local coords, distance

            if not right.zones and not right.points then
                coords = GetEntityCoords(cache.ped)
                distance = 2
            else
                coords = shared.target and right.zones and right.zones[data.index].coords or right.points and right.points[data.index]
                distance = coords and shared.target and right.zones[data.index].distance or 2
            end

            right = {
                type = 'crafting',
                id = data.id,
                label = right.label or locale('crafting_bench'),
                index = data.index,
                slots = right.slots,
                items = right.items,
                coords = coords,
                distance = distance
            }
        end
    elseif invOpen ~= nil then
        if inv == 'policeevidence' then
            if not data then
                local input = lib.inputDialog(locale('police_evidence'), {
                    { label = locale('locker_number'), type = 'number', required = true, icon = 'calculator' }
                }) --[[@as number[]? ]]

                if not input then return end

                data = input[1]
            end
        end

        left, right, accessError = lib.callback.await('ox_inventory:openInventory', false, inv, data)
    end

    if accessError then
        return lib.notify({ id = accessError, type = 'error', title = locale('notification_error'), description = locale(accessError) })
    end

    -- Stash does not exist
    if not left then
        if left == false then return false end

        if invOpen == false then
            return lib.notify({ id = 'inventory_right_access', type = 'error', title = locale('notification_access_denied'), description = locale('inventory_right_access') })
        end

        if invOpen == true then return client.closeInventory() end
    end

    plyState.invOpen = true
    TriggerEvent("berry:ui:closeAll", "inventory")

    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(true)
    closeTrunk()


    currentInventory = right or defaultInventory
	left.items = filterPlayerInventoryForUi(PlayerData.inventory)
    left.groups = PlayerData.groups
    
    -- Get player sex from ped model (IsPedMale returns true for male, false for female)
    local ped = cache.ped or PlayerPedId()
    local isMale = IsPedMale(ped)
    local sex = isMale and 'm' or 'f'
    
    left.player = {
        sex = sex
    }

    local clothingSlots = lib.callback.await('ox_inventory:getClothingSlots', false) or {}
    
    SendNUIMessage({
        action = 'setupInventory',
        data = {
            leftInventory = left,
            rightInventory = currentInventory,
            centerInventory = {
                id = 'clothing',
                type = 'clothing',
                slots = 17,
                maxWeight = 0,
                items = clothingSlots
            }
        }
    })

    -- Activer le mode crafting si c'est un inventaire de crafting
    if currentInventory and currentInventory.type == 'crafting' then
        SendNUIMessage({
            action = 'setCraftingMode',
            data = true
        })
        
        SendNUIMessage({
            action = 'setCraftingRecipes',
            data = currentInventory.items or {}
        })
        
        SendNUIMessage({
            action = 'setLockerMode',
            data = false
        })
        LocalPlayer.state.currentLockerId = nil
        
        -- Vérifier s'il y a un craft en cours
        local craftData = lib.callback.await('ox_inventory:getActiveCraft', 200)
        if craftData then
            SendNUIMessage({
                action = 'restoreCraft',
                data = craftData
            })
        end
    -- Activer le mode locker si c'est un locker
    elseif currentInventory and currentInventory.type == 'locker' then
        SendNUIMessage({
            action = 'setCraftingMode',
            data = false
        })
        
        SendNUIMessage({
            action = 'setLockerMode',
            data = true
        })
        
        local lockerId = currentInventory.id and tonumber(currentInventory.id) or nil
        if lockerId then
            LocalPlayer.state.currentLockerId = lockerId
            local casiers = lib.callback.await('ox_inventory:getCasiersFromLocker', false, lockerId)
            if casiers then
                SendNUIMessage({
                    action = 'setLockers',
                    data = casiers
                })
                SendNUIMessage({
                    action = 'setCurrentLockerId',
                    data = lockerId
                })
            end
        end
    elseif currentInventory and currentInventory.type == 'stash' and currentInventory.id and currentInventory.id:find('^locker_casier_') then
        SendNUIMessage({
            action = 'setCraftingMode',
            data = false
        })
        
        SendNUIMessage({
            action = 'setLockerMode',
            data = true
        })
    else
        SendNUIMessage({
            action = 'setCraftingMode',
            data = false
        })
        
        SendNUIMessage({
            action = 'setLockerMode',
            data = false
        })
        LocalPlayer.state.currentLockerId = nil
    end
    
    Wait(100)
    
    local refreshItems = {}
    for i = 1, 17 do
        if clothingSlots[i] and clothingSlots[i].name then
            table.insert(refreshItems, {
                item = clothingSlots[i],
                inventory = 'clothing'
            })
        end
    end
    
    if #refreshItems > 0 then
        SendNUIMessage({
            action = 'refreshSlots',
            data = {
                items = refreshItems
            }
        })
    end

    updateHUDStats()

	UtilPeds.start()

    if not currentInventory.coords and not inv == 'container' then
        currentInventory.coords = GetEntityCoords(playerPed)
    end

    if inv == 'trunk' then
        SetTimeout(200, function()
            ---@todo animation for vans?
            Utils.PlayAnim(0, 'anim@heists@prison_heiststation@cop_reactions', 'cop_b_idle', 3.0, 3.0, -1, 49, 0.0, 0, 0, 0)

            local entity = data.entity or NetworkGetEntityFromNetworkId(data.netid)
            currentInventory.entity = entity
            currentInventory.door = data.door

            if not currentInventory.door then
                local vehicleHash = GetEntityModel(entity)
                local vehicleClass = GetVehicleClass(entity)
                currentInventory.door = vehicleClass == 12 and { 2, 3 } or Vehicles.Storage[vehicleHash] and 4 or 5
            end

            while currentInventory and currentInventory.entity == entity and invOpen and DoesEntityExist(entity) and Inventory.CanAccessTrunk(entity) do
                Wait(100)
            end

            if invOpen then client.closeInventory() end
        end)
    end

	local success, err = pcall(function()
		if currentInventory.type ~= 'crafting'
			and currentInventory.type ~= 'shop'
			and currentInventory.type ~= 'locker'
			and not (currentInventory.type == 'stash' and currentInventory.id and currentInventory.id:find('^locker_casier_')) then
			PedScreenCreate(playerPed, {
				dict = "anim@amb@nightclub@peds@", 
				anim = "rcmme_amanda1_stand_loop_cop"
			})
			UtilPeds.start()
		end
	end)
    
    SendNUIMessage({
        action = 'requestBodyImagePreference'
    })

    return true
end

RegisterNetEvent('ox_inventory:openInventory', client.openInventory)
exports('openInventory', client.openInventory)

RegisterNetEvent('ox_inventory:forceOpenInventory', function(left, right)
	if source == '' then return end

	plyState.invOpen = true
	TriggerEvent("berry:ui:closeAll", "inventory")

	SetNuiFocus(true, true)
	SetNuiFocusKeepInput(true)
	closeTrunk()

	if client.screenblur then TriggerScreenblurFadeIn(0) end

	currentInventory = right or defaultInventory
	currentInventory.ignoreSecurityChecks = true
	left.items = filterPlayerInventoryForUi(PlayerData.inventory)
	left.groups = PlayerData.groups

	local clothingSlots = lib.callback.await('ox_inventory:getClothingSlots', false) or {}
	sendServerThemeUpdate()

	SendNUIMessage({
		action = 'setupInventory',
		data = {
			leftInventory = left,
			rightInventory = currentInventory,
			centerInventory = {
				id = 'clothing',
				type = 'clothing',
				slots = 17,
				maxWeight = 0,
				items = clothingSlots
			}
		}
	})
	
	Wait(100)
	
	local refreshItems = {}
	for i = 1, 17 do
		if clothingSlots[i] and clothingSlots[i].name then
			table.insert(refreshItems, {
				item = clothingSlots[i],
				inventory = 'clothing'
			})
		end
	end
	
	if #refreshItems > 0 then
		SendNUIMessage({
			action = 'refreshSlots',
			data = {
				items = refreshItems
			}
		})
	end

	updateHUDStats()

	if currentInventory.type ~= 'crafting' and currentInventory.type ~= 'shop' then
		PedScreenCreate(playerPed, {
			dict = "anim@amb@nightclub@peds@", 
			anim = "rcmme_amanda1_stand_loop_cop"
		})
		UtilPeds.start()
	end
end)

local Animations = lib.load('data.animations')
local Items = require 'modules.items.client'
local usingItem = false

local function normalizePropModel(model)
	if type(model) == 'string' then
		return joaat(model)
	end
	return model
end

local function isValidPropModel(model)
	return type(model) == 'number' and IsModelInCdimage(model) and IsModelValid(model)
end

local function sanitizeProp(prop)
	if not prop then return nil end

	if type(prop) == 'number' or type(prop) == 'string' then
		local model = normalizePropModel(prop)
		if not isValidPropModel(model) then return nil end
		return { model = model }
	end

	if prop.model then
		local model = normalizePropModel(prop.model)
		if not isValidPropModel(model) then return nil end
		local copy = {}
		for k, v in pairs(prop) do copy[k] = v end
		copy.model = model
		return copy
	end

	if prop[1] then
		local cleaned = {}
		for i = 1, #prop do
			local p = prop[i]
			if p and p.model then
				local model = normalizePropModel(p.model)
				if isValidPropModel(model) then
					local copy = {}
					for k, v in pairs(p) do copy[k] = v end
					copy.model = model
					cleaned[#cleaned + 1] = copy
				end
			end
		end
		return #cleaned > 0 and cleaned or nil
	end

	return prop
end

---@param data { name: string, label: string, count: number, slot: number, metadata: table<string, any>, weight: number }
lib.callback.register('ox_inventory:usingItem', function(data, noAnim)
	local item = Items[data.name]

	if item and usingItem then
		if not item.client then return true end
		---@cast item +OxClientProps
		item = item.client

		if type(item.anim) == 'string' then
			item.anim = Animations.anim[item.anim]
		end

		if item.prop then
			if item.prop[1] then
				for i = 1, #item.prop do
					if type(item.prop) == 'string' then
						item.prop = Animations.prop[item.prop[i]]
					end
				end
			elseif type(item.prop) == 'string' then
				item.prop = Animations.prop[item.prop]
			end
		end

		if not item.disable then
			item.disable = { combat = true }
		elseif item.disable.combat == nil then
			-- Backwards compatibility; you probably don't want people shooting while eating and bandaging anyway
			item.disable.combat = true
		end

		local prop = sanitizeProp(item.prop)
		local success = (not item.usetime or noAnim or lib.progressBar({
			duration = item.usetime,
			label = item.label or locale('using', data.metadata.label or data.label),
			useWhileDead = item.useWhileDead,
			canCancel = item.cancel,
			disable = item.disable,
			anim = item.anim or item.scenario,
			prop = prop --[[@as ProgressProps]]
		})) and not PlayerData.dead

		if success then
			if item.notification then
				lib.notify({ title = locale('notification_information'), description = item.notification })
			end

			if item.status then
				if client.setPlayerStatus then
					client.setPlayerStatus(item.status)
				end
			end

			return true
		end
	end
end)

local function canUseItem(isAmmo)
	local ped = cache.ped

	return not usingItem
    and (not isAmmo or currentWeapon)
	and PlayerData.loaded
	and not PlayerData.dead
	and not invBusy
	and not lib.progressActive()
	and not IsPedRagdoll(ped)
	and not IsPedFalling(ped)
    and not IsPedShooting(playerPed)
end

---@param data table
---@param cb fun(response: SlotWithItem | false)?
---@param noAnim? boolean
local function useItem(data, cb, noAnim)
	local slotData, result = PlayerData.inventory[data.slot]

	if not slotData or not canUseItem(data.ammo and true) then
        if currentWeapon then
			return notifyCannotPerform(getCannotPerformReason(data.ammo and true))
        end

        return
    end

	if currentWeapon and currentWeapon.timer ~= 0 then
        if not currentWeapon.timer or currentWeapon.timer - GetGameTimer() > 100 then return end

        DisablePlayerFiring(cache.playerId, true)
    end

    if invOpen and data.close then client.closeInventory() end

    usingItem = true
    ---@type boolean?
    result = lib.callback.await('ox_inventory:useItem', 200, data.name, data.slot, slotData.metadata, noAnim)

	if result and cb then
		local success, response = pcall(cb, result and slotData)

		if not success and response then
		end
	end

    if result then
        TriggerEvent('ox_inventory:usedItem', slotData.name, slotData.slot, next(slotData.metadata) and slotData.metadata)
    end

	Wait(500)
    usingItem = false
end

AddEventHandler('ox_inventory:usedItem', function(name, slot, metadata)
    TriggerServerEvent('ox_inventory:usedItemInternal', slot)
end)

AddEventHandler('ox_inventory:item', useItem)
exports('useItem', useItem)

---@param slot number
---@return boolean?
local function useSlot(slot, noAnim)
	local item = PlayerData.inventory[slot]
	if not item then return end

	local data = Items[item.name]
	if not data then return end
	local isAmmoItem = data.ammo or (currentWeapon and item.name == currentWeapon.ammo)

	-- Handle ammo boxes
	if item.name and string.match(item.name, '^ammobox_') then
		if item.metadata and item.metadata.ammoType and item.metadata.ammoCount then
			local playerPed = cache.ped
			local config = shared.ammo or Config.PackAmmo or { UseRProgress = false, Duration = 5000, Label = 'Ouverture en cours...' }
			
			RequestAnimDict("mp_arresting")
			while not HasAnimDictLoaded("mp_arresting") do
				Wait(0)
			end
			
			if DoesEntityExist(playerPed) and not IsEntityDead(playerPed) then
				TaskPlayAnim(playerPed, "mp_arresting", "a_uncuff", 8.0, -8.0, config.Duration, 48, 0, false, false, false)
			end
			
			local success = false
			
			if config.UseRProgress then
				exports.rprogress:_DOLI_PROGRESSBAR_START(config.Duration / 1000)
				Wait(config.Duration)
				success = true
			else
				success = lib.progressBar({
					duration = config.Duration,
					label = config.Label,
					useWhileDead = false,
					canCancel = true,
					disableControl = true,
				})
			end
			
			if success then
				lib.callback.await('ox_inventory:unpackAmmoBox', false, slot)
			end
			
			ClearPedTasks(playerPed)
			return
		end
	end

	if canUseItem(isAmmoItem and true) then
		if data.component and not currentWeapon then
			return lib.notify({ id = 'weapon_hand_required', type = 'error', title = locale('notification_weapon_required'), description = locale('weapon_hand_required') })
		end

		local consume = data.consume --[[@as number?]]

		data.slot = slot

		if item.metadata.container then
			return client.openInventory('container', item.slot)
		elseif data.client then
			if invOpen and data.close then client.closeInventory() end

			if data.export then
				return data.export(data, {name = item.name, slot = item.slot, metadata = item.metadata})
			elseif data.client.event then -- re-add it, so I don't need to deal with morons taking screenshots of errors when using trigger event
				return TriggerEvent(data.client.event, data, {name = item.name, slot = item.slot, metadata = item.metadata})
			end
		end

		if data.effect then
			data:effect({name = item.name, slot = item.slot, metadata = item.metadata})
		elseif data.weapon then
			if EnableWeaponWheel or not plyState.canUseWeapons then return end

			if IsCinematicCamRendering() then SetCinematicModeActive(false) end

			if currentWeapon then
                if not currentWeapon.timer or currentWeapon.timer ~= 0 then return end

				local weaponSlot = currentWeapon.slot
				currentWeapon = Weapon.Disarm(currentWeapon)

				if weaponSlot == data.slot then return end
			end

            GiveWeaponToPed(playerPed, data.hash, 0, false, true)
            SetCurrentPedWeapon(playerPed, data.hash, false)

            if data.hash ~= GetSelectedPedWeapon(playerPed) then
                return lib.notify({ type = 'error', title = locale('notification_use_impossible'), description = locale('cannot_use', data.label) })
            end

            RemoveWeaponFromPed(cache.ped, data.hash)

			useItem(data, function(result)
				if result then
                    local sleep
					currentWeapon, sleep = Weapon.Equip(item, data, noAnim)

					if sleep then Wait(sleep) end
				end
			end, noAnim)
		elseif currentWeapon then
			if isAmmoItem then
				if EnableWeaponWheel then return end

				local clipSize = GetMaxAmmoInClip(playerPed, currentWeapon.hash, true)
				local currentAmmo = GetAmmoInPedWeapon(playerPed, currentWeapon.hash)
				local _, maxAmmo = GetMaxAmmo(playerPed, currentWeapon.hash)

				if maxAmmo < clipSize then clipSize = maxAmmo end

				if currentAmmo == clipSize then return end

				useItem(data, function(resp)
					if not resp or not currentWeapon or resp.name ~= currentWeapon.ammo then return end

					if currentWeapon.metadata.specialAmmo ~= resp.metadata.type and type(currentWeapon.metadata.specialAmmo) == 'string' then
						local clipComponentKey = ('%s_CLIP'):format(Items[currentWeapon.name].model:gsub('WEAPON_', 'COMPONENT_'))
						local specialClip = ('%s_%s'):format(clipComponentKey, (resp.metadata.type or currentWeapon.metadata.specialAmmo):upper())

						if type(resp.metadata.type) == 'string' then
							if not HasPedGotWeaponComponent(playerPed, currentWeapon.hash, specialClip) then
								if not DoesWeaponTakeWeaponComponent(currentWeapon.hash, specialClip) then
									return
								end

								local defaultClip = ('%s_01'):format(clipComponentKey)

								if not HasPedGotWeaponComponent(playerPed, currentWeapon.hash, defaultClip) then
									return
								end

								if currentAmmo > 0 then
									return
								end

								currentWeapon.metadata.specialAmmo = resp.metadata.type

								GiveWeaponComponentToPed(playerPed, currentWeapon.hash, specialClip)
							end
						elseif HasPedGotWeaponComponent(playerPed, currentWeapon.hash, specialClip) then
							if currentAmmo > 0 then
								return
							end

							currentWeapon.metadata.specialAmmo = nil

							RemoveWeaponComponentFromPed(playerPed, currentWeapon.hash, specialClip)
						end
					end

					if maxAmmo > clipSize then
						clipSize = GetMaxAmmoInClip(playerPed, currentWeapon.hash, true)
					end

					currentAmmo = GetAmmoInPedWeapon(playerPed, currentWeapon.hash)
					local missingAmmo = clipSize - currentAmmo
					local addAmmo = resp.count > missingAmmo and missingAmmo or resp.count
					local newAmmo = currentAmmo + addAmmo

					if newAmmo == currentAmmo then return end

                    AddAmmoToPed(playerPed, currentWeapon.hash, addAmmo)

					if cache.vehicle then
						if cache.seat > -1 or IsVehicleStopped(cache.vehicle) then
							TaskReloadWeapon(playerPed, true)
                        else
                            -- This is a hacky solution for forcing ammo to properly load into the
                            -- weapon clip while driving; without it, ammo will be added but won't
                            -- load until the player stops doing anything. i.e. if you keep shooting,
                            -- the weapon will not reload until the clip empties.
                            -- And yes - for some reason RefillAmmoInstantly needs to run in a loop.
                            lib.waitFor(function()
                                RefillAmmoInstantly(playerPed)

                                local _, ammo = GetAmmoInClip(playerPed, currentWeapon.hash)
                                return ammo == newAmmo or nil
                            end)
                        end
					else
						Wait(100)
						MakePedReload(playerPed)

						SetTimeout(100, function()
							while IsPedReloading(playerPed) do
								DisableControlAction(0, 22, true)
								Wait(0)
							end
						end)
					end

					lib.callback.await('ox_inventory:updateWeapon', false, 'load', newAmmo, false, currentWeapon.metadata.specialAmmo)
				end)
			elseif data.component then
				local components = data.client.component

                if not components then return end

				local componentType = data.type
				local weaponComponents = PlayerData.inventory[currentWeapon.slot].metadata.components

				-- Checks if the weapon already has the same component type attached
				for componentIndex = 1, #weaponComponents do
					if componentType == Items[weaponComponents[componentIndex]].type then
						return lib.notify({ id = 'component_slot_occupied', type = 'error', title = locale('notification_slot_occupied'), description = locale('component_slot_occupied', componentType) })
					end
				end

				for i = 1, #components do
					local component = components[i]

					if DoesWeaponTakeWeaponComponent(currentWeapon.hash, component) then
						if HasPedGotWeaponComponent(playerPed, currentWeapon.hash, component) then
							lib.notify({ id = 'component_has', type = 'error', title = locale('notification_component_equipped'), description = locale('component_has', label) })
						else
							useItem(data, function(data)
								if data then
									local success = lib.callback.await('ox_inventory:updateWeapon', false, 'component', tostring(data.slot), currentWeapon.slot)

									if success then
										GiveWeaponComponentToPed(playerPed, currentWeapon.hash, component)
										TriggerEvent('ox_inventory:updateWeaponComponent', 'added', component, data.name)
									end
								end
							end)
						end
						return
					end
				end
				lib.notify({ id = 'component_invalid', type = 'error', title = locale('notification_incompatible_component'), description = locale('component_invalid', label) })
			elseif data.allowArmed then
				useItem(data)
            else
                return notifyCannotPerform('arme en main non autorisée')
			end
		elseif not isAmmoItem and not data.component then
			useItem(data)
		end
    end
end
exports('useSlot', useSlot)

-- Event to unpack ammo boxes
RegisterNetEvent('ox_inventory:unpackAmmoBox', function()
	local slot = lib.callback.await('ox_inventory:unpackAmmoBox', false)
end)

---@param id number
---@param slot number
local function useButton(id, slot)
	if PlayerData.loaded and not invBusy and not lib.progressActive() then
		local item = PlayerData.inventory[slot]
		if not item then return end

		local data = Items[item.name]
		local buttons = data and data.buttons

		if buttons and buttons[id] and buttons[id].action then
			buttons[id].action(slot)
		end
	end
end

local function openNearbyInventory() client.openInventory('player') end

exports('openNearbyInventory', openNearbyInventory)

local currentInstance
local playerCoords
local Shops = require 'modules.shops.client'

---@todo remove or replace when the bridge module gets restructured
function OnPlayerData(key, val)
	if key ~= 'groups' and key ~= 'ped' and key ~= 'dead' then return end

	if key == 'groups' then
		Inventory.Stashes()
		Inventory.Evidence()
		Shops.refreshShops()
	elseif key == 'dead' and val then
		currentWeapon = Weapon.Disarm(currentWeapon)
		client.closeInventory()
	end

	Utils.WeaponWheel()
end

-- People consistently ignore errors when one of the "modules" failed to load
if not Utils or not Weapon or not Items or not Inventory then return end

local invHotkeys = false
local medicTargetPed = nil
local medicModeActive = false
local medicHumanTabActive = false
local medicPedHeadingOffset = 0.0
local medicPedScreenData = {
	screenX = 0.80,
	screenY = 0.44,
	depth = 1.6,
	bufferSize = 2,
	scaleWidth = 0.5,
	upTempOffset = -0.47
}

local function startMedicPedScreen(ped)
	if not ped or not DoesEntityExist(ped) then return end
	medicHumanTabActive = true
	PedScreenCreate(ped, { dict = 'mp_sleep', anim = 'bind_pose_180' }, false, 'animation', medicPedScreenData)
end

---@type function?
local function buildMedicBodyParts(baseHealth)
	local health = math.max(0, math.min(100, tonumber(baseHealth) or 100))
	return {
		head = { health = health, pathologies = {} },
		thorax = { health = health, pathologies = {} },
		stomach = { health = health, pathologies = {} },
		['left-arm'] = { health = health, pathologies = {} },
		['right-arm'] = { health = health, pathologies = {} },
		['left-leg'] = { health = health, pathologies = {} },
		['right-leg'] = { health = health, pathologies = {} },
	}
end

local function normalizeMedicPart(part, fallback)
	if type(part) == 'number' then
		return { health = math.max(0, math.min(100, part)), pathologies = {} }
	end

	if type(part) == 'table' then
		local health = tonumber(part.health) or fallback
		local pathologies = type(part.pathologies) == 'table' and part.pathologies or {}
		return { health = math.max(0, math.min(100, health)), pathologies = pathologies }
	end

	return { health = math.max(0, math.min(100, fallback)), pathologies = {} }
end

local function normalizeMedicBodyParts(parts, baseHealth)
	if type(parts) ~= 'table' then
		return buildMedicBodyParts(baseHealth)
	end

	return {
		head = normalizeMedicPart(parts.head, baseHealth),
		thorax = normalizeMedicPart(parts.thorax or parts.torso or parts.upperBody, baseHealth),
		stomach = normalizeMedicPart(parts.stomach or parts.abdomen or parts.lowerBody or parts.torso, baseHealth),
		['left-arm'] = normalizeMedicPart(parts['left-arm'] or parts.leftArm or parts.left_arm, baseHealth),
		['right-arm'] = normalizeMedicPart(parts['right-arm'] or parts.rightArm or parts.right_arm, baseHealth),
		['left-leg'] = normalizeMedicPart(parts['left-leg'] or parts.leftLeg or parts.left_leg, baseHealth),
		['right-leg'] = normalizeMedicPart(parts['right-leg'] or parts.rightLeg or parts.right_leg, baseHealth),
	}
end

local function buildMedicData(targetServerId, targetPed)
	local ped = targetPed or cache.ped
	local maxHealth = ped and GetEntityMaxHealth(ped) or 200
	local currentHealth = ped and GetEntityHealth(ped) or maxHealth
	local healthPercent = math.floor((currentHealth / maxHealth) * 100)

	local state = targetServerId and Player(targetServerId) and Player(targetServerId).state or LocalPlayer.state
	local temperature = state.temperature or state.temp or 37
	local hydration = state.hydration or state.thirst or state.water or 0
	local food = state.food or state.hunger or 0
	local ata = state.ata or false
	local expectingRPDeath = state.expectingRPDeath or state.expecting_rp_death or false
	local diseases = type(state.diseases) == 'table' and state.diseases or {}
	local characterId = state.characterId or targetServerId or cache.serverId
	local bodyParts = normalizeMedicBodyParts(state.bodyParts, healthPercent)

	return {
		characterId = characterId,
		health = healthPercent,
		temperature = temperature,
		hydration = hydration,
		food = food,
		ata = ata,
		expectingRPDeath = expectingRPDeath,
		diseases = diseases,
		bodyParts = bodyParts
	}
end

local function openMedicForTarget(serverId, ped)
	local medicData = buildMedicData(serverId, ped)
	medicTargetPed = ped
	medicModeActive = true
	medicHumanTabActive = true

	if not invOpen then
		client.openInventory()
		CreateThread(function()
			local timeout = 0
			while not invOpen and timeout < 50 do
				Wait(20)
				timeout = timeout + 1
			end
			if invOpen then
				SendNUIMessage({ action = 'setMedicData', data = medicData })
				SendNUIMessage({ action = 'setMedicMode', data = true })
				startMedicPedScreen(ped)
			end
		end)
	else
		SendNUIMessage({ action = 'setMedicData', data = medicData })
		SendNUIMessage({ action = 'setMedicMode', data = true })
		startMedicPedScreen(ped)
	end
end

local function resolveMedicTarget(contextServerId)
	if contextServerId then
		local player = GetPlayerFromServerId(tonumber(contextServerId))
		if player and player ~= -1 then
			local ped = GetPlayerPed(player)
			if ped and ped ~= 0 and DoesEntityExist(ped) and #(GetEntityCoords(cache.ped) - GetEntityCoords(ped)) <= 2.5 then
				return tonumber(contextServerId), ped
			end
		end
	end

	local targetId, targetPed = Utils.GetClosestPlayer()
	local targetServerId = targetId and GetPlayerServerId(targetId)
	if targetPed and targetServerId and #(GetEntityCoords(cache.ped) - GetEntityCoords(targetPed)) <= 2.5 then
		return targetServerId, targetPed
	end

	return nil, nil
end

local pendingMedicalContext = {}

local medicalEffects = {
	bandage = { heal = 20, notify = 'Bandage appliqué' },
	medikit = { full = true, notify = 'Trousse de soins utilisée' },
	icebag = { heal = 12, notify = 'Sac de glace appliqué', clear = true },
	pommade = { heal = 10, notify = 'Pommade appliquée', clear = true }
}

local function getMedicalContext(itemName)
	local context = pendingMedicalContext[itemName]
	if not context then return nil end

	if context.expiresAt and context.expiresAt < GetGameTimer() then
		pendingMedicalContext[itemName] = nil
		return nil
	end

	pendingMedicalContext[itemName] = nil
	return context
end

local function notifyMedical(message, notifyType)
	if lib and lib.notify then
		lib.notify({
			title = 'Soins',
			description = message,
			type = notifyType or 'success'
		})
		return
	end

	if Notification then
		Notification(nil, message, 3500)
		return
	end

	TriggerEvent('esx:showNotification', message)
end

local medicalMeMessages = {
	bandage = {
		self = 'se pose un bandage',
		target = 'pose un bandage sur la personne'
	},
	medikit = {
		self = 'utilise une trousse de soins',
		target = 'utilise une trousse de soins sur la personne'
	},
	icebag = {
		self = 'applique un sac de glace',
		target = 'applique un sac de glace sur la personne'
	},
	pommade = {
		self = 'applique de la pommade',
		target = 'applique de la pommade sur la personne'
	}
}

local function playMedicalUseRoleplay(itemName, onTarget)
	local ped = cache.ped
	if not ped or ped == 0 or not DoesEntityExist(ped) then
		return true
	end

	lib.requestAnimDict('mp_common')
	TaskPlayAnim(ped, 'mp_common', 'givetake1_a', 8.0, -8.0, 1200, 49, 0.0, false, false, false)

	local success = true
	if GetResourceState('rprogress') == 'started' and exports.rprogress and exports.rprogress._DOLI_PROGRESSBAR_START then
		exports.rprogress:_DOLI_PROGRESSBAR_START(1.2)
		Wait(1200)
	else
		success = lib.progressBar({
			duration = 1200,
			label = 'Application en cours...',
			useWhileDead = false,
			canCancel = true,
			disable = {
				combat = true,
				car = true,
				move = true,
			}
		})
	end

	StopAnimTask(ped, 'mp_common', 'givetake1_a', 1.0)

	if not success then
		return false
	end

	local entry = medicalMeMessages[itemName]
	local meMessage = entry and (onTarget and entry.target or entry.self) or 'se soigne'
	TriggerServerEvent('lpF1:3dme:display', meMessage)

	return true
end

local function applyMedicalEffect(itemName)
	local effect = medicalEffects[itemName]
	if not effect then return false end

	local ped = cache.ped
	if not ped or ped == 0 or not DoesEntityExist(ped) then
		return false
	end

	local maxHealth = GetEntityMaxHealth(ped)
	if not maxHealth or maxHealth <= 0 then
		maxHealth = 200
	end

	local health = GetEntityHealth(ped)
	if effect.full then
		health = maxHealth
	else
		health = math.min(maxHealth, health + (effect.heal or 0))
	end

	SetEntityHealth(ped, health)

	if effect.clear then
		ClearPedBloodDamage(ped)
		ResetPedVisibleDamage(ped)
	end

	notifyMedical(effect.notify or 'Soin appliqué', 'success')
	return true
end

local function handleMedicalItemUse(itemName)
	if invBusy or not canOpenInventory() then
		return notifyMedical(locale('inventory_player_access'), 'error')
	end

	local context = getMedicalContext(itemName)
	local targetId = context and context.contextTarget or nil

	if targetId then
		local targetServerId, targetPed = resolveMedicTarget(targetId)
		if not targetServerId or not targetPed then
			return notifyMedical(locale('nobody_nearby'), 'error')
		end

		if not playMedicalUseRoleplay(itemName, true) then
			return
		end

		TriggerServerEvent('ox_inventory:applyMedicalItemOnTarget', targetServerId, itemName)
		return
	end

	if not playMedicalUseRoleplay(itemName, false) then
		return
	end

	applyMedicalEffect(itemName)
end

RegisterNetEvent('ox_inventory:useBandage', function()
	handleMedicalItemUse('bandage')
end)

RegisterNetEvent('ox_inventory:useMedikit', function()
	handleMedicalItemUse('medikit')
end)

RegisterNetEvent('ox_inventory:useIcebag', function()
	handleMedicalItemUse('icebag')
end)

RegisterNetEvent('ox_inventory:usePommade', function()
	handleMedicalItemUse('pommade')
end)

RegisterNetEvent('ox_inventory:contextUseMedicalItem', function(payload)
	if type(payload) ~= 'table' then return end

	local itemName = payload.itemName
	if type(itemName) ~= 'string' or itemName == '' then return end

	if not exports.ox_inventory or not exports.ox_inventory.Search or not exports.ox_inventory.useSlot then
		return
	end

	local slots = exports.ox_inventory:Search('slots', itemName)
	if type(slots) ~= 'table' then
		return notifyMedical(('Vous n\'avez pas %s'):format(itemName), 'error')
	end

	for _, slotData in pairs(slots) do
		if slotData and slotData.slot and (slotData.count or 0) > 0 then
			pendingMedicalContext[itemName] = {
				contextTarget = payload.contextTarget,
				expiresAt = GetGameTimer() + 7000
			}
			exports.ox_inventory:useSlot(slotData.slot)
			return
		end
	end

	notifyMedical(('Vous n\'avez pas %s'):format(itemName), 'error')
end)

RegisterNetEvent('ox_inventory:medicalItemEffect', function(itemName)
	applyMedicalEffect(itemName)
end)

RegisterNetEvent('ox_inventory:medicalItemFeedback', function(message)
	if type(message) == 'string' and message ~= '' then
		notifyMedical(message, 'success')
	end
end)

RegisterNetEvent('ox_inventory:useStethoscope', function(payload)
	if invBusy or not canOpenInventory() then
		return lib.notify({ id = 'inventory_player_access', type = 'error', title = locale('notification_access_denied'), description = locale('inventory_player_access') })
	end

	local targetServerId, targetPed = resolveMedicTarget(type(payload) == 'table' and payload.contextTarget or nil)
	if not targetServerId or not targetPed then
		return lib.notify({ type = 'error', title = locale('notification_error'), description = locale('nobody_nearby') })
	end

	ExecuteCommand('e mechanic4')

	local success = false
	if GetResourceState('rprogress') == 'started' then
		exports.rprogress:Start('Examen en cours...', 2000)
		success = true
	else
		success = lib.progressBar({
			duration = 2000,
			label = 'Examen en cours...',
			useWhileDead = false,
			canCancel = true,
			disableControl = true,
		})
	end

	ExecuteCommand('emotecancel')

	if not success then return end

	openMedicForTarget(targetServerId, targetPed)
end)

RegisterNetEvent('ox_inventory:useStretcher1', function()
	if invBusy or not canOpenInventory() then
		return lib.notify({ id = 'inventory_player_access', type = 'error', title = locale('notification_access_denied'), description = locale('inventory_player_access') })
	end

	local ped = PlayerPedId()
	if IsPedInAnyVehicle(ped, false) then
		return lib.notify({ type = 'error', title = locale('notification_error'), description = 'Vous ne pouvez pas sortir un brancard depuis un véhicule.' })
	end

	local forward = GetEntityForwardVector(ped)
	local spawnCoords = GetEntityCoords(ped) + (forward * 1.8)
	TriggerServerEvent('ContextMenu:Stretcher:SpawnFromItem', spawnCoords, GetEntityHeading(ped))
end)

local function registerCommands()
	RegisterCommand('steal', openNearbyInventory, false)

	local function openGlovebox(vehicle)
		if not IsPedInAnyVehicle(playerPed, false) or not NetworkGetEntityIsNetworked(vehicle) then return end

		local vehicleHash = GetEntityModel(vehicle)
		local vehicleClass = GetVehicleClass(vehicle)
		local checkVehicle = Vehicles.Storage[vehicleHash]

		-- No storage or no glovebox
		if (checkVehicle == 0 or checkVehicle == 2) or (not Vehicles.glovebox[vehicleClass] and not Vehicles.glovebox.models[vehicleHash]) then return end

		local isOpen = client.openInventory('glovebox', { netid = NetworkGetNetworkIdFromEntity(vehicle) })

		if isOpen then
			currentInventory.entity = vehicle
		end
	end

	local primary = lib.addKeybind({
		name = 'inv',
		description = locale('open_player_inventory'),
		defaultKey = client.keys[1],
		onPressed = function()
			if invOpen then
				return client.closeInventory()
			end

			if cache.vehicle then
				return openGlovebox(cache.vehicle)
			end

			local closest = lib.points.getClosestPoint()

			if closest and closest.currentDistance < 1.2 and (not closest.instance or closest.instance == currentInstance) then
				if closest.inv == 'crafting' then
					return client.openInventory('crafting', { id = closest.id, index = closest.index })
				elseif closest.inv ~= 'license' and closest.inv ~= 'policeevidence' then
					return client.openInventory(closest.inv or 'drop', { id = closest.invId, type = closest.type })
				end
			end

			return client.openInventory()
		end
	})

	lib.addKeybind({
		name = 'inv2',
		description = locale('open_secondary_inventory'),
		defaultKey = client.keys[2],
		onPressed = function(self)
            if primary:getCurrentKey() == self:getCurrentKey() then
				return
            end

			if invOpen then
				return client.closeInventory()
			end

			if invBusy or not canOpenInventory() then
				return lib.notify({ id = 'inventory_player_access', type = 'error', title = locale('notification_access_denied'), description = locale('inventory_player_access') })
			end

			if StashTarget then
				return client.openInventory('stash', StashTarget)
			end

			if cache.vehicle then
				return openGlovebox(cache.vehicle)
			end

			local entity, entityType = Utils.Raycast(2|16)

			if not entity then return end

			if not shared.target and entityType == 3 then
				local model = GetEntityModel(entity)

				if Inventory.Dumpsters:includes(model) then
					return Inventory.OpenDumpster(entity)
				end
			end

			if entityType ~= 2 then return end

			Inventory.OpenTrunk(entity)
		end
	})

	lib.addKeybind({
		name = 'reloadweapon',
		description = locale('reload_weapon'),
		defaultKey = 'r',
		onPressed = function(self)
			if not currentWeapon or EnableWeaponWheel or not canUseItem(true) then return end

			if currentWeapon.ammo then
				local slotId = Inventory.GetSlotIdWithItem(currentWeapon.ammo, { type = currentWeapon.metadata.specialAmmo }, false)

				if slotId then
					useSlot(slotId)
				end
			end
		end
	})


	registerCommands = nil
end

function client.closeInventory(server)
	-- because somehow people are triggering this when the inventory isn't loaded
	-- and they're incapable of debugging, and I can't repro on a fresh install
	if not client.interval then
		if client.screenblur then TriggerScreenblurFadeOut(0) end
		return
	end

	if invOpen then
		invOpen = nil
		SetNuiFocus(false, false)
		SetNuiFocusKeepInput(false)
		if client.screenblur then TriggerScreenblurFadeOut(0) end
		closeTrunk()
		PedScreenDelete()
		UtilPeds.stop()
		medicTargetPed = nil
		medicModeActive = false
		medicHumanTabActive = false
		medicPedHeadingOffset = 0.0
		
		-- Nettoyage complet de l'arme preview
		cleanupWeaponPreview()
		
		SendNUIMessage({ action = 'closeInventory' })
		Wait(200)

		if invOpen ~= nil then return end

		if not server and currentInventory then
			TriggerServerEvent('ox_inventory:closeInventory')
		end

		currentInventory = nil
		plyState.invOpen = false
		defaultInventory.coords = nil
	elseif client.screenblur then
		TriggerScreenblurFadeOut(0)
	end
end

RegisterNetEvent('ox_inventory:closeInventory', function(server)
	client.closeInventory(server)
	-- Ensure weapon preview is cleaned up on any close event
	if cleanupWeaponPreview then
		cleanupWeaponPreview()
	end
end)
exports('closeInventory', client.closeInventory)

---@param data updateSlot[]
---@param weight number
local function updateInventory(data, weight)
	local changes = {}
    ---@type table<string, number>
	local itemCount = {}

	for i = 1, #data do
		local v = data[i]

		if not v.inventory or v.inventory == cache.serverId then
			v.inventory = 'player'
			local item = v.item

			if currentWeapon and item and currentWeapon.slot == item.slot then
                if item.metadata then
				    currentWeapon.metadata = item.metadata
				    TriggerEvent('ox_inventory:currentWeapon', currentWeapon)
                else
                    currentWeapon = Weapon.Disarm(currentWeapon, true)
                end
			end

			local curItem = PlayerData.inventory[item.slot]

			if curItem and curItem.name then
				itemCount[curItem.name] = (itemCount[curItem.name] or 0) - curItem.count
			end

			if item.count then
				itemCount[item.name] = (itemCount[item.name] or 0) + item.count
			end

			changes[item.slot] = item.count and item or false
			if not item.count then item.name = nil end
			PlayerData.inventory[item.slot] = item.name and item or nil
		end
	end

	local uiItems = sanitizeUiUpdateItems(data)
	SendNUIMessage({ action = 'refreshSlots', data = { items = uiItems, itemCount = itemCount} })

    if weight ~= PlayerData.weight then client.setPlayerData('weight', weight) end

	for itemName, count in pairs(itemCount) do
		local item = Items(itemName)

        if item then
            item.count += count

            TriggerEvent('ox_inventory:itemCount', item.name, item.count)

            if count < 0 then
                if shared.framework == 'esx' then
                    TriggerEvent('esx:removeInventoryItem', item.name, item.count)
                end

                if item.client and item.client.remove then
                    item.client.remove(item.count)
                end
            elseif count > 0 then
                if shared.framework == 'esx' then
                    TriggerEvent('esx:addInventoryItem', item.name, item.count)
                end

                if item.client and item.client.add then
                    item.client.add(item.count)
                end
            end
        end
	end

	client.setPlayerData('inventory', PlayerData.inventory)
	TriggerEvent('ox_inventory:updateInventory', changes)
end

RegisterNetEvent('ox_inventory:updateSlots', function(items, weights)
	if source ~= '' and items and next(items) then updateInventory(items, weights) end
end)

RegisterNetEvent('ox_inventory:inventoryReturned', function(data)
	if source == '' then return end
	if currentWeapon then currentWeapon = Weapon.Disarm(currentWeapon) end

	lib.notify({ title = locale('notification_items_returned'), type = 'success', description = locale('items_returned') })
	client.closeInventory()

	local num, items = 0, {}

	for _, slotData in pairs(data[1]) do
		num += 1
		items[num] = { item = slotData, inventory = cache.serverId }
	end

	updateInventory(items, data[3])
end)

RegisterNetEvent('ox_inventory:inventoryConfiscated', function(message)
	if source == '' then return end
	if message then lib.notify({ title = locale('notification_items_confiscated'), type = 'error', description = locale('items_confiscated') }) end
	if currentWeapon then currentWeapon = Weapon.Disarm(currentWeapon) end

	client.closeInventory()

	local num, items = 0, {}

	for slot in pairs(PlayerData.inventory) do
		num += 1
		items[num] = { item = { slot = slot }, inventory = cache.serverId }
	end

	updateInventory(items, 0)
end)


---@param point CPoint
local function nearbyDrop(point)
	if not point.instance or point.instance == currentInstance then
        DrawMarker(client.dropmarker.type, point.coords.x, point.coords.y, point.coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, client.dropmarker.scale[1], client.dropmarker.scale[2], client.dropmarker.scale[3],
        ---@diagnostic disable-next-line: param-type-mismatch
        client.dropmarker.colour[1], client.dropmarker.colour[2], client.dropmarker.colour[3], 222, false, false, 0, true, false, false, false)
    end
end

---@param point CPoint
local function onEnterDrop(point)
	if not point.instance or point.instance == currentInstance and not point.entities then
		point.entities = {}
		
		if point.items and next(point.items) then
			local slotsPerRow = math.ceil(math.sqrt(point.slots or 50))
			
			for slot, item in pairs(point.items) do
				if item and item.name then
					local itemData = ItemList[item.name]
					local model = itemData and itemData.prop or client.dropmodel
					
					if not IsModelValid(model) and not IsModelInCdimage(model) then
						model = client.dropmodel
					end
					
					lib.requestModel(model)
					
					local row = math.floor((slot - 1) / slotsPerRow)
					local col = (slot - 1) % slotsPerRow
					local offsetX = (col - slotsPerRow / 2) * 0.15
					local offsetY = (row - slotsPerRow / 2) * 0.15
					
					local entity = CreateObject(model, point.coords.x + offsetX, point.coords.y + offsetY, point.coords.z, false, true, true)
					
					SetModelAsNoLongerNeeded(model)
					
					if itemData and itemData.weapon then
						SetEntityRotation(entity, 90.0, 0.0, 0.0, 2, true)
						local found, groundZ = GetGroundZFor_3dCoord(point.coords.x + offsetX, point.coords.y + offsetY, point.coords.z + 10.0, false)
						if found then
							local currentCoords = GetEntityCoords(entity)
							SetEntityCoords(entity, currentCoords.x, currentCoords.y, groundZ, false, false, true, false)
						end
					else
						PlaceObjectOnGroundProperly(entity)
					end
					
					FreezeEntityPosition(entity, true)
					SetEntityCollision(entity, false, true)
					
					point.entities[#point.entities + 1] = entity
				end
			end
		else
			local model = point.model or client.dropmodel
			
			if not IsModelValid(model) and not IsModelInCdimage(model) then
				model = client.dropmodel
			end
			
			lib.requestModel(model)
			local entity = CreateObject(model, point.coords.x, point.coords.y, point.coords.z, false, true, true)
			
			SetModelAsNoLongerNeeded(model)
			PlaceObjectOnGroundProperly(entity)
			FreezeEntityPosition(entity, true)
			SetEntityCollision(entity, false, true)
			
			point.entities[#point.entities + 1] = entity
		end
	end
end

local function onExitDrop(point)
	local entities = point.entities

	if entities then
		for i = 1, #entities do
			Utils.DeleteEntity(entities[i])
		end
		point.entities = nil
	end
end

local function createDrop(dropId, data)
	local point = lib.points.new({
		coords = data.coords,
		distance = 16,
		invId = dropId,
		instance = data.instance,
		model = data.model,
		items = data.items,
		slots = data.slots,
	})

	if point.model or client.dropprops or (data.items and next(data.items)) then
		point.distance = 30
		point.onEnter = onEnterDrop
		point.onExit = onExitDrop
	else
		point.nearby = nearbyDrop
	end

	client.drops[dropId] = point
end

RegisterNetEvent('ox_inventory:createDrop', function(dropId, data, owner, slot)
	if client.drops then
		createDrop(dropId, data)
	end

	if owner == cache.serverId then
		if currentWeapon and currentWeapon.slot == slot then
			currentWeapon = Weapon.Disarm(currentWeapon)
		end

		if invOpen and #(GetEntityCoords(playerPed) - data.coords) <= 1 then
			if not cache.vehicle then
				client.openInventory('drop', dropId)
			else
				SendNUIMessage({
					action = 'setupInventory',
					data = { rightInventory = currentInventory }
				})
			end
		end
	end
end)

RegisterNetEvent('ox_inventory:removeDrop', function(dropId)
	if client.drops then
		local point = client.drops[dropId]

		if point then
			client.drops[dropId] = nil
			point:remove()

			if point.entities then
				for i = 1, #point.entities do
					Utils.DeleteEntity(point.entities[i])
				end
			end
		end
	end
end)

RegisterNetEvent('ox_inventory:updateDrop', function(dropId, items)
	if client.drops then
		local point = client.drops[dropId]
		
		if point then
			if point.entities then
				for i = 1, #point.entities do
					Utils.DeleteEntity(point.entities[i])
				end
				point.entities = nil
			end
			
			point.items = items
			
			if not point.instance or point.instance == currentInstance then
				onEnterDrop(point)
			end
		end
	end
end)

---@type function?
local function setStateBagHandler(stateId)
	AddStateBagChangeHandler('invOpen', stateId, function(_, _, value)
		invOpen = value
	end)

	AddStateBagChangeHandler('invBusy', stateId, function(_, _, value)
		invBusy = value
	end)

    AddStateBagChangeHandler('canUseWeapons', stateId, function(_, _, value)
        if not value and currentWeapon then
            currentWeapon = Weapon.Disarm(currentWeapon)
        end
    end)

	AddStateBagChangeHandler('instance', stateId, function(_, _, value)
		currentInstance = value

		if client.drops then
			-- Iterate over known drops and remove any points in a different instance (ignoring no instance)
			for dropId, point in pairs(client.drops) do
				if point.instance then
					if point.instance ~= value then
						if point.entity then
							Utils.DeleteEntity(point.entity)
							point.entity = nil
						end

						point:remove()
					else
						-- Recreate the drop using data from the old point
						createDrop(dropId, point)
					end
				end
			end
		end
	end)

	AddStateBagChangeHandler('dead', stateId, function(_, _, value)
		Utils.WeaponWheel()
		PlayerData.dead = value
	end)

	AddStateBagChangeHandler('invHotkeys', stateId, function(_, _, value)
		invHotkeys = value
	end)

	setStateBagHandler = nil
end

lib.onCache('seat', function(seat)
	if seat then
		local hasWeapon = GetCurrentPedVehicleWeapon(cache.ped)

		if hasWeapon then
			return Utils.WeaponWheel(true)
		end
	end

	Utils.WeaponWheel(false)
end)

lib.onCache('vehicle', function(vehicle)
	if invOpen and (not currentInventory.entity or currentInventory.entity == cache.vehicle) then
		client.closeInventory()
	end

	if vehicle then
		if currentWeapon then
			savedWeapon = {
				slot = currentWeapon.slot,
				name = currentWeapon.name,
				hash = currentWeapon.hash,
				metadata = table.clone(currentWeapon.metadata or {})
			}
			currentWeapon = Weapon.Disarm(currentWeapon, true)
		end
	else
		if savedWeapon then
			CreateThread(function()
				Wait(500)
				if not cache.vehicle and savedWeapon and PlayerData.inventory[savedWeapon.slot] then
					local item = PlayerData.inventory[savedWeapon.slot]
					if item and item.name == savedWeapon.name then
						useSlot(savedWeapon.slot, true)
					end
				end
				savedWeapon = nil
			end)
		end
	end
end)

RegisterNetEvent('ox_inventory:setPlayerInventory', function(currentDrops, inventory, weight, player)
	if source == '' then return end

    ---@class PlayerData
    ---@field inventory table<number, SlotWithItem?>
    ---@field weight number
    ---@field groups table<string, number>
	PlayerData = player
	PlayerData.id = cache.playerId
	PlayerData.source = cache.serverId
    PlayerData.maxWeight = shared.playerweight

	setmetatable(PlayerData, {
		__index = function(self, key)
			if key == 'ped' then
				return PlayerPedId()
			end
		end
	})

	if setStateBagHandler then setStateBagHandler(('player:%s'):format(cache.serverId)) end

	local ItemData = table.create(0, #Items)

	for _, v in pairs(Items --[[@as table<string, OxClientItem>]]) do
		local buttons = v.buttons and {} or nil

		if buttons then
			for i = 1, #v.buttons do
				buttons[i] = {label = v.buttons[i].label, group = v.buttons[i].group}
			end
		end

		ItemData[v.name] = {
			label = v.label,
			stack = v.stack,
			close = v.close,
			count = 0,
			description = v.description,
			buttons = buttons,
			ammoName = v.ammoname,
			image = v.client and v.client.image or nil,
			rarity = v.rarity
		}
	end

	for _, data in pairs(inventory) do
		local item = Items[data.name]

		if item then
			item.count += data.count
			ItemData[data.name].count += data.count
			local add = item.client and item.client.add

			if add then
				add(item.count)
			end
		end
	end

	local phone = Items.phone

	if phone and phone.count < 1 then
		pcall(function()
			return exports.npwd:setPhoneDisabled(true)
		end)
	end

	client.setPlayerData('inventory', inventory)
	client.setPlayerData('weight', weight)
	currentWeapon = nil
	Weapon.ClearAll()

	local uiLocales = buildUiLocales()

	client.drops = currentDrops

	for dropId, data in pairs(currentDrops) do
		createDrop(dropId, data)
	end

	local hasTextUi
	local uiOptions = { icon = 'fa-id-card' }

	---@param point CPoint
	local function nearbyLicense(point)
		---@diagnostic disable-next-line: param-type-mismatch
		DrawMarker(2, point.coords.x, point.coords.y, point.coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.3, 0.2, 0.15, 30, 150, 30, 222, false, false, 0, true, false, false, false)

		if point.isClosest and point.currentDistance < 1.2 then
			if not hasTextUi then
				hasTextUi = point
				lib.showTextUI(point.message, uiOptions)
			end

			if IsControlJustReleased(0, 38) then
				lib.callback('ox_inventory:buyLicense', 1000, function(success, message)
					if success ~= nil then
						lib.notify({
							id = message,
							type = success == false and 'error' or 'success',
							title = success == false and locale('notification_error') or locale('notification_license'),
							description = locale(message, locale('license', point.type:gsub("^%l", string.upper)))
						})
					end
				end, point.invId)
			end
		elseif hasTextUi == point then
			hasTextUi = false
			lib.hideTextUI()
		end
	end

	for id, data in pairs(lib.load('data.licenses') or {}) do
		lib.points.new({
			coords = data.coords,
			distance = 16,
			inv = 'license',
			type = data.name,
			price = data.price,
			invId = id,
			nearby = nearbyLicense,
			message = ('**%s**  \n%s'):format(locale('purchase_license', data.name), locale('interact_prompt', GetControlInstructionalButton(0, 38, true):sub(3)))
		})
	end

	while not client.uiLoaded do Wait(50) end

	-- Convert hex colors to RGB format for the frontend
	local rarityWithRGB = {}
	for rarityName, rarityData in pairs(shared.rarity) do
		local hex = rarityData.hex or rarityData.color
		if hex then
			-- Remove # if present
			hex = hex:gsub('^#', '')
			-- Convert hex to RGB
			local r = tonumber(hex:sub(1, 2), 16)
			local g = tonumber(hex:sub(3, 4), 16)
			local b = tonumber(hex:sub(5, 6), 16)
			rarityWithRGB[rarityName] = {
				hex = hex,
				rgb = string.format('%d, %d, %d', r, g, b)
			}
		end
	end

	SendNUIMessage({
		action = 'init',
		data = {
			locale = uiLocales,
			localeOptions = getLocaleOptions(),
			currentLocale = currentLocale,
			items = ItemData,
			leftInventory = {
				id = cache.playerId,
				slots = shared.playerslots,
				items = filterPlayerInventoryForUi(PlayerData.inventory),
				maxWeight = shared.playerweight,
			},
			imagepath = client.imagepath,
			rarity = rarityWithRGB,
			rarityEnabled = shared.rarityEnabled,
			backpackWeights = Config and Config.BackpackWeights or {}
		}
	})

	PlayerData.loaded = true

	Shops.refreshShops()
	Inventory.Stashes()
	Inventory.Evidence()

	if registerCommands then registerCommands() end

	TriggerEvent('ox_inventory:updateInventory', PlayerData.inventory)

	client.interval = CreateThread(function()
		while true do
			local needsCheck = invOpen or currentWeapon or client.parachute
			
			if needsCheck then
				Wait(250) -- Slightly increased from 200ms
				local canSteal = canOpenTarget(playerPed)

				if canSteal ~= plyState.canSteal then
					plyState:set('canSteal', canSteal, true)
				end

				if invOpen == false then
					playerCoords = GetEntityCoords(playerPed)

					if currentWeapon and IsPedUsingActionMode(playerPed) then
						SetPedUsingActionMode(playerPed, false, -1, 'DEFAULT_ACTION')
					end

				elseif invOpen == true then
					if not canOpenInventory() then
						client.closeInventory()
					else
						playerCoords = GetEntityCoords(playerPed)

						if currentInventory and not currentInventory.ignoreSecurityChecks then
							local maxDistance = (currentInventory.distance or currentInventory.type == 'stash' and 4.8 or 1.8) + 0.2

							if currentInventory.type == 'otherplayer' then
								local id = GetPlayerFromServerId(currentInventory.id)
								local ped = GetPlayerPed(id)
								local pedCoords = GetEntityCoords(ped)

								if not id or #(playerCoords - pedCoords) > maxDistance or not (client.hasGroup(shared.police) or not Player(currentInventory.id).state.canSteal) then
									client.closeInventory()
									lib.notify({ id = 'inventory_lost_access', type = 'error', title = locale('notification_access_lost'), description = locale('inventory_lost_access') })
								else
									TaskTurnPedToFaceCoord(playerPed, pedCoords.x, pedCoords.y, pedCoords.z, 50)
								end

							elseif currentInventory.coords and (#(playerCoords - currentInventory.coords) > maxDistance or canSteal) then
								client.closeInventory()
								lib.notify({ id = 'inventory_lost_access', type = 'error', title = locale('notification_access_lost'), description = locale('inventory_lost_access') })
							end
						end
					end
				end

				if client.parachute and GetPedParachuteState(playerPed) ~= -1 then
					Utils.DeleteEntity(client.parachute[1])
					client.parachute = false
				end

				if not EnableWeaponWheel then
					local weaponHash = GetSelectedPedWeapon(playerPed)

					if currentWeapon then
						if weaponHash ~= currentWeapon.hash and currentWeapon.timer then
							local weaponCount = Items[currentWeapon.name] and Items[currentWeapon.name].count or 0

							if weaponCount > 0 then
								SetCurrentPedWeapon(playerPed, currentWeapon.hash, true)
								SetAmmoInClip(playerPed, currentWeapon.hash, currentWeapon.metadata.ammo)
								SetPedCurrentWeaponVisible(playerPed, true, false, false, false)

								weaponHash = GetSelectedPedWeapon(playerPed)
							end

							if weaponHash ~= currentWeapon.hash then
								currentWeapon = Weapon.Disarm(currentWeapon, true)
							end
						end
					elseif client.weaponmismatch and not client.ignoreweapons[weaponHash] then
						local weaponType = GetWeapontypeGroup(weaponHash)

						if weaponType ~= 0 and weaponType ~= `GROUP_UNARMED` then
							Weapon.Disarm(currentWeapon, true)
						end
					end
				end
			else
				Wait(1000)
				local canSteal = canOpenTarget(playerPed)
				if canSteal ~= plyState.canSteal then
					plyState:set('canSteal', canSteal, true)
				end
			end
		end
	end)

	local playerId = cache.playerId
	local EnableKeys = client.enablekeys
	local DisablePlayerVehicleRewards = DisablePlayerVehicleRewards
	local DisableAllControlActions = DisableAllControlActions
	local HideHudAndRadarThisFrame = HideHudAndRadarThisFrame
	local EnableControlAction = EnableControlAction
	local DisablePlayerFiring = DisablePlayerFiring
	local HudWeaponWheelIgnoreSelection = HudWeaponWheelIgnoreSelection
	local DisableControlAction = DisableControlAction
	local IsPedShooting = IsPedShooting
	local IsControlJustReleased = IsControlJustReleased

	client.tick = CreateThread(function()
		while true do
			local shouldTick = invOpen or invBusy or usingItem or currentWeapon or IsPedCuffed(playerPed)
			
			if shouldTick then
				Wait(0)
				DisablePlayerVehicleRewards(playerId)

				if invOpen then
					DisableAllControlActions(0)
					HideHudAndRadarThisFrame()

					for i = 1, #EnableKeys do
						EnableControlAction(0, EnableKeys[i], true)
					end

					if currentInventory and currentInventory.type == 'newdrop' then
						EnableControlAction(0, 30, true)
						EnableControlAction(0, 31, true)
					end
				else
					if invBusy then
						DisableControlAction(0, 23, true)
						DisableControlAction(0, 36, true)
					end

					if usingItem or invOpen or IsPedCuffed(playerPed) then
						DisablePlayerFiring(playerId, true)
					end

					if not EnableWeaponWheel then
						HudWeaponWheelIgnoreSelection()
						DisableControlAction(0, 37, true)
					end

					if currentWeapon and currentWeapon.timer then
						DisableControlAction(0, 80, true)
						DisableControlAction(0, 140, true)

						if not currentWeapon.timer then
							DisablePlayerFiring(playerId, true)
						elseif client.aimedfiring and not currentWeapon.melee and currentWeapon.group ~= `GROUP_PETROLCAN` and not IsPlayerFreeAiming(playerId) then
							DisablePlayerFiring(playerId, true)
						end

						local weaponAmmo = currentWeapon.metadata.ammo

						if not invBusy and currentWeapon.timer ~= 0 and currentWeapon.timer < GetGameTimer() then
							currentWeapon.timer = 0

							if weaponAmmo then
								TriggerServerEvent('ox_inventory:updateWeapon', 'ammo', weaponAmmo)

								if client.autoreload and currentWeapon.ammo and GetAmmoInPedWeapon(playerPed, currentWeapon.hash) == 0 then
									local slotId = Inventory.GetSlotIdWithItem(currentWeapon.ammo, { type = currentWeapon.metadata.specialAmmo }, false)

									if slotId then
										CreateThread(function() useSlot(slotId) end)
									end
								end

							end
						elseif weaponAmmo then
							if IsPedShooting(playerPed) then
								local currentAmmo = GetAmmoInPedWeapon(playerPed, currentWeapon.hash)

								if currentAmmo < weaponAmmo then
									currentAmmo = (weaponAmmo < currentAmmo) and 0 or currentAmmo
									currentWeapon.metadata.ammo = currentAmmo
								end

								if currentAmmo <= 0 then
									if cache.vehicle then
										TaskSwapWeapon(playerPed, true)
									end

									currentWeapon.timer = GetGameTimer() + 200
								else currentWeapon.timer = GetGameTimer() + (GetWeaponTimeBetweenShots(currentWeapon.hash) * 1000) + 100 end
							end
						elseif currentWeapon.throwable then
							if not invBusy and IsControlPressed(0, 24) then
								invBusy = 1

								CreateThread(function()
									local weapon = currentWeapon

									while currentWeapon and (not IsPedWeaponReadyToShoot(cache.ped) or IsDisabledControlPressed(0, 24)) and GetSelectedPedWeapon(playerPed) == weapon.hash do
										Wait(0)
									end

									if GetSelectedPedWeapon(playerPed) == weapon.hash then Wait(700) end

									while IsPedPlantingBomb(playerPed) do Wait(0) end

									TriggerServerEvent('ox_inventory:updateWeapon', 'throw', nil, weapon.slot)
									plyState:set('invBusy', false, true)

									currentWeapon = nil

									RemoveWeaponFromPed(playerPed, weapon.hash)
									TriggerEvent('ox_inventory:currentWeapon')
								end)
							end
						elseif currentWeapon.melee and IsControlJustReleased(0, 24) and IsPedPerformingMeleeAction(playerPed) then
							currentWeapon.melee += 1
							currentWeapon.timer = GetGameTimer() + 200
						end
					end
				end
			else
				Wait(0)
				if not EnableWeaponWheel then
					HudWeaponWheelIgnoreSelection()
					DisableControlAction(0, 37, true)
				end
			end
		end
	end)

	plyState:set('invBusy', false, true)
	plyState:set('invOpen', false, false)
	plyState:set('invHotkeys', true, false)
	plyState:set('canUseWeapons', true, false)
	collectgarbage('collect')
end)

AddEventHandler('onResourceStop', function(resourceName)
	if shared.resource == resourceName then
		client.onLogout()
		PedScreenDelete()
	end
end)

RegisterNetEvent('ox_inventory:viewInventory', function(left, right)
	if source == '' then return end

	plyState.invOpen = true

	SetNuiFocus(true, true)
	SetNuiFocusKeepInput(true)
	closeTrunk()

	if client.screenblur then TriggerScreenblurFadeIn(0) end

	currentInventory = right or defaultInventory
	currentInventory.ignoreSecurityChecks = true
    currentInventory.type = 'inspect'
	left.items = filterPlayerInventoryForUi(PlayerData.inventory)
	left.groups = PlayerData.groups

	local clothingSlots = lib.callback.await('ox_inventory:getClothingSlots', false) or {}

	SendNUIMessage({
		action = 'setupInventory',
		data = {
			leftInventory = left,
			rightInventory = currentInventory,
			centerInventory = {
				id = 'clothing',
				type = 'clothing',
				slots = 17,
				maxWeight = 0,
				items = clothingSlots
			}
		}
	})
	
	Wait(100)
	
	local refreshItems = {}
	for i = 1, 17 do
		if clothingSlots[i] and clothingSlots[i].name then
			table.insert(refreshItems, {
				item = clothingSlots[i],
				inventory = 'clothing'
			})
		end
	end
	
	if #refreshItems > 0 then
		SendNUIMessage({
			action = 'refreshSlots',
			data = {
				items = refreshItems
			}
		})
	end

	updateHUDStats()

	if currentInventory.type ~= 'crafting' and currentInventory.type ~= 'shop' then
		PedScreenCreate(playerPed, {
			dict = "anim@amb@nightclub@peds@", 
			anim = "rcmme_amanda1_stand_loop_cop"
		})
	end
end)

RegisterNUICallback('updateBodyImagePreference', function(data, cb)
	cb(true)
	if clonedPed and DoesEntityExist(clonedPed) then
		local newVisibility = not data.showBodyImage
		if lastPedVisibility ~= newVisibility then
			lastPedVisibility = newVisibility
			SetEntityVisible(clonedPed, newVisibility, false)
		end
	end
end)

RegisterNUICallback('uiLoaded', function(_, cb)
	client.uiLoaded = true
	cb({ success = true })
end)

-- Callback appelé par le NUI pour récupérer les configs par défaut du HUD
RegisterNUICallback('nui:loadUI', function(_, cb)
	local defaultStyle = Config.DefaultStyle or {}
	local hudEnabled = not (defaultStyle.Hud and defaultStyle.Hud.Enabled == false)
	local uiLocales = buildUiLocales()
	
	-- Construire les données de configuration pour le NUI
	local hudConfig = {
		setLocale = {
			locale = currentLocale or 'en',
			data = uiLocales
		},
		setDefaultSettings = {
			forceDefaults = defaultStyle.ForceDefaults or false,
			bar_style = defaultStyle.Hud and defaultStyle.Hud.BarStyle or 'circle',
			is_res_style_active = hudEnabled and (defaultStyle.Hud and defaultStyle.Hud.ResStyleActive ~= false),
			vehicle_hud_style = defaultStyle.Hud and defaultStyle.Hud.VehicleHudStyle or 1,
			bar_size = defaultStyle.Hud and defaultStyle.Hud.BarSize or 0,
			mini_map = {
				style = defaultStyle.MiniMap and defaultStyle.MiniMap.Style or 'rectangle',
				onlyInVehicle = defaultStyle.MiniMap and defaultStyle.MiniMap.OnlyInVehicle or false,
				editableByPlayers = hudEnabled and not (defaultStyle.ForceDefaults or false),
			},
			compass = {
				active = hudEnabled and (defaultStyle.Compass and defaultStyle.Compass.Show ~= false),
				onlyInVehicle = defaultStyle.Compass and defaultStyle.Compass.OnlyInVehicle or false,
				editableByPlayers = hudEnabled and not (defaultStyle.ForceDefaults or false),
			},
			cinematic = {
				active = hudEnabled and (defaultStyle.Cinematic and defaultStyle.Cinematic.Enabled or false),
			},
			vehicle_info = {
				kmH = true,
			},
			client_info = {
				active = hudEnabled,
				server_info = {
					active = hudEnabled and (defaultStyle.ClientInfo and defaultStyle.ClientInfo.ServerInfo ~= false),
					image = 'index.png',
					name = GetConvar('sv_projectName', 'FiveM Server'),
				},
				bank = {
					active = hudEnabled and (defaultStyle.ClientInfo and defaultStyle.ClientInfo.Bank ~= false),
				},
				cash = {
					active = hudEnabled and (defaultStyle.ClientInfo and defaultStyle.ClientInfo.Cash ~= false),
				},
				extra_currency = {
					active = hudEnabled and (defaultStyle.ClientInfo and defaultStyle.ClientInfo.ExtraCurrency ~= false),
				},
				job = {
					active = hudEnabled and (defaultStyle.ClientInfo and defaultStyle.ClientInfo.Job ~= false),
				},
				player_source = {
					active = hudEnabled and (defaultStyle.ClientInfo and defaultStyle.ClientInfo.PlayerId ~= false),
				},
				radio = {
					active = hudEnabled and (defaultStyle.ClientInfo and defaultStyle.ClientInfo.Radio ~= false),
				},
				real_time = {
					active = hudEnabled,
				},
				time = {
					active = hudEnabled and (defaultStyle.ClientInfo and defaultStyle.ClientInfo.Time ~= false),
				},
				weapon = {
					active = hudEnabled and (defaultStyle.ClientInfo and defaultStyle.ClientInfo.Weapon ~= false),
				},
			},
			navigation_widget = {
				active = hudEnabled and (defaultStyle.ClientInfo and defaultStyle.ClientInfo.NavigationWidget ~= false),
			},
			music_info = {
				active = hudEnabled,
			},
			colors = {
				'#1D4ED8', '#CF4E5B', '#FFC400', '#00FFA3', '#C4FF48', '#6b21a8', '#00C2FF', '#FFFFFF', '#CF654E'
			},
			bars = {
				armor = { color = '#1D4ED8' },
				health = { color = '#CF4E5B' },
				hunger = { color = '#FFC400' },
				oxygen = { color = '#00FFA3' },
				stamina = { color = '#C4FF48' },
				stress = { color = '#6b21a8' },
				thirst = { color = '#00C2FF' },
				vehicle_engine = { color = '#C4FF48' },
				vehicle_nitro = { color = '#CF654E' },
				voice = { color = '#FFFFFF' },
			},
		}
	}
	
	-- Envoyer les configs au NUI via ui:setupUI
	SendNUIMessage({
		action = 'ui:setupUI',
		data = hudConfig
	})
	
	cb({ success = true })
end)

-- Callback pour notifier que le HUD est complètement chargé
RegisterNUICallback('nui:onLoadUI', function(_, cb)
	cb({ success = true })
end)

RegisterNUICallback('getItemData', function(itemName, cb)
	cb(Items[itemName] or {})
end)

RegisterNUICallback('removeComponent', function(data, cb)
	cb(true)

	if not currentWeapon then
		return TriggerServerEvent('ox_inventory:updateWeapon', 'component', data)
	end

	if data.slot ~= currentWeapon.slot then
		return lib.notify({ id = 'weapon_hand_wrong', type = 'error', title = locale('notification_wrong_weapon'), description = locale('weapon_hand_wrong') })
	end

	local itemSlot = PlayerData.inventory[currentWeapon.slot]

    if not itemSlot then return end

	for _, component in pairs(Items[data.component].client.component) do
		if HasPedGotWeaponComponent(playerPed, currentWeapon.hash, component) then
			for k, v in pairs(itemSlot.metadata.components) do
				if v == data.component then
					local success = lib.callback.await('ox_inventory:updateWeapon', false, 'component', k)

					if success then
						RemoveWeaponComponentFromPed(playerPed, currentWeapon.hash, component)
						TriggerEvent('ox_inventory:updateWeaponComponent', 'removed', component, data.component)
					end

					break
				end
			end
		end
	end
end)

RegisterNUICallback('removeAmmo', function(slot, cb)
	cb(true)
	local slotData = PlayerData.inventory[slot]

	if not slotData or not slotData.metadata.ammo or slotData.metadata.ammo == 0 then return end

	local success = lib.callback.await('ox_inventory:removeAmmoFromWeapon', false, slot)

	if success and currentWeapon and slot == currentWeapon.slot then
		SetPedAmmo(playerPed, currentWeapon.hash, 0)
	end
end)

RegisterNUICallback('packAmmo', function(data, cb)
	cb(true)
	local slot = data.slot
	local playerPed = cache.ped
	local config = shared.ammo or Config.PackAmmo or { UseRProgress = false, Duration = 5000, Label = 'Remballer les munitions...' }
	
	RequestAnimDict("mp_arresting")
	while not HasAnimDictLoaded("mp_arresting") do
		Wait(0)
	end
	
	if DoesEntityExist(playerPed) and not IsEntityDead(playerPed) then
		TaskPlayAnim(playerPed, "mp_arresting", "a_uncuff", 8.0, -8.0, config.Duration, 48, 0, false, false, false)
	end
	
	local success = false
	
	if config.UseRProgress then
		exports.rprogress:_DOLI_PROGRESSBAR_START(config.Duration / 1000)
		Wait(config.Duration)
		success = true
	else
		success = lib.progressBar({
			duration = config.Duration,
			label = config.Label,
			useWhileDead = false,
			canCancel = true,
			disableControl = true,
		})
	end
	
	if success then
		lib.callback.await('ox_inventory:packAmmo', false, slot)
	end
	
	ClearPedTasks(playerPed)
end)

RegisterNUICallback('useItem', function(slot, cb)
	useSlot(slot --[[@as number]])
	cb(true)
end)

local function giveItemToTarget(serverId, slotId, count)
    if type(slotId) ~= 'number' then return TypeError('slotId', 'number', type(slotId)) end
    if count and type(count) ~= 'number' then return TypeError('count', 'number', type(count)) end

    if currentWeapon and slotId == currentWeapon.slot then
        currentWeapon = Weapon.Disarm(currentWeapon)
    end

    Utils.PlayAnim(0, 'mp_common', 'givetake1_a', 1.0, 1.0, 2000, 50, 0.0, 0, 0, 0)

    local notification = lib.callback.await('ox_inventory:giveItem', false, slotId, serverId, count or 0)

    if notification then
        lib.notify({ type = 'error', title = locale('notification_error'), description = locale(table.unpack(notification)) })
    end
end

exports('giveItemToTarget', giveItemToTarget)

local function isGiveTargetValid(ped, coords)
    if cache.vehicle and GetVehiclePedIsIn(ped, false) == cache.vehicle then
        return true
    end

    local entity = Utils.Raycast(1|2|4|8|16, coords + vec3(0, 0, 0.5), 0.2)

    return entity == ped and IsEntityVisible(ped)
end

RegisterNUICallback('giveItem', function(data, cb)
	cb(true)

    if usingItem then return end

	if client.giveplayerlist then
		local nearbyPlayers = lib.getNearbyPlayers(GetEntityCoords(playerPed), 3.0)
        local nearbyCount = #nearbyPlayers

		if nearbyCount == 0 then
			lib.notify({ type = 'error', title = locale('notification_error'), description = locale('nobody_nearby') })
			return
		end

        if nearbyCount == 1 then
			local option = nearbyPlayers[1]

			if not isGiveTargetValid(option.ped, option.coords) then
				lib.notify({ type = 'error', title = locale('notification_error'), description = locale('nobody_nearby') })
				return
			end

            return giveItemToTarget(GetPlayerServerId(option.id), data.slot, data.count)
        end

        local giveList, n = {}, 0

		for i = 1, #nearbyPlayers do
			local option = nearbyPlayers[i]

            if isGiveTargetValid(option.ped, option.coords) then
				local playerName = GetPlayerName(option.id)
				option.id = GetPlayerServerId(option.id)
                ---@diagnostic disable-next-line: inject-field
				option.label = ('[%s] %s'):format(option.id, playerName)
				n += 1
				giveList[n] = option
			end
		end

		if n == 0 then
			lib.notify({ type = 'error', title = locale('notification_error'), description = locale('nobody_nearby') })
			return
		end

		lib.registerMenu({
			id = 'ox_inventory:givePlayerList',
			title = locale('notification_give_item'),
			options = giveList,
		}, function(selected)
            giveItemToTarget(giveList[selected].id, data.slot, data.count)
        end)

		return lib.showMenu('ox_inventory:givePlayerList')
	end

	if cache.vehicle then
		local seats = GetVehicleMaxNumberOfPassengers(cache.vehicle) - 1

		if seats >= 0 then
			local passenger = GetPedInVehicleSeat(cache.vehicle, cache.seat - 2 * (cache.seat % 2) + 1)

			if passenger ~= 0 and IsEntityVisible(passenger) then
                return giveItemToTarget(GetPlayerServerId(NetworkGetPlayerIndexFromPed(passenger)), data.slot, data.count)
			end
		end

		lib.notify({ type = 'error', title = locale('notification_error'), description = locale('nobody_nearby') })
		return
	end

    local entity = Utils.Raycast(1|2|4|8|16, GetOffsetFromEntityInWorldCoords(cache.ped, 0.0, 3.0, 0.5), 0.2)

	if entity and IsPedAPlayer(entity) and IsEntityVisible(entity) and #(GetEntityCoords(playerPed, true) - GetEntityCoords(entity, true)) < 3.0 then
		return giveItemToTarget(GetPlayerServerId(NetworkGetPlayerIndexFromPed(entity)), data.slot, data.count)
	end

	lib.notify({ type = 'error', title = locale('notification_error'), description = locale('nobody_nearby') })
end)

RegisterNUICallback('useButton', function(data, cb)
	useButton(data.id, data.slot)
	cb(true)
end)

RegisterNUICallback('exit', function(_, cb)
	client.closeInventory()
	cb(true)
end)

RegisterNUICallback('Inventory:ClothLock', function(data, cb)
	cb(1)
	
	if not data.index then 
		return 
	end
	
	local slot = 70 + data.index
	TriggerServerEvent('ox_inventory:server:toggleClothLock', slot)
end)

RegisterNUICallback('Inventory:Medic:SelectedTab', function(data, cb)
	if data and data.mode == 'human' and medicTargetPed and medicModeActive then
		medicHumanTabActive = true
		startMedicPedScreen(medicTargetPed)
	else
		medicHumanTabActive = false
		medicPedHeadingOffset = 0.0
		PedScreenDelete()
	end
	cb('ok')
end)

RegisterNUICallback('Inventory:Medic:RotatePed', function(data, cb)
	if medicModeActive and medicHumanTabActive and data and tonumber(data.delta) then
		medicPedHeadingOffset = (medicPedHeadingOffset - (tonumber(data.delta) * 0.7)) % 360.0
	end
	cb('ok')
end)

RegisterNUICallback('Inventory:Medic:toggleAta', function(data, cb)
	local duration = nil

	if data and data.toggle then
		local inputValue = nil
		local lpOk = false

		if GetResourceState('lpF1') == 'started' then
			lpOk, inputValue = pcall(function()
				return exports['lpF1']:ShowSync('ATA', 'Durée (heures)', 'number')
			end)

			if not lpOk then
				lpOk, inputValue = pcall(function()
					return exports['lpF1']:ShowSync('Durée (heures)', 'number')
				end)
			end
		end

		if lpOk then
			if type(inputValue) == 'table' then
				inputValue = inputValue.value or inputValue.input or inputValue.text or inputValue.result or inputValue.number or inputValue[1]
			end

			if type(inputValue) == 'string' then
				inputValue = inputValue:gsub('[^%d]', '')
				if inputValue == '' then
					inputValue = nil
				end
			end
		else
			local input = lib.inputDialog('ATA', {
				{ label = 'Durée (heures)', type = 'number', required = true }
			})

			if input and input[1] ~= nil then
				inputValue = input[1]
			end
		end

		if not inputValue or not tonumber(inputValue) then
			return cb('ok')
		end

		duration = tonumber(inputValue)
	end

	TriggerServerEvent('ox_inventory:medic:setAta', data.characterId, data.toggle == true, duration, data.part)
	cb('ok')
end)

RegisterNUICallback('Inventory:Medic:expectingRPDeath', function(data, cb)
	TriggerServerEvent('ox_inventory:medic:setExpectingRPDeath', data.characterId, data.toggle)
	cb('ok')
end)

RegisterNetEvent('ox_inventory:updateClothLock', function(slotId, itemData)
	if not slotId then return end
	SendNUIMessage({
		action = 'refreshSlots',
		data = {
			items = {
				{
					item = itemData and {
						slot = slotId,
						name = itemData.name,
						count = itemData.count or 1,
						weight = itemData.weight or 0,
						metadata = itemData.metadata
					} or { slot = slotId },
					inventory = 'clothing'
				}
			}
		}
	})
end)

RegisterNUICallback('discardItem', function(data, cb)
	if data.item and data.amount then
		TriggerServerEvent('ox_inventory:removeItem', data.item.slot, data.amount)
	end
	cb(true)
end)

RegisterNUICallback('showNotification', function(data, cb)
	if Config.Client and Config.Client.UiNotifications == false then
		cb(true)
		return
	end

	if data.message then
		lib.notify({
			type = data.type or 'info',
			title = data.title or locale('notification_information'),
			description = data.message
		})
	end
	cb(true)
end)

weaponPreviewObject = nil
weaponPreviewCoords = nil
weaponPreviewThread = false
weaponPreviewRotation = 180.0 -- Rotation de l'arme (modifiable par l'utilisateur)

-- Fonction pour supprimer proprement l'objet arme preview
function cleanupWeaponPreview()
	weaponPreviewThread = false
	if weaponPreviewObject then
		if DoesEntityExist(weaponPreviewObject) then
			DeleteEntity(weaponPreviewObject)
		end
		weaponPreviewObject = nil
		weaponPreviewCoords = nil
	end
	weaponPreviewRotation = 180.0
end

RegisterNUICallback('openAccessoryPanel', function(data, cb)
	-- Ouvrir le panel d'accessoires pour l'arme spécifiée
	if data and data.weapon then
		invOpen = true
		
		-- S'assurer qu'il n'y a pas d'objet précédent
		cleanupWeaponPreview()
		
		-- Créer le modèle 3D de l'arme
		local weaponItem = PlayerData.inventory[data.weapon.slot]
		if weaponItem and weaponItem.name then
			local weaponName = weaponItem.name:upper()
			local weaponHash = joaat(weaponName)
			
			-- Récupérer les données de l'arme depuis la configuration
			local weaponData = Items[weaponName]
			
			-- Vérifier si c'est un modèle d'arme valide et qu'on a le prop
			if IsWeaponValid(weaponHash) and weaponData and weaponData.prop then
				-- Charger le modèle 3D (prop)
				local modelName = type(weaponData.prop) == 'number' and weaponData.prop or joaat(weaponData.prop)
				if lib.requestModel(modelName, 5000) then
					-- Créer l'arme comme le preview ped: incrusté à l'écran
					local world, normal = GetWorldCoordFromScreenCoord(0.50, 0.50)
					local depth = 1.0
					local target = world + normal * depth
					
					weaponPreviewObject = CreateWeaponObject(weaponHash, 0, target.x, target.y, target.z, true, 1.0, 0)
					SetEntityCollision(weaponPreviewObject, false, false)
					SetEntityInvincible(weaponPreviewObject, true)
					FreezeEntityPosition(weaponPreviewObject, true)
					
					-- Appliquer les composants si présents
					if weaponItem.metadata and weaponItem.metadata.components then
						for _, component in pairs(weaponItem.metadata.components) do
							local componentHash = type(component) == 'string' and joaat(component) or component
							if DoesWeaponTakeWeaponComponent(weaponHash, componentHash) then
								GiveWeaponComponentToWeaponObject(weaponPreviewObject, componentHash)
							end
						end
					end
					
					-- Thread pour maintenir l'arme à l'écran
					weaponPreviewThread = true
					weaponPreviewRotation = 180.0
					CreateThread(function()
						local positionBuffer = {}
						local bufferSize = 2
						-- Cache natives
						local GetWorldCoordFromScreenCoord = GetWorldCoordFromScreenCoord
						local GetGameplayCamRot = GetGameplayCamRot
						local SetEntityCoords = SetEntityCoords
						local SetEntityRotation = SetEntityRotation
						local DisableIdleCamera = DisableIdleCamera
						
						while weaponPreviewThread and weaponPreviewObject and DoesEntityExist(weaponPreviewObject) do
							local world, normal = GetWorldCoordFromScreenCoord(0.73, 0.40) -- Position à droite de l'écran
							local depth = 1.2
							local target = world + normal * depth
							local camRot = GetGameplayCamRot(2)
							
							-- Lissage de la position
							table.insert(positionBuffer, target)
							if #positionBuffer > bufferSize then
								table.remove(positionBuffer, 1)
							end
							
							local averagedTarget = vector3(0, 0, 0)
							for _, position in ipairs(positionBuffer) do
								averagedTarget = averagedTarget + position
							end
							averagedTarget = averagedTarget / #positionBuffer
							
							-- Positionner et orienter l'arme avec rotation modifiable
							SetEntityCoords(weaponPreviewObject, averagedTarget.x, averagedTarget.y, averagedTarget.z, false, false, false, true)
							SetEntityRotation(weaponPreviewObject, 0.0, 0.0, camRot.z + weaponPreviewRotation, 2, true)
							
							DisableIdleCamera(true)
							Wait(16) -- ~60fps instead of 333fps
						end
						
						-- Nettoyage à la fin du thread
						if weaponPreviewObject and DoesEntityExist(weaponPreviewObject) then
							DeleteEntity(weaponPreviewObject)
							weaponPreviewObject = nil
						end
					end)
				else
				end
			else
			end
		end
		
		SendNUIMessage({ 
			action = 'openAccessoryPanel', 
			data = { weapon = data.weapon }
		})
		SetNuiFocus(true, true)
		SetNuiFocusKeepInput(true)
		cb(true)
	else
		cb(false)
	end
end)

RegisterNUICallback('rotateWeaponPreview', function(data, cb)
	-- Permet au NUI de faire tourner l'arme
	if data and data.delta then
		weaponPreviewRotation = (weaponPreviewRotation + data.delta) % 360
	end
	cb(true)
end)

RegisterNUICallback('closeAccessoryPanel', function(_, cb)
	invOpen = false
	
	-- Nettoyage complet
	cleanupWeaponPreview()
	
	-- Toujours désactiver le NUI focus quand on ferme le panel d'accessoires
	SetNuiFocus(false, false)
	SetNuiFocusKeepInput(false)
	cb(true)
end)

RegisterNUICallback('backFromAccessoryPanel', function(_, cb)
	-- Supprimer l'objet arme preview quand on retourne à l'inventaire
	cleanupWeaponPreview()
	
	-- Ne pas changer invOpen ni le focus, juste supprimer l'objet
	cb(true)
end)

exports('setPlayerStatus', function(statusName, value)
	if playerStatus[statusName] then
		playerStatus[statusName] = math.floor(value)
		updateHUDStats()
	end
end)

exports('updateAllStatus', function(hunger, thirst, sleep)
	playerStatus.hunger = math.floor(hunger or 100)
	playerStatus.thirst = math.floor(thirst or 100)
	playerStatus.sleep = math.floor(sleep or 100)
	updateHUDStats()
end)

CreateThread(function()
	Wait(5000)
	
	local statusConfig = Config and Config.PlayerStatus or {
		Enabled = true,
		UpdateInterval = 30000,
		HungerDecrease = {min = 1, max = 2},
		ThirstDecrease = {min = 1, max = 3},
		SleepDecrease = 1
	}
	
	if not statusConfig.Enabled then
		return
	end
	
	while true do
		Wait(statusConfig.UpdateInterval or 30000)
		
		if PlayerData.loaded then
			local hungerDec = statusConfig.HungerDecrease
			local thirstDec = statusConfig.ThirstDecrease
			
			playerStatus.hunger = math.max(0, playerStatus.hunger - math.random(hungerDec.min or 1, hungerDec.max or 2))
			playerStatus.thirst = math.max(0, playerStatus.thirst - math.random(thirstDec.min or 1, thirstDec.max or 3))
			playerStatus.sleep = math.max(0, playerStatus.sleep - (statusConfig.SleepDecrease or 1))
			
			if invOpen then
				updateHUDStats()
			end
		end
	end
end)


lib.callback.register('ox_inventory:startCrafting', function(id, recipe)
	recipe = CraftingBenches[id].items[recipe]

	return lib.progressCircle({
		label = locale('crafting_item', recipe.metadata and recipe.metadata.label or Items[recipe.name].label),
		duration = recipe.duration or 3000,
		canCancel = true,
		disable = {
			move = true,
			combat = true,
		},
		anim = {
			dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
			clip = 'machinic_loop_mechandplayer',
		}
	})
end)

local swapActive = false
local dropActive = false

---Synchronise and validate all item movement between the NUI and server.
RegisterNUICallback('swapItems', function(data, cb)
    if swapActive or not invOpen or invBusy or usingItem then 
		return cb(false) 
	end

    swapActive = true

	if data.toType == 'accessory' then
		-- Get weapon and component data
		local weaponItem = PlayerData.inventory[data.toSlot]
		local componentData = Items[data.componentName]
		
		if not weaponItem then
			swapActive = false
			return cb(false)
		end
		
		if not componentData or not componentData.client or not componentData.client.component then
			lib.notify({ type = 'error', description = 'Ce composant n\'a pas de données de compatibilité' })
			swapActive = false
			return cb(false)
		end
		
		-- Check if weapon can accept this component
		local weaponHash = joaat(weaponItem.name)
		local componentCompatible = false
		
		for i = 1, #componentData.client.component do
			local component = componentData.client.component[i]
			if DoesWeaponTakeWeaponComponent(weaponHash, component) then
				componentCompatible = true
				break
			end
		end
		
		if not componentCompatible then
			lib.notify({ type = 'error', description = 'Ce composant n\'est pas compatible avec cette arme' })
			swapActive = false
			return cb(false)
		end
		
		-- Check if component type already installed
		if weaponItem.metadata and weaponItem.metadata.components then
			for i = 1, #weaponItem.metadata.components do
				local installedComponent = weaponItem.metadata.components[i]
				local installedComponentName = type(installedComponent) == 'table' and installedComponent.name or installedComponent
				local installedComponentData = installedComponentName and Items[installedComponentName]
				if installedComponentData and installedComponentData.type == componentData.type then
					lib.notify({ type = 'error', description = 'Un composant de ce type est déjà installé' })
					swapActive = false
					return cb(false)
				end
			end
		end
		
		local success, response = lib.callback.await('ox_inventory:addWeaponComponent', false, data.fromSlot, data.toSlot)
		
		if success and currentWeapon and currentWeapon.slot == data.toSlot then
			local componentData = Items[data.componentName]
			if componentData and componentData.client and componentData.client.component then
				for i = 1, #componentData.client.component do
					local component = componentData.client.component[i]
					if DoesWeaponTakeWeaponComponent(currentWeapon.hash, component) then
						if not HasPedGotWeaponComponent(cache.ped, currentWeapon.hash, component) then
							GiveWeaponComponentToPed(cache.ped, currentWeapon.hash, component)
						end
					end
				end
			end
		end
		
		if success and response then
			-- Convert server response to updateInventory format
			local refreshData = {}
			
			-- Add the component slot that was emptied
			table.insert(refreshData, { inventory = 'player', item = { slot = data.fromSlot } })
			
			-- Add the weapon slot that was updated
			if response.items[data.toSlot] then
				table.insert(refreshData, { inventory = 'player', item = response.items[data.toSlot] })
			end
			
			updateInventory(refreshData, response.weight)
		end
		
		swapActive = false
		cb(success or false)
		return
end

if data.fromType == 'accessory' then
	local success, response = lib.callback.await('ox_inventory:removeWeaponComponent', false, data.fromSlot, data.componentName)
	
	if success then
		local weaponItem = PlayerData.inventory[data.fromSlot]
		if weaponItem and weaponItem.metadata and weaponItem.metadata.components then
			for i = #weaponItem.metadata.components, 1, -1 do
				local installedComponent = weaponItem.metadata.components[i]
				local installedComponentName = type(installedComponent) == 'table' and installedComponent.name or installedComponent
				if installedComponentName and string.lower(installedComponentName) == string.lower(data.componentName) then
					table.remove(weaponItem.metadata.components, i)
					break
				end
			end
		end
	end
	
	if success and currentWeapon and currentWeapon.slot == data.fromSlot then
		local componentData = Items[data.componentName]
		if componentData and componentData.client and componentData.client.component then
			for i = 1, #componentData.client.component do
				local component = componentData.client.component[i]
				if HasPedGotWeaponComponent(cache.ped, currentWeapon.hash, component) then
					RemoveWeaponComponentFromPed(cache.ped, currentWeapon.hash, component)
				end
			end
		end
	end
	
	swapActive = false
	cb(success or false)
	
	if success and response then
		-- Send NUI message to refresh slots
		local refreshData = {}
		for slot, item in pairs(response.items) do
			if item then
				table.insert(refreshData, { inventory = 'player', item = item })
			end
		end
		SendNUIMessage({ action = 'refreshSlots', data = { items = refreshData } })
		updateInventory(refreshData, response.weight)
	end
	return
end

if data.toType == 'newdrop' then
	if cache.vehicle or IsPedFalling(playerPed) then
			swapActive = false
			return cb(false)
		end

		local coords = GetEntityCoords(playerPed)

		if IsEntityInWater(playerPed) then
			local destination = vec3(coords.x, coords.y, -200)
			local handle = StartShapeTestLosProbe(coords.x, coords.y, coords.z, destination.x, destination.y, destination.z, 511, cache.ped, 4)

			while true do
				Wait(0)
				local retval, hit, endCoords = GetShapeTestResult(handle)

				if retval ~= 1 then
					if not hit then return end

					data.coords = vec3(endCoords.x, endCoords.y, endCoords.z + 1.0)

					break
				end
			end
		else
			data.coords = coords
		end
    end

	if currentInstance then
		data.instance = currentInstance
	end

	if currentWeapon and data.fromType ~= data.toType then
		if (data.fromType == 'player' and data.fromSlot == currentWeapon.slot) or (data.toType == 'player' and data.toSlot == currentWeapon.slot) then
			currentWeapon = Weapon.Disarm(currentWeapon, true)
		end
	end

	local success, response, weaponSlot = lib.callback.await('ox_inventory:swapItems', false, data)
    swapActive = false

	cb(success or false)

	if success then
        if weaponSlot and currentWeapon then
            currentWeapon.slot = weaponSlot
        end

		if response then
			updateInventory(response.items, response.weight)
		end

		if data.toType == 'clothing' or data.fromType == 'clothing' then
			local function normalizeClothingSlot(slotValue)
				slotValue = tonumber(slotValue)
				if not slotValue then return nil end
				if slotValue >= 70 and slotValue <= 86 then return slotValue end
				if slotValue >= 1 and slotValue <= 17 then return slotValue + 69 end
				return nil
			end

			local toClothingSlot = data.toType == 'clothing' and normalizeClothingSlot(data.toSlot) or nil
			local fromClothingSlot = data.fromType == 'clothing' and normalizeClothingSlot(data.fromSlot) or nil

			if fromClothingSlot and (not toClothingSlot or toClothingSlot ~= fromClothingSlot) then
				applyClothing(fromClothingSlot, nil, true)
				UpdateClonedPedClothing(fromClothingSlot, nil)
			end

			if toClothingSlot then
				local equippedItem = PlayerData.inventory and PlayerData.inventory[toClothingSlot] or nil
				if not equippedItem and PlayerData and PlayerData.inventory then
					for _, invItem in pairs(PlayerData.inventory) do
						if invItem and invItem.metadata and invItem.metadata.equippedInClothingSlot == toClothingSlot then
							equippedItem = invItem
							break
						end
					end
				end

				if equippedItem and equippedItem.name then
					applyClothing(toClothingSlot, equippedItem, true)
					UpdateClonedPedClothing(toClothingSlot, equippedItem)
				end
			end

			saveClothingAppearance()
		end
	elseif response then
		if type(response) == 'table' then
			SendNUIMessage({ action = 'refreshSlots', data = { items = response } })
		else
			lib.notify({ type = 'error', title = locale('notification_error'), description = locale(response) })
		end
	end
end)

---Handle dropping items to the ground
RegisterNUICallback('dropItem', function(data, cb)
	if dropActive or not invOpen or invBusy or usingItem then return cb(false) end

	if not data.slot or not data.count or data.count < 1 then return cb(false) end

	dropActive = true

	if cache.vehicle or IsPedFalling(playerPed) then
		dropActive = false
		return cb(false)
	end

	local coords = GetEntityCoords(playerPed)

	if IsEntityInWater(playerPed) then
		local destination = vec3(coords.x, coords.y, -200)
		local handle = StartShapeTestLosProbe(coords.x, coords.y, coords.z, destination.x, destination.y, destination.z, 511, cache.ped, 4)

		while true do
			Wait(0)
			local retval, hit, endCoords = GetShapeTestResult(handle)

			if retval ~= 1 then
				if not hit then 
					dropActive = false
					return cb(false)
				end

				coords = vec3(endCoords.x, endCoords.y, endCoords.z + 1.0)
				break
			end
		end
	end

	if currentWeapon and data.slot == currentWeapon.slot then
		currentWeapon = Weapon.Disarm(currentWeapon, true)
	end

	local success, response, weaponSlot = lib.callback.await('ox_inventory:swapItems', false, {
		fromSlot = data.slot,
		fromType = 'player',
		toType = 'newdrop',
		toSlot = 1,
		count = math.floor(data.count),
		coords = coords,
		instance = currentInstance
	})
	dropActive = false

	cb(success or false)

	if success then
		if weaponSlot and currentWeapon then
			currentWeapon.slot = weaponSlot
		end

		if response then
			updateInventory(response.items, response.weight)
		end
	elseif response then
		if type(response) == 'table' then
			SendNUIMessage({ action = 'refreshSlots', data = { items = response } })
		else
			lib.notify({ type = 'error', title = locale('notification_error'), description = locale(response) })
		end
	end
end)

RegisterNUICallback('buyItem', function(data, cb)
	---@type boolean, false | { [1]: number, [2]: SlotWithItem, [3]: SlotWithItem | false, [4]: number}, NotifyProps
	local response, data, message = lib.callback.await('ox_inventory:buyItem', 100, data)

	if data then
		updateInventory({
			{
				item = data[2],
				inventory = cache.serverId
			}
		}, data[4])

		if data[3] then
			SendNUIMessage({
				action = 'refreshSlots',
				data = {
					items = {
						{
							item = data[3],
							inventory = 'shop'
						}
					}
				}
			})
		end
	end

	if message then
		lib.notify(message)
	end

	cb(response)
end)

RegisterNUICallback('craftItem', function(data, cb)
	cb(true)

	local id, index = currentInventory.id, currentInventory.index
	local success, response = lib.callback.await('ox_inventory:craftItem', 200, id, index, data.recipe, data.quantity)

	if not success then
		if response then 
			lib.notify({ 
				type = 'error', 
				title = locale('notification_error'), 
				description = locale(response or 'cannot_perform') 
			}) 
		end
	end
end)

RegisterNetEvent('ox_inventory:craftStarted', function(craftData)
	SendNUIMessage({
		action = 'craftStarted',
		data = craftData
	})
end)

RegisterNetEvent('ox_inventory:craftFinished', function(itemName, quantity)
	SendNUIMessage({
		action = 'craftFinished',
		data = {
			item = itemName,
			quantity = quantity
		}
	})
	
	lib.notify({ 
		type = 'success', 
		title = locale('notification_success'), 
		description = locale('craft_success', quantity, Items[itemName]?.label or itemName)
	})
end)

RegisterNetEvent('ox_inventory:craftFailed', function(error)
	SendNUIMessage({
		action = 'craftFailed',
		data = { error = error }
	})
	
	lib.notify({ 
		type = 'error', 
		title = locale('notification_error'), 
		description = locale(error or 'craft_failed')
	})
end)

-- Vérifier s'il y a un craft en cours lors de l'ouverture du craft
AddEventHandler('ox_inventory:openCrafting', function()
	local craftData = lib.callback.await('ox_inventory:getActiveCraft', 200)
	if craftData then
		SendNUIMessage({
			action = 'restoreCraft',
			data = craftData
		})
	end
end)

RegisterNUICallback('cancelCraft', function(data, cb)
	cb(true)
	local success = lib.callback.await('ox_inventory:cancelCraft', 200)
	if success then
		lib.notify({ 
			type = 'inform', 
			title = locale('notification_info'), 
			description = locale('craft_cancelled')
		})
	end
end)

RegisterNUICallback('renameItem', function(data, cb)
	cb(true)
	
	local input = lib.inputDialog(locale('ui_rename_item'), {
		{ type = 'input', label = locale('ui_new_name'), description = locale('ui_enter_new_name'), required = true, min = 1, max = 50 }
	})
	
	if input then
		local newName = input[1]
		if newName and newName ~= '' then
			TriggerServerEvent('ox_inventory:renameItem', data.slot, newName)
		end
	end
end)

RegisterNUICallback('updateItemLabel', function(data, cb)
	cb(true)
	
	if data.newLabel and data.newLabel ~= '' then
		TriggerServerEvent('ox_inventory:renameItem', data.slot, data.newLabel)
	end
end)

lib.callback.register('ox_inventory:getVehicleData', function(netid)
	local entity = NetworkGetEntityFromNetworkId(netid)

	if entity then
		return GetEntityModel(entity), GetVehicleClass(entity)
	end
end)

-- ========== CLOTHING SYSTEM ==========
local defaultClothing = {}
local previewClothing = {}
local isPreviewActive = false

-- Commande temporaire pour tester le crafting
RegisterCommand('testcraft', function()
    client.openInventory('crafting', { id = 1, index = 1 })
end, false)

local clothingSlotMapping = {
    -- Mapping unifié - utilise maintenant les slots 70-86 pour tous les styles
    [70] = { type = 'prop', id = 0, emptyDrawable = -1, emptyTexture = -1 },      -- hat
    [71] = { type = 'component', id = 1, emptyDrawable = 0, emptyTexture = 0 },  -- mask
    [72] = { type = 'prop', id = 1, emptyDrawable = -1, emptyTexture = -1 },     -- glasses
    [73] = { type = 'component', id = 7, emptyDrawable = 0, emptyTexture = 0 },  -- chain/neck
	[74] = { type = 'component', id = 3, emptyDrawable = 15, emptyTexture = 0 }, -- hands/gloves
	[75] = { type = 'component', id = 11, emptyDrawable = 15, emptyTexture = 0 },-- torso/jacket/undershirt
    [76] = { type = 'prop', id = 6, emptyDrawable = -1, emptyTexture = -1 },     -- watch
    [77] = { type = 'component', id = 4, emptyDrawable = 14, emptyTexture = 0 }, -- pants
    [78] = { type = 'prop', id = 2, emptyDrawable = -1, emptyTexture = -1 },     -- earrings
    [79] = { type = 'component', id = 5, emptyDrawable = 0, emptyTexture = 0 },  -- bags
    [80] = { type = 'component', id = 8, emptyDrawable = 15, emptyTexture = 0 }, -- tshirt
    [81] = { type = 'component', id = 9, emptyDrawable = 0, emptyTexture = 0 },  -- vest
    [82] = { type = 'prop', id = 7, emptyDrawable = -1, emptyTexture = -1 },     -- bracelet
    [83] = { type = 'component', id = 6, emptyDrawable = 34, emptyTexture = 0 }, -- shoes
    [85] = { type = 'component', id = 2, emptyDrawable = 0, emptyTexture = 0 },  -- hair (placeholder)
    [86] = { type = 'outfit', id = 0, emptyDrawable = 0, emptyTexture = 0 }      -- outfit
}

-- flashbackSlotMapping est maintenant identique à clothingSlotMapping (unifié)
local flashbackSlotMapping = clothingSlotMapping

-- Mapping unifié item name -> slot ID (70-86)
local itemNameToSlotMapping = {
    hat = 70, hats = 70,
    mask = 71, masks = 71,
    glasse = 72, glasses = 72, goggles = 72,
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

-- Ajouter les kevilles au mapping (slot 81 = vest)
for i = 1, 12 do
    itemNameToSlotMapping['keville' .. i] = 81
end
itemNameToSlotMapping.kevlarle = 81
itemNameToSlotMapping.kevlarm = 81
itemNameToSlotMapping.kevlarlo = 81

local clothingNameExclusions = {
	key_chain = true,
}

local function isExcludedClothingItemName(itemName)
	if type(itemName) ~= 'string' or itemName == '' then return false end
	return clothingNameExclusions[string.lower(itemName)] == true
end

-- flashbackItemToSlot est maintenant identique à itemNameToSlotMapping (unifié)
local flashbackItemToSlot = itemNameToSlotMapping


local kevlarDrawables = {
    keville1 = { drawable = 1, armour = 25 },
    keville3 = { drawable = 3, armour = 25 },
    keville4 = { drawable = 4, armour = 25 },
    kevlarle = { drawable = 1, armour = 25 },
    keville9 = { drawable = 5, armour = 50 },
    keville10 = { drawable = 6, armour = 50 },
    keville11 = { drawable = 7, armour = 50 },
    keville12 = { drawable = 8, armour = 50 },
    kevlarm = { drawable = 5, armour = 50 },
    keville5 = { drawable = 10, armour = 100 },
    keville6 = { drawable = 11, armour = 100 },
    keville7 = { drawable = 12, armour = 100 },
    keville8 = { drawable = 13, armour = 100 },
    kevlarlo = { drawable = 10, armour = 100 },
    boikev = { drawable = 1, armour = 100 },
    dojkev = { drawable = 1, armour = 100 },
    g6kev = { drawable = 1, armour = 100 },
    g6kev2 = { drawable = 1, armour = 100 },
    gouvernorkev = { drawable = 1, armour = 100 },
    gouvkev = { drawable = 1, armour = 100 },
    irscikev = { drawable = 1, armour = 100 },
    irskev = { drawable = 1, armour = 100 },
    lsfdkev1 = { drawable = 1, armour = 100 },
    lsfdkev2 = { drawable = 1, armour = 100 },
    lsfdkev3 = { drawable = 1, armour = 100 },
    lsfdkev4 = { drawable = 1, armour = 100 },
    lsfdkev5 = { drawable = 1, armour = 100 },
    lspdgiletj = { drawable = 1, armour = 100 },
    lspdgnd = { drawable = 1, armour = 100 },
    lssdgiletj = { drawable = 1, armour = 100 },
    lssdkevlo1 = { drawable = 1, armour = 100 },
    lssdkevlo2 = { drawable = 1, armour = 100 },
    lssdkevlo3 = { drawable = 1, armour = 100 },
    lssdkevlo4 = { drawable = 1, armour = 100 },
    lssdkevlo5 = { drawable = 1, armour = 100 },
    lssdkevlo6 = { drawable = 1, armour = 100 },
    lssdkevlo7 = { drawable = 1, armour = 100 },
    samskev = { drawable = 1, armour = 100 },
    samskev2 = { drawable = 1, armour = 100 },
    samskev3 = { drawable = 1, armour = 100 },
    samskev4 = { drawable = 1, armour = 100 },
    samskev5 = { drawable = 1, armour = 100 },
    usbpgiletb = { drawable = 1, armour = 100 },
    usbpgiletj = { drawable = 1, armour = 100 },
    ussskev1 = { drawable = 1, armour = 100 },
    ussskev2 = { drawable = 1, armour = 100 },
    ussskev3 = { drawable = 1, armour = 100 },
    ussskev4 = { drawable = 1, armour = 100 },
	gpb_f_1 = { drawable = 1, armour = 100, applyArmour = false },
	gpb_f_2 = { drawable = 1, armour = 100, applyArmour = false },
	gpb_h_1 = { drawable = 1, armour = 100, applyArmour = false },
	gpb_h_2 = { drawable = 1, armour = 100, applyArmour = false },
	gpb_h_3 = { drawable = 1, armour = 100, applyArmour = false },
    lsfdkev = { drawable = 1, armour = 100 },
    lspdkevco = { drawable = 1, armour = 100 },
    lspdkevcs = { drawable = 1, armour = 100 },
    lspdkevdb = { drawable = 1, armour = 100 },
    lspdkevfieldsup = { drawable = 1, armour = 100 },
    lspdkeviad = { drawable = 1, armour = 100 },
    lspdkevle1 = { drawable = 1, armour = 100 },
    lspdkevle2 = { drawable = 1, armour = 100 },
    lspdkevle3 = { drawable = 1, armour = 100 },
    lspdkevlo1 = { drawable = 1, armour = 100 },
    lspdkevlo2 = { drawable = 1, armour = 100 },
    lspdkevlo3 = { drawable = 1, armour = 100 },
    lspdkevlo4 = { drawable = 1, armour = 100 },
    lspdkevlourd = { drawable = 1, armour = 100 },
    lspdkevm1 = { drawable = 1, armour = 100 },
    lspdkevnegotiator = { drawable = 1, armour = 100 },
    lspdkevpc = { drawable = 1, armour = 100 },
    lspdkevpc2 = { drawable = 1, armour = 100 },
    lspdkevsupervisor = { drawable = 1, armour = 100 },
    lspdkevswat = { drawable = 1, armour = 100 },
    lssdkevle1 = { drawable = 1, armour = 100 },
    lssdkevle2 = { drawable = 1, armour = 100 },
    usbpkevlo1 = { drawable = 1, armour = 100 },
    usbpkevlo2 = { drawable = 1, armour = 100 },
    usbpkevlo3 = { drawable = 1, armour = 100 },
    usbpkevlo4 = { drawable = 1, armour = 100 },
    usbpkevlo5 = { drawable = 1, armour = 100 },
    usbpkevpc = { drawable = 1, armour = 100 },
}

local function shouldApplyKevlarArmour(kevlarInfo, metadata)
	if type(metadata) == 'table' then
		if metadata.applyArmour == false or metadata.giveArmour == false or metadata.clothingOnly == true then
			return false
		end
	end

	return not (type(kevlarInfo) == 'table' and kevlarInfo.applyArmour == false)
end

local function getClothingAnimationBySlot(slotId, mapping)
	if mapping.type == 'prop' then
		if mapping.id == 0 then
			return {dict = "clothingspecs", anim = "try_glasses_positive_a"}
		elseif mapping.id == 1 then
			return {dict = "mp_character_creation@lineup@male_a", anim = "loop"}
		elseif mapping.id == 2 then
			return {dict = "mp_character_creation@lineup@male_a", anim = "loop"}
		elseif mapping.id == 6 then
			return {dict = "clothingshirt", anim = "try_shirt_positive_d"}
		elseif mapping.id == 7 then
			return {dict = "clothingshirt", anim = "try_shirt_positive_d"}
		else
			return {dict = "mp_character_creation@lineup@male_a", anim = "loop"}
		end
	elseif mapping.type == 'component' then
		if mapping.id == 1 then
			return {dict = "mp_masks@standard_car@ds@", anim = "put_on_mask"}
		elseif mapping.id == 3 then
			return {dict = "clothingshirt", anim = "try_shirt_positive_d"}
		elseif mapping.id == 4 then
			return {dict = "clothingshoes", anim = "try_shoes_positive_d"}
		elseif mapping.id == 5 then
			return {dict = "clothingshirt", anim = "try_shirt_positive_c"}
		elseif mapping.id == 6 then
			return {dict = "clothingshoes", anim = "try_shoes_positive_d"}
		elseif mapping.id == 7 then
			return {dict = "clothingtie", anim = "try_tie_positive_d"}
		elseif mapping.id == 8 then
			return {dict = "mp_clothing@female@shirt", anim = "try_shirt_positive_a"}
		elseif mapping.id == 9 then
			return {dict = "clothingshirt", anim = "try_shirt_positive_d"}
		elseif mapping.id == 10 then
			return {dict = "clothingshirt", anim = "try_shirt_positive_d"}
		elseif mapping.id == 11 then
			return {dict = "clothingshirt", anim = "try_shirt_positive_d"}
		else
			return {dict = "clothingshirt", anim = "try_shirt_positive_d"}
		end
	end
	return {dict = "clothingshirt", anim = "try_shirt_positive_d"}
end

local function applyClothing(slotId, itemMetadata, skipAnimation)
    -- Slots unifiés 70-86 pour tous les styles
    if type(slotId) ~= 'number' or slotId < 70 or slotId > 86 then
        return false
    end

	if itemMetadata and itemMetadata.name and isExcludedClothingItemName(itemMetadata.name) then
		return false
	end
    
    local mapping = clothingSlotMapping[slotId]
    
    if not mapping or not mapping.type or type(mapping.id) ~= 'number' then 
        return false
    end

    local ped = cache.ped
    if not ped or not DoesEntityExist(ped) then 
        return false
    end
    
    if not skipAnimation then
        local animData
        if (slotId == 1 or slotId == 70) and mapping.type == 'prop' and mapping.id == 0 then
            if itemMetadata and itemMetadata.name then
                animData = {dict = "veh@common@fp_helmet@", anim = "put_on_helmet"}
            else
                animData = {dict = "veh@common@fp_helmet@", anim = "take_off_helmet"}
            end
        else
            animData = getClothingAnimationBySlot(slotId, mapping)
        end
        
        lib.requestAnimDict(animData.dict)
        TaskPlayAnim(ped, animData.dict, animData.anim, 8.0, 8.0, -1, 49, 0, false, false, false)

        if GetResourceState('rprogress') == 'started' then
            pcall(function()
                exports.rprogress:_DOLI_PROGRESSBAR_START(2)
            end)
        end

        Wait(2000)

        ClearPedTasks(ped)
        RemoveAnimDict(animData.dict)
    end
    
    local success = pcall(function()

    if itemMetadata and itemMetadata.name then
        local kevlarConfig = Config and Config.Kevlar or kevlarDrawables
        local kevlarInfo = kevlarConfig[itemMetadata.name]
		local metadata = itemMetadata.metadata
		if type(metadata) ~= 'table' then
			metadata = {}
		end
        
        if slotId == 81 then
            local drawable = nil
            local armour = nil
            local texture = 0
            local applyArmour = shouldApplyKevlarArmour(kevlarInfo, metadata)
            
			if metadata.component ~= nil then
				drawable = tonumber(metadata.drawable) or 0
				texture = tonumber(metadata.texture) or 0
				if applyArmour then
					armour = tonumber(metadata.armour) or (kevlarInfo and kevlarInfo.armour) or 100
				end
			elseif metadata.drawable ~= nil then
				drawable = tonumber(metadata.drawable)
				texture = tonumber(metadata.texture) or 0
				if applyArmour then
					armour = tonumber(metadata.armour) or (kevlarInfo and kevlarInfo.armour) or 100
				end
            elseif kevlarInfo then
                drawable = kevlarInfo.drawable
                texture = 0
                if applyArmour then
                    armour = kevlarInfo.armour
                end
            end
            
            if drawable then
                local currentComponent = GetPedDrawableVariation(ped, 9)
                local currentTexture = GetPedTextureVariation(ped, 9)
                local currentArmor = GetPedArmour(ped)
                
                if currentComponent ~= drawable or currentTexture ~= texture then
                    SetPedComponentVariation(ped, 9, drawable, texture, 0)
                end
                
				if armour ~= nil and currentArmor ~= armour then
                    SetPlayerMaxArmour(PlayerData.id, 100)
                    SetPedArmour(ped, armour)
                end
            end
		elseif mapping.type == 'component' and metadata.drawable ~= nil then
			local drawable = tonumber(metadata.drawable) or 0
			local texture = tonumber(metadata.texture) or 0
            
            if IsPedComponentVariationValid(ped, mapping.id, drawable, texture) then
                local currentComponent = GetPedDrawableVariation(ped, mapping.id)
                local currentTexture = GetPedTextureVariation(ped, mapping.id)
                
                if currentComponent ~= drawable or currentTexture ~= texture then
                    SetPedComponentVariation(ped, mapping.id, drawable, texture, 0)
                end
            end
		elseif mapping.type == 'prop' and metadata.drawable ~= nil then
			local drawable = tonumber(metadata.drawable)
			local texture = tonumber(metadata.texture) or 0

			if drawable == -1 then
				if GetPedPropIndex(ped, mapping.id) ~= -1 then
					ClearPedProp(ped, mapping.id)
				end
			elseif drawable ~= nil and SetPedPreloadPropData(ped, mapping.id, drawable, texture) then
				local currentProp = GetPedPropIndex(ped, mapping.id)
				local currentTexture = GetPedPropTextureIndex(ped, mapping.id)
                
				if currentProp ~= drawable or currentTexture ~= texture then
					SetPedPropIndex(ped, mapping.id, drawable, texture, false)
				end
            end
        end
    else
        if slotId == 81 then
            local currentComponent = GetPedDrawableVariation(ped, 9)
            local currentArmor = GetPedArmour(ped)
            
            if currentComponent ~= 0 then
                SetPedComponentVariation(ped, 9, 0, 0, 0)
            end
            
            if currentArmor > 0 then
                SetPedArmour(ped, 0)
            end
        elseif mapping.type == 'component' then
            local currentComponent = GetPedDrawableVariation(ped, mapping.id)
            
            if currentComponent ~= mapping.emptyDrawable then
                SetPedComponentVariation(ped, mapping.id, mapping.emptyDrawable, mapping.emptyTexture, 0)
            end
        elseif mapping.type == 'prop' then
            if mapping.emptyDrawable == -1 then
                if GetPedPropIndex(ped, mapping.id) ~= -1 then
                    ClearPedProp(ped, mapping.id)
                end
            else
                local currentProp = GetPedPropIndex(ped, mapping.id)
                
                if currentProp ~= mapping.emptyDrawable then
                    SetPedPropIndex(ped, mapping.id, mapping.emptyDrawable, mapping.emptyTexture, false)
                end
            end
        end
    end
    end)
    
    return success
end

local recentOutfitRemovals = {}

RegisterNUICallback('updateClothingSlot', function(data, cb)
	cb(true)

	if not data or type(data) ~= 'table' then
		return
	end

	local CLOTHING_SLOT_OFFSET = 69
	local rawSlot = tonumber(data.slotId)
	if not rawSlot then return end

	local normalizedSlot = rawSlot
	local slotIndex = rawSlot

	local function outfitUiDebug(...)
	end
	
	if rawSlot >= 70 and rawSlot <= 86 then
		normalizedSlot = rawSlot
		slotIndex = rawSlot
	elseif rawSlot >= 1 and rawSlot <= 17 then
		normalizedSlot = rawSlot + CLOTHING_SLOT_OFFSET
		slotIndex = rawSlot
	else
		return
	end

	if normalizedSlot == 84 then
		outfitUiDebug('updateClothingSlot: redirect raw slot 84 to slot 86')
		normalizedSlot = 86
		slotIndex = 86
	end

	-- Slot 86 is reserved for outfit/tenue. Allow it, but prevent outfit items from being placed in other clothing slots.
	if data.itemData and type(data.itemData) == 'table' and type(data.itemData.name) == 'string' then
		local itemName = string.lower(data.itemData.name)
		local isOutfitItem = (itemName == 'outfit' or itemName == 'tenue')
		if isOutfitItem and normalizedSlot ~= 86 then
			return
		end
		if (not isOutfitItem) and normalizedSlot == 86 then
			return
		end
		if isExcludedClothingItemName(itemName) then
			return
		end
	end

	local preOutfitClothingSlots = nil
	if normalizedSlot == 86 and data.itemData and data.itemData.metadata then
		preOutfitClothingSlots = lib.callback.await('ox_inventory:getClothingSlots', false) or {}
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

	local function getOutfitDataContainer(metadata)
		if not metadata or type(metadata) ~= 'table' then return nil end

		local candidates = {
			{ key = 'outfitData', value = metadata.outfitData },
			{ key = 'outfit', value = metadata.outfit },
			{ key = 'appearance', value = metadata.appearance },
			{ key = 'appearanceData', value = metadata.appearanceData },
			{ key = 'data', value = metadata.data },
			{ key = 'skin', value = metadata.skin },
			{ key = 'clothes', value = metadata.clothes },
			{ key = nil, value = metadata }
		}

		for _, candidate in ipairs(candidates) do
			local value = candidate.value
			if value then
				if type(value) == 'string' then
					local ok, decoded = pcall(json.decode, value)
					if ok and type(decoded) == 'table' then
						value = decoded
					else
						value = nil
					end
				end
				if type(value) == 'table' then
					if value.components or value.props then
						return { key = candidate.key, value = value, wasJson = type(candidate.value) == 'string' }
					end
					if value['pants'] or value['arms'] or value['t-shirt'] or value['torso2'] or value['mask'] or value['hat'] or value['glass'] or value['ear'] then
						return { key = candidate.key, value = value, wasJson = type(candidate.value) == 'string' }
					end
				end
			end
		end

		return nil
	end

	local function getOutfitCacheKey(itemData)
		if not itemData or type(itemData) ~= 'table' then return nil end
		local meta = itemData.metadata or {}
		local ok, encoded = pcall(json.encode, meta)
		if ok and encoded then
			return ('%s:%s'):format(tostring(itemData.name), encoded)
		end
		return tostring(itemData.name)
	end

	local function findComponent(components, id)
		if not components or not id then return nil end
		if type(components) == 'table' then
			if components[id] and type(components[id]) == 'table' then
				local compId = components[id].component_id or components[id].componentId or components[id].component or components[id].id
				if compId == id then return components[id] end
			end
			for _, comp in pairs(components) do
				local compId = comp.component_id or comp.componentId or comp.component or comp.id
				if compId == id then return comp end
			end
		end
		return nil
	end

	local function findProp(props, id)
		if not props or not id then return nil end
		if type(props) == 'table' then
			if props[id] and type(props[id]) == 'table' then
				local propId = props[id].prop_id or props[id].propId or props[id].prop or props[id].id
				if propId == id then return props[id] end
			end
			for _, prop in pairs(props) do
				local propId = prop.prop_id or prop.propId or prop.prop or prop.id
				if propId == id then return prop end
			end
		end
		return nil
	end

	local function buildOutfitClothingItems(itemData)
		if not itemData or type(itemData) ~= 'table' then return {} end
		local outfit = getOutfitDataFromMetadata(itemData.metadata)
		if not outfit then
			outfitUiDebug('buildOutfitClothingItems: no outfit metadata')
			return {}
		end

		local itemsBySlot = {}

		local function addComponent(slotId, name, componentId, drawable, texture)
			if drawable == nil then return end
			if componentId == 1 and (drawable == 0 or drawable == -1) and (texture == nil or texture == 0) then
				return
			end
			itemsBySlot[slotId] = {
				name = name,
				count = 1,
				weight = 0,
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
				weight = 0,
				metadata = {
					prop = propId,
					drawable = drawable,
					texture = texture or 0,
					fromOutfit = true,
					outfitSlot = 86
				}
			}
		end

		-- illenium-appearance job outfit structure
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

		-- generic appearance structure (components/props arrays)
		if outfit.components or outfit.props then
			local compMask = findComponent(outfit.components, 1)
			local compArms = findComponent(outfit.components, 3)
			local compTorso = findComponent(outfit.components, 11)
			local compTshirt = findComponent(outfit.components, 8)
			local compPants = findComponent(outfit.components, 4)
			local compShoes = findComponent(outfit.components, 6)
			local compVest = findComponent(outfit.components, 9)
			local compBag = findComponent(outfit.components, 5)
			local compChain = findComponent(outfit.components, 7)

			if compMask then addComponent(71, 'mask', 1, compMask.drawable or compMask.item, compMask.texture) end
			if compArms then addComponent(74, 'gloves', 3, compArms.drawable or compArms.item, compArms.texture) end
			if compTorso then addComponent(75, 'jacket', 11, compTorso.drawable or compTorso.item, compTorso.texture) end
			if compTshirt then addComponent(80, 'tshirt', 8, compTshirt.drawable or compTshirt.item, compTshirt.texture) end
			if compPants then addComponent(77, 'pants', 4, compPants.drawable or compPants.item, compPants.texture) end
			if compShoes then addComponent(83, 'shoes', 6, compShoes.drawable or compShoes.item, compShoes.texture) end
			if compVest then addComponent(81, 'vest', 9, compVest.drawable or compVest.item, compVest.texture) end
			if compBag then addComponent(79, 'bag', 5, compBag.drawable or compBag.item, compBag.texture) end
			if compChain then addComponent(73, 'chain', 7, compChain.drawable or compChain.item, compChain.texture) end

			local propHat = findProp(outfit.props, 0)
			local propGlasses = findProp(outfit.props, 1)
			local propEar = findProp(outfit.props, 2)
			local propWatch = findProp(outfit.props, 6)
			local propBracelet = findProp(outfit.props, 7)

			if propHat then addProp(70, 'hat', 0, propHat.drawable or propHat.item, propHat.texture) end
			if propGlasses then addProp(72, 'glasses', 1, propGlasses.drawable or propGlasses.item, propGlasses.texture) end
			if propEar then addProp(78, 'earring', 2, propEar.drawable or propEar.item, propEar.texture) end
			if propWatch then addProp(76, 'watch', 6, propWatch.drawable or propWatch.item, propWatch.texture) end
			if propBracelet then addProp(82, 'bracelet', 7, propBracelet.drawable or propBracelet.item, propBracelet.texture) end
		end

		return itemsBySlot
	end

	local function removeOutfitEntry(outfitMeta, slotId)
		if not outfitMeta or type(outfitMeta) ~= 'table' then return false end
		local removed = false

		local keyBySlot = {
			[77] = 'pants',
			[74] = 'arms',
			[80] = 't-shirt',
			[81] = 'vest',
			[75] = 'torso2',
			[83] = 'shoes',
			[73] = 'accessory',
			[71] = 'mask',
			[79] = 'bag',
			[70] = 'hat',
			[72] = 'glass',
			[78] = 'ear',
		}

		local key = keyBySlot[slotId]
		if key and outfitMeta[key] then
			outfitMeta[key] = nil
			removed = true
		end

		local function filterList(list, idValue, idKeys)
			if type(list) ~= 'table' then return false end
			local newList = {}
			local changed = false
			for _, entry in pairs(list) do
				local entryId
				if type(entry) == 'table' then
					for _, keyName in ipairs(idKeys) do
						if entry[keyName] ~= nil then
							entryId = entry[keyName]
							break
						end
					end
				end
				if entryId == idValue then
					changed = true
				else
					newList[#newList + 1] = entry
				end
			end
			if changed then
				for k in pairs(list) do
					list[k] = nil
				end
				for i, v in ipairs(newList) do
					list[i] = v
				end
			end
			return changed
		end

		local componentIdBySlot = {
			[71] = 1,
			[74] = 3,
			[75] = 11,
			[80] = 8,
			[77] = 4,
			[83] = 6,
			[81] = 9,
			[79] = 5,
			[73] = 7,
		}

		local propIdBySlot = {
			[70] = 0,
			[72] = 1,
			[78] = 2,
			[76] = 6,
			[82] = 7,
		}

		local componentId = componentIdBySlot[slotId]
		if componentId and outfitMeta.components then
			if filterList(outfitMeta.components, componentId, { 'component_id', 'componentId', 'component', 'id' }) then
				removed = true
			end
		end

		local propId = propIdBySlot[slotId]
		if propId and outfitMeta.props then
			if filterList(outfitMeta.props, propId, { 'prop_id', 'propId', 'prop', 'id' }) then
				removed = true
			end
		end

		return removed
	end

	local function addOrReplaceById(list, idValue, idKeys, newEntry)
		if type(list) ~= 'table' then return false end
		local updated = false
		for i, entry in pairs(list) do
			if type(entry) == 'table' then
				for _, keyName in ipairs(idKeys) do
					if entry[keyName] ~= nil and entry[keyName] == idValue then
						list[i] = newEntry
						updated = true
						break
					end
				end
			end
			if updated then break end
		end
		if not updated then
			list[#list + 1] = newEntry
			updated = true
		end
		return updated
	end

	local function addOutfitEntry(outfitMeta, slotId, itemMeta)
		if not outfitMeta or type(outfitMeta) ~= 'table' or not itemMeta then return false end
		local updated = false

		local keyBySlot = {
			[77] = 'pants',
			[74] = 'arms',
			[80] = 't-shirt',
			[81] = 'vest',
			[75] = 'torso2',
			[83] = 'shoes',
			[73] = 'accessory',
			[71] = 'mask',
			[79] = 'bag',
			[70] = 'hat',
			[72] = 'glass',
			[78] = 'ear',
		}

		local key = keyBySlot[slotId]
		if key then
			outfitMeta[key] = {
				item = itemMeta.drawable,
				texture = itemMeta.texture or 0
			}
			updated = true
		end

		local componentIdBySlot = {
			[71] = 1,
			[74] = 3,
			[75] = 11,
			[80] = 8,
			[77] = 4,
			[83] = 6,
			[81] = 9,
			[79] = 5,
			[73] = 7,
		}

		local propIdBySlot = {
			[70] = 0,
			[72] = 1,
			[78] = 2,
			[76] = 6,
			[82] = 7,
		}

		local componentId = componentIdBySlot[slotId]
		if componentId then
			outfitMeta.components = outfitMeta.components or {}
			local compEntry = { component_id = componentId, drawable = itemMeta.drawable, texture = itemMeta.texture or 0 }
			if addOrReplaceById(outfitMeta.components, componentId, { 'component_id', 'componentId', 'component', 'id' }, compEntry) then
				updated = true
			end
		end

		local propId = propIdBySlot[slotId]
		if propId then
			outfitMeta.props = outfitMeta.props or {}
			local propEntry = { prop_id = propId, drawable = itemMeta.drawable, texture = itemMeta.texture or 0 }
			if addOrReplaceById(outfitMeta.props, propId, { 'prop_id', 'propId', 'prop', 'id' }, propEntry) then
				updated = true
			end
		end

		return updated
	end

	local success = pcall(function()
		outfitUiDebug('updateClothingSlot: normalizedSlot=%s item=%s', tostring(normalizedSlot), tostring(data.itemData and data.itemData.name))
		applyClothing(slotIndex, data.itemData)
		UpdateClonedPedClothing(normalizedSlot, data.itemData)
		outfitUiDebug('updateClothingSlot: saveClothingSlot slot=%s item=%s', tostring(normalizedSlot), tostring(data.itemData and data.itemData.name))
		TriggerServerEvent('ox_inventory:saveClothingSlot', normalizedSlot, data.itemData)
		
		-- Save appearance using detected clothing system
		saveClothingAppearance()
		if currentInventory and currentInventory.type ~= 'crafting' and currentInventory.type ~= 'shop' then
			PedScreenCreate(cache.ped, {
				dict = "anim@amb@nightclub@peds@",
				anim = "rcmme_amanda1_stand_loop_cop"
			})
		end
		
		Wait(100)

		local refreshItems = {
			{
				item = data.itemData and {
					slot = normalizedSlot,
					name = data.itemData.name,
					count = data.itemData.count or 1,
					weight = data.itemData.weight or 0,
					metadata = data.itemData.metadata
				} or {
					slot = normalizedSlot
				},
				inventory = 'clothing'
			}
		}

		if normalizedSlot == 86 and data.itemData and data.itemData.metadata then
			local outfitItems = buildOutfitClothingItems(data.itemData)
			local outfitCount = 0
			for _ in pairs(outfitItems) do
				outfitCount = outfitCount + 1
			end
			outfitUiDebug('slot 86 apply: outfit items=%s', tostring(outfitCount))
			local clothingSlots = preOutfitClothingSlots or (lib.callback.await('ox_inventory:getClothingSlots', false) or {})
			local clothingBySlot = {}
			for _, slotData in pairs(clothingSlots) do
				if slotData and slotData.slot then
					clothingBySlot[slotData.slot] = slotData
				end
			end

			local previousSlots = {}

			local function sameClothingMeta(a, b)
				if not a or not b then return false end
				return a.component == b.component
					and a.prop == b.prop
					and a.drawable == b.drawable
					and (a.texture or 0) == (b.texture or 0)
			end

			for slotId, itemData in pairs(outfitItems) do
				outfitUiDebug('slot 86 apply: slot=%s item=%s drawable=%s texture=%s', tostring(slotId), tostring(itemData.name), tostring(itemData.metadata and itemData.metadata.drawable), tostring(itemData.metadata and itemData.metadata.texture))
				local existing = clothingBySlot[slotId]
				if existing and existing.name then
					local existingMeta = existing.metadata or {}
					if existingMeta.permanent or existingMeta.lockedCloth then
						outfitUiDebug('slot 86 apply: slot=%s locked/permanent, skip', tostring(slotId))
						goto continue_outfit_slot
					end
					previousSlots[#previousSlots + 1] = {
						slot = slotId,
						name = existing.name,
						count = existing.count or 1,
						weight = existing.weight or 0,
						metadata = existingMeta
					}
					outfitUiDebug('slot 86 apply: slot=%s move existing to inventory item=%s', tostring(slotId), tostring(existing.name))
					TriggerServerEvent('ox_inventory:clearClothingSlot', slotId, true)
				end

				TriggerServerEvent('ox_inventory:saveClothingSlot', slotId, itemData)
				outfitUiDebug('slot 86 apply: saveClothingSlot slot=%s item=%s', tostring(slotId), tostring(itemData.name))

				applyClothing(slotId, itemData, true)
				UpdateClonedPedClothing(slotId, itemData)
				::continue_outfit_slot::

				refreshItems[#refreshItems + 1] = {
					item = {
						slot = slotId,
						name = itemData.name,
						count = itemData.count or 1,
						weight = itemData.weight or 0,
						metadata = itemData.metadata
					},
					inventory = 'clothing'
				}
			end

			if #previousSlots > 0 then
				local updatedMeta = table.clone(data.itemData.metadata)
				updatedMeta.previousSlots = previousSlots
				local updatedItem = {
					name = data.itemData.name,
					count = data.itemData.count or 1,
					weight = data.itemData.weight or 0,
					metadata = updatedMeta
				}
				recentOutfitRemovals.last = previousSlots
				local cacheKey = getOutfitCacheKey(updatedItem)
				if cacheKey then
					recentOutfitRemovals[cacheKey] = previousSlots
				end
				outfitUiDebug('slot 86 apply: save previousSlots count=%s', tostring(#previousSlots))
				TriggerServerEvent('ox_inventory:saveClothingSlot', 86, updatedItem)

				refreshItems[#refreshItems + 1] = {
					item = {
						slot = 86,
						name = updatedItem.name,
						count = updatedItem.count or 1,
						weight = updatedItem.weight or 0,
						metadata = updatedItem.metadata
					},
					inventory = 'clothing'
				}
			end

			if currentInventory and currentInventory.type ~= 'crafting' and currentInventory.type ~= 'shop' then
				PedScreenCreate(cache.ped, {
					dict = "anim@amb@nightclub@peds@",
					anim = "rcmme_amanda1_stand_loop_cop"
				})
			end
		end

		if normalizedSlot ~= 86 and data.itemData and data.itemData.metadata then
			local clothingSlots = lib.callback.await('ox_inventory:getClothingSlots', false) or {}
			local outfitSlot
			for _, slotData in pairs(clothingSlots) do
				if slotData and slotData.slot == 86 and slotData.name then
					outfitSlot = slotData
					break
				end
			end

			if outfitSlot and outfitSlot.metadata then
				outfitUiDebug('update outfit metadata from slot=%s into slot 86', tostring(normalizedSlot))
				local updatedMeta = table.clone(outfitSlot.metadata)
				local container = getOutfitDataContainer(updatedMeta)
				local targetMeta = container and container.value or updatedMeta
				if addOutfitEntry(targetMeta, normalizedSlot, data.itemData.metadata) then
					if container and container.key then
						if container.wasJson then
							updatedMeta[container.key] = json.encode(targetMeta)
						else
							updatedMeta[container.key] = targetMeta
						end
					end
					updatedMeta._skipOutfitClear = true

					local updatedItem = {
						name = outfitSlot.name,
						count = outfitSlot.count or 1,
						weight = outfitSlot.weight or 0,
						metadata = updatedMeta
					}
					TriggerServerEvent('ox_inventory:saveClothingSlot', 86, updatedItem)

					refreshItems[#refreshItems + 1] = {
						item = {
							slot = 86,
							name = updatedItem.name,
							count = updatedItem.count or 1,
							weight = updatedItem.weight or 0,
							metadata = updatedItem.metadata
						},
						inventory = 'clothing'
					}
				end
			end
		end

		if normalizedSlot == 86 and data.itemData == nil then
			local clothingSlots = lib.callback.await('ox_inventory:getClothingSlots', false) or {}
			local clearedSlots = {}
			local clothingBySlot = {}

			for _, slotData in pairs(clothingSlots) do
				if slotData and slotData.slot then
					clothingBySlot[slotData.slot] = slotData
				end
			end

			if data.removedItem and data.removedItem.metadata then
				local outfitItems = buildOutfitClothingItems(data.removedItem)
				for slotId in pairs(outfitItems) do
					clearedSlots[slotId] = true
				end
			end

			for _, slotData in pairs(clothingSlots) do
				if slotData and slotData.slot and slotData.metadata and (slotData.metadata.outfitSlot == 86 or slotData.metadata.fromOutfit) then
					clearedSlots[slotData.slot] = true
				end
			end

			for slotId in pairs(clearedSlots) do
				local existing = clothingBySlot[slotId]
				if existing and existing.metadata and (existing.metadata.permanent or existing.metadata.lockedCloth) then
					goto continue_clear_slot
				end
				applyClothing(slotId, nil, true)
				UpdateClonedPedClothing(slotId, nil)
				TriggerServerEvent('ox_inventory:clearClothingSlot', slotId, false)

				refreshItems[#refreshItems + 1] = {
					item = { slot = slotId },
					inventory = 'clothing'
				}
				::continue_clear_slot::
			end

			local restoreSlots = nil
			if data.removedItem and data.removedItem.metadata and type(data.removedItem.metadata.previousSlots) == 'table' then
				restoreSlots = data.removedItem.metadata.previousSlots
			else
				local removedKey = data.removedItem and getOutfitCacheKey(data.removedItem)
				restoreSlots = (removedKey and recentOutfitRemovals[removedKey]) or recentOutfitRemovals.last
			end

			if type(restoreSlots) == 'table' then
				outfitUiDebug('slot 86 clear: restore previousSlots count=%s', tostring(#restoreSlots))
				for i = 1, #restoreSlots do
					local restoreItem = restoreSlots[i]
					if restoreItem and restoreItem.slot and restoreItem.name then
						TriggerServerEvent('ox_inventory:saveClothingSlot', restoreItem.slot, restoreItem)
						applyClothing(restoreItem.slot, restoreItem, true)
						UpdateClonedPedClothing(restoreItem.slot, restoreItem)
						refreshItems[#refreshItems + 1] = {
							item = {
								slot = restoreItem.slot,
								name = restoreItem.name,
								count = restoreItem.count or 1,
								weight = restoreItem.weight or 0,
								metadata = restoreItem.metadata
							},
							inventory = 'clothing'
						}
					end
				end
			end

			if currentInventory and currentInventory.type ~= 'crafting' and currentInventory.type ~= 'shop' then
				PedScreenCreate(cache.ped, {
					dict = "anim@amb@nightclub@peds@",
					anim = "rcmme_amanda1_stand_loop_cop"
				})
			end
		end

		if data.itemData == nil and normalizedSlot ~= 86 then
			local clothingSlots = lib.callback.await('ox_inventory:getClothingSlots', false) or {}
			local outfitSlot
			for _, slotData in pairs(clothingSlots) do
				if slotData and slotData.slot == 86 and slotData.name then
					outfitSlot = slotData
					break
				end
			end

			if outfitSlot and outfitSlot.metadata then
				local updatedMeta = table.clone(outfitSlot.metadata)
				local container = getOutfitDataContainer(updatedMeta)
				local targetMeta = container and container.value or updatedMeta
				if removeOutfitEntry(targetMeta, normalizedSlot) then
					if container and container.key then
						if container.wasJson then
							updatedMeta[container.key] = json.encode(targetMeta)
						else
							updatedMeta[container.key] = targetMeta
						end
					end
					updatedMeta._skipOutfitClear = true
					local updatedItem = {
						name = outfitSlot.name,
						count = outfitSlot.count or 1,
						weight = outfitSlot.weight or 0,
						metadata = updatedMeta
					}
					TriggerServerEvent('ox_inventory:saveClothingSlot', 86, updatedItem)

					refreshItems[#refreshItems + 1] = {
						item = {
							slot = 86,
							name = updatedItem.name,
							count = updatedItem.count or 1,
							weight = updatedItem.weight or 0,
							metadata = updatedItem.metadata
						},
						inventory = 'clothing'
					}
				end
			end
		end

		SendNUIMessage({
			action = 'refreshSlots',
			data = {
				items = refreshItems
			}
		})
	end)
	
end)

RegisterNUICallback('previewClothing', function(data, cb)
	cb(true)
	
	if not data or type(data) ~= 'table' then
		return
	end
	
	local previewEnabled = true
	if Config and Config.Clothing and Config.Clothing.EnablePreview ~= nil then
		previewEnabled = Config.Clothing.EnablePreview
	end
	
	if not previewEnabled then
		return
	end
	
	local success = pcall(function()

		local previewItemData = nil

		if type(data.itemData) == 'table' then
			previewItemData = table.clone(data.itemData)
		elseif type(data.item) == 'table' then
			previewItemData = table.clone(data.item)
		else
			previewItemData = {
				name = data.itemName or data.name,
				metadata = data.metadata or {}
			}
		end

		if previewItemData then
			previewItemData.name = previewItemData.name or data.itemName or data.name or 'preview_clothing'
			if type(previewItemData.metadata) ~= 'table' then
				previewItemData.metadata = data.metadata or {}
			end

			local previewSignature = buildClothingPreviewSignature(previewItemData)
			if previewSignature and previewSignature == lastClothingPreviewSignature then
				return
			end

			if not ensureClothingPreviewPed() then
				return
			end

			lastClothingPreviewSignature = previewSignature

			PreviewClothingOnClone(previewItemData)
		end
	end)
	
end)

RegisterNUICallback('clearClothingPreview', function(data, cb)
	cb(true)
	lastClothingPreviewSignature = nil
	
	local success = pcall(function()
		if not RestoreClothingState() then
			PedScreenCreate(cache.ped, {
				dict = "anim@amb@nightclub@peds@",
				anim = "rcmme_amanda1_stand_loop_cop"
			})
		elseif cache.ped and DoesEntityExist(cache.ped) then
			refreshClonedPedFromSource(cache.ped, {
				dict = "anim@amb@nightclub@peds@",
				anim = "rcmme_amanda1_stand_loop_cop"
			})
		end
	end)
	
end)

local storedHairStyle = nil

RegisterNUICallback('Inventory:ClothAction', function(data, cb)
	cb(true)

	if not data or type(data) ~= 'table' then return end
	local action = data.event
	if type(action) ~= 'string' then return end

	local ped = cache.ped
	if not ped or not DoesEntityExist(ped) then return end

	if action == 'hats' then
		local propId = 0
		local propIndex = GetPedPropIndex(ped, propId)
		if propIndex == -1 then
			return
		end
		local texture = GetPedPropTextureIndex(ped, propId)
		local maxTextures = GetNumberOfPedPropTextureVariations(ped, propId, propIndex)
		if maxTextures and maxTextures > 1 then
			local nextTexture = (texture + 1) % maxTextures
			SetPedPropIndex(ped, propId, propIndex, nextTexture, false)
		end
		return
	end

	if action == 'hair' then
		local componentId = 2
		if not storedHairStyle then
			storedHairStyle = {
				drawable = GetPedDrawableVariation(ped, componentId),
				texture = GetPedTextureVariation(ped, componentId)
			}
			SetPedComponentVariation(ped, componentId, 0, 0, 0)
		else
			SetPedComponentVariation(ped, componentId, storedHairStyle.drawable, storedHairStyle.texture, 0)
			storedHairStyle = nil
		end
	end
end)

RegisterNUICallback('recoverCraftedItem', function(data, cb)
	cb(true)
	
	if data.item and data.quantity then
		TriggerServerEvent('ox_inventory:recoverCraftedItem', data.item, data.quantity)
	end
end)

local placingItem = false
local previewObject = nil
local placedItems = {}
local activePickupItemId
local pickupTextVisible = false
local placementRaycastMask = 1|2|4|8|16

local defaultPlacedItemsConfig = {
	Enabled = true,
	MaxDistance = 2.0,
	PickupTextUI = {
		Position = 'left-center',
		Icon = 'hand',
		Key = 'E'
	}
}

local function GetPlacedItemsConfig()
	return (Config and Config.PlacedItems) or defaultPlacedItemsConfig
end

local function IsWeaponItem(itemName)
	if not itemName then return false end

	local item = ItemList and ItemList[itemName]
	if item and item.weapon then
		return true
	end

	return client.weapons and client.weapons[itemName] ~= nil
end

local function ResolveGroundCoords(baseCoords)
	if not baseCoords then return baseCoords end

	local testHeights = { 0.0, 2.0, 4.0, 8.0, 16.0 }
	for i = 1, #testHeights do
		local offset = testHeights[i]
		local found, groundZ = GetGroundZFor_3dCoord(baseCoords.x, baseCoords.y, baseCoords.z + offset, false)
		if found then
			return vector3(baseCoords.x, baseCoords.y, groundZ)
		end
	end

	local startCoords = baseCoords + vec3(0.0, 0.0, 4.0)
	local endCoords = baseCoords - vec3(0.0, 0.0, 25.0)
	local hit, _, rayEnd = lib.raycast.fromCoords(startCoords, endCoords, placementRaycastMask, 4)
	if hit and rayEnd then
		return vector3(rayEnd.x, rayEnd.y, rayEnd.z)
	end

	return baseCoords
end

local function ApplyPlacementOrientation(entity, heading, isWeapon)
	if not entity or not DoesEntityExist(entity) then return end

	if isWeapon then
		local rotationConfig = GetPlacedItemsConfig().WeaponRotation or {}
		if rotationConfig.Enabled ~= false then
			local pitch = rotationConfig.Pitch or 90.0
			local roll = rotationConfig.Roll or 0.0
			local yawOffset = rotationConfig.YawOffset or 0.0
			local useHeading = rotationConfig.UseHeading ~= false
			local baseHeading = useHeading and (heading or 0.0) or 0.0
			SetEntityRotation(entity, pitch, roll, baseHeading + yawOffset, 2, true)
			local snapToGround = rotationConfig.SnapToGround ~= false
			if snapToGround then
				local currentCoords = GetEntityCoords(entity)
				local groundCoords = ResolveGroundCoords(currentCoords)
				SetEntityCoordsNoOffset(entity, groundCoords.x, groundCoords.y, groundCoords.z, false, false, false)
			end
			local zOffset = rotationConfig.ZOffset or 0.0
			if zOffset ~= 0 then
				local coords = GetEntityCoords(entity)
				SetEntityCoordsNoOffset(entity, coords.x, coords.y, coords.z + zOffset, false, false, false)
			end
			return
		end
	end

	SetEntityHeading(entity, heading)
	PlaceObjectOnGroundProperly(entity)
end

local function HidePickupTextUI()
	if pickupTextVisible then
		lib.hideTextUI()
		pickupTextVisible = false
		activePickupItemId = nil
	end
end

local function ShowPickupTextUI(placedItemId)
	local textConfig = GetPlacedItemsConfig().PickupTextUI or {}
	local keyLabel = textConfig.Key or 'E'
	local message = ('[%s] %s'):format(keyLabel, locale('ui_pickup_item'))
	lib.showTextUI(message, {
		position = textConfig.Position or 'left-center',
		icon = textConfig.Icon or 'hand'
	})
	pickupTextVisible = true
	activePickupItemId = placedItemId
end

local function GetItemProp(itemName)
	if not itemName then
		return Config and Config.PlacedItems and Config.PlacedItems.DefaultProp or 'prop_money_bag_01'
	end
	
	local item = ItemList and ItemList[itemName]
	if item and item.prop then
		return item.prop
	end
	
	local weaponData = client.weapons and client.weapons[itemName]
	if weaponData and weaponData.prop then
		return weaponData.prop
	end
	
	if item and item.weapon then
		local weaponDataFile = lib.load('data.weapons')
		if weaponDataFile and weaponDataFile.Weapons and weaponDataFile.Weapons[itemName] and weaponDataFile.Weapons[itemName].prop then
			return weaponDataFile.Weapons[itemName].prop
		end
		
		return 'w_pi_pistol'
	end
	
	return Config and Config.PlacedItems and Config.PlacedItems.DefaultProp or 'prop_money_bag_01'
end

RegisterNUICallback('placeItem', function(data, cb)
	cb(true)
	
	if placingItem then return end
	
	local slot = data.slot
	if not slot then return end
	
	local slotData = PlayerData.inventory[slot]
	if not slotData then return end
	
	local itemName = slotData.name
	local isWeapon = IsWeaponItem(itemName)
	local propModel = GetItemProp(itemName)
	
	placingItem = true
	local playerPed = PlayerPedId()
	local modelHash
	if type(propModel) == 'number' then
		modelHash = propModel
	elseif tonumber(propModel) then
		modelHash = tonumber(propModel)
	else
		modelHash = joaat(propModel)
	end
	
	lib.requestModel(modelHash, 5000)
	
	if not HasModelLoaded(modelHash) then
		placingItem = false
		return
	end
	
	local previewCoords = GetEntityCoords(playerPed)
	local forwardVector = GetEntityForwardVector(playerPed)
	local initialCoords = ResolveGroundCoords(previewCoords + forwardVector * 2.0)
	
	previewObject = CreateObject(modelHash, initialCoords.x, initialCoords.y, initialCoords.z, false, false, false)
	SetEntityAlpha(previewObject, 180, false)
	SetEntityCollision(previewObject, false, false)
	SetEntityInvincible(previewObject, true)
	FreezeEntityPosition(previewObject, true)
	ApplyPlacementOrientation(previewObject, GetEntityHeading(playerPed), isWeapon)
	
	AddTextEntry('ox_inventory_place_item', locale('ui_place') .. ' - ~INPUT_CONTEXT~')
	
	CreateThread(function()
		while placingItem do
			Wait(0)
			
			local playerCoords = GetEntityCoords(playerPed)
			local forwardVector = GetEntityForwardVector(playerPed)
			local distance = 2.0
			local targetCoords = playerCoords + forwardVector * distance
			
			local destination = playerCoords + forwardVector * (distance + 1.0)
			local hit, entityHit, endCoords = lib.raycast.fromCoords(playerCoords + vec3(0, 0, 0.5), destination, 1|2|4|8|16, 4)
			
			if hit and endCoords then
				targetCoords = endCoords
			else
				targetCoords = ResolveGroundCoords(targetCoords)
			end
			
			targetCoords = ResolveGroundCoords(targetCoords)
			SetEntityCoords(previewObject, targetCoords.x, targetCoords.y, targetCoords.z + 0.05, false, false, false, false)
			local heading = GetEntityHeading(playerPed)
			ApplyPlacementOrientation(previewObject, heading, isWeapon)
			
			BeginTextCommandDisplayHelp('ox_inventory_place_item')
			EndTextCommandDisplayHelp(0, false, false, -1)
			
			if IsControlJustPressed(0, 38) then
				local heading = GetEntityHeading(playerPed)
				ApplyPlacementOrientation(previewObject, heading, isWeapon)
				local finalCoords = ResolveGroundCoords(GetEntityCoords(previewObject))
				local finalHeading = GetEntityHeading(previewObject)
				
				DeleteEntity(previewObject)
				previewObject = nil
				placingItem = false
				
				local playerPed = PlayerPedId()
				lib.requestAnimDict('pickup_object')
				while not HasAnimDictLoaded('pickup_object') do
					Wait(10)
				end
				TaskPlayAnim(playerPed, 'pickup_object', 'putdown_low', 8.0, -8.0, 1000, 0, 0, false, false, false)
				Wait(1000)
				
				local success = lib.callback.await('ox_inventory:placeItem', false, slot, finalCoords, finalHeading)
				if success then
					lib.notify({ type = 'success', description = locale('ui_place') .. ' ' .. (ItemList[itemName] and ItemList[itemName].label or itemName) })
				else
					notifyCannotPerform('refus serveur')
				end
				
				ClearPedTasks(playerPed)
				break
			end
			
			if IsControlJustPressed(0, 73) then
				DeleteEntity(previewObject)
				previewObject = nil
				placingItem = false
				break
			end
		end
		
		SetModelAsNoLongerNeeded(modelHash)
	end)
end)

RegisterNetEvent('ox_inventory:itemPlaced', function(placedItemId, itemName, propModel, coords, heading)
	local modelHash
	if type(propModel) == 'number' then
		modelHash = propModel
	elseif tonumber(propModel) then
		modelHash = tonumber(propModel)
	else
		modelHash = joaat(propModel)
	end
	lib.requestModel(modelHash, 5000)
	
	if HasModelLoaded(modelHash) then
		local groundCoords = ResolveGroundCoords(coords)
		local object = CreateObject(modelHash, groundCoords.x, groundCoords.y, groundCoords.z, false, false, false)
		local isWeapon = IsWeaponItem(itemName)
		ApplyPlacementOrientation(object, heading, isWeapon)
		FreezeEntityPosition(object, true)
		SetEntityAsMissionEntity(object, true, true)
		
		placedItems[placedItemId] = {
			object = object,
			itemName = itemName,
			coords = coords,
			heading = heading
		}
		
		
		SetModelAsNoLongerNeeded(modelHash)
	end
end)

RegisterNetEvent('ox_inventory:itemPickedUp', function(placedItemId)
	local placedItem = placedItems[placedItemId]
	if placedItem and DoesEntityExist(placedItem.object) then
		DeleteEntity(placedItem.object)
		placedItems[placedItemId] = nil
	end

	if activePickupItemId == placedItemId then
		HidePickupTextUI()
	end
end)

CreateThread(function()
	local placedItemsConfig = Config and Config.PlacedItems or {
		Enabled = true,
		MaxDistance = 2.0
	}
	
	if not placedItemsConfig.Enabled then
		return
	end
	
	local maxDistance = placedItemsConfig.MaxDistance or 2.0
	
	while true do
		local waitTime = 500
		local playerPed = cache.ped
		local playerCoords = GetEntityCoords(playerPed)
		local hasPlacedItems = next(placedItems) ~= nil
		
		if hasPlacedItems then
			local promptVisible = false
			for placedItemId, placedItem in pairs(placedItems) do
				if placedItem and DoesEntityExist(placedItem.object) then
					local objectCoords = GetEntityCoords(placedItem.object)
					local distance = #(playerCoords - objectCoords)
					
					if distance < maxDistance then
						waitTime = 0
						promptVisible = true
						if not pickupTextVisible or activePickupItemId ~= placedItemId then
							ShowPickupTextUI(placedItemId)
						end

						if IsControlJustPressed(0, 38) then
							HidePickupTextUI()
							lib.requestAnimDict('pickup_object')
							while not HasAnimDictLoaded('pickup_object') do
								Wait(10)
							end
							TaskPlayAnim(playerPed, 'pickup_object', 'pickup_low', 8.0, -8.0, 1000, 0, 0, false, false, false)
							Wait(1000)
							
							TriggerServerEvent('ox_inventory:pickupPlacedItem', placedItemId)
							
							ClearPedTasks(playerPed)
						end
						break
					end
				end
			end

			if not promptVisible then
				HidePickupTextUI()
			end
		else
			HidePickupTextUI()
			waitTime = 1000
		end
		
		Wait(waitTime)
	end
end)

AddEventHandler('onResourceStop', function(resourceName)
	if resourceName == GetCurrentResourceName() then
		for _, placedItem in pairs(placedItems) do
			if DoesEntityExist(placedItem.object) then
				DeleteEntity(placedItem.object)
			end
		end
		if previewObject and DoesEntityExist(previewObject) then
			DeleteEntity(previewObject)
		end
		HidePickupTextUI()
	end
end)

local function applyClothingSlotsFromStorage(reason, attempt)
	attempt = attempt or 1
	local clothingSlots = lib.callback.await('ox_inventory:getClothingSlots', false)
	if not clothingSlots then
		return
	end

	local applied = 0
	for _, slotData in pairs(clothingSlots) do
		if slotData and slotData.name and slotData.slot then
			applyClothing(slotData.slot, slotData, true)
			applied = applied + 1
			Wait(0)
		end
	end

	if applied == 0 and attempt < 5 then
		SetTimeout(1000, function()
			applyClothingSlotsFromStorage(reason, attempt + 1)
		end)
	end
end


CreateThread(function()
    while not PlayerData.loaded do
        Wait(100)
    end
    
    -- Wait for clothing system to be ready
    waitForClothingSystemReady()
    
	applyClothingSlotsFromStorage('startup', 1)

	local system = getClothingSystem()
end)

AddEventHandler('onResourceStart', function(resourceName)
	if resourceName ~= GetCurrentResourceName() then return end
	if not PlayerData or not PlayerData.loaded then return end
	CreateThread(function()
		Wait(500)
		applyClothingSlotsFromStorage('restart', 1)
	end)
end)

CreateThread(function()
    local slotKeys = Config and Config.Hotkeys and Config.Hotkeys.SlotKeys or {
        {control = 157, slot = 1},
        {control = 158, slot = 2},
        {control = 160, slot = 3},
        {control = 164, slot = 4},
        {control = 165, slot = 5}
    }
    
    local seatKeys = Config and Config.VehicleSeatSwitch and Config.VehicleSeatSwitch.Keys or {
        {control = 157, seat = -1},
        {control = 158, seat = 0},
        {control = 160, seat = 1},
        {control = 164, seat = 2},
        {control = 165, seat = 3},
        {control = 159, seat = 4}
    }
    
    while true do
        local needsFrameCheck = false
        
        if cache.vehicle then
            if not Config or not Config.VehicleSeatSwitch or Config.VehicleSeatSwitch.Enabled then
                needsFrameCheck = true
                local vehicle = cache.vehicle
                local ped = cache.ped
                local maxSeats = GetVehicleMaxNumberOfPassengers(vehicle)
                
                for i = 1, #seatKeys do
                    if IsControlJustPressed(0, seatKeys[i].control) then
                        local targetSeat = seatKeys[i].seat
                        if targetSeat == -1 or targetSeat <= maxSeats then
                            if GetPedInVehicleSeat(vehicle, targetSeat) == 0 or GetPedInVehicleSeat(vehicle, targetSeat) == ped then
                                SetPedIntoVehicle(ped, vehicle, targetSeat)
                            end
                        end
                        break
                    end
                end
            end
        elseif not invOpen and not usingItem and not invBusy and PlayerData.loaded then
            if not Config or not Config.Hotkeys or Config.Hotkeys.Enabled then
                needsFrameCheck = true
                for i = 1, #slotKeys do
                    DisableControlAction(0, slotKeys[i].control, true)
                    if IsDisabledControlJustPressed(0, slotKeys[i].control) then
                        local item = PlayerData.inventory[slotKeys[i].slot]
                        if item then
                            useSlot(slotKeys[i].slot)
                        end
                        break
                    end
                end
            end
        end
        
        Wait(needsFrameCheck and 0 or 500)
    end
end)

CreateThread(function()
    local previousArmor = 0
    
    while true do
        Wait(Config and Config.KevlarBreaking and Config.KevlarBreaking.CheckInterval or 1000) -- Increased default from 500 to 1000
        
        if PlayerData.loaded then
            local ped = cache.ped
            local currentArmor = GetPedArmour(ped)
            
            if previousArmor > 0 and currentArmor == 0 then
                local clothingSlots = lib.callback.await('ox_inventory:getClothingSlots', false)
                
                if clothingSlots and clothingSlots[4] and clothingSlots[4].name then
                    local kevlarItem = clothingSlots[4].name
                    local kevlarConfig = Config and Config.Kevlar or kevlarDrawables
                    
                    if kevlarConfig[kevlarItem] then
                        TriggerServerEvent('ox_inventory:removeKevlar', 4, kevlarItem)
                        
                        lib.notify({
                            type = 'error',
                            title = locale('notification_error'),
                            description = locale('ui_kevlar_broken') or 'Votre kevlar est cassé'
                        })
                        
                        SetPedComponentVariation(ped, 9, 0, 0, 0)
                        SetPedArmour(ped, 0)
                    end
                end
            end
            
            previousArmor = currentArmor
        end
    end
end)

CreateThread(function()
    Wait(1000)
    
    local success = pcall(function()
        require 'modules.craftmanager.client'
    end)
    
end)

-- Gestion du panel d'accessoires d'arme (comme inventairefb)
-- Callback NUI pour ouvrir le panel depuis l'interface web
RegisterNUICallback('openWeaponPanel', function(data, cb)
    if cb then cb('ok') end
    
    local slot = data.slot
    if not slot then return end
    
    -- Cacher le previewped quand on ouvre le panel d'accessoires
    PedScreenDelete()
    
    -- React dispatche directement après fetchNui, pas besoin de SendNUIMessage ici
end)

-- Quand le panel se ferme, on recrée le previewped
RegisterNUICallback('setInventoryLocale', function(data, cb)
	if currentLocale == forcedLocale then
		cb({ success = true, locale = currentLocale })
		return
	end

	local ok = pcall(lib.locale, forcedLocale)

	if not ok then
		cb({ success = false, error = 'locale_load_failed' })
		return
	end

	currentLocale = forcedLocale
	pcall(SetResourceKvp, localeStorageKey, forcedLocale)
	sendLocaleUpdate()
	cb({ success = true, locale = forcedLocale })
end)

RegisterNUICallback('closeWeaponPanel', function(_, cb)
    if cb then cb('ok') end
    
    -- Recréer le ped quand on ferme le panel d'accessoires
    if invOpen and not LocalPlayer.state.dead then
        local playerPed = cache.ped
        
        -- Recréer le previewped seulement si l'inventaire est toujours ouvert
        -- et qu'on n'est pas en mode crafting ou shop
        if currentInventory and currentInventory.type ~= 'crafting' and currentInventory.type ~= 'shop' then
            local success, err = pcall(function()
                PedScreenCreate(playerPed, {
                    dict = "anim@amb@nightclub@peds@", 
                    anim = "rcmme_amanda1_stand_loop_cop"
                })
            end)
            
        end
    end
end)

-- Event pour ouvrir le panel d'accessoires depuis le serveur ou client
RegisterNetEvent('ox_inventory:openWeaponPanel', function(slot)
    -- Cacher le previewped quand on ouvre le panel d'accessoires
    PedScreenDelete()
    
    -- Envoyer l'événement au NUI pour ouvrir le panel
    SendNUIMessage({
        action = 'openWeaponPanel',
        data = { slot = slot }
    })
end)

-- Export pour ouvrir le panel d'accessoires
exports('openWeaponPanel', function(slot)
    TriggerEvent('ox_inventory:openWeaponPanel', slot)
end)

-- Event pour appliquer automatiquement un vêtement lors d'un drag/drop
RegisterNetEvent('ox_inventory:clothingUpdated', function(slotNum)
	local inventory = PlayerData and PlayerData.inventory
	if not inventory then return end
	
	local clothingItem = nil
	for _, item in pairs(inventory) do
		if item and item.metadata and item.metadata.equippedInClothingSlot == slotNum then
			clothingItem = item
			break
		end
	end
	
	if clothingItem then
		applyClothing(slotNum, clothingItem, true)
	end
end)

local lastBodyDamage = {}
local lastHealth = 200

local medicBodyParts = {
	head = { health = 100, pathologies = {} },
	thorax = { health = 100, pathologies = {} },
	stomach = { health = 100, pathologies = {} },
	['left-arm'] = { health = 100, pathologies = {} },
	['right-arm'] = { health = 100, pathologies = {} },
	['left-leg'] = { health = 100, pathologies = {} },
	['right-leg'] = { health = 100, pathologies = {} }
}

local boneToMedicPart = {
	[31086] = 'head',
	[12844] = 'head',
	[65068] = 'head',
	[57597] = 'thorax',
	[24816] = 'thorax',
	[24818] = 'thorax',
	[11816] = 'stomach',
	[18905] = 'left-arm',
	[61163] = 'left-arm',
	[26610] = 'left-arm',
	[57005] = 'right-arm',
	[28252] = 'right-arm',
	[58866] = 'right-arm',
	[58271] = 'left-leg',
	[63931] = 'left-leg',
	[2108] = 'left-leg',
	[14201] = 'left-leg',
	[51826] = 'right-leg',
	[36864] = 'right-leg',
	[20781] = 'right-leg',
	[52301] = 'right-leg'
}

local function clampHealth(value)
	if value < 0 then return 0 end
	if value > 100 then return 100 end
	return value
end

local function resetMedicBodyParts()
	for part, data in pairs(medicBodyParts) do
		data.health = 100
		data.pathologies = {}
		medicBodyParts[part] = data
	end
end

local function applyMedicDamage(part, delta)
	if not part or not medicBodyParts[part] then return end
	local current = tonumber(medicBodyParts[part].health) or 100
	medicBodyParts[part].health = clampHealth(current - delta)
end

local function healMedicBodyParts(delta)
	if delta <= 0 then return end
	for part, data in pairs(medicBodyParts) do
		local current = tonumber(data.health) or 100
		data.health = clampHealth(current + delta)
		medicBodyParts[part] = data
	end
end

CreateThread(function()
	while true do
		Wait(1000) -- Increased from 500ms to 1000ms
		
		local ped = cache.ped
		if ped and DoesEntityExist(ped) then
			local maxHealth = GetEntityMaxHealth(ped)
			local currentHealth = GetEntityHealth(ped)
			
			if currentHealth ~= lastHealth then
				if currentHealth <= 0 then
					resetMedicBodyParts()
					TriggerServerEvent('ox_inventory:medic:updateBodyParts', medicBodyParts)
				end

				local healthPercent = (currentHealth / maxHealth) * 100
				local lastHealthPercent = (lastHealth / maxHealth) * 100
				local deltaPercent = lastHealthPercent - healthPercent

				if deltaPercent > 0 then
					local hasBone, bone = GetPedLastDamageBone(ped)
					local part = hasBone and boneToMedicPart[bone] or 'thorax'
					applyMedicDamage(part, deltaPercent)
					TriggerServerEvent('ox_inventory:medic:updateBodyParts', medicBodyParts)
				elseif deltaPercent < 0 then
					healMedicBodyParts(math.abs(deltaPercent))
					TriggerServerEvent('ox_inventory:medic:updateBodyParts', medicBodyParts)
				end
				
				if invOpen then
					local bodyDamage = {
						head = 0,
						torso = currentHealth < lastHealth and math.max(0, 100 - healthPercent) or 0,
						leftArm = 0,
						rightArm = 0,
						leftLeg = 0,
						rightLeg = 0
					}
					
					lastBodyDamage = bodyDamage
					SendNUIMessage({
						action = 'updateBodyDamage',
						data = bodyDamage
					})
				end
				
				lastHealth = currentHealth
			end
		end
	end
end)

-- Event pour retirer automatiquement un vêtement lors d'un drag/drop
RegisterNetEvent('ox_inventory:clothingRemoved', function(slotNum)
	-- Retirer le vêtement (passer nil comme itemMetadata)
	applyClothing(slotNum, nil, true)
end)

-- Callback pour vérifier la compatibilité d'une arme avec chaque type de slot d'accessoire
RegisterNUICallback('checkWeaponSlotCompatibility', function(data, cb)
	local weaponName = data.weaponName
	local slotTypes = data.slotTypes
	
	if not weaponName or not slotTypes then
		return cb({})
	end
	
	local weaponHash = joaat(weaponName)
	local compatibility = {}
	
	-- Map des types de slots vers les types d'items
	local slotTypeToItemType = {
		clip = 'magazine',
		scope = 'sight',
		grip = 'grip',
		supp = 'muzzle',
		flsh = 'flashlight',
		varmod = 'skin',
		barrel = 'barrel'
	}
	
	-- Pour chaque type de slot demandé
	for _, slotType in ipairs(slotTypes) do
		local itemType = slotTypeToItemType[slotType]
		local isCompatible = false
		
		if itemType then
			-- Parcourir tous les composants pour trouver ceux de ce type
			for componentName, componentData in pairs(Items) do
				if componentData.component and componentData.type == itemType then
					-- Vérifier si ce composant a des hash de composants GTA définis
					if componentData.client and componentData.client.component then
						-- Vérifier chaque hash de composant
						for _, componentHash in ipairs(componentData.client.component) do
							if DoesWeaponTakeWeaponComponent(weaponHash, componentHash) then
								isCompatible = true
								break
							end
						end
					end
				end
				if isCompatible then break end
			end
		end
		
		compatibility[slotType] = isCompatible
	end
	
	cb(compatibility)
end)
