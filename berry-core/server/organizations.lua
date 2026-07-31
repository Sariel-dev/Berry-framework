local Berry = exports["berry-core"]:GetCoreObject()

BerryOrganizations = BerryOrganizations or {}

function BerryOrganizations.Create(id, label, orgType)
    MySQL.insert.await([[
        INSERT INTO berry_organizations (id, label, type, balance)
        VALUES (?, ?, ?, 0.00)
    ]], { id, label, orgType or "gang" })
    Berry.Logger.Info("ORGANIZATIONS", "Created organization '%s' (%s)", label, id)
    return true
end

function BerryOrganizations.AddMember(orgId, characterId, grade)
    MySQL.insert.await([[
        INSERT INTO berry_organization_members (organization_id, character_id, grade)
        VALUES (?, ?, ?)
    ]], { orgId, characterId, grade or 0 })
    return true
end
