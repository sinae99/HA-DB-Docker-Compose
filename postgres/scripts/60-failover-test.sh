#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-}"
if [ -z "${TARGET}" ]; then
  echo "Usage: $0 <vm1|vm2|vm3|pg-node1|pg-node2|pg-node3>"
  exit 1
fi

case "${TARGET}" in
  vm1) CONTAINER="pg-node1" ;;
  vm2) CONTAINER="pg-node2" ;;
  vm3) CONTAINER="pg-node3" ;;
  pg-node1|pg-node2|pg-node3) CONTAINER="${TARGET}" ;;
  *) echo "Unknown target: ${TARGET}"; exit 1 ;;
esac

echo "== Failover test: stopping ${CONTAINER} on THIS VM (must be run on the VM hosting that container) =="
docker stop "${CONTAINER}"

echo
echo "== Now watch the monitor state on VM3 =="
echo "Run this on VM3:"
echo "  cd /home/s/db/monitor && docker compose exec -u postgres pg-monitor pg_autoctl show state --pgdata /var/lib/postgres/pgaf"
echo
echo "TIP: re-run the show state command a few times until you see a new primary."

