if not lib then return end

local CMConfig = require 'modules.craftmanager.config'

if not CMConfig or not CMConfig.Enabled then
    return
end

local CraftingBenches = lib.load('data.crafting') or {}

local function hasPermission(source)
    if not source or type(source) ~= 'number' then
        return false
    end
    
    if not CMConfig.CheckPermissions then
        return true
    end
    
    local success, result = pcall(function()
        if shared and shared.framework == 'esx' then
            if not _G.ESX then
                return false
            end
            
            local xPlayer = ESX.GetPlayerFromId(source)
            if not xPlayer then return false end
            
            for i = 1, #CMConfig.AllowedGroups do
                local group = CMConfig.AllowedGroups[i]
                
                if xPlayer.getGroup and xPlayer.getGroup() == group then
                    return true
                end
                
                if xPlayer.get and xPlayer.get('group') == group then
                    return true
                end
                
                if xPlayer.variables and xPlayer.variables.group == group then
                    return true
                end
                
                if xPlayer.job and xPlayer.job.name == group then
                    return true
                end
            end
            
        elseif shared and (shared.framework == 'qb' or shared.framework == 'qbx') then
            if not _G.QBCore then
                return false
            end
            
            local Player = QBCore.Functions.GetPlayer(source)
            if not Player then return false end
            
            for i = 1, #CMConfig.AllowedGroups do
                local group = CMConfig.AllowedGroups[i]
                if Player.PlayerData and Player.PlayerData.job and Player.PlayerData.job.name == group then
                    return true
                end
            end
        else
            if not _G.Ox then
                return false
            end
            
            local player = Ox.GetPlayer(source)
            if not player then return false end
            
            for i = 1, #CMConfig.AllowedGroups do
                local group = CMConfig.AllowedGroups[i]
                if player.hasGroup and player.hasGroup(group) then
                    return true
                end
            end
        end
        
        return false
    end)
    
    return success and result or false
end

local function getAllItems()
    local ItemList = require 'modules.items.shared'
    local itemList = {}
    
    if not ItemList or type(ItemList) ~= 'table' then
        return {}
    end
    
    for itemName, itemData in pairs(ItemList) do
        if type(itemData) == 'table' and itemData.label then
            table.insert(itemList, {
                value = itemName,
                label = itemData.label,
                description = itemData.description or ''
            })
        end
    end
    
    table.sort(itemList, function(a, b)
        return a.label < b.label
    end)
    
    return itemList
end

local function getCraftingBenches()
    local benches = {}
    
    for benchId, benchData in pairs(CraftingBenches) do
        if type(benchData) == 'table' then
            local hasPosition = false
            if benchData.zones and benchData.zones[1] and benchData.zones[1].coords then
                hasPosition = true
            elseif benchData.points and benchData.points[1] then
                hasPosition = true
            end
            
            local label = benchData.label or benchId
            local itemsCount = benchData.items and #benchData.items or 0
            local positionText = hasPosition and locale('cm_positioned') or locale('cm_no_position')
            
            table.insert(benches, {
                value = benchId,
                label = label,
                description = locale('cm_items_count', itemsCount, positionText)
            })
        end
    end
    
    table.sort(benches, function(a, b)
        return a.label < b.label
    end)
    
    return benches
end

local function normalizeIngredients(ingredients)
    if not ingredients or type(ingredients) ~= 'table' then
        return {}
    end
    
    local normalized = {}
    
    if ingredients[1] and type(ingredients[1]) == 'table' then
        for i = 1, #ingredients do
            local ing = ingredients[i]
            if type(ing) == 'table' and ing[1] then
                normalized[ing[1]] = ing[2] or 1
            end
        end
    else
        normalized = ingredients
    end
    
    return normalized
end

local function ingredientsToArray(ingredients)
    if not ingredients or type(ingredients) ~= 'table' then
        return {}
    end
    
    local array = {}
    
    for itemName, count in pairs(ingredients) do
        if type(itemName) == 'string' and type(count) == 'number' then
            table.insert(array, {itemName, count})
        end
    end
    
    table.sort(array, function(a, b)
        return a[1] < b[1]
    end)
    
    return array
end

