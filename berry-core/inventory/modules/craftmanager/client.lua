if not lib then return end

local CMConfig = require 'modules.craftmanager.config'
local Items = require 'modules.items.client'

if not CMConfig or not CMConfig.Enabled then
    return
end

local currentBench = nil
local currentRecipe = nil
local ingredientsList = {}

local openMainMenu
local openBenchList
local openBenchMenu
local openRecipeList
local openRecipeMenu
local openRecipeDetails
local openCreateRecipe
local openAddIngredients
local openSelectIngredient
local openEditRecipe
local openEditIngredients
local openSelectIngredientEdit
local openDeleteRecipe
local openCreateBench
local openCreateBenchAtPosition
local openDeleteBench
local openTeleportBench
local teleportToBenchLocation
local CraftingBenches

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

local function getBenchTeleportCoords(bench)
    if not bench then return nil end

    if bench.zones then
        for i = 1, #bench.zones do
            local zone = bench.zones[i]
            if zone then
                local coords = toVector3(zone.coords or zone.loc)
                if coords then
                    return coords, zone.rotation
                end
            end
        end
    end

    if bench.points then
        for i = 1, #bench.points do
            local coords = toVector3(bench.points[i])
            if coords then
                return coords, nil
            end
        end
    end

    return nil
end


openMainMenu = function()
    local hasPermission = lib.callback.await('craftmanager:hasPermission', false)
    
    if not hasPermission then
        return lib.notify({
            type = 'error',
            title = locale('cm_access_denied'),
            description = locale('cm_no_permission')
        })
    end
    
    lib.registerContext({
        id = 'craftmanager_main',
        title = locale('cm_manager_title'),
        options = {
            {
                title = locale('cm_manage_benches'),
                description = locale('cm_manage_benches_desc'),
                icon = 'hammer',
                onSelect = function()
                    openBenchList()
                end
            },
            {
                title = locale('cm_create_bench'),
                description = locale('cm_create_bench_desc'),
                icon = 'plus',
                onSelect = function()
                    openCreateBench()
                end
            },
            {
                title = locale('cm_create_bench_at_pos'),
                description = locale('cm_create_bench_at_pos_desc'),
                icon = 'location-dot',
                onSelect = function()
                    openCreateBenchAtPosition()
                end
            },
            {
                title = locale('cm_reload_crafts'),
                description = locale('cm_reload_crafts_desc'),
                icon = 'rotate',
                onSelect = function()
                    local success, message = lib.callback.await('craftmanager:reloadCrafts', false)
                    lib.notify({
                        type = success and 'success' or 'error',
                        title = success and locale('cm_success') or locale('cm_error'),
                        description = message
                    })
                    if success then
                        openMainMenu()
                    end
                end
            },
            {
                title = locale('cm_close'),
                description = locale('cm_close_desc'),
                icon = 'xmark',
                onSelect = function()
                    lib.hideContext()
                end
            }
        }
    })
    
    lib.showContext('craftmanager_main')
end

openBenchList = function()
    local benches = lib.callback.await('craftmanager:getCraftingBenches', false)
    
    if not benches or #benches == 0 then
        return lib.notify({
            type = 'info',
            title = locale('cm_no_bench'),
            description = locale('cm_no_bench_desc')
        })
    end
    
    local options = {}
    
    for i = 1, #benches do
        local bench = benches[i]
        table.insert(options, {
            title = bench.label,
            description = bench.description,
            icon = 'hammer',
            onSelect = function()
                currentBench = bench.value
                openBenchMenu(bench.value, bench.label)
            end
        })
    end
    
    table.insert(options, {
        title = locale('cm_back'),
        description = locale('cm_back_main'),
        icon = 'arrow-left',
        onSelect = function()
            openMainMenu()
        end
    })
    
    lib.registerContext({
        id = 'craftmanager_bench_list',
        title = locale('cm_bench_list'),
        options = options
    })
    
    lib.showContext('craftmanager_bench_list')
end

