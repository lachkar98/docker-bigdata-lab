> Guide issu de la variante ARM64. Pour cette variante AMD64, utiliser le README.md
> et compose.yaml fournis : Hadoop utilise l’archive standard et tous les conteneurs
> ciblent linux/amd64. Les remarques de portage ARM64 ci-dessous sont historiques.

# Laboratoire Big Data ARM64 — proposition à valider

## État réel

Le ZIP original est conservé séparément. Cette extension est une proposition de laboratoire,
pas une distribution intégrée certifiée. La structure Compose, le XML et la syntaxe shell
sont contrôlés. Aucun build, téléchargement complet ni test de bout en bout n'a été exécuté.
Docker refuse l'accès au socket dans la session de préparation.

HDFS/YARN/Hive/Spark : fichiers de construction et configuration fournis.
Hue : profil Compose fourni, image ARM64 à construire et tester.
Ranger : procédure officielle de construction et plan de raccordement fournis ;
Ranger et ses plugins NE SONT PAS installés automatiquement dans cette proposition.
Il ne s'agit donc pas encore d'une stack complète sécurisée par Ranger.

## Analyse de l'archive reçue

`Dockerfile` part d'eclipse-temurin:17-jdk-jammy et ne télécharge que
hadoop-3.4.3-aarch64.tar.gz. Aucun téléchargement Hive, Spark, Ranger ou Hue.
`docker-compose.yml` réutilise cette même image pour six processus :
namenode, datanode1, datanode2, resourcemanager, nodemanager1 et nodemanager2.
Les trois derniers sont déjà YARN. Les fichiers yarn-site.xml et mapred-site.xml
configurent bien MapReduce sur YARN. « Hadoop » comprend ici HDFS et YARN,
mais n'installe pas les produits de l'écosystème.
Le script entrypoint démarre un seul démon par conteneur. Aucun métastore,
serveur SQL, moteur Spark, gestionnaire de politiques ou interface Hue n'est déclaré.
Le fichier VERIFICATION.txt original indique lui-même que Java 17, les builds
et les démons n'ont pas été testés. La publication de ports n'installe aucun logiciel.

## Architecture et versions proposées

- Hadoop 3.4.3 ARM64 natif, deux DataNodes, réplication 2, deux NodeManagers.
- Java 8 pour ce laboratoire Hive 3 ; remplace le choix Java 17 non validé de l'original.
- Hive 3.1.3, métastore distant PostgreSQL 16 et HiveServer2 ; moteur MapReduce.
- Spark 3.5.6 : client persistant, calculs sur YARN, aucun master/worker standalone requis.
- Hue : interface SQL vers HiveServer2 et navigation WebHDFS, image distincte.
- Ranger : Admin + base dédiée + stockage d'audit, plugins dans les services protégés.

Dépendances : PostgreSQL → init schéma → métastore ; HDFS → init répertoires →
métastore ; métastore + YARN → HiveServer2 ; HiveServer2 → Hue.
Les ports TCP des healthchecks confirment l'écoute, pas la réussite d'une requête SQL.
Prévoir 24 Gio de RAM, idéalement 32 avec Ranger/audit, 8 cœurs et 50 Gio libres.
Les limites Compose sont des plafonds, elles ne réservent pas la RAM à l'hôte.

## Démarrage du socle

Depuis ce dossier, sur un hôte ARM64 avec Docker Compose v2 :

```bash
docker compose config --quiet
docker compose build namenode
# L'image tools dépend de l'image Hadoop locale : construire dans cet ordre.
docker compose build metastore
# Initialisation explicite et idempotente ; utiliser les nouveaux volumes de ce projet.
docker compose run --rm --no-deps -e CONFIRM_INITIAL_FORMAT=YES namenode format
docker compose up -d namenode datanode1 datanode2 resourcemanager nodemanager1 nodemanager2 metastore-db
docker compose up -d metastore hiveserver2 spark-client
docker compose ps -a
docker compose logs --tail=100 metastore-init metastore hiveserver2
```

