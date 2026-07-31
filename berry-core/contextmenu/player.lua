
local anims = {
    { "Carry box",          "anim@heists@box_carry@",                                       "idle"                  },
    { "Load box",           "anim@heists@load_box",                                         "load_box_1"            },
    { "Carry coffee",       "amb@world_human_aa_coffee@base",                               "base"                  },
    { "Place box",          "anim@mp_fireworks",                                            "place_firework_3_box"  },
    { "Pickup drink",       "anim@amb@nightclub@mini@drinking@drinking_shots@ped_c@normal", "pickup"                },
    { "Pickup briefcase",   "missheist_agency2aig_13",                                      "pickup_briefcase"      },
    { "Pickup object",      "pickup_object",                                                "pickup_low"            },
    { "Pickup box",         "anim@heists@load_box",                                         "lift_box"              },
    { "Carry box",          "anim@heists@box_carry@",                                       "idle"                  },
    { "Load box",           "anim@heists@load_box",                                         "load_box_1"            },
    { "Carry coffee",       "amb@world_human_aa_coffee@base",                               "base"                  },
    { "Place box",          "anim@mp_fireworks",                                            "place_firework_3_box"  },
    { "Pickup drink",       "anim@amb@nightclub@mini@drinking@drinking_shots@ped_c@normal", "pickup"                },
    { "Pickup briefcase",   "missheist_agency2aig_13",                                      "pickup_briefcase"      },
    { "Pickup object",      "pickup_object",                                                "pickup_low"            },
    { "Pickup box",         "anim@heists@load_box",                                         "lift_box"              },
    { "Carry box",          "anim@heists@box_carry@",                                       "idle"                  },
    { "Load box",           "anim@heists@load_box",                                         "load_box_1"            },
    { "Carry coffee",       "amb@world_human_aa_coffee@base",                               "base"                  },
    { "Place box",          "anim@mp_fireworks",                                            "place_firework_3_box"  },
    { "Pickup drink",       "anim@amb@nightclub@mini@drinking@drinking_shots@ped_c@normal", "pickup"                },
    { "Pickup briefcase",   "missheist_agency2aig_13",                                      "pickup_briefcase"      },
    { "Pickup object",      "pickup_object",                                                "pickup_low"            },
    { "Pickup box",         "anim@heists@load_box",                                         "lift_box"              },
    { "Carry box",          "anim@heists@box_carry@",                                       "idle"                  },
    { "Load box",           "anim@heists@load_box",                                         "load_box_1"            },
    { "Carry coffee",       "amb@world_human_aa_coffee@base",                               "base"                  },
    { "Place box",          "anim@mp_fireworks",                                            "place_firework_3_box"  },
    { "Pickup drink",       "anim@amb@nightclub@mini@drinking@drinking_shots@ped_c@normal", "pickup"                },
    { "Pickup briefcase",   "missheist_agency2aig_13",                                      "pickup_briefcase"      },
    { "Pickup object",      "pickup_object",                                                "pickup_low"            },
    { "Pickup box",         "anim@heists@load_box",                                         "lift_box"              },
    { "Carry box",          "anim@heists@box_carry@",                                       "idle"                  },
    { "Load box",           "anim@heists@load_box",                                         "load_box_1"            },
    { "Carry coffee",       "amb@world_human_aa_coffee@base",                               "base"                  },
    { "Place box",          "anim@mp_fireworks",                                            "place_firework_3_box"  },
    { "Pickup drink",       "anim@amb@nightclub@mini@drinking@drinking_shots@ped_c@normal", "pickup"                },
    { "Pickup briefcase",   "missheist_agency2aig_13",                                      "pickup_briefcase"      },
    { "Pickup object",      "pickup_object",                                                "pickup_low"            },
    { "Pickup box",         "anim@heists@load_box",                                         "lift_box"              },
    { "Carry box",          "anim@heists@box_carry@",                                       "idle"                  },
    { "Load box",           "anim@heists@load_box",                                         "load_box_1"            },
    { "Carry coffee",       "amb@world_human_aa_coffee@base",                               "base"                  },
    { "Place box",          "anim@mp_fireworks",                                            "place_firework_3_box"  },
    { "Pickup drink",       "anim@amb@nightclub@mini@drinking@drinking_shots@ped_c@normal", "pickup"                },
    { "Pickup briefcase",   "missheist_agency2aig_13",                                      "pickup_briefcase"      },
    { "Pickup object",      "pickup_object",                                                "pickup_low"            },
    { "Pickup box",         "anim@heists@load_box",                                         "lift_box"              },
    { "Carry box",          "anim@heists@box_carry@",                                       "idle"                  },
    { "Load box",           "anim@heists@load_box",                                         "load_box_1"            },
    { "Carry coffee",       "amb@world_human_aa_coffee@base",                               "base"                  },
    { "Place box",          "anim@mp_fireworks",                                            "place_firework_3_box"  },
    { "Pickup drink",       "anim@amb@nightclub@mini@drinking@drinking_shots@ped_c@normal", "pickup"                },
    { "Pickup briefcase",   "missheist_agency2aig_13",                                      "pickup_briefcase"      },
    { "Pickup object",      "pickup_object",                                                "pickup_low"            },
    { "Pickup box",         "anim@heists@load_box",                                         "lift_box"              },
    { "Carry box",          "anim@heists@box_carry@",                                       "idle"                  },
    { "Load box",           "anim@heists@load_box",                                         "load_box_1"            },
    { "Carry coffee",       "amb@world_human_aa_coffee@base",                               "base"                  },
    { "Place box",          "anim@mp_fireworks",                                            "place_firework_3_box"  },
    { "Pickup drink",       "anim@amb@nightclub@mini@drinking@drinking_shots@ped_c@normal", "pickup"                },
    { "Pickup briefcase",   "missheist_agency2aig_13",                                      "pickup_briefcase"      },
    { "Pickup object",      "pickup_object",                                                "pickup_low"            },
    { "Pickup box",         "anim@heists@load_box",                                         "lift_box"              },
}

