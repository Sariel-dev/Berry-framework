if not lib then return end

-- Fonction pour afficher une notification avec l'état de durabilité
local function showDurabilityWarning(itemLabel, durability)
    if durability <= 0 then
        lib.notify({
            title = 'Item cassé',
            description = ('Votre %s est cassé et doit être réparé!'):format(itemLabel),
            type = 'error',
            duration = 5000
        })
    elseif durability <= 20 then
        lib.notify({
            title = 'Durabilité faible',
            description = ('Votre %s est presque cassé! (%d%%)'):format(itemLabel, durability),
            type = 'warning',
            duration = 5000
        })
    end
end

-- Fonction pour afficher un avertissement de péremption
local function showExpirationWarning(itemLabel, freshnessPercent)
    if freshnessPercent <= 0 then
        lib.notify({
            title = 'Item périmé',
            description = ('Votre %s est périmé! Consommer cet item est dangereux.'):format(itemLabel),
            type = 'error',
            duration = 5000
        })
    elseif freshnessPercent <= 20 then
        lib.notify({
            title = 'Bientôt périmé',
            description = ('Votre %s va bientôt périmer! (%d%% de fraîcheur)'):format(itemLabel, freshnessPercent),
            type = 'warning',
            duration = 5000
        })
    end
end

-- Export des fonctions
exports('showDurabilityWarning', showDurabilityWarning)
exports('showExpirationWarning', showExpirationWarning)

return {
    showDurabilityWarning = showDurabilityWarning,
    showExpirationWarning = showExpirationWarning,
}
