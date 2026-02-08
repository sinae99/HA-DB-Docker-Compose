# API Client -- PostgreSQL Connection

------------------------------------------------------------------------

## Topology

  VM       IP                Role
  -------- ----------------- -------------------------------
  VM1      192.168.122.18    Postgres node (`pg-node1`)
  VM2      192.168.122.233   Postgres node (`pg-node2`)
  VM3      192.168.122.246   Primary Postgres (`pg-node3`)
  API VM   192.168.122.16    Application host

-   Exactly **one primary**, others **standby**
-   Automatic failover via **pg_auto_failover**

------------------------------------------------------------------------

## 1) Verify Network Connectivity (API VM)

``` bash
nc -vz 192.168.122.18 5432
nc -vz 192.168.122.233 5432
nc -vz 192.168.122.246 5432
```

All must succeed.

------------------------------------------------------------------------

## 2) Create Application Role and Database (run on primary)

First identify the primary:

``` bash
docker compose exec -u postgres pg-monitor pg_autoctl show state --pgdata /var/lib/postgres/pgaf
```

Run the following on the **primary node container**:

``` bash
docker exec -u postgres -it pg-node3 psql -d postgres -c "CREATE ROLE \"api-client\" LOGIN PASSWORD 'api-client-pass';"

docker exec -u postgres -it pg-node3 psql -d postgres -c "CREATE DATABASE appdb OWNER \"api-client\";"

docker exec -u postgres -it pg-node3 psql -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE appdb TO \"api-client\";"
```

> Roles and databases replicate automatically to standby nodes.

------------------------------------------------------------------------

## 3) Allow API VM in pg_hba.conf ----> ALL nodes

**pg_hba.conf is local ---> no replication**

On **each Postgres node container** (`pg-node1`, `pg-node2`,
`pg-node3`):

``` bash
docker exec -u postgres -it pg-nodeX bash -lc '
cat >> /var/lib/postgres/pgaf/pg_hba.conf <<EOF

host  appdb  api-client  192.168.122.16/32  md5
EOF
tail -n 5 /var/lib/postgres/pgaf/pg_hba.conf
'
```

Reload config:

``` bash
docker exec -u postgres -it pg-nodeX psql -d postgres -c "select pg_reload_conf();"
```

------------------------------------------------------------------------

## 4) Test Authentication from API VM

``` bash
apt-get update && apt-get install -y postgresql-client

PGPASSWORD='api-client-pass' psql -h 192.168.122.18  -U api-client -d appdb -c 'select inet_server_addr(), pg_is_in_recovery();'
PGPASSWORD='api-client-pass' psql -h 192.168.122.233 -U api-client -d appdb -c 'select inet_server_addr(), pg_is_in_recovery();'
PGPASSWORD='api-client-pass' psql -h 192.168.122.246 -U api-client -d appdb -c 'select inet_server_addr(), pg_is_in_recovery();'
```

Expected: - Primary: `pg_is_in_recovery = f` - Standby:
`pg_is_in_recovery = t`

------------------------------------------------------------------------

## 5) Application Configuration (no TLS)

Environment variables expected by the API:

``` env
POSTGRES_APP_NAME=api
POSTGRES_HOST=192.168.122.18,192.168.122.233,192.168.122.246
POSTGRES_PORT=5432
POSTGRES_USER=api-client
POSTGRES_PASSWORD=api-client-pass
POSTGRES_DB=appdb
POSTGRES_SSLMODE=disable
```

------------------------------------------------------------------------

## Notes

-   `pg_hba.conf` is **not replicated** → must be edited on every node
-   Roles and databases **are replicated**
