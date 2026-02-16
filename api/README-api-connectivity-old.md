# API Client — HA PostgreSQL + Redis Sentinel + Mongo (Docker Compose)

## Topology

- VM1 → `192.168.122.18`  Postgres node (`pg-node1`)
- VM2 → `192.168.122.233` Postgres node (`pg-node2`)
- VM3 → `192.168.122.246` Postgres primary (`pg-node3`) + monitor on `:5500`
- API VM → `192.168.122.16` runs **goapi + mongodb**, connects to **Redis Sentinel** + **Postgres HA**

---

## 1) Verify network connectivity (API VM)

```bash
nc -vz 192.168.122.18 5432
nc -vz 192.168.122.233 5432
nc -vz 192.168.122.246 5432

nc -vz 192.168.122.18 26379
nc -vz 192.168.122.233 26379
nc -vz 192.168.122.246 26379
```

---

## 2) Confirm primary node (VM3)

```bash
docker compose exec -u postgres pg-monitor \
  pg_autoctl show state --pgdata /var/lib/postgres/pgaf
```

---

## 3) Create UTF8 database on primary

```bash
docker exec -u postgres -it pg-node3 psql -d postgres -c \
"CREATE DATABASE appdb_utf8 OWNER postgres TEMPLATE template0 ENCODING 'UTF8' LC_COLLATE 'C' LC_CTYPE 'C';"
```

---

## 4) Allow API VM in pg_hba.conf (ALL nodes)

```bash
docker exec -u postgres -it pg-nodeX bash -lc '
cat >> /var/lib/postgres/pgaf/pg_hba.conf <<EOF

host  all  postgres  192.168.122.16/32  trust
EOF
'
docker exec -u postgres -it pg-nodeX psql -d postgres -c "select pg_reload_conf();"
```

---

## 5) Fix UTF8 client encoding

```bash
docker exec -u postgres -it pg-node3 psql -d postgres -c \
"ALTER DATABASE appdb_utf8 SET client_encoding TO 'UTF8';"

docker exec -u postgres -it pg-node3 psql -d postgres -c \
"ALTER ROLE postgres SET client_encoding TO 'UTF8';"
```

---

## 6) Test HA multi-host connectivity

```bash
psql \
  "host=192.168.122.18,192.168.122.233,192.168.122.246 port=5432 dbname=appdb_utf8 user=postgres sslmode=disable target_session_attrs=read-write" \
  -c "select inet_server_addr(), pg_is_in_recovery();"
```

---

## 7) API configuration (POSTGRES_URI)

```env
POSTGRES_URI=postgres://postgres@192.168.122.18,192.168.122.233,192.168.122.246:5432/appdb_utf8?sslmode=disable&target_session_attrs=read-write&options=-c%20client_encoding%3DUTF8

REDIS_SENTINEL=1
REDIS_MASTER_NAME=mymaster
REDIS_ADDRS=192.168.122.18:26379,192.168.122.233:26379,192.168.122.246:26379

MONGO_URL=mongodb://goapi-mongodb:27017
MONGO_DB=arcaptcha
```

---

## 8) Docker Compose (API VM)

```yaml
services:
  mongodb:
    image: mongo:7
    container_name: goapi-mongodb
    restart: unless-stopped
    ports:
      - "27017:27017"
    volumes:
      - mongodb:/data/db

  api:
    image: harbor.arcaptcha.ir/backend/goapi:4.38.1
    container_name: goapi
    restart: unless-stopped
    volumes:
      - ./default.env:/default.env:ro
    ports:
      - "80:80"
      - "2112:2112"
    depends_on:
      - mongodb

volumes:
  mongodb:
```

---

## Notes

- `pg_hba.conf` is not replicated → update every node
- Databases and roles replicate automatically
- API requires Mongo at startup
- For HA behavior, always use `POSTGRES_URI` with `target_session_attrs=read-write`
