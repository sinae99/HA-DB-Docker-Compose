#!/usr/bin/env bash
set -euo pipefail

# VM2 — bring up Postgres node (standby)
# Assumes: /home/s/db/node/docker-compose.yml exists on VM2

echo "== VM2 node: starting =="
cd /home/s/db/node

docker compose up -d

echo
echo "== VM2 node: container status =="
docker compose ps

echo
echo "== VM2 node: last logs =="
docker logs --tail=180 pg-node2 || true

echo
echo "TIP: On VM3 monitor, run: pg_autoctl show state (VM2 should move to secondary)"

