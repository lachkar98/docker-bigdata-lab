# Ajout expérimental de YARN UI2 pour la stack AMD64 existante

Extraire Dockerfile.yarn-ui2 et compose.ui2.yaml dans le dossier de compose.yaml.
Garder les images et volumes existants. Aucun formatage ou down n'est requis.
L'image locale bigdata-hadoop:3.4.3-java8 doit déjà exister (c'est votre image actuelle).
La première construction télécharge les sources et dépendances Maven/Node/Bower.

```bash
sudo docker compose -f compose.yaml -f compose.ui2.yaml config --quiet
sudo docker compose -f compose.yaml -f compose.ui2.yaml build resourcemanager
sudo docker compose -f compose.yaml -f compose.ui2.yaml up -d --no-deps resourcemanager
```

Ouvrir http://localhost:8088/ui2/ . L'interface classique reste sur http://localhost:8088/ .
Les jobs en cours peuvent être interrompus par le remplacement du ResourceManager :
faire l'opération quand aucun job n'est en cours.

```bash
sudo docker compose logs --tail=100 resourcemanager
```

Conserver les DEUX options -f dans les futures commandes de déploiement : sans le
second fichier, Compose pourra rétablir l'image originale.
Retour à l'interface/image originale :

```bash
sudo docker compose -f compose.yaml up -d --no-deps resourcemanager
```

Ce module utilise le profil officiel yarn-ui du tag Hadoop 3.4.3. Le plugin Maven
installe les versions frontend déclarées par Hadoop. Les dépendances anciennes
Node/Bower peuvent nécessiter des corrections si leurs dépôts ne sont plus accessibles.
La construction complète et l'affichage navigateur n'ont pas été testés ici.
Les vues d'historique/flows peuvent nécessiter Timeline Service, non ajouté ici.
Si des appels navigateur échouent malgré le chargement UI2, examiner les URL REST,
la résolution des noms Docker depuis l'hôte et les besoins CORS avant de les modifier.

Source : https://hadoop.apache.org/docs/r3.4.3/hadoop-yarn/hadoop-yarn-site/YarnUI2.html
POM : https://github.com/apache/hadoop/blob/rel/release-3.4.3/hadoop-yarn-project/hadoop-yarn/hadoop-yarn-ui/pom.xml
