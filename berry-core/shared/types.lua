BerryTypes = {}

function BerryTypes.IsVector3(val)
    if type(val) == "vector3" then return true end
    if type(val) == "table" and type(val.x) == "number" and type(val.y) == "number" and type(val.z) == "number" then
        return true
    end
    return false
end

function BerryTypes.IsNumber(val)
    return type(val) == "number" and val == val -- NaN check
end

function BerryTypes.IsPositiveNumber(val)
    return BerryTypes.IsNumber(val) and val > 0
end

function BerryTypes.IsNonNegativeNumber(val)
    return BerryTypes.IsNumber(val) and val >= 0
end

function BerryTypes.IsString(val)
    return type(val) == "string" and #val > 0
end

function BerryTypes.IsTable(val)
    return type(val) == "table"
end