openBenchMenu = function(benchId, benchLabel)
    lib.registerContext({
        id = 'craftmanager_bench_menu',
        title = benchLabel,
        options = {
            {
                title = locale('cm_open_craft_ui'),
                description = locale('cm_open_craft_ui_desc'),
                icon = 'wrench',
                onSelect = function()
                    -- Fermer le menu
                    lib.hideContext()
                    -- Ouvrir l'inventaire de craft
                    exports.ox_inventory:openInventory('crafting', { id = benchId, index = 1 })
                end
            },
            {
                title = locale('cm_view_recipes'),
                description = locale('cm_view_recipes_desc'),
                icon = 'list',
                onSelect = function()
                    openRecipeList(benchId, benchLabel)
                end
            },
            {
                title = locale('cm_create_recipe'),
                description = locale('cm_create_recipe_desc'),
                icon = 'plus',
                onSelect = function()
                    openCreateRecipe(benchId, benchLabel)
                end
            },
            {
                title = locale('cm_go_to_bench'),
                description = locale('cm_go_to_bench_desc'),
                icon = 'location-dot',
                onSelect = function()
                    teleportToBenchLocation(benchId, benchLabel)
                end
            },
            {
                title = locale('cm_teleport_bench'),
                description = locale('cm_teleport_bench_desc'),
                icon = 'location-dot',
                onSelect = function()
                    openTeleportBench(benchId, benchLabel)
                end
            },
            {
                title = locale('cm_delete_bench'),
                description = locale('cm_delete_bench_desc'),
                icon = 'trash',
                onSelect = function()
                    openDeleteBench(benchId, benchLabel)
                end
            },
            {
                title = locale('cm_back'),
                description = locale('cm_back_bench_list'),
                icon = 'arrow-left',
                onSelect = function()
                    openBenchList()
                end
            }
        }
    })
    
    lib.showContext('craftmanager_bench_menu')
end

openRecipeList = function(benchId, benchLabel)
    local recipes = lib.callback.await('craftmanager:getBenchRecipes', false, benchId)
    
    if not recipes or #recipes == 0 then
        return lib.notify({
            type = 'info',
            title = locale('cm_no_recipe'),
            description = locale('cm_no_recipe_desc')
        })
    end
    
    local options = {}
    
    for i = 1, #recipes do
        local recipe = recipes[i]
        table.insert(options, {
            title = recipe.label,
            description = recipe.description,
            icon = 'scroll',
            onSelect = function()
                currentRecipe = recipe.value
                openRecipeMenu(benchId, benchLabel, recipe.value, recipe.label)
            end
        })
    end
    
    table.insert(options, {
        title = locale('cm_back'),
        description = locale('cm_back_bench_menu'),
        icon = 'arrow-left',
        onSelect = function()
            openBenchMenu(benchId, benchLabel)
        end
    })
    
    lib.registerContext({
        id = 'craftmanager_recipe_list',
        title = benchLabel .. ' - ' .. locale('cm_recipes'),
        options = options
    })
    
    lib.showContext('craftmanager_recipe_list')
end

openRecipeMenu = function(benchId, benchLabel, recipeIndex, recipeLabel)
    lib.registerContext({
        id = 'craftmanager_recipe_menu',
        title = recipeLabel,
        options = {
            {
                title = locale('cm_view_details'),
                description = locale('cm_view_details_desc'),
                icon = 'eye',
                onSelect = function()
                    openRecipeDetails(benchId, benchLabel, recipeIndex, recipeLabel)
                end
            },
            {
                title = locale('cm_edit'),
                description = locale('cm_edit_desc'),
                icon = 'pen',
                onSelect = function()
                    openEditRecipe(benchId, benchLabel, recipeIndex)
                end
            },
            {
                title = locale('cm_delete'),
                description = locale('cm_delete_desc'),
                icon = 'trash',
                onSelect = function()
                    openDeleteRecipe(benchId, benchLabel, recipeIndex, recipeLabel)
                end
            },
            {
                title = locale('cm_back'),
                description = locale('cm_back_recipe_list'),
                icon = 'arrow-left',
                onSelect = function()
                    openRecipeList(benchId, benchLabel)
                end
            }
        }
    })
    
    lib.showContext('craftmanager_recipe_menu')
