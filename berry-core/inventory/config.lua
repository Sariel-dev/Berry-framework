Config = {}

Config.Framework = 'esx'

-- Enable/Disable item rarity system
Config.RarityEnabled = true

Config.Rarity = {
    common = {
        color = '#FFFFFF',
        hex = 'FFFFFF',
        label = 'Common'
    },
    uncommon = {
        color = '#1EFF00',
        hex = '1EFF00',
        label = 'Uncommon'
    },
    rare = {
        color = '#0070DD',
        hex = '0070DD',
        label = 'Rare'
    },
    epic = {
        color = '#A335EE',
        hex = 'A335EE',
        label = 'Epic'
    },
    legendary = {
        color = '#FF8000',
        hex = 'FF8000',
        label = 'Legendary'
    },
    mythic = {
        color = 'FFFF0000',
        hex = 'FF00FF',
        label = 'Mythic'
    }
}

Config.Inventory = {
    Slots = 50,
    Weight = 30000,
    DropSlots = 50,
    DropWeight = 30000,
}

Config.Target = {
    Enabled = false,
}

Config.PackAmmo = {
    UseRProgress = true,
    Duration = 5000,
    Label = 'Remballer les munitions...',
}

Config.Police = {
    Jobs = {'police', 'sheriff'},
}

--[[
    Clothing System Configuration
    Determines which appearance/clothing system to use for saving player appearance
    
    Options:
    - 'auto'                  : Automatically detect available system (recommended)
    - 'illenium-appearance'   : Use illenium-appearance
    - 'rcore_clothing'        : Use rcore_clothing v2
    - '17mov_CharacterSystem' : Use 17mov Character System (uses illenium bridge)
    - 'none'                  : Disable appearance saving
]]
Config.ClothingSystem = 'auto'

Config.Accounts = {
    'money'
}

Config.Server = {
    BulkStashSave = true,
    LogLevel = 1,
    RandomPrices = false,
    RandomLoot = true,
    EvidenceGrade = 2,
    TrimPlate = true,
    
    VehicleLoot = {
        {name = 'sprunk', min = 1, max = 1, chance = 100},
        {name = 'water', min = 1, max = 1, chance = 100},
        {name = 'garbage', min = 1, max = 2, chance = 50},
        {name = 'panties', min = 1, max = 1, chance = 5},
        {name = 'money', min = 1, max = 50, chance = 100},
        {name = 'money', min = 200, max = 400, chance = 5},
        {name = 'bandage', min = 1, max = 1, chance = 100}
    },
    
    DumpsterLoot = {
        {name = 'mustard', min = 1, max = 1, chance = 100},
        {name = 'garbage', min = 1, max = 3, chance = 100},
        {name = 'money', min = 1, max = 10, chance = 100},
        {name = 'burger', min = 1, max = 1, chance = 100}
    },
    
    NetworkDumpsters = false,
}

Config.Client = {
    AutoReload = false,
    ScreenBlur = true,
    
    Keys = {
        Primary = 'F2',
        Secondary = 'K',
        Tertiary = 'TAB'
    },
    
    EnableKeys = {249},
    
    AimedFiring = false,
    
    GivePlayerList = false,
    
    WeaponAnims = false,
    
    ItemNotify = false,

    WeaponNotify = false,

    UiNotifications = false,
    
    ImagePath = 'nui://ox_inventory/web/images',
    
    DropProps = false,
    
    DropModel = 'prop_med_bag_01b',
    
    WeaponMismatch = true,
    
    IgnoreWeapons = {
        'WEAPON_NEWSPAPER'
    },
    
    SuppressPickups = true,
    
    DisableWeapons = false,
    
    Markers = {
        Shop = {
            Type = 29,
            Colour = {30, 150, 30},
            Scale = {0.5, 0.5, 0.5}
        },
        
        Evidence = {
            Type = 2,
            Colour = {30, 30, 150},
            Scale = {0.3, 0.2, 0.15}
        },
        
        Crafting = {
            Type = 2,
            Colour = {150, 150, 30},
            Scale = {0.3, 0.2, 0.15}
        },
        
        Drop = {
            Type = 2,
            Colour = {150, 30, 30},
            Scale = {0.3, 0.2, 0.15}
        }
    }
}