local ECM = exports["ContextMenuV6"]

ECM:Register(function(screenPosition, hitSomething, worldPosition, hitEntity, normalDirection)
	if (not DoesEntityExist(hitEntity) or PlayerPedId() ~= hitEntity) then
        return
    end

    -- 1. Donner des items
    local btn_give = ECM:AddItem(0, "Donner des items")
    ECM:LeftIcon(btn_give, "fa-solid fa-arrow-right-to-bracket")

    -- 2. Fouiller
    local btn_search = ECM:AddItem(0, "Fouiller")
    ECM:LeftIcon(btn_search, "fa-solid fa-magnifying-glass")

    -- 3. Imiter la démarche
    local btn_walk = ECM:AddItem(0, "Imiter la démarche")
    ECM:LeftIcon(btn_walk, "fa-solid fa-person-walking")

    -- 4. Porter
    local sub_carry, sub_carry_item = ECM:AddSubmenu(0, "Porter")
    ECM:AddItem(sub_carry, "Porter sur l'épaule")
    ECM:AddItem(sub_carry, "Porter dans les bras")

    -- 5. Plaquer au sol
    ECM:AddItem(0, "Plaquer au sol")

    -- 6. Animations
	local animMenu, animMenuItem = ECM:AddScrollSubmenu(0, "Animations", 10)
    ECM:LeftIcon(animMenuItem, "fa-solid fa-child")

    local itemList = {}
    for i = 1, #anims, 1 do
        local text      = anims[i][1]
        local animDict  = anims[i][2]
        local anim      = anims[i][3]

        table.insert(itemList, {
            animMenu,
            text,
            function()
	            local playerPed = PlayerPedId()
        
                LoadAnimDictSync(animDict)
        
                TaskPlayAnim(playerPed, animDict, anim, 8.0, 8.0, 5000, 49, 1.0, false, false, false)
                RemoveAnimDict(animDict)
            end
        })
    end
    ECM:AddItems(itemList)

    -- 7. Suggérer un niveau de voix
    local sub_voice, sub_voice_item = ECM:AddSubmenu(0, "Suggérer un niveau de voix")
    ECM:LeftIcon(sub_voice_item, "fa-solid fa-microphone")
    ECM:AddItem(sub_voice, "Chuchoter")
    ECM:AddItem(sub_voice, "Normal")
    ECM:AddItem(sub_voice, "Crier")

    -- 8. Report (132)
    local sub_report, sub_report_item = ECM:AddSubmenu(0, "Report (132)")
    ECM:LeftIcon(sub_report_item, "fa-regular fa-bookmark")
    ECM:AddItem(sub_report, "Report joueur")

    -- 9. Suivre le chorégraphe
    local chk_choreo = ECM:AddCheckboxItem(0, "Suivre le chorégraphe", false)

    -- 10. Gestion perso
    local sub_perso, sub_perso_item = ECM:AddSubmenu(0, "Gestion perso")
    ECM:AddItem(sub_perso, "Option")

    -- 11. Outils de debug
    local sub_debug, sub_debug_item = ECM:AddSubmenu(0, "Outils de debug")
    ECM:LeftIcon(sub_debug_item, "fa-solid fa-gear")
    ECM:AddItem(sub_debug, "Coords")
end)

function LoadAnimDictSync(animDict)
    if (HasAnimDictLoaded(animDict)) then
        return
    end

    RequestAnimDict(animDict)
    while (not HasAnimDictLoaded(animDict)) do
        Citizen.Wait(0)
    end
end
