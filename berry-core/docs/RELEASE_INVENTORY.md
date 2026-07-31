# 🎒 Release Notes — Berry Inventory Engine (v2.44 — Berry Edition)

> **Mise à jour majeure** : Intégration, optimisation et synchronisation NUI totale de l'inventaire sous le nom **`berry-inventory`** au sein de la ressource unique **`berry-core`**.

---

## 🌟 Points Forts de la Release

- **💎 Code Source 100% Libre & Open Source (`escrow_ignore`)** : Aucun fichier chiffré. Accès complet et modifications illimitées sur l'intégralité du code client, serveur, modules et NUI.
- **🔄 Synchronisation NUI Intelligente (`berry:ui:closeAll`)** : Gestion de focus NUI parfaitement orchestrée. Si le **Menu F1** s'ouvre, l'inventaire se ferme automatiquement, et inversement, évitant tout conflit de focus ou de superposition d'écrans.
- **🎒 Système par Slots & Poids avec Métadonnées** : Gestion fluide des objets empilables, durabilité des armes, conteneurs, sacs et métadonnées personnalisées.
- **🛠️ Gestionnaire de Craft Avancé (`modules/craftmanager`)** : Tables de fabrication intégrées pour les métiers et activités illégales.
- **👕 Intégration Magasin de Vêtements & Emplacements de Corps** : Icônes d'emplacements personnalisés pour les tenues et accessoires (`web/clothingslotsicons/`).
- **🏥 Système Médical Intégré (`server/medic.lua`)** : Prise en compte des dégâts physiques et de l'état des membres du corps.
- **⚡ Web Build Optimisé (HTML/CSS/JS)** : Interface NUI haute performance avec animations fluides et réactivité instantanée.

---

## 📁 Emplacement dans le Framework

L'inventaire réside dans le sous-dossier `inventory/` de la ressource unique :

```text
berry-core/
└── inventory/                      # MOTEUR BERRY-INVENTORY
    ├── config.lua                   # Configuration principale
    ├── init.lua                     # Initialisation partagée
    ├── client.lua                   # Traitement client & event hooks UI
    ├── server.lua                   # Traitement serveur
    ├── config_loader.lua            # Chargeur de configuration dynamique
    ├── data/                        # Définitions des objets (items.lua, containers.lua)
    ├── modules/                     # Modules supplémentaires (craftmanager, medic, etc.)
    └── web/                         # Build NUI (index.html, CSS, JS, SVG, images)
```

---

## 📌 Guide d'Utilisation API & Exports

### Côté Serveur (Lua)

```lua
-- Ajouter un objet dans l'inventaire d'un joueur
exports['berry-core']:AddItem(source, 'water', 2)

-- Retirer un objet
exports['berry-core']:RemoveItem(source, 'bread', 1)

-- Vérifier si un joueur possède un objet
local count = exports['berry-core']:GetItemCount(source, 'phone')
if count > 0 then
    -- Le joueur possède au moins 1 téléphone
end

-- Récupérer le contenu complet de l'inventaire
local inventory = exports['berry-core']:GetInventory(source)
```

### Côté Client (Lua)

```lua
-- Ouvrir l'inventaire
TriggerEvent('ox_inventory:openInventory')

-- Fermer l'inventaire
TriggerEvent('ox_inventory:closeInventory')

-- Utiliser un objet
TriggerServerEvent('ox_inventory:useItem', item)
```

---

## ⚙️ Comment Personnaliser la Configuration

1. **Modifier les Objets & Poids** :
   Ouvrez [berry-core/inventory/data/items.lua](file:///c:/Users/Sariel/Desktop/berry_framework/berry-core/inventory/data/items.lua) pour ajouter ou modifier des objets, leur poids, leur rareté ou leur icône.

2. **Modifier la Configuration Générale** :
   Ouvrez [berry-core/inventory/config.lua](file:///c:/Users/Sariel/Desktop/berry_framework/berry-core/inventory/config.lua) pour ajuster les touches par défaut, le poids maximal des joueurs et les règles de lâcher d'objets au sol.

---

## 🛠️ Spécifications Techniques

```yaml
Ressource: berry-core
Sous-dossier: inventory/
UI Frame: inventory/web/build/index.html
Synchronisation NUI: Evénement global berry:ui:closeAll
Licence: GPL-3.0 / Open Source
Préréquis: oxmysql, ox_lib
```

---

*Berry Framework v1.0 — Développé pour la performance et l'excellence visuelle.*