end

openRecipeDetails = function(benchId, benchLabel, recipeIndex, recipeLabel)
    local recipe = lib.callback.await('craftmanager:getRecipeDetails', false, benchId, recipeIndex)
    
    if not recipe then
        return lib.notify({
            type = 'error',
            title = locale('cm_error'),
            description = locale('cm_cannot_load_recipe')
        })
    end
    
    local options = {
        {
            title = locale('cm_produced_item'),
            description = ('%s x%s'):format(recipe.name, recipe.count or 1),
            icon = 'box',
            disabled = true
        },
        {
            title = locale('cm_craft_duration'),
            description = ('%sms'):format(recipe.duration or CMConfig.DefaultDuration),
            icon = 'clock',
            disabled = true
        }
    }
    
    if recipe.ingredients and #recipe.ingredients > 0 then
        table.insert(options, {
            title = locale('ui_ingredients'),
            description = locale('cm_ingredients_list'),
            icon = 'list',
            disabled = true
        })
        
        for i = 1, #recipe.ingredients do
            local ing = recipe.ingredients[i]
            table.insert(options, {
                title = ('  • %s'):format(ing[1] or ing.name or locale('cm_unknown')),
                description = (locale('cm_quantity') .. ': %s'):format(ing[2] or ing.count or 1),
                icon = 'circle',
                disabled = true
            })
        end
    end
    
    table.insert(options, {
        title = locale('cm_back'),
        description = locale('cm_back_recipe_menu'),
        icon = 'arrow-left',
        onSelect = function()
            openRecipeMenu(benchId, benchLabel, recipeIndex, recipeLabel)
        end
    })
    
    lib.registerContext({
        id = 'craftmanager_recipe_details',
        title = recipeLabel .. ' - ' .. locale('cm_recipe_details'),
        options = options
    })
    
    lib.showContext('craftmanager_recipe_details')
end

openCreateRecipe = function(benchId, benchLabel)
    ingredientsList = {}
    
    local items = lib.callback.await('craftmanager:getAllItems', false)
    
    if not items or #items == 0 then
        return lib.notify({
            type = 'error',
            title = locale('cm_error'),
            description = locale('cm_cannot_load_items')
        })
    end
    
    local input = lib.inputDialog(locale('cm_create_recipe_title'), {
        {
            type = 'select',
            label = locale('cm_item_to_produce'),
            description = locale('cm_item_to_produce_desc'),
            options = items,
            required = true,
            searchable = true
        },
        {
            type = 'number',
            label = locale('cm_produced_quantity'),
            description = locale('cm_produced_quantity_desc'),
            default = 1,
            min = 1,
            max = 100,
            required = true
        },
        {
            type = 'number',
            label = locale('cm_duration_ms'),
            description = locale('cm_duration_ms_desc'),
            default = CMConfig.DefaultDuration,
            min = 1000,
            max = 60000,
            required = true
        }
    })
    
    if not input then
        return openBenchMenu(benchId, benchLabel)
    end
    
    openAddIngredients(benchId, benchLabel, {
        name = input[1],
        count = input[2],
        duration = input[3]
    })
end

