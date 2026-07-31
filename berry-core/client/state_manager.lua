Berry.State = Berry.State or {}

function Berry.State.GetLocalPlayerState(key)
    return LocalPlayer.state[key]
end

function Berry.State.SetLocalPlayerState(key, value, replicated)
    LocalPlayer.state:set(key, value, replicated or false)
end

function Berry.State.GetEntityState(entity, key)
    if DoesEntityExist(entity) then
        return Entity(entity).state[key]
    end
    return nil
end
