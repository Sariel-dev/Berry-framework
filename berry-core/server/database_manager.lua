Berry.Database = {}

local SlowQueryThreshold = BerryConfig.Database.SlowQueryThresholdMs or 100

function Berry.Database.Ready()
    return MySQL and MySQL.ready ~= nil
end

function Berry.Database.Query(query, params)
    local startTime = GetGameTimer()
    local result = MySQL.query.await(query, params or {})
    local duration = GetGameTimer() - startTime

    if duration >= SlowQueryThreshold then
        Berry.Logger.Warn("DATABASE", "Slow Query (%d ms): %s", duration, query)
    end

    return result
end

function Berry.Database.Scalar(query, params)
    local startTime = GetGameTimer()
    local result = MySQL.scalar.await(query, params or {})
    local duration = GetGameTimer() - startTime

    if duration >= SlowQueryThreshold then
        Berry.Logger.Warn("DATABASE", "Slow Query (%d ms): %s", duration, query)
    end

    return result
end

function Berry.Database.Single(query, params)
    local startTime = GetGameTimer()
    local result = MySQL.single.await(query, params or {})
    local duration = GetGameTimer() - startTime

    if duration >= SlowQueryThreshold then
        Berry.Logger.Warn("DATABASE", "Slow Query (%d ms): %s", duration, query)
    end

    return result
end

function Berry.Database.Insert(query, params)
    local startTime = GetGameTimer()
    local result = MySQL.insert.await(query, params or {})
    local duration = GetGameTimer() - startTime

    if duration >= SlowQueryThreshold then
        Berry.Logger.Warn("DATABASE", "Slow Query (%d ms): %s", duration, query)
    end

    return result
end

function Berry.Database.Update(query, params)
    local startTime = GetGameTimer()
    local result = MySQL.update.await(query, params or {})
    local duration = GetGameTimer() - startTime

    if duration >= SlowQueryThreshold then
        Berry.Logger.Warn("DATABASE", "Slow Query (%d ms): %s", duration, query)
    end

    return result
end

function Berry.Database.Transaction(queries, params)
    local startTime = GetGameTimer()
    local result = MySQL.transaction.await(queries, params or {})
    local duration = GetGameTimer() - startTime

    if duration >= SlowQueryThreshold then
        Berry.Logger.Warn("DATABASE", "Slow Transaction (%d ms)", duration)
    end

    return result
end
