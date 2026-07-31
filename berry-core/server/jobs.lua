local Berry = exports["berry-core"]:GetCoreObject()

BerryJobs = BerryJobs or {}

function BerryJobs.SetPlayerJob(source, jobName, grade)
    local player = Berry.GetPlayer(source)
    if not player then return false, "Player not found." end

    local jobRow = MySQL.single.await("SELECT * FROM berry_jobs WHERE name = ?", { jobName })
    if not jobRow then return false, "Job does not exist." end

    local gradeRow = MySQL.single.await("SELECT * FROM berry_job_grades WHERE job_name = ? AND grade = ?", { jobName, grade or 0 })
    if not gradeRow then return false, "Job grade does not exist." end

    player.job = {
        name = jobName,
        label = jobRow.label,
        grade = gradeRow.grade,
        grade_name = gradeRow.name,
        grade_label = gradeRow.label,
        grade_salary = gradeRow.salary
    }

    player:MarkDirty("job")
    TriggerClientEvent("berry:jobChanged", source, player.job)
    Berry.Logger.Info("JOBS", "Set player %s job to %s (%s)", player:GetName(), jobName, gradeRow.label)
    return true
end

-- Paycheck Timer
CreateThread(function()
    while true do
        Wait(15 * 60 * 1000)
        Berry.Logger.Info("JOBS", "Processing paychecks...")
        for _, player in pairs(Berry.PlayersBySource) do
            local job = player:GetJob()
            local salary = job.grade_salary or 200
            if salary > 0 then
                player:AddMoney("bank", salary, "paycheck")
                TriggerClientEvent("berry:notify", player:GetSource(), string.format("Salaire reçu : %d$ (%s)", salary, job.label or job.name))
            end
        end
    end
end)
