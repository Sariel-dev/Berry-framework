local groups = PlayerData.groups or {}
local QBCore = exports['qb-core']:GetCoreObject()

local function getGradeLevel(grade)
    if type(grade) == 'number' then return grade end
    if type(grade) == 'table' then
        if type(grade.level) == 'number' then return grade.level end
        if type(grade.grade) == 'number' then return grade.grade end
        if type(grade.value) == 'number' then return grade.value end
    end
    return 0
end

local function applyGroupData(playerData)
    if not playerData then return end

    local newGroups = {}

    if playerData.job and playerData.job.name then
        newGroups[playerData.job.name] = getGradeLevel(playerData.job.grade)
    end

    if playerData.gang and playerData.gang.name then
        newGroups[playerData.gang.name] = getGradeLevel(playerData.gang.grade)
    end

    groups = newGroups
    client.setPlayerData('groups', groups)
end

local function refreshGroups()
    local playerData = QBCore.Functions.GetPlayerData()
    if not playerData then return end
    applyGroupData(playerData)
end

RegisterNetEvent('QBCore:Client:OnPlayerUnload', client.onLogout)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
    local playerData = QBCore.Functions.GetPlayerData() or {}
    playerData.job = job
    applyGroupData(playerData)
end)

RegisterNetEvent('QBCore:Client:OnGangUpdate', function(gang)
    local playerData = QBCore.Functions.GetPlayerData() or {}
    playerData.gang = gang
    applyGroupData(playerData)
end)

RegisterNetEvent('QBCore:Player:SetPlayerData', function(playerData)
    if not PlayerData.loaded then return end
    applyGroupData(playerData)
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    refreshGroups()
end)
