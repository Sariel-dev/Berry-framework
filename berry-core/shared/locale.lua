BerryLocales = BerryLocales or {}

BerryLocales["en"] = {
    ["core_started"] = "Core initialized successfully.",
    ["player_not_found"] = "Player not found.",
    ["invalid_amount"] = "Invalid amount provided.",
    ["insufficient_funds"] = "Insufficient funds.",
    ["permission_denied"] = "You do not have permission to execute this action.",
    ["rate_limit_exceeded"] = "Action rate limit exceeded. Please slow down.",
    ["security_violation"] = "Security validation failed."
}

BerryLocales["fr"] = {
    ["core_started"] = "Noyau initialisé avec succès.",
    ["player_not_found"] = "Joueur non trouvé.",
    ["invalid_amount"] = "Montant fourni invalide.",
    ["insufficient_funds"] = "Fonds insuffisants.",
    ["permission_denied"] = "Vous n'avez pas la permission d'exécuter cette action.",
    ["rate_limit_exceeded"] = "Limite d'actions dépassée. Veuillez ralentir.",
    ["security_violation"] = "Échec de la validation de sécurité."
}

function Berry.Locale.Translate(key, ...)
    local currentLang = BerryConfig.Framework.Locale or "fr"
    local localeTable = BerryLocales[currentLang] or BerryLocales["en"]
    local translation = localeTable[key] or BerryLocales["en"][key] or key

    if select('#', ...) > 0 then
        return string.format(translation, ...)
    end
    return translation
end

Berry.Locale.t = Berry.Locale.Translate