Ne pas réutiliser automatiquement les volumes de l'archive originale. `hdfs-init`
et `metastore-init` doivent sortir avec code 0. Une erreur de schéma existant exige
une inspection et, si nécessaire, une migration explicite ; ne pas effacer les tables.
La résolution Maven du client métastore Spark nécessite Internet au premier usage.

## Vérifications fonctionnelles à exécuter

```bash
bash scripts/validate.sh
docker compose exec -T hiveserver2 /opt/hive/bin/beeline -u 'jdbc:hive2://localhost:10000/default' -n hadoop -e "CREATE EXTERNAL TABLE IF NOT EXISTS lab_numbers (id INT) STORED AS TEXTFILE LOCATION '/user/hadoop/lab_numbers'; SHOW TABLES;"
docker compose exec -T spark-client spark-sql -e "SHOW TABLES; SELECT sum(id) FROM range(100);"
docker compose exec -T spark-client spark-submit --master yarn --deploy-mode client --class org.apache.spark.examples.SparkPi /opt/spark/examples/jars/spark-examples_2.12-3.5.6.jar 5
docker compose exec -T resourcemanager yarn application -list -appStates FINISHED
```

Résultats attendus : deux DataNodes vivants et deux NodeManagers RUNNING ; wordcount
valide ; table lab_numbers visible dans Spark ; somme 4950 ; application SparkPi FINISHED/SUCCEEDED.
Le test SQL de métadonnées seul ne valide pas l'accès aux données : charger ensuite
un fichier dans /user/hadoop/lab_numbers et vérifier son contenu depuis les deux moteurs.
Exécuter Spark depuis spark-client : son nom est fixé comme adresse du driver.

Interfaces : HDFS http://localhost:9870 ; YARN http://localhost:8088 ;
HiveServer2 http://localhost:10002 ; Hive JDBC localhost:10000.
Les clients HDFS/Spark s'exécutent dans le réseau Compose : les noms et ports
internes des DataNodes ne sont pas directement utilisables depuis l'hôte.

## Hue : démarrage sur AMD64 avec l’image publiée

L’image gethue/hue inspectée sur votre machine annonce linux/amd64 : aucune
compilation Hue ni émulation ARM64 n’est nécessaire. Son architecture est confirmée ;
le démarrage et les requêtes Hive avec la configuration fournie restent à vérifier.

### 1. Se placer dans le dossier de la stack

```bash
cd ~/docker/bigdata-amd64
```

Les fichiers compose.yaml et compose.ui2.yaml doivent être dans ce dossier.
Le service hue est déjà déclaré dans compose.yaml sous le profil optionnel hue.
Le fichier config/hue.ini fourni pointe vers hiveserver2:10000 et conserve la base
SQLite de Hue dans le volume hue-data monté sur /var/lib/hue.

### 2. Choisir l’image Hue dans .env

Avant de renseigner .env, inspecter l’image publiée :

```bash
sudo docker manifest inspect --verbose gethue/hue:latest
```

Cette commande ne nécessite pas l’extension Buildx. Dans le résultat, vérifier
`Descriptor.platform.os` = `linux` et `Descriptor.platform.architecture` = `amd64`,
puis copier la valeur de `Descriptor.digest` (avec son préfixe `sha256:`).
Ne pas prendre le digest de `config` ou d’une entrée de `layers` : ils identifient
d’autres éléments de l’image.

Pour le manifeste simple obtenu dans notre session, l’extrait utile était :

```json
{
  "Descriptor": {
    "digest": "sha256:7d5c1b9f8a79ac987e3a04fba987890dd9cd6055c6c475e63fcb0355455fa4e1",
    "platform": {
      "architecture": "amd64",
      "os": "linux"
    }
  }
}
```

Si le résultat est une liste de manifestes, choisir l’entrée dont la plateforme
est `linux/amd64` et utiliser son digest. Si aucune entrée ne correspond, ne pas
poursuivre avec cette image. Le tag latest peut évoluer : le digest affiché lors
d’une nouvelle inspection peut donc différer de l’exemple ci-dessous.

Construire la valeur sous la forme `HUE_IMAGE=gethue/hue@<digest copié>`, puis
ouvrir le fichier :

```bash
nano .env
```

