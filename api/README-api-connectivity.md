# API Client --- HA PostgreSQL + Redis Sentinel + MongoDB Replica Set


------------------------------------------------------------------------

## Topology

-   VM1 → `192.168.122.18`
    -   PostgreSQL node (`pg-node1`)
    -   Redis + Sentinel
    -   MongoDB replica set member
-   VM2 → `192.168.122.233`
    -   PostgreSQL node (`pg-node2`)
    -   Redis + Sentinel
    -   MongoDB replica set member
-   VM3 → `192.168.122.246`
    -   PostgreSQL primary (`pg-node3`)
    -   pg_auto_failover monitor (`:5500`)
    -   Redis + Sentinel
    -   MongoDB replica set member
-   API VM → `192.168.122.16`
    -   runs **goapi**
    -   connects to PostgreSQL HA, Redis Sentinel, MongoDB HA

------------------------------------------------------------------------

## 1) Verify network connectivity (API VM)

``` bash
# PostgreSQL
nc -vz 192.168.122.18 5432
nc -vz 192.168.122.233 5432
nc -vz 192.168.122.246 5432

# Redis Sentinel
nc -vz 192.168.122.18 26379
nc -vz 192.168.122.233 26379
nc -vz 192.168.122.246 26379

# MongoDB Replica Set
nc -vz 192.168.122.18 27017
nc -vz 192.168.122.233 27017
nc -vz 192.168.122.246 27017
```

------------------------------------------------------------------------

## 2) Confirm PostgreSQL primary node

Run on VM3 (monitor node):

``` bash
docker compose exec -u postgres pg-monitor   pg_autoctl show state --pgdata /var/lib/postgres/pgaf
```

------------------------------------------------------------------------

## 3) Create UTF-8 database (once, on primary)

``` bash
docker exec -u postgres -it pg-node3 psql -d postgres -c "CREATE DATABASE appdb_utf8 OWNER postgres TEMPLATE template0 ENCODING 'UTF8' LC_COLLATE 'C' LC_CTYPE 'C';"
```

------------------------------------------------------------------------

## 4) Allow API VM in `pg_hba.conf` (ALL PostgreSQL nodes)

> `pg_hba.conf` is **not replicated** --- this must be applied to every
> node.

``` bash
docker exec -u postgres -it pg-nodeX bash -lc '
cat >> /var/lib/postgres/pgaf/pg_hba.conf <<EOF

host  all  postgres  192.168.122.16/32  trust
EOF
'
docker exec -u postgres -it pg-nodeX psql -d postgres -c "select pg_reload_conf();"
```

------------------------------------------------------------------------

## 5) Enforce UTF-8 client encoding

``` bash
docker exec -u postgres -it pg-node3 psql -d postgres -c "ALTER DATABASE appdb_utf8 SET client_encoding TO 'UTF8';"

docker exec -u postgres -it pg-node3 psql -d postgres -c "ALTER ROLE postgres SET client_encoding TO 'UTF8';"
```

------------------------------------------------------------------------

## 6) Test PostgreSQL HA connectivity

``` bash
psql   "host=192.168.122.18,192.168.122.233,192.168.122.246 port=5432 dbname=appdb_utf8 user=postgres sslmode=disable target_session_attrs=read-write"   -c "select inet_server_addr(), pg_is_in_recovery();"
```

------------------------------------------------------------------------

## 7) API environment configuration (`default-envs`)

``` env
##############################################
# Postgres (HA)
POSTGRES_URI=postgres://postgres@192.168.122.18,192.168.122.233,192.168.122.246:5432/appdb_utf8?sslmode=disable&target_session_attrs=read-write

PGOPTIONS=-c client_encoding=UTF8
PGCLIENTENCODING=UTF8

##############################################
# Redis (Sentinel)
REDIS_SENTINEL=1
REDIS_MASTER_NAME=mymaster
REDIS_ADDRS=192.168.122.18:26379,192.168.122.233:26379,192.168.122.246:26379

##############################################
# MongoDB (Replica Set HA)
MONGO_URL=mongodb://192.168.122.18:27017,192.168.122.233:27017,192.168.122.246:27017/?replicaSet=rs0
MONGO_DB=arcaptcha
```

------------------------------------------------------------------------

## 8) Docker Compose (API VM)

``` yaml
services:
  api:
    image: harbor.arcaptcha.ir/backend/goapi:4.38.1
    container_name: goapi
    restart: unless-stopped
    volumes:
      - ./default.env:/default.env:ro
    ports:
      - "80:80"
      - "2112:2112"
```

------------------------------------------------------------------------
