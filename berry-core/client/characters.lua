local Berry = exports["berry-core"]:GetCoreObject()

RegisterNetEvent("berry:clientCoreReady", function()
    Berry.Callbacks.Trigger("berry:characters:getCharacters", function(characters)
        if not characters or #characters == 0 then
            Berry.Callbacks.Trigger("berry:characters:createCharacter", function(success, charId)
                if success then
                    Berry.Callbacks.Trigger("berry:characters:selectCharacter", function(selected)
                        if selected then
                            Berry.ClientUtils.ShowNotification("Personnage créé et chargé avec succès !", "success")
                        end
                    end, charId)
                end
            end, { firstname = "John", lastname = "Doe", dateofbirth = "1990-01-01", sex = "m" })
        else
            local firstChar = characters[1]
            Berry.Callbacks.Trigger("berry:characters:selectCharacter", function(selected)
                if selected then
                    Berry.ClientUtils.ShowNotification("Personnage chargé : " .. firstChar.firstname .. " " .. firstChar.lastname, "info")
                end
            end, firstChar.id)
        end
    end)
end)
