# 🍓 Berry Framework — Documentation Maître & Guide Développeur Complet

[![FiveM](https://img.shields.io/badge/FiveM-FXServer_Cerulean-purple.svg)](https://fivem.net/)
[![Lua](https://img.shields.io/badge/Lua-5.4_Generational_GC-blue.svg)](https://www.lua.org/)
[![Database](https://img.shields.io/badge/Database-oxmysql-orange.svg)](https://github.com/overextended/oxmysql)
[![UI](https://img.shields.io/badge/UI-Master_Single_HTML_Frame-purple.svg)]()
[![Performance](https://img.shields.io/badge/Performance-0.00ms_idle-brightgreen.svg)]()
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

**Berry Framework** est un framework FiveM de nouvelle génération, ultra-rapide, modulaire et sécurisé pour serveurs Roleplay. Conçu en pure **Lua 5.4**, il réunit la totalité de sa logique au sein d'une **ressource unique (`berry-core`)** avec un cadre HTML maître unique (`ui/index.html`).

---

## 📋 Sommaire

- [🌟 Présentation & Philosophie](#-présentation--philosophie)
- [📁 Architecture de la Ressource Unique (`berry-core`)](#-architecture-de-la-ressource-unique-berry-core)
- [🚀 Guide d'Installation & Démarrage Rapide](#-guide-dinstallation--démarrage-rapide)
- [🛠️ TUTORIELS & GUIDES DE MODIFICATION PAS À PAS](#️-tutoriels--guides-de-modification-pas-à-pas)
  - [1. Configurer les Rôles Admin & la Commande /setgroup](#1-configurer-les-rôles-admin--la-commande-setgroup)
  - [2. Configurer les Logs Discord Webhooks](#2-configurer-les-logs-discord-webhooks)
  - [3. Ajouter ou Modifier un Item dans l'Inventaire](#3-ajouter-ou-modifier-un-item-dans-linventaire)
  - [4. Créer ou Modifier un Métier & ses Grades](#4-créer-ou-modifier-un-métier--ses-grades)
  - [5. Ajouter et Configurer une Propriété / Maison](#5-ajouter-et-configurer-une-propriété--maison)
  - [6. Ajouter des Options & Boutons dans le Menu F1](#6-ajouter-des-options--boutons-dans-le-menu-f1)
  - [7. Ajouter des Actions Contextuelles au Clic Droit / ALT](#7-ajouter-des-actions-contextuelles-au-clic-droit--alt)
  - [8. Déclencher les Notifications Toast & la Barre de Progression](#8-déclencher-les-notifications-toast--la-barre-de-progression)
  - [9. Régler le Moteur Anti-Cheat](#9-régler-le-moteur-anti-cheat)
  - [10. Ajouter une Animation ou un Prop 3D Personnalisé](#10-ajouter-une-animation-ou-un-prop-3d-personnalisé)
- [📚 Documentation des APIs Serveur & Client](#-documentation-des-apis-serveur--client)
- [📊 Schéma Base de Données (`berry_*`)](#-schéma-base-de-données-berry_)
- [📄 Licence](#-licence)

---

## 📁 Architecture de la Ressource Unique (`berry-core`)

```text
berry-core/                           # DOSSIER RESSOURCE UNIQUE ALL-IN-ONE
├── fxmanifest.lua                     # Manifeste FiveM maître (1 seule ui_page)
├── README.md                          # Documentation développeur
├── CHANGELOG.md                       # Historique des versions
├── LICENSE                            # Licence MIT
│
├── shared/                            # Primitives partagées & configuration
│   ├── init.lua                       # Initialisation du singleton Berry
│   ├── constants.lua                  # Rôles admin (Fondateur, Co-Fondateur, Admin, Mod, Helper, Citoyen)
│   ├── config.lua                     # Configuration globale & Liens Webhooks Discord
│   ├── locale.lua                     # Système multilingue (fr/en)
│   ├── types.lua                      # Types et helpers de validation
│   └── utilities.lua                  # Distances carrées, copies et helpers
│
├── server/                            # Logique serveur autoritaire
│   ├── logger.lua                     # Logger structuré [BERRY:CATEGORY]
│   ├── discord_logger.lua             # Moteur de Logs Discord Webhooks
│   ├── database_manager.lua           # Abstraction SQL oxmysql avec profilage
│   ├── cache_manager.lua              # Cache mémoire TTL avec expiration
│   ├── security_manager.lua           # Rate limiting et validation de distance
│   ├── permission_manager.lua         # Gestionnaire de rangs & /setgroup
│   ├── anticheat.lua                  # AntiCheat autoritaire (Speed, Weapons, EntitySpam)
│   ├── event_manager.lua              # Wrapper d'événements autoritaires
│   ├── callback_manager.lua           # RPCs asynchrones client-serveur
│   ├── player_manager.lua             # Classe Joueur Orientée Objet
│   ├── state_manager.lua              # Liaison State Bags FiveM
│   ├── module_manager.lua             # Chargement ordonné des sous-modules
│   ├── characters.lua                 # Système multi-personnages (jusqu'à 4 perso)
│   ├── economy.lua                    # Trésorerie et virements audités
│   ├── jobs.lua                       # Métiers, grades et salaires
│   ├── organizations.lua              # Factions, gangs et entreprises
│   ├── vehicles.lua                   # Propriété et génération de plaques
│   ├── properties.lua                 # Achat de propriétés, clés & coffres
│   ├── police_ems.lua                 # Commandes menottage, escorte, réanimation
│   ├── interim.lua                    # Missions de livraison débutants
│   ├── admin.lua                      # Commandes de modération (/kick, /givemoney)
│   ├── devtools.lua                   # Profiler CPU/mémoire (/berrystats)
│   ├── bridges.lua                    # Pont d'émulation ESX
│   └── bootstrap.lua                  # Démarrage et Generational GC Lua 5.4
│
├── client/                            # Logique client
│   ├── utilities.lua                  # Notifications Berry UI, Progress Bar & 3D text
│   ├── event_manager.lua              # Événements client
│   ├── callback_manager.lua           # Callbacks client
│   ├── player_manager.lua             # Cache local des données joueur
│   ├── state_manager.lua              # State bags local player
│   ├── characters.lua                 # Menu de sélection du personnage
│   ├── vehicles.lua                   # Menu des véhicules possédés
│   ├── vehicle_realism.lua            # Pannes moteur & réparations
│   ├── emotes.lua                     # Moteur d'animations & attachement d'objets 3D
│   ├── properties.lua                 # Markers d'entrée/sortie/coffre (0.00ms)
│   ├── police_ems.lua                 # Animations menottes, escorte, soignages
│   ├── interim.lua                    # Marqueurs Pôle Emploi et trajets GPS
│   ├── density.lua                    # Régulation densité PNJ et trafic
│   ├── f1menu.lua                     # Logique du Menu F1 NUI Violet
│   ├── markers.lua                    # Spatial Hashing 100m² chunking (0.00ms)
│   ├── minigames.lua                  # Crochetage de coffre et câbles
│   ├── anticheat.lua                  # Immunité au spawn et détections
│   └── bootstrap.lua                  # Initialisation client Lua 5.4
│
├── ui/                                # Master NUI Frame (F1 + Inventaire + ContextMenu)
│   ├── index.html                     # 1 Seul Fichier HTML maître pour toute la suite NUI
│   ├── preview.html                   # Prévisualisation dynamique pour navigateur
│   ├── style.css                      # Style Violet Berry & Notifications Toast
│   └── app.js                         # Moteur JS principal (F1, Progress Bar, Notifs)
│
├── contextmenu/                       # Moteur ContextMenu V6 (Clic Droit / ALT)
│   ├── example/player.lua             # Actions sur les personnages (Fouiller, Menotter)
│   ├── example/vehicle.lua            # Actions sur véhicules (Moteur, Coffre, Câbles)
│   └── html/                          # CSS/JS intégrés dans ui/index.html
│
├── inventory/                         # Moteur Berry Inventory (Grid & Metadata)
│   ├── config.lua                     # Configuration des poids et slots
│   ├── init.lua                       # Moteur principal d'inventaire
│   ├── client.lua / server.lua
│   ├── data/items.lua                 # Déclarations des objets
│   └── web/                           # Build React monté dans ui/index.html
│
└── sql/                               # Migration SQL initialisation BDD
    └── 001_berry_schema.sql
```

---

## 🚀 Guide d'Installation & Démarrage Rapide

### 1. Initialiser la Base de Données
Importez le fichier **`berry-core/sql/001_berry_schema.sql`** dans votre serveur MySQL ou MariaDB via HeidiSQL ou phpMyAdmin.

### 2. Configurer le `server.cfg`
Ajoutez les ressources suivantes dans votre `server.cfg` :

```text
# Connecteur SQL & Utilitaires
ensure oxmysql
ensure ox_lib

# Ressource Unique Berry Framework
ensure berry-core
```

---

## 🛠️ TUTORIELS & GUIDES DE MODIFICATION PAS À PAS

### 1. Configurer les Rôles Admin & la Commande `/setgroup`

Berry Framework intègre une hiérarchie de permissions en français :

| Rôle | Nom de la Commande | Niveau |
| :--- | :--- | :---: |
| 👑 **Fondateur** | `fondateur` | **5** |
| 🛡️ **Co-Fondateur** | `co_fondateur` | **4** |
| ⚡ **Administrateur** | `administrateur` | **3** |
| 🔨 **Modérateur** | `moderateur` | **2** |
| 🤝 **Helper** | `helper` | **1** |
| 👤 **Citoyen** | `citoyen` | **0** |

#### Changer le groupe d'un joueur en jeu :
```text
/setgroup [ID_JOUEUR] [fondateur | co_fondateur | administrateur | moderateur | helper | citoyen]

# Exemple :
/setgroup 1 fondateur
```

---

### 2. Configurer les Logs Discord Webhooks

Le moteur de logs **`berry-core/server/discord_logger.lua`** envoie automatiquement des cartes Embeds colorées à Discord.

#### Ajouter vos Webhooks dans `berry-core/shared/config.lua` :
```lua
BerryConfig.DiscordWebhooks = {
    Enabled = true,
    ServerName = "Berry Roleplay",
    
    Webhooks = {
        AntiCheat   = "https://discord.com/api/webhooks/VOICE_WEBHOOK_URL",
        SetGroup    = "https://discord.com/api/webhooks/VOICE_WEBHOOK_URL",
        Admin       = "https://discord.com/api/webhooks/VOICE_WEBHOOK_URL",
        Economy     = "https://discord.com/api/webhooks/VOICE_WEBHOOK_URL",
        Inventory   = "https://discord.com/api/webhooks/VOICE_WEBHOOK_URL",
        Properties  = "https://discord.com/api/webhooks/VOICE_WEBHOOK_URL",
        Connections = "https://discord.com/api/webhooks/VOICE_WEBHOOK_URL"
    }
}
```

---

### 3. Ajouter ou Modifier un Item dans l'Inventaire

Tous les items sont déclarés dans **`berry-core/inventory/data/items.lua`**.

#### Exemple d'ajout d'un item usable (Ex: Bouteille d'Eau) :
```lua
['water'] = {
    label = 'Bouteille d\'Eau',
    weight = 250,
    stack = true,
    close = true,
    description = 'Une bouteille d\'eau fraîche qui étanche votre soif.'
}
```

---

### 4. Créer ou Modifier un Métier & ses Grades

Les métiers sont gérés dans la base de données SQL (`berry_jobs` et `berry_job_grades`).

```sql
-- 1. Insérer le métier
INSERT INTO `berry_jobs` (`name`, `label`, `whitelisted`) VALUES ('mechanic', 'Mécano', 1);

-- 2. Insérer les grades
INSERT INTO `berry_job_grades` (`job_name`, `grade`, `name`, `label`, `salary`) VALUES
('mechanic', 0, 'recrue', 'Apprenti Mécano', 350),
('mechanic', 1, 'mecano', 'Mécanicien Qualifié', 550),
('mechanic', 2, 'patron', 'Patron Garage', 850);
```

---

### 5. Ajouter et Configurer une Propriété / Maison

Les logements sont gérés par **`berry-core/server/properties.lua`**.

```sql
INSERT INTO `berry_properties` (`name`, `label`, `price`, `entry_coords`, `exit_coords`, `storage_coords`) VALUES
(
    'villa_vinewood',
    'Villa Vinewood Hills',
    450000,
    '{"x": -266.3, "y": -961.1, "z": 31.2, "h": 180.0}',
    '{"x": 347.0, "y": -999.2, "z": -99.2, "h": 90.0}',
    '{"x": 351.2, "y": -998.1, "z": -99.2}'
);
```

---

### 6. Ajouter des Options & Boutons dans le Menu F1

Le Menu F1 NUI est géré dans **`berry-core/client/f1menu.lua`**.

```lua
-- Dans client/f1menu.lua :
elseif menuKey == "my_custom_menu" then
    local items = {
        { label = "Mon Action 1", action = "my_action_1" },
        { label = "Mon Action 2", action = "my_action_2", value = "Option" }
    }
    table.insert(currentMenuStack, { title = "MON MENU", subtitle = "Mes Options", items = items })
    OpenNuiMenu("MON MENU", "Mes Options", items)
end
```

---

### 7. Ajouter des Actions Contextuelles au Clic Droit / ALT

Le **ContextMenu** écoute les entités sous le curseur dans **`berry-core/contextmenu/example/`**.

#### Action lors du clic droit sur un Joueur (`contextmenu/example/player.lua`) :
```lua
local btn_custom = ECM:AddItem(0, "Donner un cadeau")
ECM:LeftIcon(btn_custom, "fa-solid fa-gift")
ECM:OnActivate(btn_custom, function()
    print("Cadeau donné au joueur ID: " .. targetServerId)
end)
```

---

### 8. Déclencher les Notifications Toast & la Barre de Progression

#### Notification Toast NUI :
```lua
Berry.UI.Notify({ title = "SUCCÈS", message = "Opération réussie !", type = "success", duration = 4000 })
```

#### Barre de Progression NUI animée :
```lua
Berry.UI.ProgressBar("Réparation en cours...", 5000, function()
    print("Réparation terminée !")
end)
```

---

### 9. Régler le Moteur Anti-Cheat

L'Anti-Cheat autoritaire est dans **`berry-core/server/anticheat.lua`**.

```lua
-- Accorder 10 secondes d'immunité temporaire :
exports['berry-core']:ExtendGrace(source, 10000)

-- Bannir un joueur manuellement avec log Discord :
exports['berry-core']:BanPlayer(source, "Triche détectée")
```

---

### 10. Ajouter une Animation ou un Prop 3D Personnalisé

Le moteur d'animation est géré dans **`berry-core/client/emotes.lua`**.

```lua
exports['berry-core']:PlayEmote(
    "amb@world_human_drinking@beer@female@idle_a",
    "idle_e",
    "prop_amb_beer_bottle",
    28422
)
```

---

## 📄 Licence

Ce projet est sous licence **MIT**. Vous êtes 100% libre de le modifier, de le redistribuer et de l'utiliser sur vos serveurs FiveM.

Copyright (c) 2026 **Berry Framework Team**.
