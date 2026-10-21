#!/usr/bin/env bash
set -euo pipefail
# Ce script ne formate JAMAIS un répertoire contenant déjà des données.
if [[ -s /data/nn/current/VERSION ]]; then
  echo 'NameNode déjà initialisé : aucune modification.'
  exit 0
fi
if [[ -n "$(find /data/nn -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
  echo 'REFUS : /data/nn non vide sans VERSION valide. Inspection manuelle requise.' >&2
  exit 1
fi
[[ "${CONFIRM_INITIAL_FORMAT:-}" == YES ]] || { echo 'Initialisation requise : CONFIRM_INITIAL_FORMAT=YES' >&2; exit 1; }
hdfs namenode -format -nonInteractive -clusterid CID-hadoop-amd64-lab
test -s /data/nn/current/VERSION
