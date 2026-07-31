# 📖 Documentation API Complète — Berry Framework

## Table des Matières
1. [Initialisation](#1-initialisation)
2. [Méthodes du Core (`Berry`)](#2-méthodes-du-core-berry)
3. [Classe Joueur (`Player`)](#3-classe-joueur-player)
4. [Gestionnaire d'Événements & Callbacks](#4-gestionnaire-dévénements--callbacks)
5. [Sécurité & Rate Limiting](#5-sécurité--rate-limiting)
6. [Gestionnaire SQL (`oxmysql`)](#6-gestionnaire-sql-oxmysql)
7. [Créer un Module Personnalisé](#7-créer-un-module-personnalisé)

---

## 1. Initialisation

Dans toute ressource externe ou script client/serveur, commencez par importer l'instance singleton du framework :

```lua
local Berry = exports["berry-core"]:GetCoreObject()
```

---

## 2. Méthodes du Core (`Berry`)

### Recherche de Joueur
```lua
-- Obtenir l'instance Player par l'ID serveur (source)
local player = Berry.GetPlayer(source)

-- Obtenir l'instance Player par identifiant (license/discord)
local player = Berry.GetPlayerByIdentifier("license:xxxx")

-- Obtenir l'instance Player par ID de personnage (ID SQL)
local player = Berry.GetPlayerByCharacterId(12)
```

---

## 3. Classe Joueur (`Player`)

Lorsqu'un joueur est chargé, l'objet `player` dispose des méthodes suivantes :

### Informatives
```lua
local src = player:GetSource()        -- ID serveur (integer)
local id = player:GetIdentifier()      -- Identifiant principal (string)
local charId = player:GetCharacterId() -- ID de personnage SQL (integer)
local name = player:GetName()          -- Prénom et Nom ("John Doe")
local pos = player:GetPosition()       -- Position actuelle {x, y, z, heading}
```

### Opérations Financières
```lua
-- Consulter un solde ("cash", "bank", "black_money")
local money = player:GetMoney("cash")

-- Créditer un compte (Retourne boolean)
local success = player:AddMoney("cash", 500, "raison_log")

-- Débiter un compte (Vérifie automatiquement le solde suffisant)
local success = player:RemoveMoney("bank", 200, "achat_shop")
```

### Métiers & Métadonnées
```lua
-- Métier actuel
local job = player:GetJob() -- { name, grade, label, grade_name, grade_salary }

-- Modifier le métier
player:SetJob("police", 2)

-- Métadonnées dynamiques (faim, soif, états)
local thirst = player:GetMetadata("thirst")
player:SetMetadata("thirst", 100)
```

---

## 4. Gestionnaire d'Événements & Callbacks

### Événements Réservés (`berry:`)
```lua
-- Écouter un événement côté serveur (validation automatique de sécurité)
Berry.Events.On("player:heal", function(source, targetSource)
    local target = Berry.GetPlayer(targetSource)
    if target then
        TriggerClientEvent("berry:notify", targetSource, "Vous avez été soigné !", "success")
    end
end)

-- Déclencher un événement serveur
Berry.Events.Emit("player:heal", 2)

-- Déclencher un événement vers un client spécifique
Berry.Events.EmitClient("notify", source, "Message envoyé !", "info")
```

### Callbacks RPC (Asynchrones)
```lua
-- Enregistrer un callback côté serveur
Berry.Callbacks.Register("berry:getCharData", function(source, cb, charId)
    local data = MySQL.single.await("SELECT * FROM berry_characters WHERE id = ?", { charId })
    cb(data)
end)

-- Déclencher le callback côté client
Berry.Callbacks.Trigger("berry:getCharData", function(charData)
    if charData then
        print("Nom du personnage : " .. charData.firstname)
    end
end, 12)
```

---

## 5. Sécurité & Rate Limiting

```lua
-- Vérifier la limitation de débit (Max 5 requêtes par seconde)
if not Berry.Security.CheckRateLimit(source, "purchase_item", 5, 1000) then
    return Berry.Logger.Warn("SECURITY", "Spam détecté de la part du joueur %d", source)
end

-- Valider une distance (Vérifie la distance carrée sans sqrt)
local isNear = Berry.Security.ValidateDistance(source, { x = 100.0, y = 200.0, z = 20.0 }, 10.0)
if not isNear then
    return -- Action rejetée : joueur trop loin
end
```

---

## 6. Gestionnaire SQL (`oxmysql`)

Le noyau abstrait les requêtes SQL via `Berry.Database` avec profilage automatique des requêtes lentes (>100ms) :

```lua
-- Sélection d'une ligne unique
local char = Berry.Database.Single("SELECT * FROM berry_characters WHERE id = ?", { 12 })

-- Insertion avec récupération de l'ID inséré
local newId = Berry.Database.Insert("INSERT INTO berry_accounts (identifier) VALUES (?)", { "license:xxx" })

-- Mise à jour
local updatedRows = Berry.Database.Update("UPDATE berry_characters SET position = ? WHERE id = ?", { posJson, 12 })
```

---

## 7. Créer un Module Personnalisé

Pour créer un module personnalisé au sein du framework :

1. Ajoutez votre fichier dans `berry-core/server/my_module.lua` ou `berry-core/client/my_module.lua`.
2. Déclarez le fichier dans `berry-core/fxmanifest.lua`.
3. Utilisez l'API `Berry` directement sans aucune instanciation supplémentaire.