Config.Clothing = {
    EnablePreview = true,
    
    SlotMapping = {
        [1] = {type = 'prop', id = 0, emptyDrawable = -1, emptyTexture = -1},
        [2] = {type = 'component', id = 8, emptyDrawable = 15, emptyTexture = 0},
        [3] = {type = 'component', id = 11, emptyDrawable = 15, emptyTexture = 0},
        [4] = {type = 'component', id = 9, emptyDrawable = 0, emptyTexture = 0},
        [5] = {type = 'component', id = 4, emptyDrawable = 14, emptyTexture = 0},
        [6] = {type = 'component', id = 6, emptyDrawable = 34, emptyTexture = 0},
        [7] = {type = 'prop', id = 1, emptyDrawable = -1, emptyTexture = -1},
        [8] = {type = 'prop', id = 2, emptyDrawable = -1, emptyTexture = -1},
        [9] = {type = 'component', id = 7, emptyDrawable = 0, emptyTexture = 0},
        [10] = {type = 'component', id = 3, emptyDrawable = 15, emptyTexture = 0},
        [11] = {type = 'prop', id = 6, emptyDrawable = -1, emptyTexture = -1},
        [12] = {type = 'component', id = 5, emptyDrawable = 0, emptyTexture = 0},
        [13] = {type = 'component', id = 1, emptyDrawable = 0, emptyTexture = 0},
        [14] = {type = 'prop', id = 7, emptyDrawable = -1, emptyTexture = -1},
        [15] = {type = 'outfit', id = 0, emptyDrawable = -1, emptyTexture = -1}
    },
    
    ItemNameMapping = {
        hat = 1,
        tshirt = 2,
        torso = 3,
        jacket = 3,
        bulletproof = 4,
        bodyarmor = 4,
        pants = 5,
        shoes = 6,
        glasse = 7,
        glasses = 7,
        earings = 8,
        earrings = 8,
        chain = 9,
        hands = 10,
        gloves = 10,
        watch = 11,
        bags = 12,
        bag = 12,
        mask = 13,
        bracelet = 14
    }
}

