local Berry = exports["berry-core"]:GetCoreObject()

CreateThread(function()
    if not BerryConfig.DiscordRichPresence or not BerryConfig.DiscordRichPresence.Enabled then return end

    local cfg = BerryConfig.DiscordRichPresence
    local appId = cfg.AppId or "1234567890123456789"

    SetDiscordAppId(appId)
    SetDiscordRichPresenceAsset(cfg.AssetLogo or "berry_logo")
    SetDiscordRichPresenceAssetText(cfg.AssetLogoText or "Berry Framework")

    if cfg.AssetSmall and cfg.AssetSmall ~= "" then
        SetDiscordRichPresenceAssetSmall(cfg.AssetSmall)
        SetDiscordRichPresenceAssetSmallText(cfg.AssetSmallText or "Roleplay")
    end

    if cfg.Buttons and #cfg.Buttons > 0 then
        for i, btn in ipairs(cfg.Buttons) do
            if i <= 2 and btn.label and btn.url then
                SetDiscordRichPresenceAction(i - 1, btn.label, btn.url)
            end
        end
    end

    while true do
        Wait(cfg.UpdateIntervalMs or 15000)

        local pData = Berry.GetPlayerData() or {}
        local charName = pData.firstname and (pData.firstname .. " " .. (pData.lastname or "")) or GetPlayerName(PlayerId())
        local jobName = pData.job and pData.job.label or "Citoyen"
        local serverId = GetPlayerServerId(PlayerId())

        local statusText = string.format("Joueur: %s [ID: %d] | %s", charName, serverId, jobName)
        SetRichPresence(statusText)
    end
end)
