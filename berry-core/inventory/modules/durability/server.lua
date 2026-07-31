if not lib then return end

local Inventory
local Items

CreateThread(function()
    Inventory = require 'modules.inventory.server'
    Items = require 'modules.items.server'
end)

---@class DurabilityConfig
---@field enabled boolean
---@field degradeRate number Pourcentage de dégradation par utilisation (0-1)
---@field perishables table Items périssables avec durée de vie en heures

local config = {
    enabled = Config.Durability?.enabled or true,
    
    -- Items avec durabilité (outils, vêtements, etc.)
    durableItems = Config.Durability?.durableItems or {
        -- Outils
        ['pickaxe'] = { maxDurability = 100, degradeRate = 0.05 },
        ['axe'] = { maxDurability = 100, degradeRate = 0.05 },
        ['fishing_rod'] = { maxDurability = 100, degradeRate = 0.03 },
        ['hammer'] = { maxDurability = 100, degradeRate = 0.02 },
        ['wrench'] = { maxDurability = 100, degradeRate = 0.02 },
        
        -- Vêtements
        ['bulletproof'] = { maxDurability = 100, degradeRate = 0.1 },
        ['kevlar'] = { maxDurability = 100, degradeRate = 0.1 },
        
        -- Sacs
        ['backpack'] = { maxDurability = 100, degradeRate = 0.01 },
    },
    
    -- Items périssables (nourriture) avec durée de vie en heures
    perishables = Config.Durability?.perishables or {
        -- Viandes
        ['beef'] = 48,
        ['pork'] = 48,
        ['chicken'] = 36,
        ['fish'] = 24,
        
        -- Produits laitiers
        ['milk'] = 72,
        ['cheese'] = 168, -- 7 jours
        
        -- Fruits et légumes
        ['apple'] = 120,
        ['banana'] = 72,
        ['orange'] = 120,
        ['tomato'] = 96,
        ['lettuce'] = 48,
        
        -- Préparations
        ['burger'] = 12,
        ['sandwich'] = 24,
        ['bread'] = 120,
        ['pizza'] = 24,
        
        -- Boissons
        ['water_bottle'] = 720, -- 30 jours
        ['milk_bottle'] = 168, -- 7 jours
    },
    
    -- Dégâts causés par la consommation d'items périmés
    expiredDamage = Config.Durability?.expiredDamage or 20,
}

---Initialise la durabilité d'un item lors de sa création
---@param itemName string
---@param metadata table?
---@return table metadata
local function initializeDurability(itemName, metadata)
    metadata = metadata or {}
    
    -- Vérifier si c'est un item durable
    if config.durableItems[itemName] then
        if not metadata.durability then
            metadata.durability = config.durableItems[itemName].maxDurability
        end
    end
    
    -- Vérifier si c'est un item périssable
    if config.perishables[itemName] then
        if not metadata.expirationDate then
            local expirationTime = os.time() + (config.perishables[itemName] * 3600)
            metadata.expirationDate = expirationTime
            metadata.createdDate = os.time()
        end
    end
    
    return metadata
end

---Vérifie si un item est périmé
---@param metadata table
---@return boolean
local function isExpired(metadata)
    if not metadata or not metadata.expirationDate then
        return false
    end
    
    return os.time() >= metadata.expirationDate
end

---Calcule le pourcentage de fraîcheur d'un item
---@param metadata table
---@return number percentage 0-100
local function getFreshnessPercentage(metadata)
    if not metadata or not metadata.expirationDate or not metadata.createdDate then
        return 100
    end
    
    local currentTime = os.time()
    local totalDuration = metadata.expirationDate - metadata.createdDate
    local timeRemaining = metadata.expirationDate - currentTime
    
    if timeRemaining <= 0 then
        return 0
    end
    
    return math.floor((timeRemaining / totalDuration) * 100)
end

---Dégrade la durabilité d'un item
---@param inventory table
---@param slot number
---@param amount number?
---@return boolean success
local function degradeDurability(inventory, slot, amount)
    if not config.enabled then return true end
    
    local item = inventory.items[slot]
    if not item or not item.metadata then return true end
    
    local itemConfig = config.durableItems[item.name]
    if not itemConfig then return true end
    
    local degradeAmount = amount or itemConfig.degradeRate
    item.metadata.durability = (item.metadata.durability or 100) - degradeAmount
    
    if item.metadata.durability <= 0 then
        -- L'item est cassé
        item.metadata.durability = 0
        item.metadata.broken = true
        
        -- Notifier le joueur
        local player = Inventory.GetInventory(inventory.id)
        if player then
            TriggerClientEvent('ox_inventory:notify', inventory.id, {
                type = 'error',
                message = ('Votre %s est cassé!'):format(Items(item.name).label)
            })
        end
        
        return false
    end
    
    return true
end

---Répare un item
---@param inventory table
---@param slot number
---@param repairAmount number?
---@return boolean success
local function repairItem(inventory, slot, repairAmount)
    local item = inventory.items[slot]
    if not item or not item.metadata then return false end
    
    local itemConfig = config.durableItems[item.name]
    if not itemConfig then return false end
    
    local repair = repairAmount or 100
    item.metadata.durability = math.min((item.metadata.durability or 0) + repair, itemConfig.maxDurability)
    item.metadata.broken = nil
    
    return true
end

---Vérifie si un item peut être utilisé (durabilité et péremption)
---@param item table
---@return boolean canUse
---@return string? reason
local function canUseItem(item)
    if not config.enabled then return true end
    
    -- Vérifier la durabilité
    if item.metadata and item.metadata.broken then
        return false, 'Cet item est cassé et doit être réparé'
    end
    
    -- Vérifier la péremption
    if item.metadata and isExpired(item.metadata) then
        -- Les items périmés peuvent être utilisés mais avec des conséquences
        return true, 'expired'
    end
    
    return true
end

-- Exports
exports('initializeDurability', initializeDurability)
exports('degradeDurability', degradeDurability)
exports('repairItem', repairItem)
exports('canUseItem', canUseItem)
exports('isExpired', isExpired)
exports('getFreshnessPercentage', getFreshnessPercentage)

-- Hook sur l'ajout d'items
AddEventHandler('ox_inventory:itemAdded', function(inventoryId, slot, item, metadata)
    local inventory = Inventory.Get(inventoryId)
    if not inventory then return end
    
    -- Initialiser la durabilité si nécessaire
    if item.metadata then
        item.metadata = initializeDurability(item.name, item.metadata)
    end
end)

-- Commande pour réparer un item (exemple)
lib.addCommand('repairitem', {
    help = 'Réparer un item dans votre inventaire',
    params = {
        {
            name = 'slot',
            type = 'number',
            help = 'Numéro du slot de l\'item'
        }
    },
    restricted = false
}, function(source, args)
    local inventory = Inventory.Get(source)
    if not inventory then return end
    
    local success = repairItem(inventory, args.slot, 50)
    
    if success then
        TriggerClientEvent('ox_inventory:notify', source, {
            type = 'success',
            message = 'Item réparé de 50%'
        })
    else
        TriggerClientEvent('ox_inventory:notify', source, {
            type = 'error',
            message = 'Impossible de réparer cet item'
        })
    end
end)

return {
    config = config,
    initializeDurability = initializeDurability,
    degradeDurability = degradeDurability,
    repairItem = repairItem,
    canUseItem = canUseItem,
    isExpired = isExpired,
    getFreshnessPercentage = getFreshnessPercentage,
}
