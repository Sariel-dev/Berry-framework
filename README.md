# 🍓 Berry Framework — FiveM Roleplay Engine

[![FiveM](https://img.shields.io/badge/FiveM-FXServer_Cerulean-purple.svg)](https://fivem.net/)
[![Lua](https://img.shields.io/badge/Lua-5.4-blue.svg)](https://www.lua.org/)
[![Database](https://img.shields.io/badge/Database-oxmysql-orange.svg)](https://github.com/overextended/oxmysql)
[![UI](https://img.shields.io/badge/UI-NUI_F1__Menu_%26_Volta__Notifications-purple.svg)]()
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Performance](https://img.shields.io/badge/Performance-0.00ms_idle-brightgreen.svg)]()

**Berry Framework** est un framework FiveM nouvelle génération, complet, original, ultra-optimisé et sécurisé pour serveurs RP sérieux. Conçu en pure **Lua 5.4**, il est condensé au sein d'une **ressource unique (`berry-core`)** avec une architecture autoritaire côté serveur.

---

## 📋 Sommaire

- [✨ Aperçu & Fonctionnalités](#-aperçu--fonctionnalités)
- [🎮 Menu F1 NUI & Notifications Volta-UI](#-menu-f1-nui--notifications-volta-ui)
- [📁 Structure de la Ressource Unique](#-structure-de-la-ressource-unique)
- [🚀 Installation & Configuration](#-installation--configuration)
- [⚙️ Guide de Configuration Master](#️-guide-de-configuration-master)
- [📚 Documentation API Développeur](#-documentation-api-développeur)
- [📦 Guide des Sous-Systèmes](#-guide-des-sous-systèmes)
- [📄 Licence](#-licence)

---

## ✨ Aperçu & Fonctionnalités

- **Ressource Unique (`berry-core`)** : Un seul dossier de ressource à charger dans FiveM (`ensure berry-core`).
- **Zéro Boucle CPU Passive (`0.00 ms`)** : 100% Event-Driven. Aucune boucle `while true do Wait(0)` sur le thread principal.
- **Logique Autoritaire Serveur** : Le client ne valide aucune donnée sensible. Contrôle automatique des montants, des permissions et des distances carrées (`CalculateDistanceSqr`).
- **Sauvegarde SQL Ciblée (`MarkDirty`)** : Seules les variables modifiées sont enregistrées en BDD.
- **Multi-Personnages Natif** : Prise en charge jusqu'à 4 personnages par compte joueur avec séparation stricte des données.
- **Menu F1 NUI Style Flashback / Zeno** : Interface NUI ultra-fluide au thème Violet Berry.
- **Système de Notifications Volta-UI** : Toast notifications en verre translucide avec barre de décompte animée.

---

## 🎮 Menu F1 NUI & Notifications Volta-UI

### 💜 Menu F1 NUI (Design Flashback / Zeno)
Inspiré par les meilleures interfaces NUI communautaires, le menu F1 NUI de Berry Framework combine vitesse d'exécution et esthétique premium :

#### 🎨 Style & Design
- **Bannière d'En-Tête Violet Berry** : Gradient violet profond (`linear-gradient(180deg, #4c1d95 0%, #1e1b4b 100%)`) avec typographie bold `BERRY`.
- **Barre de Statut & Compteur** : Affichage dynamique de la section courante (`Actions`) et décompte des éléments (`1/5`).
- **Châssis Glassmorphic** : Arrière-plan sombre translucide avec flou d'arrière-plan (`backdrop-filter: blur(14px)`).
- **Sélection Active Lumineuse** : Surbrillance violette dégradée (`#6b21a8` -> `#3b0764`) avec bordure violette néon et ombre projetée.

#### 🛠️ Technologies
- **Front-End** : HTML5, CSS3 Vanilla (sans framework externe pour un poids < 10 KB), JavaScript ES6.
- **Back-End Client** : Handler client Lua 5.4 (`berry-core/client/f1menu.lua`).
- **Contrôles Hybrides** : Support complet **Clavier** (`Z/S`, `Flèches`, `Entrée`, `Retour Arrière`) + **Souris** (clics & survol).
- **Effets Sonores Native** : Rétroaction sonore FiveM (`PlaySoundFrontend`) lors des déplacements et sélections.

#### 📌 Catégories Intégrées
1. 👤 **Informations** : Synchronisation en direct avec `Berry.GetPlayerData()` (Nom, Métier, Portefeuille, Banque, ID Serveur).
2. ⌨️ **Touches du Serveur** : Raccourcis claviers principaux (`[F1] Menu`, `[F2] Inventaire`, `[T] Tchat`, `[E] Interaction`).
3. 💬 **Commandes du Serveur** : Accès rapide aux commandes (`/myvehicles`, `/me`, `/do`, `/report`).
4. 🕺 **Animations** : Emotes intégrées (Saluer, S'asseoir, Croiser les bras, Danser, Annuler animation).
5. 🚗 **Menu Véhicule** : Gestion véhicule (Moteur On/Off, Verrouillage portes, Capot, Coffre).

---

### 🔔 Notifications Volta-UI
- **Toast Cards Glassmorphic** : Alignées en haut à droite avec coins arrondis et ombre portée.
- **Accents de Bordure par Variante** :
  - 🟢 `success` : Vert néon (`#22c55e`)
  - 🔴 `error` : Rouge néon (`#ef4444`)
  - 🟡 `warning` : Orange ambré (`#f59e0b`)
  - 🟣 `info` / `inform` : Violet Berry (`#c084fc`)
- **Barre de Décompte Temporel** : Animation CSS `transition` réduisant la barre de progression selon la durée configurée.
- **Support Multi-Frameworks** : Écoute nativement `berry:notify`, `esx:showNotification`, `ox_lib:notify` et `QBCore:Notify`.

---

## 📁 Structure de la Ressource Unique

```text
berry_framework/
├── berry-core/                     # RESSOURCE UNIQUE BERRY FRAMEWORK
│   ├── fxmanifest.lua               # Manifeste maître FiveM
│   ├── shared/                      # Primitives partagées & configuration
│   │   ├── init.lua
│   │   ├── constants.lua
│   │   ├── config.lua
│   │   ├── locale.lua
│   │   ├── types.lua
│   │   └── utilities.lua
│   ├── server/                      # Logique métier serveur
│   │   ├── logger.lua
│   │   ├── database_manager.lua
│   │   ├── cache_manager.lua
│   │   ├── security_manager.lua
│   │   ├── permission_manager.lua
│   │   ├── event_manager.lua
│   │   ├── callback_manager.lua
│   │   ├── player_manager.lua
│   │   ├── state_manager.lua
│   │   ├── module_manager.lua
│   │   ├── characters.lua
│   │   ├── economy.lua
│   │   ├── jobs.lua
│   │   ├── organizations.lua
│   │   ├── vehicles.lua
│   │   ├── properties.lua
│   │   ├── admin.lua
│   │   ├── devtools.lua
│   │   ├── bridges.lua
│   │   └── bootstrap.lua
│   ├── client/                      # Handlers client & F1 menu
│   │   ├── utilities.lua            # Notifications Volta-UI
│   │   ├── event_manager.lua
│   │   ├── callback_manager.lua
│   │   ├── player_manager.lua
│   │   ├── state_manager.lua
│   │   ├── characters.lua
│   │   ├── vehicles.lua
│   │   ├── f1menu.lua               # Logique Menu F1 Lua
│   │   └── bootstrap.lua
│   └── ui/                          # Master NUI Frame (F1 Menu + Volta UI)
│       ├── index.html
│       ├── style.css                # Style Violet Berry & Notifications
│       └── app.js                   # Moteurs NUI F1 & Notifications
```

---

## 🚀 Installation & Configuration

### 1. Importer la Base de Données
Importez le fichier de migration SQL dans MariaDB / MySQL :
```bash
migrations/001_berry_schema.sql
```

### 2. Configurer le fichier `server.cfg`
```text
ensure oxmysql
ensure berry-core
```

---

## 📄 Licence

Ce projet est sous licence **MIT**. Vous êtes libre de le modifier et de le redistribuer sur vos serveurs FiveM.

Copyright (c) 2026 **Berry Framework Team**.
