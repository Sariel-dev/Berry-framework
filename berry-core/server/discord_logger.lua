Berry.Discord = Berry.Discord or {}

local colors = {
    red = 16711680,      -- AntiCheat / Ban (#FF0000)
    purple = 11030519,   -- SetGroup / Staff (#A855F7)
    orange = 16753920,   -- Admin Action (#FFA500)
    green = 65280,       -- Economy / Transaction (#00FF00)
    blue = 39423,        -- Inventory (#0099FF)
    cyan = 65535,        -- Properties (#00FFFF)
    grey = 8421504       -- Connections (#808080)
}

function Berry.Discord.SendLog(category, title, description, colorKey, fields)
    if not BerryConfig.DiscordWebhooks or not BerryConfig.DiscordWebhooks.Enabled then return end

    local webhookUrl = BerryConfig.DiscordWebhooks.Webhooks[category]
    if not webhookUrl or webhookUrl == "" then return end

    local embedColor = colors[colorKey] or colors.purple

    local embed = {
        {
            title = title or "Log Berry Framework",
            description = description or "",
            color = embedColor,
            footer = {
                text = (BerryConfig.DiscordWebhooks.ServerName or "Berry RP") .. " • " .. os.date("%d/%m/%Y à %H:%M:%S")
            },
            fields = fields or {}
        }
    }

    local payload = json.encode({
        username = "Berry Logs - " .. (category:upper()),
        avatar_url = BerryConfig.DiscordWebhooks.AvatarUrl,
        embeds = embed
    })

    PerformHttpRequest(webhookUrl, function(err, text, headers) end, 'POST', payload, { ['Content-Type'] = 'application/json' })
end

-- Helper to extract player identifiers nicely for Discord Logs
function Berry.Discord.GetPlayerInfo(src)
    if not src or src <= 0 then return "Console / Système" end
    local name = GetPlayerName(src) or "Inconnu"
    local license = GetPlayerIdentifierByType and GetPlayerIdentifierByType(src, "license") or "N/A"
    local discord = GetPlayerIdentifierByType and GetPlayerIdentifierByType(src, "discord") or "N/A"
    return string.format("**Joueur:** %s (ID: %d)\n**Licence:** `%s`\n**Discord:** `%s`", name, src, license, discord)
end

-- Hook Events Automatically
AddEventHandler("playerConnecting", function(name, setKickReason, deferrals)
    local src = source
    Berry.Discord.SendLog("Connections", "📥 Connexion Joueur", Berry.Discord.GetPlayerInfo(src), "grey")
end)

AddEventHandler("playerDropped", function(reason)
    local src = source
    local info = Berry.Discord.GetPlayerInfo(src) .. "\n**Raison:** " .. tostring(reason or "Déconnexion normale")
    Berry.Discord.SendLog("Connections", "📤 Déconnexion Joueur", info, "grey")
end)

exports("SendDiscordLog", Berry.Discord.SendLog)
