# PostgreSQL + pg_auto_failover + 3 VM + Docker Compose

High-availability PostgreSQL using **pg_auto_failover** across **3 Ubuntu VMs** with **Docker Compose**.  
(No Kubernetes world!)

## Architecture

| VM | IP | Role |
|---|---|---|
| VM1 | 192.168.122.18 | Postgres node (`pg-node1`) |
| VM2 | 192.168.122.233 | Postgres node (`pg-node2`) |
| VM3 | 192.168.122.246 | **Monitor** (`pg-monitor`) on **5500** + Postgres node (`pg-node3`) on host **5432** |

- Exactly **one primary** (read-write), others **standby** (read-only)
- Failover is automatic via **pg_auto_failover monitor**
- Note: The pg_auto_failover monitor runs PostgreSQL on port 5432 inside the container,
but is exposed on host port 5500 to avoid conflict with pg-node3.


## Repo / VM Layout

This repo contains reference configs, but on the VMs we run from:

- VM3 monitor: `/home/s/db/monitor/docker-compose.yml`
- VM1 node: `/home/s/db/node/docker-compose.yml`
- VM2 node: `/home/s/db/node/docker-compose.yml`
- VM3 node: `/home/s/db/node3/docker-compose.yml`

> Make sure the compose files are copied to those exact paths before starting.


## 1) Start Monitor (VM3)

```bash
cd /home/s/db/monitor
docker compose up -d
docker logs -f --tail=200 pg-monitor
```

Confirm:
```bash
docker compose exec -u postgres pg-monitor psql -d pg_auto_failover -c "select 1;"
```

## 2) Fix Monitor pg_hba.conf (REQUIRED)

```bash
docker exec -u postgres -it pg-monitor bash -lc '
cat >> /var/lib/postgres/pgaf/pg_hba.conf <<EOF

host  pg_auto_failover  autoctl_node  192.168.122.18/32   trust
host  pg_auto_failover  autoctl_node  192.168.122.233/32  trust
host  pg_auto_failover  autoctl_node  192.168.122.246/32  trust
EOF
tail -n 20 /var/lib/postgres/pgaf/pg_hba.conf
'
```

Reload:
```bash
docker compose exec -u postgres pg-monitor psql -d pg_auto_failover -c "select pg_reload_conf();"
```

## 3) Start VM1 Node (initial primary)

```bash
cd /home/s/db/node
docker compose up -d
docker logs -f --tail=200 pg-node1
```

Verify:
```bash
cd /home/s/db/monitor
docker compose exec -u postgres pg-monitor pg_autoctl show state --pgdata /var/lib/postgres/pgaf
```

## 4) Start VM2 Node (standby)

```bash
cd /home/s/db/node
docker compose up -d
docker logs -f --tail=300 pg-node2
```

Verify again from monitor.

## 5) Start VM3 Node (standby)

```bash
cd /home/s/db/node3
docker compose up -d
docker logs -f --tail=300 pg-node3
```

Confirm ports:
```bash
docker ps --format "table {{.Names}}\t{{.Ports}}"
```

Final verify:
```bash
cd /home/s/db/monitor
docker compose exec -u postgres pg-monitor pg_autoctl show state --pgdata /var/lib/postgres/pgaf
```

## Application Connectivity

Use a multi-host DSN with `target_session_attrs=read-write`:

```
host=192.168.122.18,192.168.122.233,192.168.122.246
port=5432
sslmode=disable
target_session_attrs=read-write
```