local function getBenchRecipes(benchId)
    local bench = CraftingBenches[benchId]
    if not bench or not bench.items then
        return {}
    end
    
    local recipes = {}
    for i = 1, #bench.items do
        local recipe = bench.items[i]
        if type(recipe) == 'table' and recipe.name then
            local ItemList = require 'modules.items.shared'
            local itemData = ItemList[recipe.name]
            local label = recipe.metadata and recipe.metadata.label or (itemData and itemData.label) or recipe.name
            
            table.insert(recipes, {
                value = i,
                label = label,
                description = (locale('ui_quantity') .. ': %s | ' .. locale('ui_time') .. ': %sms'):format(recipe.count or 1, recipe.duration or CMConfig.DefaultDuration)
            })
        end
    end
    
    return recipes
end

local function serializeValue(value, indent)
    indent = indent or ''
    local valueType = type(value)
    
    if valueType == 'vector3' then
        return ('vec3(%.8f, %.8f, %.8f)'):format(value.x, value.y, value.z)
    elseif valueType == 'string' then
        return ('\"%s\"'):format(value:gsub('"', '\\"'))
    elseif valueType == 'number' or valueType == 'boolean' then
        return tostring(value)
    elseif valueType == 'table' then
        if value.x ~= nil and value.y ~= nil and value.z ~= nil then
            return ('vec3(%.8f, %.8f, %.8f)'):format(value.x, value.y, value.z)
        end
        
        local lines = {'{'}
        local nextIndent = indent .. '    '
        
        for k, v in pairs(value) do
            -- Ne pas sauvegarder les valeurs nil
            if v ~= nil then
                local key
                if type(k) == 'string' then
                    key = ('["%s"]'):format(k)
                else
                    key = ('[%s]'):format(k)
                end
                
                table.insert(lines, ('%s%s = %s,'):format(nextIndent, key, serializeValue(v, nextIndent)))
            end
        end
        
        table.insert(lines, indent .. '}')
        return table.concat(lines, '\n')
    end
    
    return 'nil'
end

local function saveCraftingData()
    local success, err = pcall(function()
        -- Nettoyer les points vides avant sauvegarde
        for benchId, bench in pairs(CraftingBenches) do
            if bench.points and type(bench.points) == 'table' then
                local hasPoints = false
                for _ in pairs(bench.points) do
                    hasPoints = true
                    break
                end
                if not hasPoints then
                    bench.points = nil
                end
            end
        end
        
        local content = 'return ' .. serializeValue(CraftingBenches, '')
        
        local saved = SaveResourceFile(GetCurrentResourceName(), CMConfig.SavePath, content, -1)
        
        if not saved then
            return false
        end
        
        return true
    end)
    
    return success
end

lib.callback.register('craftmanager:hasPermission', function(source)
    return hasPermission(source)
end)

lib.callback.register('craftmanager:getAllItems', function(source)
    if not hasPermission(source) then
        return {}
    end
    
    return getAllItems()
end)

lib.callback.register('craftmanager:getCraftingBenches', function(source)
    if not hasPermission(source) then
        return {}
    end
    
    return getCraftingBenches()
end)

lib.callback.register('craftmanager:getBenchRecipes', function(source, benchId)
    if not hasPermission(source) then
        return {}
    end
    
    return getBenchRecipes(benchId)
end)

lib.callback.register('craftmanager:getRecipeDetails', function(source, benchId, recipeIndex)
    if not hasPermission(source) then
        return nil
    end
    
    local bench = CraftingBenches[benchId]
    if not bench or not bench.items or not bench.items[recipeIndex] then
        return nil
    end
    
    local recipe = bench.items[recipeIndex]
    local recipeDetails = {
        name = recipe.name,
        count = recipe.count,
        duration = recipe.duration,
        metadata = recipe.metadata,
        ingredients = ingredientsToArray(recipe.ingredients)
    }
    
    return recipeDetails
end)

lib.callback.register('craftmanager:createRecipe', function(source, benchId, recipeData)
    if not hasPermission(source) then
        return false, locale('cm_permission_denied')
    end
    
    if not benchId or not recipeData or type(recipeData) ~= 'table' then
        return false, locale('cm_invalid_data')
    end
    
    local bench = CraftingBenches[benchId]
    if not bench then
        return false, locale('cm_bench_not_found')
    end
    
    if not bench.items then
        bench.items = {}
    end
    
    local newRecipe = {
        name = recipeData.name,
        count = tonumber(recipeData.count) or 1,
        duration = tonumber(recipeData.duration) or CMConfig.DefaultDuration,
        ingredients = normalizeIngredients(recipeData.ingredients),
        metadata = recipeData.metadata
    }
    
    table.insert(bench.items, newRecipe)
    
    local saved = saveCraftingData()
    
    TriggerClientEvent('craftmanager:reloadBench', -1, benchId, bench)
    
    return true, locale('cm_recipe_created')
end)