Ajouter HUE_IMAGE, ou remplacer sa valeur si elle existe déjà, avec le digest
récupéré à l’étape précédente. Conserver les autres paramètres du fichier et une
seule définition de HUE_IMAGE. Exemple avec le digest obtenu dans notre session :

```dotenv
HUE_IMAGE=gethue/hue@sha256:7d5c1b9f8a79ac987e3a04fba987890dd9cd6055c6c475e63fcb0355455fa4e1
```

Cet identifiant fixe exactement l’image dont le manifeste a été inspecté,
contrairement au tag latest qui peut changer. Enregistrer avec Ctrl+O, Entrée,
puis quitter avec Ctrl+X. Si .env n’existe pas, nano le crée.

### 3. Télécharger l’image

```bash
sudo docker compose -f compose.yaml -f compose.ui2.yaml --profile hue pull hue
```

### 4. Préparer les droits du volume Hue

```bash
sudo docker compose -f compose.yaml -f compose.ui2.yaml --profile hue run --rm --no-deps --user root --entrypoint sh hue -c 'chown hue:hue /var/lib/hue'
```

Ce conteneur temporaire prépare les droits du dossier de données, puis est supprimé.
Le volume persistant est conservé. Si cette étape échoue, lire son erreur avant
le démarrage : l’utilisateur et les chemins de l’image doivent correspondre.

### 5. Démarrer Hue

```bash
sudo docker compose -f compose.yaml -f compose.ui2.yaml --profile hue up -d hue
```

Compose attend que HiveServer2 soit sain, conformément aux dépendances du service.
Ouvrir http://localhost:8888 et suivre la création du premier compte si proposée.
Tester ensuite une requête dans l’éditeur Hive :

```sql
SHOW DATABASES;
```

### 6. Vérifier en cas de problème

```bash
sudo docker compose -f compose.yaml -f compose.ui2.yaml --profile hue ps -a hue
sudo docker compose -f compose.yaml -f compose.ui2.yaml --profile hue logs --tail=100 hue
```

Vérifier notamment les migrations de la base Hue, les permissions de /var/lib/hue
et la connexion à HiveServer2. SQLite convient ici à un seul Hue de démonstration.

### Démarrages suivants avec Hue et UI2

```bash
sudo docker compose -f compose.yaml -f compose.ui2.yaml --profile hue up -d
```

Les deux fichiers -f conservent la variante ResourceManager UI2 ; --profile hue
inclut Hue parmi les services à démarrer. Aucun volume à supprimer ni formatage
HDFS nécessaire pour cet ajout.

## Ranger : construction et intégration restantes

Utiliser le laboratoire Docker maintenu dans le dépôt Apache plutôt qu'une image
communautaire AMD64 au démarrage inconnu :
https://github.com/apache/ranger/tree/master/dev-support/ranger-docker

1. Cloner apache/ranger, choisir un tag/commit et conserver son identifiant.
2. Suivre le README DE CE COMMIT pour construire Ranger et ses dépendances.
   Le README consulté emploie docker-compose.ranger-build.yml pour la construction.
   Les fichiers Compose de lancement et variables changent entre versions.
3. Vérifier les architectures de toutes les images de base : JDK, base SQL,
   ZooKeeper/KDC si activés, Solr/OpenSearch selon le backend d'audit sélectionné.
   Certains Dockerfiles ou archives peuvent encore supposer x86_64 : les corriger
   pour ARM64 ou documenter séparément une émulation AMD64.
4. Utiliser une base Ranger distincte du métastore ; attendre l'initialisation du
   schéma Admin avant de démarrer les plugins. Définir les mots de passe dans la
   configuration Ranger ; ne pas réutiliser les valeurs d'exemple hors laboratoire.
5. Raccorder le conteneur Admin au réseau de ce laboratoire :
   `docker network connect --alias ranger-admin bigdata-amd64-hadoop <conteneur-admin>`

   URL interne des plugins : http://ranger-admin:6080. Les plugins tirent leurs
   politiques depuis Admin ; Admin doit aussi résoudre Hive/HDFS pour ses tests.
