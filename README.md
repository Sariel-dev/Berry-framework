# Berry Framework

Berry Framework est un framework FiveM moderne, modulaire et orienté performance, conçu pour fournir une base solide, sécurisée et évolutive pour le développement de serveurs roleplay.

Son architecture repose sur un noyau léger et un ensemble de modules indépendants. Cette approche permet de maintenir une séparation claire entre les différents systèmes, de réduire les dépendances inutiles et de faciliter la création, l’intégration et la maintenance de fonctionnalités personnalisées.

Berry Framework est conçu pour répondre aux besoins des développeurs et des équipes souhaitant disposer d’une base technique fiable, structurée et adaptée aux projets FiveM de toutes tailles.

## Principales fonctionnalités

* Noyau léger et modulaire
* Système avancé de gestion des joueurs
* Support multi-personnages
* Gestion économique et transactions sécurisées
* Système de métiers, grades et entreprises
* Gestion des organisations, factions et groupes
* Inventaire extensible avec poids, emplacements et métadonnées
* Registre d’objets personnalisable
* Gestion des véhicules, garages et clés
* Système de propriétés et de stockages
* Système de permissions et outils d’administration
* API basée sur des exports, événements et callbacks
* Architecture compatible avec les extensions et modules externes
* Système de configuration centralisé
* Support multilingue
* Couche d’abstraction pour la base de données
* Migrations et gestion optimisée des données
* Bridges de compatibilité optionnels
* Outils de développement, diagnostic et tests

## Architecture

Berry Framework est construit autour d’un noyau central :

```text id="6m4zo7"
berry-core
```

Les fonctionnalités sont réparties dans des modules spécialisés :

```text id="zk2h6t"
berry-characters
berry-economy
berry-jobs
berry-organizations
berry-items
berry-inventory
berry-vehicles
berry-properties
berry-admin
berry-ui
berry-security
berry-bridges
berry-devtools
```

Chaque module est conçu pour limiter les dépendances directes avec les autres composants. Les communications reposent sur des interfaces publiques, des exports, des événements et des callbacks documentés.

Cette architecture permet d’activer uniquement les systèmes nécessaires, de remplacer certains composants et de développer de nouvelles fonctionnalités sans modifier directement le noyau.

## Performances

Berry Framework adopte une approche orientée performance.

Les principaux objectifs sont :

* Réduire la consommation CPU et mémoire
* Limiter les boucles permanentes
* Privilégier les systèmes événementiels
* Réduire les échanges inutiles entre le client et le serveur
* Limiter les requêtes répétitives vers la base de données
* Utiliser le cache de manière contrôlée
* Synchroniser uniquement les données nécessaires
* Optimiser les sauvegardes et les opérations critiques
* Fournir des outils de profilage et de diagnostic

L’objectif est de maintenir des performances stables tout en conservant une architecture complète et extensible.

## Sécurité

Berry Framework applique un modèle dans lequel le serveur reste l’autorité principale.

Les systèmes sensibles intègrent notamment :

* Validation des événements réseau
* Validation des données reçues
* Vérification des permissions
* Contrôle des états et des distances
* Limitation de fréquence des requêtes
* Protection contre les appels abusifs
* Validation des transactions financières
* Contrôle des opérations d’inventaire
* Journalisation des actions sensibles
* Détection des comportements anormaux

Les données provenant du client ne sont jamais considérées comme fiables sans validation côté serveur.

## Développement

Berry fournit une API structurée permettant aux développeurs d’interagir avec les systèmes du framework de manière claire et cohérente.

```lua id="9mrm8x"
local Berry = exports["berry-core"]:GetCoreObject()

local Player = Berry.GetPlayer(source)

Player:AddMoney(
    "bank",
    500,
    "salary"
)
```

Le framework met à disposition :

* Une API principale
* Des exports documentés
* Des événements
* Des callbacks asynchrones
* Des systèmes de permissions
* Des interfaces publiques pour les modules
* Des outils destinés au développement d’extensions

## Objectif

Berry Framework a pour objectif de proposer une fondation technique moderne et durable pour les serveurs FiveM.

Le projet vise à offrir un équilibre entre :

* Performances
* Sécurité
* Modularité
* Stabilité
* Maintenabilité
* Extensibilité
* Simplicité de développement

Berry Framework est conçu pour servir de base à des projets personnalisés tout en conservant une architecture claire, fiable et adaptée à une évolution sur le long terme.
