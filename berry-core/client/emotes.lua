local Berry = exports["berry-core"]:GetCoreObject()
Berry.Emotes = Berry.Emotes or {}

local currentProp = nil
local isPlayingEmote = false

-- Emote Categories Data
Berry.Emotes.Categories = {
    dances = {
        { label = "Danse 1", dict = "anim@amb@nightclub@dancers@crowddance@groups@hi_intensity", anim = "hi_dance_09_v1_female^1" },
        { label = "Danse HipHop", dict = "anim@amb@nightclub@mini@dance@dance_solo@male@var_a@", anim = "high_center" },
        { label = "Danse Party", dict = "anim@mp_player_intupperdancedopeman", anim = "dancedopeman_face" },
        { label = "Danse Salsa", dict = "anim@amb@nightclub@mini@dance@dance_solo@female@var_b@", anim = "med_center" },
        { label = "Danse Slow", dict = "anim@amb@nightclub@mini@dance@dance_solo@female@var_a@", anim = "low_center" }
    },
    gestures = {
        { label = "Saluer", dict = "anim@mp_player_intincrowdwave", anim = "a_wave" },
        { label = "Croiser les bras", dict = "anim@amb@nightclub@peds@", anim = "rcmme_amanda1_stand_loop_cop" },
        { label = "Applaudir", dict = "anim@mp_player_intupperapplause", anim = "idle_a" },
        { label = "Signe Gang West", dict = "mp_player_int_uppergang_sign_a", anim = "gang_sign_a" },
        { label = "Signe Gang East", dict = "mp_player_int_uppergang_sign_b", anim = "gang_sign_b" },
        { label = "Penser / Réfléchir", dict = "amb@world_human_hang_out_street@female_arms_crossed@idle_a", anim = "idle_a" }
    },
    sitting = {
        { label = "S'asseoir au sol", dict = "anim@heists@fleeca_bank@ig_7_jetski_owner", anim = "owner_idle" },
        { label = "S'asseoir sur chaise", dict = "anim@amb@business@bty@bty_office@sit_chair@", anim = "sit_chair_idle" },
        { label = "S'allonger sur le dos", dict = "amb@world_human_sunbathe@male@back@idle_a", anim = "idle_a" },
        { label = "S'allonger sur le ventre", dict = "amb@world_human_sunbathe@female@front@idle_a", anim = "idle_a" }
    },
    props = {
        { label = "Boire une bière", dict = "amb@world_human_drinking@beer@female@idle_a", anim = "idle_e", prop = "prop_amb_beer_bottle", bone = 28422, pos = vector3(0.0, 0.0, 0.0), rot = vector3(0.0, 0.0, 0.0) },
        { label = "Manger un burger", dict = "mp_player_inteat@burger", anim = "mp_player_int_eat_burger", prop = "prop_cs_burger_01", bone = 18905, pos = vector3(0.13, 0.05, 0.02), rot = vector3(-50.0, 16.0, 60.0) },
        { label = "Fumer une cigarette", dict = "amb@world_human_smoking@male@male_a@idle_a", anim = "idle_a", prop = "ng_proc_cigar01a", bone = 28422, pos = vector3(0.0, 0.0, 0.0), rot = vector3(0.0, 0.0, 0.0) },
        { label = "Café à emporter", dict = "amb@world_human_drinking@coffee@male@idle_a", anim = "idle_a", prop = "p_amb_coffeecup_01", bone = 28422, pos = vector3(0.0, 0.0, 0.0), rot = vector3(0.0, 0.0, 0.0) }
    }
}

-- Play Emote Engine
function Berry.Emotes.Play(dict, anim, propModel, bone, pos, rot, flag)
    local ped = PlayerPedId()

    Berry.Emotes.Stop()

    if dict and anim then
        RequestAnimDict(dict)
        while not HasAnimDictLoaded(dict) do Wait(10) end

        TaskPlayAnim(ped, dict, anim, 8.0, -8.0, -1, flag or 49, 0, false, false, false)
        isPlayingEmote = true
    end

    if propModel then
        local pHash = GetHashKey(propModel)
        RequestModel(pHash)
        while not HasModelLoaded(pHash) do Wait(10) end

        local pCoords = GetEntityCoords(ped)
        local propObj = CreateObject(pHash, pCoords.x, pCoords.y, pCoords.z + 0.2, true, true, true)
        AttachEntityToEntity(propObj, ped, GetPedBoneIndex(ped, bone or 28422), pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, true, true, false, true, 1, true)
        currentProp = propObj
    end
end

-- Stop Emote Engine
function Berry.Emotes.Stop()
    local ped = PlayerPedId()
    ClearPedTasks(ped)
    if currentProp and DoesEntityExist(currentProp) then
        DeleteEntity(currentProp)
        currentProp = nil
    end
    isPlayingEmote = false
end

exports("PlayEmote", Berry.Emotes.Play)
exports("StopEmote", Berry.Emotes.Stop)
