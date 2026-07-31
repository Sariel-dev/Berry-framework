Berry.Utils = {}

local type = type
local math_sqrt = math.sqrt
local math_random = math.random
local math_floor = math.floor
local table_insert = table.insert
local table_concat = table.concat
local string_sub = string.sub

function Berry.Utils.DeepCopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[Berry.Utils.DeepCopy(orig_key)] = Berry.Utils.DeepCopy(orig_value)
        end
        setmetatable(copy, Berry.Utils.DeepCopy(getmetatable(orig)))
    else
        copy = orig
    end
    return copy
end

function Berry.Utils.Trim(str)
    if type(str) ~= "string" then return str end
    return str:match("^%s*(.-)%s*$")
end

function Berry.Utils.CalculateDistanceSqr(coords1, coords2)
    if not coords1 or not coords2 then return 99999999.0 end
    local x1, y1, z1 = coords1.x or 0.0, coords1.y or 0.0, coords1.z or 0.0
    local x2, y2, z2 = coords2.x or 0.0, coords2.y or 0.0, coords2.z or 0.0
    local dx, dy, dz = x1 - x2, y1 - y2, z1 - z2
    return dx * dx + dy * dy + dz * dz
end

function Berry.Utils.CalculateDistance(coords1, coords2)
    return math_sqrt(Berry.Utils.CalculateDistanceSqr(coords1, coords2))
end

function Berry.Utils.RandomString(length)
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
    local res = {}
    local len = #chars
    for i = 1, (length or 8) do
        local rand = math_random(1, len)
        table_insert(res, string_sub(chars, rand, rand))
    end
    return table_concat(res)
end

function Berry.Utils.Round(num, numDecimalPlaces)
    local mult = 10^(numDecimalPlaces or 0)
    return math_floor(num * mult + 0.5) / mult
end
