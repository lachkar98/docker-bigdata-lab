#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  format) exec /opt/lab/format-namenode.sh ;;
  namenode)
    test -s /data/nn/current/VERSION || { echo 'NameNode non initialisé : suivre le README.' >&2; exit 1; }
    exec hdfs namenode ;;
  datanode) exec hdfs datanode ;;
  resourcemanager) exec yarn resourcemanager ;;
  nodemanager) exec yarn nodemanager ;;
  *) exec "$@" ;;
esac
