BerryConfig = {}

BerryConfig.Framework = {
    Name = "Berry",
    Version = "1.0.0",
    Environment = "development", -- development, test, production
    LogLevel = "debug", -- debug, info, warn, error
    Locale = "fr"
}

BerryConfig.Player = {
    MaxCharacters = 4,
    SaveIntervalSeconds = 300, -- Auto-save every 5 minutes
    DefaultMoney = {
        cash = 500,
        bank = 5000,
        black_money = 0
    },
    DefaultSpawn = {
        x = -1037.6,
        y = -2737.8,
        z = 20.1,
        heading = 0.0
    }
}

BerryConfig.Security = {
    EnableRateLimiting = true,
    DefaultRateLimit = {
        maxRequests = 10,
        intervalMs = 1000
    },
    MaxEventDistance = 250.0,
    DropOnViolation = false,
    LogViolations = true
}

BerryConfig.DiscordWebhooks = {
    Enabled = true,
    ServerName = "Berry Roleplay",
    AvatarUrl = "https://cdn.discordapp.com/embed/avatars/0.png",
    
    -- Webhook URLs (Insérez vos liens Webhooks Discord ici)
    Webhooks = {
        AntiCheat = "",    -- Logs des bans & détections AntiCheat
        SetGroup = "",     -- Logs des changements de rangs /setgroup
        Admin = "",        -- Logs des commandes Modération/Staff
        Economy = "",      -- Logs des dons/virements bancaires
        Inventory = "",    -- Logs des échanges et jet d'objets
        Properties = "",   -- Logs d'achats de maisons
        Connections = ""   -- Logs de connexions/déconnexions
    }
}

BerryConfig.Database = {
    SlowQueryThresholdMs = 100,
    MaxConnections = 10
}