Config.Kevlar = {
    keville1 = {drawable = 1, armour = 25},
    keville3 = {drawable = 3, armour = 25},
    keville4 = {drawable = 4, armour = 25},
    kevlarle = {drawable = 1, armour = 25},
    
    keville9 = {drawable = 5, armour = 50},
    keville10 = {drawable = 6, armour = 50},
    keville11 = {drawable = 7, armour = 50},
    keville12 = {drawable = 8, armour = 50},
    kevlarm = {drawable = 5, armour = 50},
    
    keville5 = {drawable = 10, armour = 100},
    keville6 = {drawable = 11, armour = 100},
    keville7 = {drawable = 12, armour = 100},
    keville8 = {drawable = 13, armour = 100},
    kevlarlo = {drawable = 10, armour = 100},
    
    boikev = {drawable = 1, armour = 100},
    dojkev = {drawable = 1, armour = 100},
    g6kev = {drawable = 1, armour = 100},
    g6kev2 = {drawable = 1, armour = 100},
    gouvernorkev = {drawable = 1, armour = 100},
    gouvkev = {drawable = 1, armour = 100},
    irscikev = {drawable = 1, armour = 100},
    irskev = {drawable = 1, armour = 100},
    
    lsfdkev = {drawable = 1, armour = 100},
    lsfdkev1 = {drawable = 1, armour = 100},
    lsfdkev2 = {drawable = 1, armour = 100},
    lsfdkev3 = {drawable = 1, armour = 100},
    lsfdkev4 = {drawable = 1, armour = 100},
    lsfdkev5 = {drawable = 1, armour = 100},
    
    lspdgiletj = {drawable = 1, armour = 100},
    lspdgnd = {drawable = 1, armour = 100},
    lspdkevco = {drawable = 1, armour = 100},
    lspdkevcs = {drawable = 1, armour = 100},
    lspdkevdb = {drawable = 1, armour = 100},
    lspdkevfieldsup = {drawable = 1, armour = 100},
    lspdkeviad = {drawable = 1, armour = 100},
    lspdkevle1 = {drawable = 1, armour = 100},
    lspdkevle2 = {drawable = 1, armour = 100},
    lspdkevle3 = {drawable = 1, armour = 100},
    lspdkevlo1 = {drawable = 1, armour = 100},
    lspdkevlo2 = {drawable = 1, armour = 100},
    lspdkevlo3 = {drawable = 1, armour = 100},
    lspdkevlo4 = {drawable = 1, armour = 100},
    lspdkevlourd = {drawable = 1, armour = 100},
    lspdkevm1 = {drawable = 1, armour = 100},
    lspdkevnegotiator = {drawable = 1, armour = 100},
    lspdkevpc = {drawable = 1, armour = 100},
    lspdkevpc2 = {drawable = 1, armour = 100},
    lspdkevsupervisor = {drawable = 1, armour = 100},
    lspdkevswat = {drawable = 1, armour = 100},
    
    lssdgiletj = {drawable = 1, armour = 100},
    lssdkevle1 = {drawable = 1, armour = 100},
    lssdkevle2 = {drawable = 1, armour = 100},
    lssdkevlo1 = {drawable = 1, armour = 100},
    lssdkevlo2 = {drawable = 1, armour = 100},
    lssdkevlo3 = {drawable = 1, armour = 100},
    lssdkevlo4 = {drawable = 1, armour = 100},
    lssdkevlo5 = {drawable = 1, armour = 100},
    lssdkevlo6 = {drawable = 1, armour = 100},
    lssdkevlo7 = {drawable = 1, armour = 100},
    
    samskev = {drawable = 1, armour = 100},
    samskev2 = {drawable = 1, armour = 100},
    samskev3 = {drawable = 1, armour = 100},
    samskev4 = {drawable = 1, armour = 100},
    samskev5 = {drawable = 1, armour = 100},
    
    usbpgiletb = {drawable = 1, armour = 100},
    usbpgiletj = {drawable = 1, armour = 100},
    usbpkevlo1 = {drawable = 1, armour = 100},
    usbpkevlo2 = {drawable = 1, armour = 100},
    usbpkevlo3 = {drawable = 1, armour = 100},
    usbpkevlo4 = {drawable = 1, armour = 100},
    usbpkevlo5 = {drawable = 1, armour = 100},
    usbpkevpc = {drawable = 1, armour = 100},
    
    ussskev1 = {drawable = 1, armour = 100},
    ussskev2 = {drawable = 1, armour = 100},
    ussskev3 = {drawable = 1, armour = 100},
    ussskev4 = {drawable = 1, armour = 100},
    
    gpb_f_1 = {drawable = 1, armour = 100, applyArmour = false},
    gpb_f_2 = {drawable = 1, armour = 100, applyArmour = false},
    gpb_h_1 = {drawable = 1, armour = 100, applyArmour = false},
    gpb_h_2 = {drawable = 1, armour = 100, applyArmour = false},
    gpb_h_3 = {drawable = 1, armour = 100, applyArmour = false},
}

local function slotNum(n)
    return n + 69 -- clothing slots start at 70
end

Config.ItemSlotMapping = {}
for itemName, slotId in pairs(Config.Clothing.ItemNameMapping) do
    Config.ItemSlotMapping[itemName] = slotNum(slotId)
end

for kevlarName, _ in pairs(Config.Kevlar) do
    Config.ItemSlotMapping[kevlarName] = slotNum(4)
end

