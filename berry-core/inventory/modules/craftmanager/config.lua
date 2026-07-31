CraftManager = CraftManager or {}

CraftManager.Config = {
    Enabled = true,
    
    Command = 'craftmanager',
    
    CheckPermissions = false,
    
    AllowedGroups = {
        'admin',
        'superadmin',
        'owner'
    },
    
    DefaultDuration = 5000,
    
    MaxIngredients = 10,
    
    SavePath = 'data/crafting.lua'
}

return CraftManager.Config

