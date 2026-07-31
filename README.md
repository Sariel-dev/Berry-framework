# 🍓 Berry Framework — Master Documentation & Developer Guide

[![FiveM](https://img.shields.io/badge/FiveM-FXServer_Cerulean-purple.svg)](https://fivem.net/)
[![Lua](https://img.shields.io/badge/Lua-5.4-blue.svg)](https://www.lua.org/)
[![Database](https://img.shields.io/badge/Database-oxmysql-orange.svg)](https://github.com/overextended/oxmysql)
[![UI](https://img.shields.io/badge/UI-NUI_F1__Menu_%26_Berry__Notifications-purple.svg)]()
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Performance](https://img.shields.io/badge/Performance-0.00ms_idle-brightgreen.svg)]()

**Berry Framework** est un framework FiveM nouvelle génération, complet, original, ultra-optimisé et sécurisé pour serveurs RP sérieux. Conçu en pure **Lua 5.4**, il est condensé au sein d'une **ressource unique (`berry-core`)** avec une architecture autoritaire côté serveur.

---

## 📋 Sommaire

- [🌟 Présentation & Philosophie](#-présentation--philosophie)
- [📁 Architecture de la Ressource Unique](#-architecture-de-la-ressource-unique)
- [🚀 Guide d'Installation & Démarrage](#-guide-dinstallation--démarrage)
- [⚙️ Configuration Globale (`config.lua`)](#️-configuration-globale-configlua)
- [📚 Documentation API Complète (`Berry` & `Player`)](#-documentation-api-complète-berry--player)
- [🎮 Menu F1 NUI & Notifications Berry UI](#-menu-f1-nui--notifications-berry-ui)
- [📦 Spécifications des Sous-Systèmes Métier](#-spécifications-des-sous-systèmes-métier)
- [🛠️ TUTORIELS & GUIDES D'ADAPTATION (Comment tout modifier)](#️-tutoriels--guides-dadaptation-comment-tout-modifier)
  - [Tuto 1 : Modifier le thème & les couleurs du Menu F1](#tuto-1--modifier-le-thème--les-couleurs-du-menu-f1)
  - [Tuto 2 : Ajouter des boutons ou catégories dans le Menu F1](#tuto-2--ajouter-des-boutons-ou-catégories-dans-le-menu-f1)
  - [Tuto 3 : Créer un nouveau métier avec grades et salaires](#tuto-3--créer-un-nouveau-métier-avec-grades-et-salaires)
  - [Tuto 4 : Brancher un nouvel inventaire dans le framework](#tuto-4--brancher-un-nouvel-inventaire-dans-le-framework)
  - [Tuto 5 : Créer une commande administrative personnalisée](#tuto-5--créer-une-commande-administrative-personnalisée)
  - [Tuto 6 : Déclencher des notifications Berry UI](#tuto-6--déclencher-des-notifications-berry-ui)
- [📊 Référence du Schéma Base de Données (`berry_*`)](#-référence-du-schéma-base-de-données-berry_)
- [🧪 Tests Unitaires & DevTools](#-tests-unitaires--devtools)
- [📄 Licence](#-licence)

---

## 🌟 Présentation & Philosophie

Berry Framework réunit les meilleures approches techniques modernes pour FiveM :

1. **Ressource Unique (`berry-core`)** : Simplification extrême du serveur. Un seul dossier de ressource à déclarer dans votre `server.cfg` (`ensure berry-core`).
2. **Performance First (`0.00 ms`)** : 100% Event-Driven. Aucune boucle `while true do Wait(0)` permanente sur le thread principal client ou serveur.
3. **Sécurité Autoritaire** : Logique serveur 100% autoritaire. Le client ne valide aucun montant, aucune permission et aucune propriété. Validation automatique des distances carrées (`CalculateDistanceSqr`) et rate-limiting par événement.
4. **Sauvegarde Ciblée (`MarkDirty`)** : Seules les variables modifiées lors d'une session sont enregistrées en BDD, évitant les spams et surcharges I/O SQL.

---

## 📁 Architecture de la Ressource Unique

```text
berry_framework/
├── berry-core/                     # RESSOURCE UNIQUE BERRY FRAMEWORK
│   ├── fxmanifest.lua               # Manifeste maître FiveM
│   ├── shared/                      # Primitives partagées & configuration
│   │   ├── init.lua                 # Initialisation du singleton Berry
│   │   ├── constants.lua            # Constantes immutables & rôles
│   │   ├── config.lua               # Configuration globale
│   │   ├── locale.lua               # Système multilingue (fr/en)
│   │   ├── types.lua                # Types et helpers de validation
│   │   └── utilities.lua            # Distances carrées, copies et helpers
│   ├── server/                      # Logique serveur autoritaire
│   │   ├── logger.lua               # Logger structuré [BERRY:CATEGORY]
│   │   ├── database_manager.lua     # Abstraction SQL oxmysql avec profilage
│   │   ├── cache_manager.lua        # Cache mémoire TTL avec expiration
│   │   ├── security_manager.lua     # Rate limiting et validation de distance
│   │   ├── permission_manager.lua   # Arbre de hiérarchie des permissions
│   │   ├── event_manager.lua        # Wrapper d'événements autoritaires
│   │   ├── callback_manager.lua     # RPCs asynchrones client-serveur
│   │   ├── player_manager.lua       # Classe Joueur Orientée Objet
│   │   ├── state_manager.lua        # Liaison State Bags FiveM
│   │   ├── module_manager.lua       # Chargement ordonné des sous-modules
│   │   ├── characters.lua           # Système multi-personnages
│   │   ├── economy.lua              # Trésorerie et virements audités
│   │   ├── jobs.lua                 # Métiers, grades et salaires
│   │   ├── organizations.lua        # Factions, gangs et entreprises
│   │   ├── vehicles.lua             # Propriété et génération de plaques
│   │   ├── properties.lua           # Achat de propriétés et coffres
│   │   ├── admin.lua                # Commandes de modération (/kick, /givemoney)
│   │   ├── devtools.lua             # Profiler CPU/mémoire (/berrystats)
│   │   ├── bridges.lua              # Pont d'émulation ESX
│   │   └── bootstrap.lua            # Démarrage et thread d'auto-sauvegarde
│   ├── client/                      # Logique client
│   │   ├── utilities.lua            # Notifications Berry UI & helpers Vector3
│   │   ├── event_manager.lua        # Événements client
│   │   ├── callback_manager.lua     # Callbacks client
│   │   ├── player_manager.lua       # Cache local des données joueur
│   │   ├── state_manager.lua        # State bags local player
│   │   ├── characters.lua           # Sélection du personnage
│   │   ├── vehicles.lua             # Menu véhicules possédés
│   │   ├── f1menu.lua               # Logique Menu F1 Lua
│   │   └── bootstrap.lua
│   └── ui/                          # Master NUI Frame (F1 Menu + Berry UI)
│       ├── index.html               # Cadre HTML unique
│       ├── style.css                # Style Violet Berry & Notifications
│       └── app.js                   # Moteurs NUI F1 & Notifications
├── config/                          # Exemple de configuration server.cfg
│   └── server.cfg.example
├── migrations/                      # Script SQL d'initialisation
│   └── 001_berry_schema.sql
├── tests/                           # Suite de tests unitaires
│   └── test_runner.lua
├── docs/                            # Documentation complémentaire
│   ├── installation.md
│   ├── api.md
│   └── RELEASE_F1_MENU.md
├── CHANGELOG.md
├── LICENSE
└── README.md
```

---

## 🚀 Guide d'Installation & Démarrage

### 1. Initialiser la Base de Données
Importez le fichier `migrations/001_berry_schema.sql` dans votre serveur MySQL / MariaDB via HeidiSQL ou phpMyAdmin.

### 2. Configurer le `server.cfg`
Déclarez les ressources dans votre `server.cfg` dans cet ordre exact :

```text
# Connecteur Base de Données
ensure oxmysql

# Noyau Unique Berry Framework
ensure berry-core
```

---

## ⚙️ Configuration Globale (`config.lua`)

Le fichier [berry-core/shared/config.lua](file:///c:/Users/Sariel/Desktop/berry_framework/berry-core/shared/config.lua) centralise tous les paramètres du serveur :

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

## 📚 Documentation API Complète (`Berry` & `Player`)

### Importer l'objet Core
Dans tout script client ou serveur :
```lua
local Berry = exports["berry-core"]:GetCoreObject()
```

### Méthodes du Singleton `Berry`
```lua
-- Obtenir l'instance Player par ID serveur (source)
local player = Berry.GetPlayer(source)

-- Obtenir l'instance Player par identifiant (license/discord)
local player = Berry.GetPlayerByIdentifier("license:xxxx")

-- Obtenir l'instance Player par ID de personnage SQL
local player = Berry.GetPlayerByCharacterId(12)
```

### Méthodes de la Classe Joueur `Player`

```lua
-- Informations de base
local src = player:GetSource()        --> integer (ex: 1)
local id = player:GetIdentifier()      --> string ("license:...")
local charId = player:GetCharacterId() --> integer (ex: 5)
local name = player:GetName()          --> string ("John Doe")
local pos = player:GetPosition()       --> table {x, y, z, heading}

-- Gestion Financière (Vérifiée côté serveur)
local cash = player:GetMoney("cash")
local success = player:AddMoney("cash", 500, "mission_reward")
local success = player:RemoveMoney("bank", 250, "achat_magasin")

-- Métiers & Métadonnées
local job = player:GetJob()           --> { name="police", grade=2, label="LSPD", ... }
player:SetJob("police", 3)            -- Change le métier et le grade
local thirst = player:GetMetadata("thirst")
player:SetMetadata("thirst", 100)      -- Définit une métadonnée

-- Sauvegarde Manuelle
player:MarkDirty("money")             -- Marque le champ comme modifié
player:Save()                         -- Effectue l'UPDATE SQL ciblé
```

---

## 🎮 Menu F1 NUI & Notifications Berry UI

### 💜 Menu F1 NUI (Design Flashback / Zeno)
Le Menu F1 de Berry est intégré dans [berry-core/ui/style.css](file:///c:/Users/Sariel/Desktop/berry_framework/berry-core/ui/style.css) et [berry-core/client/f1menu.lua](file:///c:/Users/Sariel/Desktop/berry_framework/berry-core/client/f1menu.lua) :

- **Raccourci** : Touche **`F1`** (Personnalisable dans les options GTA V).
- **Navigation Clavier** : `Z`/`S`, `Flèches Haut/Bas`, `Entrée` (Valider), `Retour Arrière` (Retour/Fermer).
- **Souris** : Support complet du survol et des clics.
- **Thème** : Violet Berry (`#4c1d95` en en-tête, `#6b21a8` sur l'élément sélectionné).

### 🔔 Notifications Berry UI
Intégrées en haut à droite avec barres de décompte animées :
```lua
-- Déclencher une notification
TriggerEvent("berry:notify", "Transaction effectuée avec succès !", "success", 5000, "SUCCÈS", "BANQUE")
```

---

## 🛠️ TUTORIELS & GUIDES D'ADAPTATION (Comment tout modifier)

### Tuto 1 : Modifier le thème & les couleurs du Menu F1
Ouvrez le fichier [berry-core/ui/style.css](file:///c:/Users/Sariel/Desktop/berry_framework/berry-core/ui/style.css).

- **Changer la couleur de l'en-tête** (Ligne ~35) :
  ```css
  .menu-header {
      background: linear-gradient(180deg, #4c1d95 0%, #1e1b4b 100%);
  }
  ```
- **Changer la couleur du bouton sélectionné** (Ligne ~120) :
  ```css
  .menu-item.active {
      background: linear-gradient(90deg, #6b21a8 0%, #3b0764 100%);
      border: 1px solid rgba(192, 132, 252, 0.4);
  }
  ```

---

### Tuto 2 : Ajouter des boutons ou catégories dans le Menu F1
Ouvrez le fichier [berry-core/client/f1menu.lua](file:///c:/Users/Sariel/Desktop/berry_framework/berry-core/client/f1menu.lua).

1. Pour ajouter une catégorie dans le menu principal, modifiez `ShowMainMenu()` (Ligne ~33) :
```lua
local mainItems = {
    { label = "Informations", type = "submenu", menuKey = "info" },
    { label = "Touches du Serveur", type = "submenu", menuKey = "keys" },
    { label = "Commandes du Serveur", type = "submenu", menuKey = "commands" },
    { label = "Animations", type = "submenu", menuKey = "emotes" },
    { label = "Menu Véhicule", type = "submenu", menuKey = "vehicle" },
    { label = "Ma Nouvelle Catégorie", type = "submenu", menuKey = "my_category" } -- NOUVEAU
}
```

2. Ajoutez la sous-section correspondante dans `OpenSubMenu(menuKey)` (Ligne ~45) :
```lua
elseif menuKey == "my_category" then
    local items = {
        { label = "Mon Bouton 1", action = "my_action_1" },
        { label = "Mon Bouton 2", action = "my_action_2" }
    }
    table.insert(currentMenuStack, { title = "MA CATÉGORIE", subtitle = "Options", items = items })
    OpenNuiMenu("MA CATÉGORIE", "Options", items)
```

3. Ajoutez l'action exécutée dans `RegisterNUICallback("selectItem")` (Ligne ~113) :
```lua
elseif item.action == "my_action_1" then
    Berry.ClientUtils.ShowNotification("Vous avez cliqué sur Mon Bouton 1 !", "success")
```

---

### Tuto 3 : Créer un nouveau métier avec grades et salaires
Pour ajouter un métier (ex: `mechanic`), exécutez ces requêtes SQL dans votre base de données :

```sql
-- 1. Créer le métier
INSERT INTO `berry_jobs` (`name`, `label`, `whitelisted`) 
VALUES ('mechanic', 'Mécano Benys', 1);

-- 2. Créer les grades du métier avec leurs salaires (en $)
INSERT INTO `berry_job_grades` (`job_name`, `grade`, `name`, `label`, `salary`) VALUES
('mechanic', 0, 'recrue', 'Apprenti Mécano', 300),
('mechanic', 1, 'mechanic', 'Mécanicien', 450),
('mechanic', 2, 'boss', 'Patron Mécano', 650);
```

Pour attribuer ce métier à un joueur en Lua serveur :
```lua
local player = Berry.GetPlayer(source)
if player then
    player:SetJob("mechanic", 1) -- Assigne le grade 1 (Mécanicien)
end
```

---

### Tuto 4 : Brancher un nouvel inventaire dans le framework
Pour lier un nouvel inventaire au framework Berry :

1. Déclarez votre ressource d'inventaire dans `server.cfg` **avant ou après** `berry-core` selon sa documentation.
2. Si votre inventaire utilise les fonctions ESX (`esx:getSharedObject` ou `ESX.GetPlayerFromId`), le module [berry-core/server/bridges.lua](file:///c:/Users/Sariel/Desktop/berry_framework/berry-core/server/bridges.lua) fait le lien automatiquement.
3. Pour donner un objet à un joueur via votre inventaire dans un script Berry :
```lua
-- Exemple d'appel d'export d'inventaire
exports['votre_inventaire']:AddItem(source, 'water', 1)
```

---

### Tuto 5 : Créer une commande administrative personnalisée
Ouvrez [berry-core/server/admin.lua](file:///c:/Users/Sariel/Desktop/berry_framework/berry-core/server/admin.lua) et ajoutez votre commande :

```lua
-- Commande /setgroup [id] [rôle]
RegisterCommand("setgroup", function(source, args)
    if source > 0 and not Berry.Permissions.Has(source, "superadmin") then
        return TriggerClientEvent("berry:notify", source, "Permission refusée.", "error")
    end

    local targetSrc = tonumber(args[1])
    local role = args[2]

    if targetSrc and role then
        local success = Berry.Permissions.Set(targetSrc, role)
        if success then
            TriggerClientEvent("berry:notify", source, string.format("Rôle %s attribué au joueur %d", role, targetSrc), "success")
        end
    end
end, false)
```

---

### Tuto 6 : Déclencher des notifications Berry UI
Le système de notification prend en charge tous les formats de message.

#### Côté Serveur (Envoyer à un joueur) :
```lua
TriggerClientEvent("berry:notify", source, "Votre véhicule a été rangé au garage.", "info", 5000, "GARAGE", "VÉHICULE")
```

#### Côté Client (Notification locale) :
```lua
Berry.UI.Notify({
    message = "Connexion au serveur établie.",
    type = "success",   -- "success", "error", "warning", "info"
    duration = 4000,
    title = "SUCCÈS",
    subtitle = "SYSTEM"
})
```

---

## 📊 Référence du Schéma Base de Données (`berry_*`)

| Table SQL | Description |
|---|---|
| `berry_accounts` | Racines des comptes identifiants (license, discord) |
| `berry_characters` | Personnages RP (nom, prénom, position, métadonnées JSON) |
| `berry_character_data` | Données complémentaires clé/valeur par personnage |
| `berry_economy_accounts` | Comptes bancaires d'entreprises et d'organisations |
| `berry_jobs` | Registre des métiers |
| `berry_job_grades` | Rangs, intitulés et salaires par métier |
| `berry_organizations` | Factions, gangs et entreprises |
| `berry_organization_members` | Membres et grades au sein d'une organisation |
| `berry_vehicles` | Véhicules possédés, garage d'attache et état |
| `berry_properties` | Propriétés immobilières et prix |
| `berry_transactions` | Audit complet de toutes les transactions financières |
| `berry_bans` & `berry_warnings` | Sanctions et avertissements administratifs |

---

## 🧪 Tests Unitaires & DevTools

### Exécuter les tests unitaires
Pour valider les calculs mathématiques, les types et la hiérarchie des permissions, lancez le fichier [tests/test_runner.lua](file:///c:/Users/Sariel/Desktop/berry_framework/tests/test_runner.lua).

### Commande de Métriques en Jeu
En jeu, tapez la commande d'administration :
```text
/berrystats
```
Affiche le nombre de joueurs actifs et la consommation mémoire RAM du framework en temps réel.

---

## 📄 Licence

Ce projet est sous licence **MIT**. Vous êtes libre de le modifier, de l'adapter et de le redistribuer sur vos serveurs FiveM.

Copyright (c) 2026 **Berry Framework Team**.
