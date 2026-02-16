#!/usr/bin/env bash
# Download (pull) pg_auto_failover, redis, mongo images and save as .tar in current directory.
# Run from the directory where you want the tar files (e.g. gm-gateway).

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Pulling images ==="
docker pull citusdata/pg_auto_failover:latest
docker pull redis:7.2-alpine
docker pull mongo:7
docker pull harbor.arcaptcha.ir/backend/goapi:4.39.1

echo ""
echo "=== Saving images to $(pwd) ==="
docker save -o citusdata-pg_auto_failover-latest.tar citusdata/pg_auto_failover:latest
docker save -o redis-7.2-alpine.tar redis:7.2-alpine
docker save -o mongo-7.tar mongo:7
docker save -o harbor.arcaptcha.ir/backend/goapi:4.39.1
echo ""
echo "=== Done. Files: ==="
ls -la citusdata-pg_auto_failover-latest.tar redis-7.2-alpine.tar mongo-7.tar

