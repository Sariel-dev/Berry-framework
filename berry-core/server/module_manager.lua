Berry.ModuleManager = {}

local registeredModules = {}
local moduleLoadOrder = {}

function Berry.ModuleManager.RegisterModule(name, options)
    if registeredModules[name] then
        Berry.Logger.Warn("MODULE", "Module '%s' is already registered.", name)
        return false
    end

    local moduleData = {
        name = name,
        version = options.version or "1.0.0",
        dependencies = options.dependencies or {},
        onInit = options.onInit,
        onStart = options.onStart,
        onStop = options.onStop,
        loaded = false
    }

    registeredModules[name] = moduleData
    table.insert(moduleLoadOrder, name)
    Berry.Logger.Info("MODULE", "Registered module '%s' (v%s)", name, moduleData.version)
    return true
end

function Berry.ModuleManager.LoadAll()
    for _, name in ipairs(moduleLoadOrder) do
        local mod = registeredModules[name]
        if mod and not mod.loaded then
            -- Verify dependencies
            local depsMet = true
            for _, dep in ipairs(mod.dependencies) do
                if not registeredModules[dep] or not registeredModules[dep].loaded then
                    Berry.Logger.Error("MODULE", "Cannot load module '%s': Missing dependency '%s'", name, dep)
                    depsMet = false
                    break
                end
            end

            if depsMet then
                if type(mod.onInit) == "function" then
                    mod.onInit()
                end
                if type(mod.onStart) == "function" then
                    mod.onStart()
                end
                mod.loaded = true
                Berry.Logger.Info("MODULE", "Module '%s' successfully started.", name)
            end
        end
    end
end

function Berry.ModuleManager.GetModules()
    return registeredModules
end
