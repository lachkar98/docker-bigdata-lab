#!/usr/bin/env bash
set -euo pipefail
# Query the schema marker explicitly: connection failures must not trigger init.
python3 /opt/extra/tcp.py metastore-db 5432
if /opt/hive/bin/schematool -dbType postgres -info; then exit 0; fi
# No automatic reinitialization/upgrade; initSchema fails if existing tables conflict.
exec /opt/hive/bin/schematool -dbType postgres -initSchema
