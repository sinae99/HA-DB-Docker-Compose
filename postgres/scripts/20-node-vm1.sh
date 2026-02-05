#!/usr/bin/env bash
set -euo pipefail

# VM1 — bring up Postgres node (initial primary)
# Assumes: /home/s/db/node/docker-compose.yml exists on VM1

echo "== VM1 node: starting =="
cd /home/s/db/node

docker compose up -d

echo
echo "== VM1 node: container status =="
docker compose ps

echo
echo "== VM1 node: last logs =="
docker logs --tail=120 pg-node1 || true

echo
echo "TIP: On VM3 monitor, run: pg_autoctl show state (should show VM1 as primary/single initially)"

