# Guide d'Installation — Berry Framework

## Prérequis

1. Serveur FiveM (Artifacts recommandés : v5848 ou supérieur).
2. Base de données MySQL / MariaDB.
3. Ressource `oxmysql` (dernière version stable).

## Étapes d'Installation

1. **Base de données** :
   - Exécutez le fichier de migration SQL dans votre base de données :
     `migrations/001_berry_schema.sql`

2. **Copie des ressources** :
   - Déplacez le dossier `berry_framework` (ou les modules individuels `berry-*`) dans le répertoire `resources/` de votre serveur FiveM.

3. **Configuration du `server.cfg`** :
   - Ajoutez les lignes de chargement dans l'ordre suivant :
     ```text
     ensure oxmysql
     ensure berry-core
     ensure berry-items
     ensure berry-inventory
     ensure berry-characters
     ensure berry-economy
     ensure berry-jobs
     ensure berry-organizations
     ensure berry-vehicles
     ensure berry-properties
     ensure berry-commands
     ensure berry-admin
     ensure berry-ui
     ensure berry-bridges
     ensure berry-devtools
     ensure berry-demo
     ```

4. **Démarrage** :
   - Lancez votre serveur FiveM. Observez le bannière et les logs `[BERRY:CORE]` confirmant la bonne initialisation du noyau et la connexion SQL.
