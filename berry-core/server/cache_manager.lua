Berry.Cache = {}

local cacheStore = {}

function Berry.Cache.Set(key, value, ttlSeconds)
    local expiry = ttlSeconds and (os.time() + ttlSeconds) or nil
    cacheStore[key] = {
        value = value,
        expiry = expiry
    }
end

function Berry.Cache.Get(key)
    local entry = cacheStore[key]
    if not entry then return nil end

    if entry.expiry and os.time() > entry.expiry then
        cacheStore[key] = nil
        return nil
    end

    return entry.value
end

function Berry.Cache.Invalidate(key)
    cacheStore[key] = nil
end

function Berry.Cache.Clear()
    cacheStore = {}
end

function Berry.Cache.Cleanup()
    local now = os.time()
    local count = 0
    for k, v in pairs(cacheStore) do
        if v.expiry and now > v.expiry then
            cacheStore[k] = nil
            count = count + 1
        end
    end
    if count > 0 then
        Berry.Logger.Debug("CACHE", "Cleaned up %d expired cache items.", count)
    end
end
