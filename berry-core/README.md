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
  - [1. Configurer la Présence Discord (Discord Rich Presence)](#1-configurer-la-présence-discord-discord-rich-presence)
  - [2. Configurer les Rôles Admin & la Commande /setgroup](#2-configurer-les-rôles-admin--la-commande-setgroup)
  - [3. Configurer les Logs Discord Webhooks](#3-configurer-les-logs-discord-webhooks)
  - [4. Ajouter ou Modifier un Item dans l'Inventaire](#4-ajouter-ou-modifier-un-item-dans-linventaire)
  - [5. Créer ou Modifier un Métier & ses Grades](#5-créer-ou-modifier-un-métier--ses-grades)
  - [6. Ajouter et Configurer une Propriété / Maison](#6-ajouter-et-configurer-une-propriété--maison)
  - [7. Ajouter des Options & Boutons dans le Menu F1](#7-ajouter-des-options--boutons-dans-le-menu-f1)
  - [8. Ajouter des Actions Contextuelles au Clic Droit / ALT](#8-ajouter-des-actions-contextuelles-au-clic-droit--alt)
  - [9. Déclencher les Notifications Toast & la Barre de Progression](#9-déclencher-les-notifications-toast--la-barre-de-progression)
  - [10. Régler le Moteur Anti-Cheat](#10-régler-le-moteur-anti-cheat)
  - [11. Ajouter une Animation ou un Prop 3D Personnalisé](#11-ajouter-une-animation-ou-un-prop-3d-personnalisé)
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
│   ├── config.lua                     # Config Discord RPC, Webhooks & Paramètres
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
│   ├── rich_presence.lua              # Moteur Discord Rich Presence
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

## 🛠️ TUTORIELS & GUIDES DE MODIFICATION PAS À PAS

### 1. Configurer la Présence Discord (Discord Rich Presence)

La présence Discord affiche le statut dynamique de vos joueurs dans Discord quand ils jouent sur votre serveur.

#### Configuration dans `berry-core/shared/config.lua` :
```lua
BerryConfig.DiscordRichPresence = {
    Enabled = true,
    AppId = "1234567890123456789",  -- ID de votre application Discord Developer Portal
    AssetLogo = "berry_logo",        -- Nom du logo téléchargé sur Discord Portal
    AssetLogoText = "Berry Framework RP",
    AssetSmall = "player_icon",
    AssetSmallText = "En Jeu",
    UpdateIntervalMs = 15000,        -- Intervalle de mise à jour (15 secondes)
    Buttons = {
        { label = "Rejoindre le Discord", url = "https://discord.gg/berry" }
    }
}
```

---

## 📄 Licence

Ce projet est sous licence **MIT**. Vous êtes 100% libre de le modifier, de le redistribuer et de l'utiliser sur vos serveurs FiveM.

Copyright (c) 2026 **Berry Framework Team**.
