#!/usr/bin/env bash
set -euo pipefail

CONTAINER="${1:-}"
MODE="${2:-soft}"

if [ -z "${CONTAINER}" ]; then
  echo "Usage: $0 <pg-node1|pg-node2|pg-node3> [soft|clean]"
  exit 1
fi

if ! docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
  echo "Container ${CONTAINER} not found on this VM."
  exit 1
fi

echo "== Rejoin old primary: ${CONTAINER} (${MODE}) =="

if [ "${MODE}" = "soft" ]; then
  echo "-- Starting container (no wipe)"
  docker start "${CONTAINER}"
  echo "-- Tail logs (Ctrl+C to stop)"
  docker logs -f --tail=120 "${CONTAINER}"
  exit 0
fi

if [ "${MODE}" = "clean" ]; then
  echo "!! CLEAN mode will DELETE the local PGDATA volume for this node."
  echo "-- Stopping compose stack in current directory (you should run from /home/s/db/node or /home/s/db/node3)"
  docker compose down || true

  # Guess the volume name based on common pattern. Adjust if yours differs.
  # VM1: node_node1_pgdata or node1_pgdata depending on compose project name.
  echo "-- Candidate volumes:"
  docker volume ls | grep -E 'node.*node1_pgdata|node.*node2_pgdata|node.*node3_pgdata|node1_pgdata|node2_pgdata|node3_pgdata' || true

  echo
  echo "Now delete the right volume manually (recommended), then run docker compose up -d again."
  echo "Example (VM1): docker volume rm node_node1_pgdata"
  echo "Example (VM2): docker volume rm node_node2_pgdata"
  echo "Example (VM3 node): docker volume rm node3_node3_pgdata  (depends on project dir name)"
  exit 0
fi

echo "Unknown mode: ${MODE} (use soft|clean)"
exit 1

