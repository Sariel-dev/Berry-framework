local Berry = exports["berry-core"]:GetCoreObject()

BerryVehicles = BerryVehicles or {}

local function GeneratePlate()
    local plate
    local isUnique = false
    while not isUnique do
        plate = string.format("%s%03d%s", Berry.Utils.RandomString(3):upper(), math.random(100, 999), Berry.Utils.RandomString(2):upper())
        local existing = MySQL.single.await("SELECT plate FROM berry_vehicles WHERE plate = ?", { plate })
        if not existing then
            isUnique = true
        end
    end
    return plate
end

function BerryVehicles.GiveVehicle(source, model, garage)
    local player = Berry.GetPlayer(source)
    if not player then return false, "Player not loaded." end

    local plate = GeneratePlate()
    local charId = player:GetCharacterId()

    MySQL.insert.await([[
        INSERT INTO berry_vehicles (plate, owner_id, model, garage, state)
        VALUES (?, ?, ?, ?, 1)
    ]], { plate, charId, model, garage or "pillbox" })

    Berry.Logger.Info("VEHICLES", "Gave vehicle %s (Plate: %s) to character ID %d", model, plate, charId)
    return true, plate
end

Berry.Callbacks.Register("berry:vehicles:getOwned", function(source, cb)
    local player = Berry.GetPlayer(source)
    if not player then return cb({}) end

    local charId = player:GetCharacterId()
    local vehicles = MySQL.query.await("SELECT * FROM berry_vehicles WHERE owner_id = ?", { charId })
    cb(vehicles)
end)
