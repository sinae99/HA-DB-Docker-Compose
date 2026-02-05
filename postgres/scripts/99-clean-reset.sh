#!/usr/bin/env bash
set -euo pipefail

echo "== Clean reset: stopping compose in $(pwd) =="
docker compose down || true

echo
echo "== Containers (remaining) =="
docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'

echo
echo "== Candidate volumes (pgaf) =="
docker volume ls | grep -E 'pgdata|pgaf|node1|node2|node3|monitor|pg_auto' || true

echo
echo "To fully reset, remove the correct volume(s) shown above, then rerun bring-up."
echo "Examples:"
echo "  docker volume rm node_node1_pgdata"
echo "  docker volume rm node_node2_pgdata"
echo "  docker volume rm node3_node3_pgdata   # project-dir dependent"
echo "  docker volume rm monitor_monitor_pgdata # if your monitor uses a named volume"

