local Berry = exports["berry-core"]:GetCoreObject()
Berry.Markers = {}

local registeredMarkers = {}
local spatialChunks = {}
local activeMarker = nil

local function GetChunkKey(x, y)
    local chunkX = math.floor(x / 100.0)
    local chunkY = math.floor(y / 100.0)
    return string.format("%d_%d", chunkX, chunkY)
end

function Berry.Markers.Add(id, coords, options)
    options = options or {}
    local markerData = {
        id = id,
        coords = vector3(coords.x, coords.y, coords.z),
        type = options.type or 1,
        size = options.size or vector3(1.0, 1.0, 1.0),
        color = options.color or { r = 192, g = 132, b = 252, a = 180 },
        drawDistance = options.drawDistance or 15.0,
        interactDistance = options.interactDistance or 1.5,
        label = options.label or "Interaction",
        onInteract = options.onInteract
    }

    registeredMarkers[id] = markerData

    local chunkKey = GetChunkKey(coords.x, coords.y)
    spatialChunks[chunkKey] = spatialChunks[chunkKey] or {}
    table.insert(spatialChunks[chunkKey], markerData)
end

function Berry.Markers.Remove(id)
    if registeredMarkers[id] then
        local coords = registeredMarkers[id].coords
        local chunkKey = GetChunkKey(coords.x, coords.y)
        if spatialChunks[chunkKey] then
            for i, m in ipairs(spatialChunks[chunkKey]) do
                if m.id == id then
                    table.remove(spatialChunks[chunkKey], i)
                    break
                end
            end
        end
        registeredMarkers[id] = nil
    end
end

-- High Performance Event Loop (0.00ms Idle)
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local pCoords = GetEntityCoords(ped)
        local currentChunkKey = GetChunkKey(pCoords.x, pCoords.y)
        local nearbyMarkers = spatialChunks[currentChunkKey]

        if nearbyMarkers and #nearbyMarkers > 0 then
            local sleep = 500
            local closestDist = 9999.0
            local currentClosest = nil

            for _, marker in ipairs(nearbyMarkers) do
                local distSqr = #(pCoords - marker.coords)
                if distSqr < (marker.drawDistance * marker.drawDistance) then
                    sleep = 0
                    DrawMarker(
                        marker.type,
                        marker.coords.x, marker.coords.y, marker.coords.z,
                        0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                        marker.size.x, marker.size.y, marker.size.z,
                        marker.color.r, marker.color.g, marker.color.b, marker.color.a,
                        false, true, 2, false, nil, nil, false
                    )

                    if distSqr < (marker.interactDistance * marker.interactDistance) then
                        if distSqr < closestDist then
                            closestDist = distSqr
                            currentClosest = marker
                        end
                    end
                end
            end

            if currentClosest then
                activeMarker = currentClosest
                BeginTextCommandDisplayHelp("STRING")
                AddTextComponentSubstringPlayerName("Appuyez sur ~INPUT_CONTEXT~ pour ~purple~" .. currentClosest.label .. "~s~")
                EndTextCommandDisplayHelp(0, false, true, -1)

                if IsControlJustReleased(0, 38) then -- E key
                    if currentClosest.onInteract then
                        currentClosest.onInteract(currentClosest)
                    end
                end
            else
                activeMarker = nil
            end

            Wait(sleep)
        else
            Wait(1000)
        end
    end
end)

exports("AddMarker", Berry.Markers.Add)
exports("RemoveMarker", Berry.Markers.Remove)
