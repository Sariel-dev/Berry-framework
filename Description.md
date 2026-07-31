# 🍓 Berry Framework — FiveM Roleplay Engine

[![FiveM](https://img.shields.io/badge/FiveM-FXServer_Cerulean-purple.svg)](https://fivem.net/)
[![Lua](https://img.shields.io/badge/Lua-5.4-blue.svg)](https://www.lua.org/)
[![Database](https://img.shields.io/badge/Database-oxmysql-orange.svg)](https://github.com/overextended/oxmysql)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Performance](https://img.shields.io/badge/Performance-0.00ms_idle-brightgreen.svg)]()

**Berry Framework** est un framework FiveM nouvelle génération, complet, original, ultra-optimisé et sécurisé pour serveurs RP sérieux. Conçu en pure **Lua 5.4**, il est condensé au sein d'une **ressource unique (`berry-core`)** avec une architecture autoritaire côté serveur.

---

## 📋 Sommaire

- [✨ Aperçu & Fonctionnalités](#-aperçu--fonctionnalités)
- [📁 Structure de la Ressource Unique](#-structure-de-la-ressource-unique)
- [🚀 Installation & Configuration](#-installation--configuration)
- [⚙️ Guide de Configuration Master](#️-guide-de-configuration-master)
- [📚 Documentation API Développeur](#-documentation-api-développeur)
  - [Objet Global `Berry`](#objet-global-berry)
  - [Classe Joueur `Player`](#classe-joueur-player)
  - [Système d'Événements & Callbacks RPC](#système-dévénements--callbacks-rpc)
  - [Système de Sécurité & Rate Limiting](#système-de-sécurité--rate-limiting)
- [📦 Guide des Sous-Systèmes](#-guide-des-sous-systèmes)
  - [1. Multi-Personnages](#1-multi-personnages)
  - [2. Économie & Virements](#2-économie--virements)
  - [3. Métiers & Paychecks](#3-métiers--paychecks)
  - [4. Factions & Entreprises](#4-factions--entreprises)
  - [5. Véhicules & Garages](#5-véhicules--garages)
  - [6. Propriétés & Immobilier](#6-propriétés--immobilier)
  - [7. Commandes Typées & Administration](#7-commandes-typées--administration)
  - [8. Pont de Rétrocompatibilité ESX](#8-pont-de-rétrocompatibilité-esx)
- [🛠️ Comment Étendre & Créer un Module](#️-comment-étendre--créer-un-module)
- [📊 Base de Données & Migrations](#-base-de-données--migrations)
- [📄 Licence](#-licence)

---

## ✨ Aperçu & Fonctionnalités

- **Ressource Unique (`berry-core`)** : Un seul dossier de ressource à charger dans FiveM (`ensure berry-core`).
- **Zéro Boucle CPU Passive (`0.00 ms`)** : 100% Event-Driven. Aucune boucle `while true do Wait(0)` sur le thread principal.
- **Logique Autoritaire Serveur** : Le client ne valide aucune donnée sensible. Contrôle automatique des montants, des permissions et des distances carrées (`CalculateDistanceSqr`).
- **Sauvegarde SQL Ciblée (`MarkDirty`)** : Seules les variables modifiées sont enregistrées en BDD, évitant les surcharges d'I/O SQL.
- **Multi-Personnages Natif** : Prise en charge jusqu'à 4 personnages par compte joueur avec séparation stricte des données.
- **Virements & Audit SQL** : Système financier sécurisé avec enregistrement automatique des transactions dans `berry_transactions`.
- **Rétrocompatibilité ESX** : Inclut un pont de compatibilité transparent (`esx:getSharedObject`, `ESX.GetPlayerFromId`).

---

## 📁 Structure de la Ressource Unique

```text
berry_framework/
├── berry-core/                     # RESSOURCE UNIQUE BERRY FRAMEWORK
│   ├── fxmanifest.lua               # Manifeste maître FiveM
│   ├── shared/                      # Primitives partagées & configuration
│   │   ├── init.lua                 # Initialisation de l'objet Berry
│   │   ├── constants.lua            # Constantes immutables
│   │   ├── config.lua               # Configuration master
│   │   ├── locale.lua               # Système multilingue (fr/en)
│   │   ├── types.lua                # Types et helpers de validation
│   │   └── utilities.lua            # Distances carrées, copies et helpers
│   ├── server/                      # Logique métier serveur
│   │   ├── logger.lua               # Logger structuré [BERRY:CATEGORY]
│   │   ├── database_manager.lua     # Abstraction SQL oxmysql avec profilage
│   │   ├── cache_manager.lua        # Cache mémoire avec expiration TTL
│   │   ├── security_manager.lua     # Rate limiting et validation des payloads
│   │   ├── permission_manager.lua   # Arbre de hiérarchie des permissions
│   │   ├── event_manager.lua        # Wrapper d'événements autoritaires
│   │   ├── callback_manager.lua     # RPCs asynchrones client-serveur
│   │   ├── player_manager.lua       # Classe Joueur Orientée Objet
│   │   ├── state_manager.lua        # Liaison State Bags FiveM
│   │   ├── module_manager.lua       # Chargement ordonné des sous-modules
│   │   ├── characters.lua           # Système multi-personnages
│   │   ├── economy.lua              # Trésorerie et virements bancaires
│   │   ├── jobs.lua                 # Métiers, grades et salaires
│   │   ├── organizations.lua        # Factions, gangs et entreprises
│   │   ├── vehicles.lua             # Propriété et génération de plaques
│   │   ├── properties.lua           # Achat de propriétés et coffres
│   │   ├── admin.lua                # Commandes de modération (/kick, /givemoney)
│   │   ├── devtools.lua             # Profiler CPU/mémoire (/berrystats)
│   │   ├── bridges.lua              # Pont d'émulation ESX
│   │   └── bootstrap.lua            # Démarrage et thread d'auto-sauvegarde
│   └── client/                      # Handlers et wrappers client
│       ├── utilities.lua            # Notifications et utilitaires vector3
│       ├── event_manager.lua        # Événements client
│       ├── callback_manager.lua     # Callbacks client
│       ├── player_manager.lua       # Cache local des données joueur
│       ├── state_manager.lua        # State bags local player
│       ├── characters.lua           # Menu de sélection personnage
│       ├── vehicles.lua             # Menu véhicules possédés
│       └── bootstrap.lua            # Prêt du client
├── config/                          # Exemple de server.cfg
│   └── server.cfg.example
├── migrations/                      # Script d'initialisation BDD
│   └── 001_berry_schema.sql
├── tests/                           # Suite de tests unitaires automatisés
│   └── test_runner.lua
├── docs/                            # Guides techniques et documentation API
│   ├── installation.md
│   └── api.md
├── CHANGELOG.md
├── LICENSE
└── README.md
```

---

## 🚀 Installation & Configuration

### 1. Importer la Base de Données
Importez le fichier de migration SQL dans MariaDB / MySQL :
```bash
migrations/001_berry_schema.sql
```

### 2. Configurer le fichier `server.cfg`
Ajoutez les lignes de démarrage suivantes dans votre `server.cfg` :

```text
# Dépendance BDD
ensure oxmysql

# Noyau Unique Berry Framework
ensure berry-core
```

---

## ⚙️ Guide de Configuration Master

Toute la configuration du framework se trouve dans [berry-core/shared/config.lua](file:///c:/Users/Sariel/Desktop/berry_framework/berry-core/shared/config.lua) :

```lua
BerryConfig = {}

BerryConfig.Framework = {
    Name = "Berry",
    Version = "1.0.0",
    Environment = "development", -- "development", "test", "production"
    LogLevel = "debug",          -- "debug", "info", "warn", "error"
    Locale = "fr"                -- "fr", "en"
}

BerryConfig.Player = {
    MaxCharacters = 4,
    SaveIntervalSeconds = 300,  -- Auto-sauvegarde toutes les 5 minutes
    DefaultMoney = {
        cash = 500,
        bank = 5000,
        black_money = 0
    },
    DefaultSpawn = {
        x = -1037.6,
        y = -2737.8,
        z = 20.1,
        heading = 0.0
    }
}

BerryConfig.Security = {
    EnableRateLimiting = true,
    DefaultRateLimit = {
        maxRequests = 10,
        intervalMs = 1000
    },
    MaxEventDistance = 250.0,
    DropOnViolation = false,
    LogViolations = true
}

BerryConfig.Database = {
    SlowQueryThresholdMs = 100
}
```

---

## 📚 Documentation API Développeur

### Objet Global `Berry`
Dans n'importe quelle ressource, importez le noyau via l'export :
```lua
local Berry = exports["berry-core"]:GetCoreObject()
```

#### Fonctions de Recherche de Joueur
```lua
-- Récupérer un joueur par son ID serveur (source)
local player = Berry.GetPlayer(source)

-- Récupérer par identifiant (license/discord)
local player = Berry.GetPlayerByIdentifier("license:xxxx")

-- Récupérer par ID de personnage SQL
local player = Berry.GetPlayerByCharacterId(12)
```

---

### Classe Joueur `Player`

Lorsqu'un joueur est récupéré avec `Berry.GetPlayer(source)`, vous obtenez une instance de la classe `Player`.

#### Méthodes Informations
```lua
local src = player:GetSource()        --> integer (ex: 1)
local id = player:GetIdentifier()      --> string ("license:...")
local charId = player:GetCharacterId() --> integer (ex: 5)
local name = player:GetName()          --> string ("John Doe")
local pos = player:GetPosition()       --> table {x, y, z, heading}
```

#### Méthodes Financières (Autoritaires)
```lua
-- Consulter le solde d'un compte ("cash", "bank", "black_money")
local cash = player:GetMoney("cash")

-- Ajouter de l'argent (retourne boolean)
local success = player:AddMoney("cash", 500, "mission_reward")

-- Retirer de l'argent (vérifie automatiquement le solde suffisant)
local success = player:RemoveMoney("bank", 250, "vehicle_repair")
```

#### Métiers & Métadonnées
```lua
-- Obtenir le métier actuel
local job = player:GetJob() --> { name="police", grade=2, label="LSPD", ... }

-- Définir un métier
player:SetJob("police", 3)

-- Métadonnées dynamiques
local hunger = player:GetMetadata("hunger")
player:SetMetadata("hunger", 100)
```

#### Sauvegarde Manuelle
```lua
player:MarkDirty("money") -- Marque le champ comme modifié
player:Save()             -- Exécute l'UPDATE SQL de manière ciblée
```

---

### Système d'Événements & Callbacks RPC

#### Événements Serveur Validés
```lua
-- Écouter un événement
Berry.Events.On("player:heal", function(source, targetId)
    local target = Berry.GetPlayer(targetId)
    if target then
        -- Logique de soin
    end
end)

-- Déclencher un événement côté serveur
Berry.Events.Emit("player:heal", targetId)

-- Déclencher un événement vers le client
Berry.Events.EmitClient("notify", source, "Vous avez été soigné !", "success")
```

#### Callbacks RPC (Async)
```lua
-- Côté Serveur : Enregistrer un callback
Berry.Callbacks.Register("berry:getPlayerData", function(source, cb, targetId)
    local player = Berry.GetPlayer(targetId)
    if player then
        cb({ name = player:GetName(), cash = player:GetMoney("cash") })
    else
        cb(nil)
    end
end)

-- Côté Client : Appeler le callback
Berry.Callbacks.Trigger("berry:getPlayerData", function(data)
    if data then
        print("Nom du joueur : " .. data.name)
    end
end, targetId)
```

---

### Système de Sécurité & Rate Limiting

#### Validation de Limitation de Débit (Rate Limiting)
```lua
-- Vérifier si le joueur dépasse 5 appels par 1000ms
if not Berry.Security.CheckRateLimit(source, "craft_item", 5, 1000) then
    return print("Joueur en train de spammer !")
end
```

#### Validation de Distance (Anti-Teleport / Anti-Noclip Abuse)
```lua
local isClose = Berry.Security.ValidateDistance(source, targetPedCoords, 5.0)
if not isClose then
    -- Action suspecte rejetée
    return
end
```

---

## 📦 Guide des Sous-Systèmes

### 1. Multi-Personnages
Géré dans [server/characters.lua](file:///c:/Users/Sariel/Desktop/berry_framework/berry-core/server/characters.lua).
- Permet la création jusqu'à la limite définie dans `BerryConfig.Player.MaxCharacters`.
- Charge automatiquement la position, la faim, la soif et les métadonnées lors de la sélection.

### 2. Économie & Virements
Géré dans [server/economy.lua](file:///c:/Users/Sariel/Desktop/berry_framework/berry-core/server/economy.lua).
- Offre la fonction `BerryEconomy.Transfer(source, targetSource, account, amount, reason)` avec vérifications atomiques et annulation (rollback) en cas d'échec.
- Journalise chaque transfert dans la table SQL `berry_transactions`.

### 3. Métiers & Paychecks
Géré dans [server/jobs.lua](file:///c:/Users/Sariel/Desktop/berry_framework/berry-core/server/jobs.lua).
- Un thread périodique distribue automatiquement les salaires (`paycheck`) sur le compte bancaire toutes les 15 minutes.

### 4. Factions & Entreprises
Géré dans [server/organizations.lua](file:///c:/Users/Sariel/Desktop/berry_framework/berry-core/server/organizations.lua).
- Prise en charge des gangs, factions et entreprises avec comptes bancaires dédiés et rôles de membres.

### 5. Véhicules & Garages
Géré dans [server/vehicles.lua](file:///c:/Users/Sariel/Desktop/berry_framework/berry-core/server/vehicles.lua).
- Génération de plaques d'immatriculation uniques au format `AAA111AA`.
- Sauvegarde du modèle, du garage et de l'état du véhicule.

### 6. Propriétés & Immobilier
Géré dans [server/properties.lua](file:///c:/Users/Sariel/Desktop/berry_framework/berry-core/server/properties.lua).
- Gestion des achats immobiliers avec prélèvement bancaire direct et affectation du personnage propriétaire.

### 7. Commandes Typées & Administration
Géré dans [server/admin.lua](file:///c:/Users/Sariel/Desktop/berry_framework/berry-core/server/admin.lua).
Commandes intégrées :
- `/kick [id] [raison]` : Expulse un joueur (nécessite le rôle `moderator`).
- `/givemoney [id] [compte] [montant]` : Accorde de l'argent (nécessite le rôle `administrator`).
- `/berrystats` : Affiche les métriques serveur et la consommation mémoire du framework.

### 8. Pont de Rétrocompatibilité ESX
Géré dans [server/bridges.lua](file:///c:/Users/Sariel/Desktop/berry_framework/berry-core/server/bridges.lua).
Expose l'événement `esx:getSharedObject` et les fonctions classiques `ESX.GetPlayerFromId(source)`, permettant de faire tourner des scripts tiers prévus pour ESX sans modification.

---

## 🛠️ Comment Étendre & Créer un Module

Pour ajouter une nouvelle fonctionnalité à **Berry Framework**, créez simplement un nouveau fichier dans `berry-core/server/` ou `berry-core/client/` et enregistrez-le dans [berry-core/fxmanifest.lua](file:///c:/Users/Sariel/Desktop/berry_framework/berry-core/fxmanifest.lua).

### Exemple : Ajouter un système de météo personnalisé (`server/weather.lua`)

1. Créez `berry-core/server/weather.lua` :
```lua
local Berry = exports["berry-core"]:GetCoreObject()

local currentSyncWeather = "EXTRASUNNY"

Berry.Events.On("weather:set", function(source, newWeather)
    if Berry.Permissions.Has(source, "admin") then
        currentSyncWeather = newWeather
        TriggerClientEvent("berry:updateWeather", -1, currentSyncWeather)
        Berry.Logger.Info("WEATHER", "Météo modifiée par %d: %s", source, newWeather)
    end
end)
```

2. Ajoutez `'server/weather.lua'` dans la section `server_scripts` du `fxmanifest.lua`.

---

## 📊 Base de Données & Migrations

Le schéma BDD utilise le préfixe `berry_` et comprend les tables suivantes :

| Table SQL | Rôle |
|---|---|
| `berry_accounts` | Racines des comptes identifiants (license, discord) |
| `berry_characters` | Données des personnages (nom, prénom, position, métadonnées) |
| `berry_character_data` | Clés/valeurs additionnelles par personnage |
| `berry_economy_accounts` | Soldes des comptes d'entreprises et d'organisations |
| `berry_jobs` & `berry_job_grades` | Définition des métiers, grades et salaires |
| `berry_organizations` & `members` | Factions, gangs et liste des membres |
| `berry_vehicles` | Véhicules possédés et état des garages |
| `berry_properties` | Propriétés immobilières |
| `berry_transactions` | Journaux d'audit de toutes les opérations financières |
| `berry_bans` & `berry_warnings` | Historique des sanctions administratives |

---

## 📄 Licence

Ce projet est sous licence **MIT**. Vous êtes libre de le modifier et de le redistribuer sur vos serveurs FiveM.

Copyright (c) 2026 **Berry Framework Team**.