lib.callback.register('craftmanager:updateRecipe', function(source, benchId, recipeIndex, recipeData)
    if not hasPermission(source) then
        return false, locale('cm_permission_denied')
    end
    
    if not benchId or not recipeIndex or not recipeData or type(recipeData) ~= 'table' then
        return false, locale('cm_invalid_data')
    end
    
    local bench = CraftingBenches[benchId]
    if not bench or not bench.items or not bench.items[recipeIndex] then
        return false, locale('cm_recipe_not_found')
    end
    
    bench.items[recipeIndex] = {
        name = recipeData.name,
        count = tonumber(recipeData.count) or 1,
        duration = tonumber(recipeData.duration) or CMConfig.DefaultDuration,
        ingredients = normalizeIngredients(recipeData.ingredients),
        metadata = recipeData.metadata
    }
    
    local saved = saveCraftingData()
    
    TriggerClientEvent('craftmanager:reloadBench', -1, benchId, bench)
    
    return true, locale('cm_recipe_updated')
end)

lib.callback.register('craftmanager:deleteRecipe', function(source, benchId, recipeIndex)
    if not hasPermission(source) then
        return false, locale('cm_permission_denied')
    end
    
    if not benchId or not recipeIndex then
        return false, locale('cm_invalid_data')
    end
    
    local bench = CraftingBenches[benchId]
    if not bench or not bench.items or not bench.items[recipeIndex] then
        return false, locale('cm_recipe_not_found')
    end
    
    table.remove(bench.items, recipeIndex)
    
    local saved = saveCraftingData()
    
    TriggerClientEvent('craftmanager:reloadBench', -1, benchId, bench)
    
    return true, locale('cm_recipe_deleted')
end)

lib.callback.register('craftmanager:createBench', function(source, benchData)
    if not hasPermission(source) then
        return false, locale('cm_permission_denied')
    end
    
    if not benchData or type(benchData) ~= 'table' or not benchData.id or not benchData.label then
        return false, locale('cm_invalid_data')
    end
    
    if CraftingBenches[benchData.id] then
        return false, locale('cm_bench_exists')
    end
    
    CraftingBenches[benchData.id] = {
        label = benchData.label,
        items = {},
        slots = tonumber(benchData.slots) or 50
    }
    
    local saved = saveCraftingData()
    
    return true, locale('cm_bench_created')
end)

lib.callback.register('craftmanager:createBenchAtPosition', function(source, benchData)
    if not hasPermission(source) then
        return false, locale('cm_permission_denied')
    end
    
    if not benchData or type(benchData) ~= 'table' or not benchData.id or not benchData.label or not benchData.coords then
        return false, locale('cm_invalid_data')
    end
    
    if type(benchData.id) ~= 'string' and type(benchData.id) ~= 'number' then
        return false, locale('cm_invalid_data')
    end
    
    if type(benchData.label) ~= 'string' or #benchData.label < 1 or #benchData.label > 100 then
        return false, locale('cm_invalid_data')
    end
    
    if type(benchData.coords) ~= 'vector3' and (type(benchData.coords) ~= 'table' or not benchData.coords.x or not benchData.coords.y or not benchData.coords.z) then
        return false, locale('cm_invalid_data')
    end
    
    local playerCoords = GetEntityCoords(GetPlayerPed(source))
    local coords = type(benchData.coords) == 'vector3' and benchData.coords or vector3(benchData.coords.x, benchData.coords.y, benchData.coords.z)
    local distance = #(playerCoords - coords)
    if distance > 5.0 then
        return false, locale('cm_invalid_data')
    end
    
    if CraftingBenches[benchData.id] then
        return false, locale('cm_bench_exists')
    end
    
    local benchDistance = tonumber(benchData.distance) or 2.0
    if benchDistance < 0.5 or benchDistance > 10.0 then
        benchDistance = 2.0
    end
    
    CraftingBenches[benchData.id] = {
        label = benchData.label,
        items = {},
        slots = tonumber(benchData.slots) or 50,
        zones = {
            [1] = {
                coords = coords,
                rotation = benchData.heading or 0.0,
                distance = benchDistance
            }
        }
        -- Ne pas ajouter points = {} vide
    }
    
    local saved = saveCraftingData()
    
    TriggerClientEvent('craftmanager:reloadBench', -1, benchData.id, CraftingBenches[benchData.id])
    
    return true, locale('cm_bench_created_at_pos')
end)