-- Add backpack mapping to slot 12 (bags)
if Config.BackpackWeights then
    for backpackName, _ in pairs(Config.BackpackWeights) do
        Config.ItemSlotMapping[backpackName] = slotNum(12)
    end
end

Config.Hotkeys = {
    Enabled = true,
    
    SlotKeys = {
        {control = 157, slot = 1},
        {control = 158, slot = 2},
        {control = 160, slot = 3},
        {control = 164, slot = 4},
        {control = 165, slot = 5}
    }
}

Config.VehicleSeatSwitch = {
    Enabled = true,
    
    Keys = {
        {control = 157, seat = -1},
        {control = 158, seat = 0},
        {control = 160, seat = 1},
        {control = 164, seat = 2},
        {control = 165, seat = 3},
        {control = 159, seat = 4}
    }
}

Config.PlayerStatus = {
    Enabled = true,
    
    UpdateInterval = 30000,
    
    HungerDecrease = {min = 1, max = 2},
    ThirstDecrease = {min = 1, max = 3},
    SleepDecrease = 1,
}

Config.PlacedItems = {
    Enabled = true,
    
    MaxDistance = 2.0,
    
    DefaultProp = 'prop_money_bag_01',

    PickupTextUI = {
        Position = 'left-center',
        Icon = 'hand',
        Key = 'E'
    },

    WeaponRotation = {
        Enabled = true,
        Pitch = 90.0,
        Roll = 0.0,
        YawOffset = 0.0,
        UseHeading = false,
        ZOffset = 0.0
    },

    AllowAnyPlayerPickup = true
}

Config.KevlarBreaking = {
    Enabled = true,
    
    CheckInterval = 500,
    
    RemoveOnBreak = true
}

Config.Locker = {
    MaxLockers = 1000,
    MaxCasiersPerLocker = 100,
    CasierSlots = 50,
    CasierMaxWeight = 50000,
    MarkerDistance = 16.0,
    InteractionDistance = 1.5,
    MinLockerNameLength = 1,
    MaxLockerNameLength = 255,
    MinCasierNameLength = 1,
    MaxCasierNameLength = 255,
    PinCodeLength = 4,
    CheckPermissions = true,
    AllowedGroups = {'admin', 'superadmin'},
    
    AccessGroups = nil,
    
    CreateGroups = nil,
}

Config.BackpackWeights = {
    backpack_black = {male = 81, female = 81, texture = 0, component = 5, weight = 5000},
    backpack_green = {male = 1, female = 1, texture = 0, component = 5, weight = 5000},
    backpack_blue = {male = 2, female = 2, texture = 0, component = 5, weight = 7000},
    backpack_tactical = {male = 3, female = 3, texture = 0, component = 5, weight = 10000},
}

Config.Durability = {
    enabled = false,
    expiredDamage = 20,
    
    durableItems = {
        ['pickaxe'] = { maxDurability = 100, degradeRate = 0.05 },
        ['axe'] = { maxDurability = 100, degradeRate = 0.05 },
        ['fishing_rod'] = { maxDurability = 100, degradeRate = 0.03 },
        ['hammer'] = { maxDurability = 100, degradeRate = 0.02 },
        ['wrench'] = { maxDurability = 100, degradeRate = 0.02 },
        ['bulletproof'] = { maxDurability = 100, degradeRate = 0.1 },
        ['kevlar'] = { maxDurability = 100, degradeRate = 0.1 },
        ['backpack'] = { maxDurability = 100, degradeRate = 0.01 },
    },
    
    perishables = {
        ['beef'] = 48,
        ['pork'] = 48,
        ['chicken'] = 36,
        ['fish'] = 24,
        ['milk'] = 72,
        ['cheese'] = 168,
        ['apple'] = 120,
        ['banana'] = 72,
        ['orange'] = 120,
        ['tomato'] = 96,
        ['lettuce'] = 48,
        ['burger'] = 12,
        ['sandwich'] = 24,
        ['bread'] = 120,
        ['pizza'] = 24,
        ['water_bottle'] = 720,
        ['milk_bottle'] = 168,
    },
}

