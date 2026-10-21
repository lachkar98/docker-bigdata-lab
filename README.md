# Laboratoire Big Data AMD64 — adapté pour x86_64

Cette variante corrige le décalage d’architecture : plateformes Compose linux/amd64,
contrôle TARGETARCH=amd64 et archive Hadoop standard hadoop-3.4.3.tar.gz.
Aucune émulation ARM n’est nécessaire sur un moteur Docker AMD64.

## Démarrage

Depuis ce dossier :

```bash
docker compose config --quiet
docker compose build --no-cache namenode
docker compose build --no-cache metastore
docker compose run --rm --no-deps -e CONFIRM_INITIAL_FORMAT=YES namenode format
docker compose up -d namenode datanode1 datanode2 resourcemanager nodemanager1 nodemanager2 metastore-db
docker compose up -d metastore hiveserver2 spark-client
docker compose ps -a
```

Le script de formatage refuse un répertoire déjà rempli sans métadonnées valides et
ne reformate pas un NameNode déjà initialisé. Ce projet utilise de nouveaux volumes
sous le nom bigdata-amd64 ; les anciens volumes ne sont pas migrés.

Hue : les étapes AMD64 (image publiée, fichier .env, droits du volume et démarrage
avec UI2) figurent dans la section [Hue du guide](GUIDE.md#hue--démarrage-sur-amd64-avec-limage-publiée).
Ranger et ses plugins restent à construire et intégrer : ils ne sont pas activés.
Les limites Hive/Spark/Java et les tests fonctionnels figurent dans GUIDE.md.
La configuration est vérifiée statiquement ; aucun build ou démarrage n’a été validé.

## Correction réseau Hive 3

Le réseau Docker porte un nom explicite sans underscore : bigdata-amd64-hadoop.
Hive 3 canonicalise le nom du métastore ; un nom DNS retourné contenant un underscore
provoque URISyntaxException avant ouverture du port HiveServer2. Après remplacement
de compose.yaml, arrêter les conteneurs avec `docker compose down` (sans -v), puis
relancer `docker compose up -d`. Les volumes sont conservés ; aucun formatage requis.
