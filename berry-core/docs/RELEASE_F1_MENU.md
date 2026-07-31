# 🚀 Release Notes — Berry F1 NUI Menu Engine (v1.0)

> **Mise à jour majeure** : Intégration du moteur de menu NUI F1 au design **Berry NUI**, adapté au thème **Violet Berry** et prêt pour la production.

---

## 🌟 Points Forts de la Release

- **🎨 Design Premium Glassmorphic** : Structure épurée avec bannière dégradée bordeaux/violet (`#4c1d95` ➔ `#1e1b4b`), bordure d'accent violet néon (`#c084fc`) et barre de sélection lumineuse (`#6b21a8`).
- **⚡ Ultra-Performant (`0.00 ms`)** : Développé en HTML5/CSS3 Vanilla (sans dépendance lourde, < 10 KB) et géré par un thread Lua 5.4 100% Event-Driven.
- **🎮 Navigation Hybride Intuitives** : Support simultané des touches clavier (`F1`, `Z/S`, `Flèches`, `Entrée`, `Retour Arrière`) et des clics/survol à la souris.
- **🔊 Feedback Sonore Natif** : Intégration des effets sonores front-end FiveM (`PlaySoundFrontend`) lors des déplacements et validations.

---

## 📌 Fonctionnalités & Catégories Intégrées

| Catégorie | Description & Actions |
|---|---|
| 👤 **Informations** | Synchronisation en temps réel avec les données du joueur (`Berry.GetPlayerData()`) : Nom, Prénom, Métier, Portefeuille, Banque, ID Serveur. |
| ⌨️ **Touches du Serveur** | Guide des raccourcis claviers principaux du serveur (`[F1] Menu`, `[F2] Inventaire`, `[T] Tchat`, `[E] Interaction`). |
| 💬 **Commandes du Serveur** | Déclencheur rapide de commandes RP et utilitaires (`/myvehicles`, `/me`, `/do`, `/report`). |
| 🕺 **Animations / Emotes** | Menu d'émotes express (Saluer, S'asseoir, Croiser les bras, Danser, Annuler animation). |
| 🚗 **Menu Véhicule** | Gestion des interactions véhicule en direct (Allumer/Éteindre moteur, Verrouiller/Déverrouiller portes, Ouvrir capot, Ouvrir coffre). |

---

## 🛠️ Spécifications Techniques

```yaml
Ressource: berry-core
Module Client: client/f1menu.lua
UI Frame: ui/index.html (Master NUI Frame)
Stylesheet: ui/style.css
Script JS: ui/app.js
Touche par défaut: F1 (RegisterKeyMapping 'berryf1menu')
Consommation CPU: 0.00 ms (Idle) / 0.01 ms (Ouvert)
```

---

*Berry Framework v1.0 — Développé pour la performance et l'excellence visuelle.*
