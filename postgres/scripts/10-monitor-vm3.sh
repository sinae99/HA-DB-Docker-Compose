#!/usr/bin/env bash
set -euo pipefail

# VM3 — bring up pg_auto_failover monitor
# Assumes: /home/s/db/monitor/docker-compose.yml exists on VM3

echo "== VM3 monitor: starting =="
cd /home/s/db/monitor

docker compose up -d

echo
echo "== VM3 monitor: containers =="
docker compose ps

echo
echo "== VM3 monitor: last logs (pg-monitor) =="
# If your service name differs, adjust "pg-monitor" below.
docker compose logs --tail=80 pg-monitor || true

echo
echo "== VM3 monitor: state (should be just monitor, no nodes yet) =="
docker compose exec -u postgres pg-monitor pg_autoctl show state --pgdata /var/lib/postgres/pgaf || true

echo
echo "DONE: monitor should now be running on 192.168.122.246:5432"