6. Construire les plugins HDFS et Hive de la même version que Ranger Admin.
   Vérifier leur compatibilité binaire avec Hadoop 3.4.3/Hive 3.1.3 : ne pas copier
   simplement des JAR récents dans cette stack. Installer le plugin HDFS dans
   l'image NameNode et le plugin Hive dans l'image tools/HiveServer2.
7. Dans les install.properties des plugins : POLICY_MGR_URL=http://ranger-admin:6080,
   noms de repositories lab_hdfs et lab_hive ; configurer cache local et audit.
   Exécuter leurs scripts enable-*-plugin.sh selon le README de la version retenue.
   La factory Hive attendue est
   org.apache.ranger.authorization.hive.authorizer.RangerHiveAuthorizerFactory ;
   HDFS utilise org.apache.ranger.authorization.hadoop.RangerHdfsAuthorizer comme
   dfs.namenode.inode.attributes.provider.class. Les classes seules ne suffisent pas :
   fichiers ranger-*-security.xml, classpath et audit sont aussi nécessaires.
8. Recréer NameNode/HiveServer2 avec ces images et vérifier les téléchargements de
   politiques ainsi qu'un test autorisé ET refusé pour deux utilisateurs distincts.
   Conserver ces tests avant d'annoncer l'intégration opérationnelle.

Ranger Admin sans plugin n'applique AUCUNE politique. Le plugin Hive protège les
requêtes passant par HiveServer2 ; Spark lit directement HDFS et ne traverse pas
cette autorisation. Le plugin HDFS est donc nécessaire pour ces fichiers, et une
politique SQL Spark nécessite une intégration supplémentaire compatible.
Ce laboratoire fonctionne en identité simple sans Kerberos : un client peut
usurper un nom d'utilisateur. Ranger seul ne fournit pas une authentification forte.
UserSync devient utile avec un annuaire ; ce n'est pas un remplaçant de Kerberos.

## Limites de compatibilité et sécurité

- Versions choisies pour explorer l'interopérabilité, pas recommandation de production.
  Hive 3.1.3 et Java 8 sont anciens : analyser CVE/support avant tout déploiement réel.
- Spark 3.5 accepte le métastore Hive 3.1.3 ; ne pas remplacer par Hive 4 sans revoir
  la matrice du client Spark. La distribution Spark embarque son propre Hadoop 3 :
  alignement client/serveur à vérifier avec de vraies lectures/écritures YARN/HDFS.
- Hive 3 + Hadoop 3.4 reste une combinaison non certifiée ici. La substitution Guava
  traite un conflit connu mais ne prouve pas la compatibilité de tous les JAR.
- Les tables ACID Hive ne sont pas interchangeables avec les tables Spark classiques.
  Commencer avec des tables EXTERNAL TEXTFILE/Parquet non transactionnelles.
- Hive utilise MapReduce ici pour éviter une installation Tez incomplète ; c'est
  lent et ancien. Une configuration Tez exige ses archives HDFS et sa matrice de versions.
- Les binaires Java sont portables, les bibliothèques JNI ne le sont pas. Hadoop
  utilise l'archive aarch64 ; tester compression Snappy/Zstd et dépendances natives Spark/Hue.
- Pas de TLS, Kerberos, HA, sauvegardes, rotation de secrets ou isolation multiutilisateur.
  Les proxyusers avec '*' et doAs=false sont uniquement pour le laboratoire local.
- Ports liés à 127.0.0.1 ; ne pas publier ce réseau sur Internet.
- Réplication 2 dans deux conteneurs du même hôte ne protège pas contre sa perte.
- `docker compose stop` arrête ; `docker compose down` conserve les volumes.
  L'option `down -v` détruit les données : ne l'utiliser que pour un reset volontaire.

## Sources primaires

- https://hadoop.apache.org/docs/r3.4.3/
- https://spark.apache.org/docs/3.5.6/sql-data-sources-hive-tables.html
- https://hive.apache.org/docs/latest/admin/setting-up-hive-with-docker/
- https://github.com/apache/ranger/blob/master/dev-support/ranger-docker/README.md
- https://github.com/cloudera/hue/blob/master/tools/docker/hue/Dockerfile

Les sources latest/master servent de documentation, pas de dépendances reproductibles.
Épingler commits et digests des images après validation sur votre machine ARM64.
