# Journal des Modifications — Berry Framework

Toutes les modifications notables apportées au **Berry Framework** sont documentées dans ce fichier.

## [1.0.0] - 2026-07-31

### Nouveautés & Ajouts

- **Moteur Discord Rich Presence (`berry-core/client/rich_presence.lua` & `berry-core/shared/config.lua`)** : Système de présence Discord dynamique affichant le nom du personnage, l'ID serveur, le métier, l'icône personnalisée, le nom du serveur et un bouton de redirection Discord.
- **Moteur de Logs Discord Webhooks (`berry-core/server/discord_logger.lua`)** : Système complet de journalisation vers Discord avec cartes Embeds stylisées (couleurs par catégorie, date/heure, licence, ID Discord, exécuteur et cible). Automatiquement connecté à l'Anti-Cheat, au changement de rang `/setgroup`, aux commandes Staff, à l'économie, aux connexions/déconnexions et aux achats immobiliers.
- **Hiérarchie des Rôles Admin & Commande `/setgroup` (`berry-core/server/permission_manager.lua`)** : Configuration de la hiérarchie des permissions avec les rôles français natifs : `fondateur` (Niveau 5), `co_fondateur` (Niveau 4), `administrateur` (Niveau 3), `moderateur` (Niveau 2), `helper` (Niveau 1) et `citoyen` (Niveau 0). Commande `/setgroup [ID] [GROUPE]` autoritaire.
- **Moteur de Menu Contexte Clic Droit / ALT (`berry-core/contextmenu/`)** : Intégration complète du **ContextMenu** synchronisé avec `berry-core`. Interactions contextuelles 3D sur joueurs (Fouiller, Menotter, Escorter, Mettre/Sortir du véhicule, Réanimer) et véhicules (Verrouiller, Moteur, Coffre inventaire, Capot, Démarrage aux câbles, Supprimer).
- **Système d'Urgences & Police/EMS (`berry-core/client/police_ems.lua` & `berry-core/server/police_ems.lua`)** : Mécaniques de menottage (`/cuff`), d'escorte (`/escort`), mise dans le véhicule (`/putinveh`), sortie de véhicule (`/outveh`), réanimation médicale (`/revive`) et soignages (`/heal`).
- **Système de Métiers d'Intérim Débutant (`berry-core/client/interim.lua` & `berry-core/server/interim.lua`)** : Missions de livraisons de colis au Pôle Emploi avec itinéraires GPS automatiques, marqueurs de livraison et paie en argent liquide.
- **Moteur de Réalisme & Panne Véhicule (`berry-core/client/vehicle_realism.lua`)** : Dégradation du moteur en cas de collision, coupure du moteur en dessous de 250 de santé et kit de réparation (`berry:vehicle:repair`).
- **Gestionnaire de Densité Peds & Trafic (`berry-core/client/density.lua`)** : Régulation de la densité de peds et de véhicules en ville pour un jeu fluide à 60 FPS.
- **Système Immobilier & Logements Avancé (`berry-core/server/properties.lua` & `berry-core/client/properties.lua`)** : Système de logements et propriétés complètes avec achat par compte bancaire, verrouillage/déverrouillage de porte, téléportation dans les instances/buckets d'intérieur, et coffre de stockage maison directement relié à `berry-inventory`.
- **Moteur d'Animations & Props (`berry-core/client/emotes.lua`)** : Système complet d'émotes, danses, gestes de gangs, positions assises/allongées et attachement d'objets (bouteille de bière, burger, café, cigarette) avec synchronisation des os (bone index) et annulation instantanée.
- **Noyau Principal (`berry-core`)** : Gestionnaire de démarrage modulaire, gestionnaire d'objets joueurs (`Player`), limitation de débit (rate limiting), validation autoritaire d'événements, callbacks RPC asynchrones, state bags et système de logs structurés.
- **Architecture Ressource Unique (Tout-en-un)** : Regroupement de tous les modules, des migrations BDD SQL (`sql/`), des guides développeur (`docs/`), des exemples de configuration et des tests unitaires (`tests/`) au sein du dossier unique `berry-core`.
- **Moteur de Menu NUI F1 (Thème Violet Berry)** : Interface Web moderne en Glassmorphic avec bannière bordeaux/violet, compteur d'éléments (`1/5`), barre de sélection néon, informations joueur en direct, touches, commandes, animations et contrôle des véhicules.
- **Système de Notifications Berry UI** : Cartes notifications Toast en verre translucide avec barre de décompte temporel animée, variantes de couleur de statut (`success`, `error`, `warning`, `info`), et écouteurs natifs pour `berry:notify`, `esx:showNotification`, `ox_lib:notify` et `QBCore:Notify`.
- **Composant Barre de Progression NUI (Berry Progress Bar)** : Barre de progression animée centrée en bas d'écran avec compteur de pourcentage en direct (`0%` -> `100%`) pour le craft, la récolte et les réparations.
- **Cadre NUI Maître Unique (`ui/index.html`)** : Fichier HTML 100% unifié hébergeant le conteneur React de l'inventaire, les notifications, la barre de progression et le Menu F1 sans aucun conflit de page NUI FiveM.
- **Moteur d'Inventaire Berry (`berry-inventory`)** : Système d'inventaire par grille/slots/poids/métadonnées (Flashback Edition, 100% open-source non chiffré), gestionnaire de craft (`modules/craftmanager`), icônes d'emplacements de vêtements et système médical de dégâts corporel (`server/medic.lua`).
- **Moteur de Synchronisation UI (`berry:ui:closeAll`)** : Orchestration automatique du focus NUI fermant le Menu F1 lors de l'ouverture de l'inventaire et vice versa.
- **Moteur de Markers par Découpage Spatial** : Système de grilles spatiales de 100m² pour les markers du monde réduisant la charge CPU à **`0.00 ms` au repos**.
- **Suite de Minijeux RP** : Crochetage de coffre-fort interactif (`StartSafeCrack`) et démarrage de véhicule aux câbles (`StartHotwire`).
- **Moteur Anti-Cheat Berry (`berry-anticheat`)** : Protection autoritaire serveur contre la téléportation, le speedhack, les armes destructrices interdites, le spam de création d'entités crash-serveur (`entityCreating`), seuil de preuve d'évidence et système de grâce d'immunité au spawn/téléport (`ExtendGrace`).
- **Optimisation des Performances Lua 5.4** : Activation du Ramasse-Miettes Générationnel (`collectgarbage("generational")`) côté serveur et client avec localisation rapide des fonctions natives et calculs de distances carrées (`CalculateDistanceSqr`).
- **Système Multi-Personnages (`berry-characters`)** : Création et chargement natif jusqu'à 4 personnages par compte joueur.
- **Système Économique (`berry-economy`)** : Gestion multi-comptes (liquide, banque, argent sale), trésoreries d'entreprises et journalisation audite des transactions (`berry_transactions`).
- **Métiers & Organisations (`berry-jobs`, `berry-organizations`)** : Rangs, salaires automatiques, factions et soldes d'entreprises.
- **Véhicules & Propriétés (`berry-vehicles`, `berry-properties`)** : Garages, génération de plaques d'immatriculation uniques, habitations et coffres de stockage.
- **Administration & Commandes (`berry-admin`)** : Commandes de modération (/kick, /givemoney, /berrystats) et analyseur d'arguments typés.
- **Ponts d'Émulation ESX (`berry-bridges`)** : Rétrocompatibilité totale pour les ressources et scripts ESX existants.