--[[
    Configuration des styles par défaut pour l'inventaire et le HUD
    Ces paramètres seront appliqués à tous les joueurs si ForceDefaults = true
    Sinon ils servent de valeurs par défaut initiales
]]
Config.DefaultStyle = {
    ForceDefaults = true,
    
    Hud = {
        Enabled = false,
        
        -- Style des barres HUD
        -- Valeurs possibles: 'circle', 'square', 'hexagon', 'hexagon-w', 'zarg', 'wave-c', 'wave-h', 'classic', 'universal', 'grt-premium', 'zarg-m'
        BarStyle = 'circle',
        
        -- Style RES actif (style alternatif)
        ResStyleActive = true,
        
        -- Style du HUD véhicule (1 à 10)
        VehicleHudStyle = 1,
        
        -- Taille des barres (0 = normale)
        BarSize = 0,
        
        -- Style d'icône HUD (1 à 4)
        IconStyle = 1,
        
        -- Opacité du HUD (0.0 à 1.0)
        Opacity = 1.0,
        
        -- Orientation des barres: 'horizontal' ou 'vertical'
        Orientation = 'horizontal',
    },
    
    MiniMap = {
        -- Style de la minimap: 'circle' ou 'rectangle'
        Style = 'rectangle',
        
        -- Afficher la minimap uniquement en véhicule
        OnlyInVehicle = false,
    },
    
    Compass = {
        -- Afficher la boussole
        Show = true,
        
        -- Afficher uniquement en véhicule
        OnlyInVehicle = false,
    },
    
    -- Éléments d'info client à afficher/masquer
    ClientInfo = {
        NavigationWidget = true,
        PlayerId = true,
        Job = true,
        Cash = true,
        Bank = true,
        ExtraCurrency = true,
        Radio = true,
        Time = true,
        Weapon = true,
        ServerInfo = true,
    },
    
    -- Mode cinématique (barres noires)
    Cinematic = {
        Enabled = false,
    },
    
    -- Paramètres de l'inventaire
    Inventory = {
        -- Style de l'inventaire: 'normal', 'compact', 'modern'
        Style = 'normal',
        
        -- Style des images: 'default', 'rounded', 'square'
        ImageStyle = 'default',
        
        -- Style de la barre de poids: 'bar', 'circle', 'text'
        WeightBarStyle = 'bar',
        
        -- Style des notifications: 'default', 'minimal', 'modern'
        NotificationStyle = 'default',
        
        -- Taille des slots: 'small', 'medium', 'large'
        SlotSize = 'medium',
        
        -- Taille des images d'items: 'small', 'medium', 'large'
        ItemImageSize = 'medium',
        
        -- Afficher les numéros de hotslot
        ShowHotslotNumbers = true,
        
        -- Style des numéros de hotslot: 'corner', 'center', 'badge'
        HotslotNumberStyle = 'corner',
        
        -- Couleur des numéros de hotslot (hex)
        HotslotNumberColor = '#ffffff',
        
        -- Afficher le dégradé de rareté
        ShowRarityGradient = true,
        
        -- Afficher la barre de durabilité
        ShowDurabilityBar = true,
        
        -- Afficher les labels des items
        ShowItemLabels = true,
        
        -- Afficher le nombre d'items
        ShowItemCount = true,
        
        -- Afficher le poids des items
        ShowItemWeight = true,
        
        -- Activer les animations
        EnableAnimations = true,
        
        -- Mode compact
        CompactMode = false,
        
        -- Délai du tooltip en ms
        TooltipDelay = 300,
        
        -- Durée des notifications en secondes
        NotificationDuration = 5,
        
        -- Afficher l'image du corps
        ShowBodyImage = false,
        
        -- Couleur d'accent flashback (hex)
        FlashbackAccentColor = '#001ec5',
    },
}
