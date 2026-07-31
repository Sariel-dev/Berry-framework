Berry.Logger = {}

local LogLevels = BerryConstants.LogLevels
local ConfigLevel = LogLevels[BerryConfig.Framework.LogLevel:sub(1,1):upper() .. BerryConfig.Framework.LogLevel:sub(2)] or LogLevels.Info

local function FormatMessage(category, levelStr, message, ...)
    local prefix = string.format("[BERRY:%s] [%s]", category:upper(), levelStr)
    local formatted = message
    if select('#', ...) > 0 then
        formatted = string.format(message, ...)
    end
    return string.format("%s %s", prefix, formatted)
end

function Berry.Logger.Debug(category, message, ...)
    if ConfigLevel <= LogLevels.Debug then
        print("^5" .. FormatMessage(category, "DEBUG", message, ...) .. "^7")
    end
end

function Berry.Logger.Info(category, message, ...)
    if ConfigLevel <= LogLevels.Info then
        print("^2" .. FormatMessage(category, "INFO", message, ...) .. "^7")
    end
end

function Berry.Logger.Warn(category, message, ...)
    if ConfigLevel <= LogLevels.Warn then
        print("^3" .. FormatMessage(category, "WARN", message, ...) .. "^7")
    end
end

function Berry.Logger.Error(category, message, ...)
    if ConfigLevel <= LogLevels.Error then
        print("^1" .. FormatMessage(category, "ERROR", message, ...) .. "^7")
    end
end
