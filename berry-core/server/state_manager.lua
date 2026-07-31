Berry.State = Berry.State or {}

function Berry.State.SetPlayerState(source, key, value, replicated)
    local playerState = Player(source).state
    if playerState then
        playerState:set(key, value, replicated or false)
    end
end

function Berry.State.GetPlayerState(source, key)
    local playerState = Player(source).state
    if playerState then
        return playerState[key]
    end
    return nil
end

function Berry.State.SetEntityState(entity, key, value, replicated)
    if DoesEntityExist(entity) then
        local entityState = Entity(entity).state
        if entityState then
            entityState:set(key, value, replicated or false)
        end
    end
end

function Berry.State.GetEntityState(entity, key)
    if DoesEntityExist(entity) then
        local entityState = Entity(entity).state
        if entityState then
            return entityState[key]
        end
    end
    return nil
end
