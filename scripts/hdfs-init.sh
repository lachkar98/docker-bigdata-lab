#!/usr/bin/env bash
set -euo pipefail
timeout 180 hdfs dfsadmin -safemode wait
hdfs dfs -mkdir -p /tmp /user/hadoop /warehouse/tablespace/external/hive /spark-history
hdfs dfs -chmod 1777 /tmp
hdfs dfs -chmod 775 /warehouse/tablespace/external/hive
