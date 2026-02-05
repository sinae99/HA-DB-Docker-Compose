#!/usr/bin/env bash
set -euo pipefail

echo "== Verify: monitor cluster state (run on VM3 where monitor lives) =="
echo "If you're NOT on VM3, skip this section or run it on VM3."
if [ -d /home/s/db/monitor ]; then
  cd /home/s/db/monitor
  docker compose exec -u postgres pg-monitor pg_autoctl show state --pgdata /var/lib/postgres/pgaf || true
else
  echo "Not on VM3 (/home/s/db/monitor not found)."
fi

echo
echo "== Verify: node role check (pg_is_in_recovery) if node container exists on this VM =="
if docker ps --format '{{.Names}}' | grep -q '^pg-node1$'; then
  docker exec -it pg-node1 psql -U postgres -d postgres -c "select inet_server_addr() as addr, pg_is_in_recovery() as in_recovery;"
fi
if docker ps --format '{{.Names}}' | grep -q '^pg-node2$'; then
  docker exec -it pg-node2 psql -U postgres -d postgres -c "select inet_server_addr() as addr, pg_is_in_recovery() as in_recovery;"
fi
if docker ps --format '{{.Names}}' | grep -q '^pg-node3$'; then
  docker exec -it pg-node3 psql -U postgres -d postgres -c "select inet_server_addr() as addr, pg_is_in_recovery() as in_recovery;"
fi

echo
echo "== Verify: replication view if primary is on this VM =="
# If this VM hosts a primary, pg_stat_replication will have rows.
for c in pg-node1 pg-node2 pg-node3; do
  if docker ps --format '{{.Names}}' | grep -q "^${c}$"; then
    echo "-- ${c}: pg_stat_replication (may be empty if this node is standby)"
    docker exec -it "${c}" psql -U postgres -d postgres -c \
      "select client_addr, state, sync_state from pg_stat_replication order by client_addr;" || true
  fi
done

echo
echo "DONE"