lib.callback.register('craftmanager:deleteBench', function(source, benchId)
    if not hasPermission(source) then
        return false, locale('cm_permission_denied')
    end

    if not benchId then
        return false, locale('cm_invalid_data')
    end

    local bench = CraftingBenches[benchId]
    if not bench then
        return false, locale('cm_bench_not_found')
    end

    local benchLabel = bench.label or benchId
    CraftingBenches[benchId] = nil

    local saved = saveCraftingData()
    if not saved then
        CraftingBenches[benchId] = bench
        return false, locale('cm_save_error')
    end

    TriggerClientEvent('craftmanager:benchDeleted', -1, benchId, source)
    
    return true, locale('cm_bench_deleted', benchLabel)
end)

lib.callback.register('craftmanager:teleportBench', function(source, benchId, positionData)
    if not hasPermission(source) then
        return false, locale('cm_permission_denied')
    end
    
    if not benchId or not positionData or type(positionData) ~= 'table' then
        return false, locale('cm_invalid_data')
    end
    
    if not positionData.x or not positionData.y or not positionData.z then
        return false, locale('cm_invalid_data')
    end
    
    local playerCoords = GetEntityCoords(GetPlayerPed(source))
    local newCoords = vector3(positionData.x, positionData.y, positionData.z)
    local distance = #(playerCoords - newCoords)
    if distance > 5.0 then
        return false, locale('cm_invalid_data')
    end
    
    local bench = CraftingBenches[benchId]
    if not bench then
        return false, locale('cm_bench_not_found')
    end
    
    -- Nettoyer les points vides et s'assurer que zones existe
    bench.points = nil
    if not bench.zones then
        bench.zones = {}
    end
    
    if not bench.zones[1] then
        bench.zones[1] = {}
    end
    
    bench.zones[1].coords = newCoords
    bench.zones[1].rotation = positionData.heading or 0.0
    bench.zones[1].distance = bench.zones[1].distance or 2.0
    
    local saved = saveCraftingData()
    
    if not saved then
        return false, locale('cm_save_error')
    end
    
    TriggerClientEvent('craftmanager:reloadBench', -1, benchId, bench)
    
    return true, locale('cm_bench_teleported')
end)

lib.callback.register('craftmanager:reloadCrafts', function(source)
    if not hasPermission(source) then
        return false, locale('cm_permission_denied')
    end
    
    local success = pcall(function()
        CraftingBenches = lib.load('data.crafting') or {}
    end)
    
    if success then
        TriggerClientEvent('ox_inventory:reloadCrafts', -1)
        return true, locale('cm_crafts_reloaded_success')
    else
        return false, locale('cm_reload_error_msg')
    end
end)

RegisterCommand(CMConfig.Command, function(source, args, raw)
    if not hasPermission(source) then
        return TriggerClientEvent('esx:showNotification', source, locale('cm_no_permission_command'))
    end
    
    TriggerClientEvent('craftmanager:openMenu', source)
end, false)

exports('reloadCraftingBenches', function()
    CraftingBenches = lib.load('data.crafting') or {}
    TriggerClientEvent('ox_inventory:reloadCrafts', -1)
end)

exports('createBenchAtPosition', function(benchId, coords, heading, distance)
    if not CraftingBenches[benchId] then
        return false, locale('cm_bench_not_found')
    end
    
    local bench = CraftingBenches[benchId]
    if not bench.zones then
        bench.zones = {}
    end
    
    if not bench.zones[1] then
        bench.zones[1] = {}
    end
    
    bench.zones[1].coords = vector3(coords.x, coords.y, coords.z)
    bench.zones[1].rotation = heading or 0.0
    bench.zones[1].distance = distance or 2.0
    
    local saved = saveCraftingData()
    
    if saved then
        TriggerClientEvent('craftmanager:benchTeleported', -1, benchId, {
            coords = vector3(coords.x, coords.y, coords.z),
            heading = heading or 0.0
        })
        return true, locale('cm_bench_created')
    end
    
    return false, locale('cm_save_error')
end)

