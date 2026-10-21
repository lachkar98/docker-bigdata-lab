#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
docker compose exec -T namenode hdfs dfsadmin -safemode wait
docker compose exec -T namenode hdfs dfsadmin -report
docker compose exec -T resourcemanager yarn node -list -all
# À contrôler : Live datanodes (2), Total Nodes:2 et deux nœuds RUNNING.
run="/user/hadoop/validation-$(date +%Y%m%d-%H%M%S)-$$"
docker compose exec -T namenode hdfs dfs -mkdir -p "$run/input"
printf 'bonjour hadoop\nbonjour yarn\n' | docker compose exec -T namenode hdfs dfs -put - "$run/input/texte.txt"
docker compose exec -T namenode hadoop jar /opt/hadoop/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.4.3.jar wordcount "$run/input" "$run/output"
docker compose exec -T namenode hdfs dfs -cat "$run/output/part-r-*"
docker compose exec -T namenode hdfs fsck "$run" -files -blocks -locations
echo "Attendu : bonjour 2, hadoop 1, yarn 1 ; fsck HEALTHY et réplication 2. Données conservées dans $run"
