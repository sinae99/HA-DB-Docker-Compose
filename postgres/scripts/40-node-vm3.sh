#!/usr/bin/env bash
set -euo pipefail

# VM3 — bring up Postgres node alongside the monitor
# Assumes: /home/s/db/node3/docker-compose.yml exists on VM3
# IMPORTANT: this node must NOT use host port 5432 (monitor already uses it). In your setup it is 5433:5432.

echo "== VM3 node: starting (alongside monitor) =="
cd /home/s/db/node3

docker compose up -d

echo
echo "== VM3 node: container status =="
docker compose ps

echo
echo "== VM3 node: last logs =="
docker logs --tail=180 pg-node3 || true

echo
echo "NOTE: VM3 node is exposed on host port 5433 (container 5432). Monitor remains on 5432."