openAddIngredients = function(benchId, benchLabel, recipeData)
    local options = {}
    
    if #ingredientsList > 0 then
        table.insert(options, {
            title = locale('cm_ingredients_added'),
            description = ('%s ' .. locale('ui_ingredients')):format(#ingredientsList),
            icon = 'list',
            disabled = true
        })
        
        for i = 1, #ingredientsList do
            local ing = ingredientsList[i]
            table.insert(options, {
                title = ('  • %s x%s'):format(ing[1], ing[2]),
                description = locale('cm_ingredient_remove'),
                icon = 'circle',
                onSelect = function()
                    table.remove(ingredientsList, i)
                    openAddIngredients(benchId, benchLabel, recipeData)
                end
            })
        end
    end
    
    table.insert(options, {
        title = locale('cm_add_ingredient'),
        description = locale('cm_add_ingredient_desc'),
        icon = 'plus',
        onSelect = function()
            openSelectIngredient(benchId, benchLabel, recipeData)
        end
    })
    
    if #ingredientsList > 0 then
        table.insert(options, {
            title = locale('cm_validate_recipe'),
            description = locale('cm_validate_recipe_desc'),
            icon = 'check',
            onSelect = function()
                recipeData.ingredients = ingredientsList
                local success, message = lib.callback.await('craftmanager:createRecipe', false, benchId, recipeData)
                
                lib.notify({
                    type = success and 'success' or 'error',
                    title = success and locale('cm_success') or locale('cm_error'),
                    description = message
                })
                
                if success then
                    ingredientsList = {}
                    openBenchMenu(benchId, benchLabel)
                end
            end
        })
    end
    
    table.insert(options, {
        title = locale('cm_cancel'),
        description = locale('cm_cancel_desc'),
        icon = 'xmark',
        onSelect = function()
            ingredientsList = {}
            openBenchMenu(benchId, benchLabel)
        end
    })
    
    lib.registerContext({
        id = 'craftmanager_add_ingredients',
        title = locale('cm_add_ingredients_title'),
        options = options
    })
    
    lib.showContext('craftmanager_add_ingredients')
end

openSelectIngredient = function(benchId, benchLabel, recipeData)
    local items = lib.callback.await('craftmanager:getAllItems', false)
    
    if not items or #items == 0 then
        return lib.notify({
            type = 'error',
            title = locale('cm_error'),
            description = locale('cm_cannot_load_items')
        })
    end
    
    local input = lib.inputDialog(locale('cm_add_ingredient_title'), {
        {
            type = 'select',
            label = locale('cm_item') or locale('cm_item_to_produce'),
            description = locale('cm_item_desc'),
            options = items,
            required = true,
            searchable = true
        },
        {
            type = 'number',
            label = locale('cm_quantity'),
            description = locale('cm_quantity_desc'),
            default = 1,
            min = 1,
            max = 100,
            required = true
        }
    })
    
    if not input then
        return openAddIngredients(benchId, benchLabel, recipeData)
    end
    
    table.insert(ingredientsList, {input[1], input[2]})
    openAddIngredients(benchId, benchLabel, recipeData)
end

openEditRecipe = function(benchId, benchLabel, recipeIndex)
    local recipe = lib.callback.await('craftmanager:getRecipeDetails', false, benchId, recipeIndex)
    
    if not recipe then
        return lib.notify({
            type = 'error',
            title = locale('cm_error'),
            description = locale('cm_cannot_load_recipe')
        })
    end
    
    ingredientsList = recipe.ingredients or {}
    
    local items = lib.callback.await('craftmanager:getAllItems', false)
    
    if not items or #items == 0 then
        return lib.notify({
            type = 'error',
            title = locale('cm_error'),
            description = locale('cm_cannot_load_items')
        })
    end
    
    local selectedIndex = 1
    for i = 1, #items do
        if items[i].value == recipe.name then
            selectedIndex = i
            break
        end
    end
    
    local input = lib.inputDialog(locale('cm_edit_recipe_title'), {
        {
            type = 'select',
            label = locale('cm_item_to_produce'),
            description = locale('cm_item_to_produce_desc'),
            options = items,
            default = selectedIndex,
            required = true,
            searchable = true
        },
        {
            type = 'number',
            label = locale('cm_produced_quantity'),
            description = locale('cm_produced_quantity_desc'),
            default = recipe.count or 1,
            min = 1,
            max = 100,
            required = true
        },
        {
            type = 'number',
            label = locale('cm_duration_ms'),
            description = locale('cm_duration_ms_desc'),
            default = recipe.duration or CMConfig.DefaultDuration,
            min = 1000,
            max = 60000,
            required = true
        }
    })
    
    if not input then
        ingredientsList = {}
        return openRecipeList(benchId, benchLabel)
    end
    
    openEditIngredients(benchId, benchLabel, recipeIndex, {
        name = input[1],
        count = input[2],
        duration = input[3]
    })
end

openEditIngredients = function(benchId, benchLabel, recipeIndex, recipeData)
    local options = {}
    
    if #ingredientsList > 0 then
        table.insert(options, {
            title = locale('ui_ingredients'),
            description = ('%s ' .. locale('ui_ingredients')):format(#ingredientsList),
            icon = 'list',
            disabled = true
        })
        
        for i = 1, #ingredientsList do
            local ing = ingredientsList[i]
            local itemName = ing[1] or ing.name or locale('cm_unknown')
            local itemCount = ing[2] or ing.count or 1
            table.insert(options, {
                title = ('  • %s x%s'):format(itemName, itemCount),
                description = locale('cm_ingredient_remove'),
                icon = 'circle',
                onSelect = function()
                    table.remove(ingredientsList, i)
                    openEditIngredients(benchId, benchLabel, recipeIndex, recipeData)
                end
            })
        end
    end
    
    table.insert(options, {
        title = locale('cm_add_ingredient'),
        description = locale('cm_add_ingredient_desc'),
        icon = 'plus',
        onSelect = function()
            openSelectIngredientEdit(benchId, benchLabel, recipeIndex, recipeData)
        end
    })
    
    table.insert(options, {
        title = locale('cm_validate_changes'),
        description = locale('cm_validate_changes_desc'),
        icon = 'check',
        onSelect = function()
            recipeData.ingredients = ingredientsList
            local success, message = lib.callback.await('craftmanager:updateRecipe', false, benchId, recipeIndex, recipeData)
            
            lib.notify({
                type = success and 'success' or 'error',
                title = success and locale('cm_success') or locale('cm_error'),
                description = message
            })
            
            if success then
                ingredientsList = {}
                openRecipeList(benchId, benchLabel)
            end
        end
    })
    
    table.insert(options, {
        title = locale('cm_cancel'),
        description = locale('cm_cancel_changes'),
        icon = 'xmark',
        onSelect = function()
            ingredientsList = {}
            openRecipeList(benchId, benchLabel)
        end
    })
    
    lib.registerContext({
        id = 'craftmanager_edit_ingredients',
        title = locale('cm_edit_ingredients'),
        options = options
    })
    
    lib.showContext('craftmanager_edit_ingredients')
end

openSelectIngredientEdit = function(benchId, benchLabel, recipeIndex, recipeData)
    local items = lib.callback.await('craftmanager:getAllItems', false)
    
    if not items or #items == 0 then
        return lib.notify({
            type = 'error',
            title = locale('cm_error'),
            description = locale('cm_cannot_load_items')
        })
    end
    
    local input = lib.inputDialog(locale('cm_add_ingredient_title'), {
        {
            type = 'select',
            label = locale('cm_item') or locale('cm_item_to_produce'),
            description = locale('cm_item_desc'),
            options = items,
            required = true,
            searchable = true
        },
        {
            type = 'number',
            label = locale('cm_quantity'),
            description = locale('cm_quantity_desc'),
            default = 1,
            min = 1,
            max = 100,
            required = true
        }
    })
    
    if not input then
        return openEditIngredients(benchId, benchLabel, recipeIndex, recipeData)
    end
    
    table.insert(ingredientsList, {input[1], input[2]})
    openEditIngredients(benchId, benchLabel, recipeIndex, recipeData)
end

openDeleteRecipe = function(benchId, benchLabel, recipeIndex, recipeLabel)
    local alert = lib.alertDialog({
        header = locale('cm_delete_recipe_title'),
        content = locale('cm_delete_recipe_confirm', recipeLabel),
        centered = true,
        cancel = true,
        labels = {
            confirm = locale('cm_delete_confirm'),
            cancel = locale('cm_cancel')
        }
    })
    
    if alert == 'confirm' then
        local success, message = lib.callback.await('craftmanager:deleteRecipe', false, benchId, recipeIndex)
        
        lib.notify({
            type = success and 'success' or 'error',
            title = success and locale('cm_success') or locale('cm_error'),
            description = message
        })
        
        if success then
            openRecipeList(benchId, benchLabel)
        end
    else
        openRecipeMenu(benchId, benchLabel, recipeIndex, recipeLabel)
    end
end

openCreateBench = function()
    local input = lib.inputDialog(locale('cm_create_bench_title'), {
        {
            type = 'input',
            label = locale('cm_bench_id'),
            description = locale('cm_bench_id_desc'),
            required = true,
            min = 3,
            max = 50
        },
        {
            type = 'input',
            label = locale('cm_bench_name'),
            description = locale('cm_bench_name_desc'),
            required = true,
            min = 3,
            max = 100
        },
        {
            type = 'number',
            label = locale('cm_bench_slots'),
            description = locale('cm_bench_slots_desc'),
            default = 50,
            min = 10,
            max = 100,
            required = true
        }
    })
    
    if not input then
        return openMainMenu()
    end
    
    local success, message = lib.callback.await('craftmanager:createBench', false, {
        id = input[1],
        label = input[2],
        slots = input[3]
    })
    
    lib.notify({
        type = success and 'success' or 'error',
        title = success and locale('cm_success') or locale('cm_error'),
        description = message
    })
    
    if success then
        openBenchList()
    else
        openMainMenu()
    end
end

openCreateBenchAtPosition = function()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local heading = GetEntityHeading(playerPed)
    
    local input = lib.inputDialog(locale('cm_create_bench_at_pos_title'), {
        {
            type = 'input',
            label = locale('cm_bench_id'),
            description = locale('cm_bench_id_desc'),
            required = true,
            min = 3,
            max = 50
        },
        {
            type = 'input',
            label = locale('cm_bench_name'),
            description = locale('cm_bench_name_desc'),
            required = true,
            min = 3,
            max = 100
        },
        {
            type = 'number',
            label = locale('cm_bench_slots'),
            description = locale('cm_bench_slots_desc'),
            default = 50,
            min = 10,
            max = 100,
            required = true
        },
        {
            type = 'number',
            label = locale('cm_interaction_distance'),
            description = locale('cm_interaction_distance_desc'),
            default = 2.0,
            min = 1.0,
            max = 10.0,
            required = true
        }
    })
    
    if not input then
        return openMainMenu()
    end
    
    local success, message = lib.callback.await('craftmanager:createBenchAtPosition', false, {
        id = input[1],
        label = input[2],
        slots = input[3],
        coords = {x = coords.x, y = coords.y, z = coords.z},
        heading = heading,
        distance = input[4]
    })
    
    lib.notify({
        type = success and 'success' or 'error',
        title = success and locale('cm_success') or locale('cm_error'),
        description = message
    })
    
    if success then
        openBenchList()
    else
        openMainMenu()
    end
end

teleportToBenchLocation = function(benchId, benchLabel)
    local bench = CraftingBenches[benchId]
    if not bench then
        lib.notify({
            type = 'error',
            title = locale('cm_error'),
            description = locale('cm_bench_not_found')
        })
        return
    end

    local coords, heading = getBenchTeleportCoords(bench)
    if not coords then
        lib.notify({
            type = 'error',
            title = locale('cm_error'),
            description = locale('cm_go_to_bench_no_position')
        })
        return
    end

    local ped = cache.ped or PlayerPedId()
    if not ped or ped == 0 then
        lib.notify({
            type = 'error',
            title = locale('cm_error'),
            description = locale('cm_go_to_bench_failed')
        })
        return
    end

    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    if heading then
        SetEntityHeading(ped, heading)
    end

    lib.notify({
        type = 'success',
        title = locale('cm_success'),
        description = locale('cm_go_to_bench_success', benchLabel or benchId)
    })
end

openTeleportBench = function(benchId, benchLabel)
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local heading = GetEntityHeading(playerPed)
    
    local alert = lib.alertDialog({
        header = locale('cm_teleport_bench_title'),
        content = locale('cm_teleport_bench_confirm', benchLabel),
        centered = true,
        cancel = true,
        labels = {
            confirm = locale('cm_teleport_confirm'),
            cancel = locale('cm_cancel')
        }
    })
    
    if alert == 'confirm' then
        local success, message = lib.callback.await('craftmanager:teleportBench', false, benchId, {
            x = coords.x,
            y = coords.y,
            z = coords.z,
            heading = heading
        })
        
        lib.notify({
            type = success and 'success' or 'error',
            title = success and 'Succès' or 'Erreur',
            description = message
        })
        
        if success then
            openBenchMenu(benchId, benchLabel)
        end
    else
        openBenchMenu(benchId, benchLabel)
    end
end

openDeleteBench = function(benchId, benchLabel)
    local alert = lib.alertDialog({
        header = locale('cm_delete_bench_title'),
        content = locale('cm_delete_bench_confirm', benchLabel or benchId),
        centered = true,
        cancel = true,
        labels = {
            confirm = locale('cm_delete_confirm'),
            cancel = locale('cm_cancel')
        }
    })

    if alert ~= 'confirm' then
        return openBenchMenu(benchId, benchLabel)
    end

    local success, message = lib.callback.await('craftmanager:deleteBench', false, benchId)

    lib.notify({
        type = success and 'success' or 'error',
        title = success and locale('cm_success') or locale('cm_error'),
        description = message
    })

    if success then
        currentBench = nil
        openBenchList()
    else
        openBenchMenu(benchId, benchLabel)
    end
end

RegisterNetEvent('craftmanager:openMenu', function()
    openMainMenu()
end)

CraftingBenches = require 'modules.crafting.client'

RegisterNetEvent('craftmanager:reloadBench', function(benchId, benchData)
    if not benchId or not benchData then return end
    
    local success = pcall(function()
        if benchData.items then
            benchData.slots = #benchData.items
            
            for i = 1, benchData.slots do
                local recipe = benchData.items[i]
                local item = Items[recipe.name]
                
                if item then
                    recipe.weight = item.weight
                    recipe.slot = i
                end
            end
        end
        
        CraftingBenches[benchId] = benchData
    end)
    
    if not success then
        return lib.notify({
            type = 'error',
            title = locale('cm_error'),
            description = locale('cm_reload_error')
        })
    end

    lib.notify({
        type = 'success',
        title = locale('cm_bench_updated'),
        description = locale('cm_bench_available', benchData.label or benchId)
    })
end)

RegisterNetEvent('craftmanager:benchDeleted', function(benchId, sourceId)
    if not benchId then return end
    
    local benchLabel = benchId
    if CraftingBenches and CraftingBenches[benchId] and CraftingBenches[benchId].label then
        benchLabel = CraftingBenches[benchId].label
    end
    
    local success = pcall(function()
        if CraftingBenches then
            CraftingBenches[benchId] = nil
        end
    end)
    
    if not success then
        return lib.notify({
            type = 'error',
            title = locale('cm_error'),
            description = locale('cm_reload_error')
        })
    end
    
    local isInitiator = sourceId and cache and cache.serverId and sourceId == cache.serverId
    
    if currentBench == benchId then
        currentBench = nil
        lib.hideContext()
        return lib.notify({
            type = 'info',
            title = locale('cm_manager_title'),
            description = locale('cm_bench_deleted', benchLabel)
        })
    end
    
    if not isInitiator then
        lib.notify({
            type = 'info',
            title = locale('cm_manager_title'),
            description = locale('cm_bench_deleted', benchLabel)
        })
    end
end)

RegisterNetEvent('ox_inventory:reloadCrafts', function()
    lib.notify({
        type = 'info',
        title = locale('cm_crafts_reloaded'),
        description = locale('cm_crafts_reloaded_desc')
    })
end)

if CMConfig and CMConfig.Command then
    RegisterCommand(CMConfig.Command, function()
        openMainMenu()
    end, false)
end

