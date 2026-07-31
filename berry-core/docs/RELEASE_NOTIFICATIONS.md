# 🔔 Release Notes — Berry UI Notification Engine (v1.0)

> **Mise à jour majeure** : Déploiement du nouveau moteur de notifications NUI **Berry UI** au style **Glassmorphic Toast**, avec barres de décompte temporel animées et support d'événements multi-frameworks.

---

## 🌟 Points Forts de la Release

- **🎨 Design Toast Glassmorphic** : Cartes visuelles épurées sur fond sombre translucide (`rgba(15, 13, 22, 0.92)`) avec flou d'arrière-plan (`backdrop-filter: blur(16px)`), coins arrondis et ombre portée.
- **🌈 4 Variantes de Status Lumineuses** :
  - 🟢 **Success** : Bordure néon verte (`#22c55e`) & titre vert pastel (`#44ade80`).
  - 🔴 **Error** : Bordure néon rouge (`#ef4444`) & titre rouge pastel (`#f87171`).
  - 🟡 **Warning** : Bordure ambrée (`#f59e0b`) & titre jaune pastel (`#fbbf24`).
  - 🟣 **Info / Inform** : Bordure violette Berry (`#c084fc`) & titre violet pastel (`#c084fc`).
- **⏳ Barre de Décompte Temporel Animée** : Barre de progression dynamique en bas de carte indiquant visuellement le temps restant avant la disparition.
- **⚡ Ultra-Performant (`0.00 ms`)** : Développé en HTML5/CSS3 Vanilla sans dépendance lourde (< 8 KB) et intégré dans le cadre NUI unique du noyau (`ui_page 'ui/index.html'`).
- **🔄 Interception Événementielle Universelle** : Écoute et convertit automatiquement les notifications provenant de n'importe quel script tiers (ESX, ox_lib, QBCore, Berry).

---

## 📌 Spécifications & Exemples API

### 1. Côté Serveur (Lua)
Envoyer une notification visuelle à un joueur ou à tout le serveur :
```lua
-- À un joueur spécifique :
TriggerClientEvent("berry:notify", source, "Votre compte bancaire a été crédité de 1,500$.", "success", 5000, "SUCCÈS", "BANQUE")

-- À tous les joueurs connectés :
TriggerClientEvent("berry:notify", -1, "Le serveur redémarrera dans 15 minutes.", "warning", 10000, "AVERTISSEMENT", "SERVEUR")
```

### 2. Côté Client (Lua)
```lua
-- Via l'API Berry UI :
Berry.UI.Notify({
    title = "GARAGE",
    subtitle = "VÉHICULE",
    message = "Votre véhicule a été sorti du garage avec succès.",
    type = "success",   -- "success", "error", "warning", "info"
    duration = 5000
})

-- Via l'utilitaire rapide :
Berry.ClientUtils.ShowNotification("Action effectuée avec succès.", "success", 3000)
```

### 3. Via les Exports Directs
```lua
-- Export générique Berry :
exports['berry-core']:Notify("Message de notification", "info", 5000, "TITRE", "SOUS-TITRE")

-- Export compatible Volta / Advanced :
exports['berry-core']:addNotification(nil, "TITRE", "Notification", "SUB", "Contenu de la notification", 6000, false, "success")
```

---

## 🔄 Rétrocompatibilité Multi-Frameworks Natifs

Le moteur **Berry UI** intercepte nativement les événements suivants sans nécessiter aucune modification de vos scripts tiers :

- ✅ `berry:notify`
- ✅ `esx:showNotification`
- ✅ `esx:showAdvancedNotification`
- ✅ `ox_lib:notify`
- ✅ `QBCore:Notify` & `QBCore:Client:Notify`

---

## 🛠️ Fichiers Technique

```yaml
Ressource: berry-core
Handler Client: client/utilities.lua
NUI Frame: ui/index.html
Feuille CSS: ui/style.css
Script JS: ui/app.js
Emplacement écran: Top-Right (Haut Droite)
Consommation CPU: 0.00 ms (Idle)
```

---

*Berry Framework v1.0 — Développé pour la performance et l'excellence visuelle.*
