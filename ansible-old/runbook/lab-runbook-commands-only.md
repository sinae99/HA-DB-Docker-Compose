# Runbook


- VM inventory:
  - VM1 = 192.168.122.18
  - VM2 = 192.168.122.233
  - VM3 = 192.168.122.246
  - API VM = 192.168.122.16
- You have the repo on your laptop at: `~/Desktop/db-ha/`
- You will copy compose files to the target VM paths exactly as referenced.

---

## 0) Quick SSH aliases (optional)

**On laptop**
```bash
alias vm1='ssh s@192.168.122.18'
alias vm2='ssh s@192.168.122.233'
alias vm3='ssh s@192.168.122.246'
alias apivm='ssh s@192.168.122.16'
```

Check:
```bash
vm1 'hostname; ip a | grep 192.168.122'
vm2 'hostname; ip a | grep 192.168.122'
vm3 'hostname; ip a | grep 192.168.122'
apivm 'hostname; ip a | grep 192.168.122'
```

---

# A) Postgres (pg_auto_failover)

## 1) Copy compose files to VMs

**On laptop**
```bash
# VM3 monitor
scp -r ~/Desktop/db-ha/postgres/docker-compose/monitor vm3:/home/s/db/

# VM1 node
ssh vm1 'mkdir -p /home/s/db/node'
scp ~/Desktop/db-ha/postgres/docker-compose/node-vm1/docker-compose.yml vm1:/home/s/db/node/docker-compose.yml

# VM2 node
ssh vm2 'mkdir -p /home/s/db/node'
scp ~/Desktop/db-ha/postgres/docker-compose/node-vm2/docker-compose.yml vm2:/home/s/db/node/docker-compose.yml

# VM3 node
ssh vm3 'mkdir -p /home/s/db/node3'
scp ~/Desktop/db-ha/postgres/docker-compose/node-vm3/docker-compose.yml vm3:/home/s/db/node3/docker-compose.yml
```

Check:
```bash
vm3 'ls -la /home/s/db/monitor && sed -n "1,120p" /home/s/db/monitor/docker-compose.yml'
vm1 'ls -la /home/s/db/node && sed -n "1,160p" /home/s/db/node/docker-compose.yml'
vm2 'ls -la /home/s/db/node && sed -n "1,160p" /home/s/db/node/docker-compose.yml'
vm3 'ls -la /home/s/db/node3 && sed -n "1,200p" /home/s/db/node3/docker-compose.yml'
```

---

## 2) Start monitor (VM3)

**On VM3**
```bash
cd /home/s/db/monitor
docker compose up -d
docker logs -f --tail=20 pg-monitor
```

Wait/Chec
```bash
docker compose exec -u postgres pg-monitor psql -d pg_auto_failover -c "select 1;"
```

---

## 3) Allow nodes to connect to monitor (pg_hba.conf) (VM3 monitor)

**On VM3**
```bash
docker exec -u postgres -it pg-monitor bash -lc '
cat >> /var/lib/postgres/pgaf/pg_hba.conf <<EOF

host  pg_auto_failover  autoctl_node  192.168.122.18/32   trust
host  pg_auto_failover  autoctl_node  192.168.122.233/32  trust
host  pg_auto_failover  autoctl_node  192.168.122.246/32  trust
EOF
tail -n 30 /var/lib/postgres/pgaf/pg_hba.conf
'
```

Check :
```bash
docker compose exec -u postgres pg-monitor psql -d pg_auto_failover -c "select pg_reload_conf();"
```

---

## 4) Start VM1 Postgres node (initial primary)

**On VM1**
```bash
cd /home/s/db/node
docker compose up -d
docker logs -f --tail=20 pg-node1
```

Wait/Check (from VM3 monitor):
```bash
cd /home/s/db/monitor
docker compose exec -u postgres pg-monitor pg_autoctl show state --pgdata /var/lib/postgres/pgaf
```

---

## 5) Start VM2 Postgres node (standby)

**On VM2**
```bash
cd /home/s/db/node
docker compose up -d
docker logs -f --tail=30 pg-node2
```

Wait/Check (from VM3 monitor):
```bash
cd /home/s/db/monitor
docker compose exec -u postgres pg-monitor pg_autoctl show state --pgdata /var/lib/postgres/pgaf
```

---

## 6) Start VM3 Postgres node (standby)

**On VM3**
```bash
cd /home/s/db/node3
docker compose up -d
docker logs -f --tail=30 pg-node3
```

Wait/Check (ports + final state):
```bash
docker ps --format "table {{.Names}}\t{{.Ports}}"
cd /home/s/db/monitor
docker compose exec -u postgres pg-monitor pg_autoctl show state --pgdata /var/lib/postgres/pgaf
```

---

## 7) PostgreSQL final check (client connectivity from laptop or API VM)

**On laptop (or API VM)**
```bash
psql "host=192.168.122.18,192.168.122.233,192.168.122.246 port=5432 dbname=postgres user=postgres sslmode=disable target_session_attrs=read-write" \
  -c "select inet_server_addr() as primary_ip, pg_is_in_recovery() as in_recovery;"
```

---

# B) Redis (Replication + Sentinel)

## 8) Kernel setting (ALL redis VMs)

**On VM1**
```bash
sudo sysctl -w vm.overcommit_memory=1
echo 'vm.overcommit_memory=1' | sudo tee /etc/sysctl.d/99-redis.conf
sudo sysctl --system
```

Repeat for **VM2** and **VM3**:
```bash
vm2 'sudo sysctl -w vm.overcommit_memory=1; echo vm.overcommit_memory=1 | sudo tee /etc/sysctl.d/99-redis.conf; sudo sysctl --system'
vm3 'sudo sysctl -w vm.overcommit_memory=1; echo vm.overcommit_memory=1 | sudo tee /etc/sysctl.d/99-redis.conf; sudo sysctl --system'
```

Check:
```bash
vm1 'sysctl vm.overcommit_memory'
vm2 'sysctl vm.overcommit_memory'
vm3 'sysctl vm.overcommit_memory'
```

---

## 9) Prepare Redis directory (ALL redis VMs)

**On VM1**
```bash
mkdir -p /home/s/redis-ha
```

Repeat for **VM2** and **VM3**:
```bash
vm2 'mkdir -p /home/s/redis-ha'
vm3 'mkdir -p /home/s/redis-ha'
```

---

## 10) Stage 1 — Start Redis master (VM1)

**On VM1**
```bash
cd /home/s/redis-ha

cat > docker-compose.yml <<'YAML'
services:
  redis:
    image: redis:7.2-alpine
    container_name: redis1
    network_mode: host
    command: >
      redis-server
      --bind 0.0.0.0
      --port 6379
      --protected-mode no
      --appendonly no
      --save ""
YAML

docker compose up -d
```

Check:
```bash
docker exec -it redis1 redis-cli -p 6379 INFO replication
```

---

## 11) Stage 1 — Start Redis replica (VM2)

**On VM2**
```bash
cd /home/s/redis-ha

cat > docker-compose.yml <<'YAML'
services:
  redis:
    image: redis:7.2-alpine
    container_name: redis2
    network_mode: host
    command: >
      redis-server
      --bind 0.0.0.0
      --port 6379
      --protected-mode no
      --appendonly no
      --save ""
      --replicaof 192.168.122.18 6379
YAML

docker compose up -d
```

Check:
```bash
docker exec -it redis2 redis-cli -p 6379 INFO replication
```

---

## 12) Stage 1 — Start Redis replica (VM3)

**On VM3**
```bash
cd /home/s/redis-ha

cat > docker-compose.yml <<'YAML'
services:
  redis:
    image: redis:7.2-alpine
    container_name: redis3
    network_mode: host
    command: >
      redis-server
      --bind 0.0.0.0
      --port 6379
      --protected-mode no
      --appendonly no
      --save ""
      --replicaof 192.168.122.18 6379
YAML

docker compose up -d
```

Check:
```bash
docker exec -it redis3 redis-cli -p 6379 INFO replication
```

---

## 13) Stage 1 — Validate Redis replication (VM1)

**On VM1**
```bash
docker exec -it redis1 redis-cli -p 6379 INFO replication
```

---

## 14) Stage 2 — Create Sentinel config (ALL redis VMs)

**On VM1**
```bash
cd /home/s/redis-ha
mkdir -p sentinel-data

cat > sentinel-data/sentinel.conf <<'EOF'
port 26379
bind 0.0.0.0
protected-mode no

sentinel monitor mymaster 192.168.122.18 6379 2
sentinel down-after-milliseconds mymaster 5000
sentinel failover-timeout mymaster 60000
sentinel parallel-syncs mymaster 1
EOF

chmod 777 sentinel-data
chmod 666 sentinel-data/sentinel.conf
```

Repeat for **VM2** and **VM3**:
```bash
vm2 'cd /home/s/redis-ha && mkdir -p sentinel-data && cat > sentinel-data/sentinel.conf <<EOF
port 26379
bind 0.0.0.0
protected-mode no

sentinel monitor mymaster 192.168.122.18 6379 2
sentinel down-after-milliseconds mymaster 5000
sentinel failover-timeout mymaster 60000
sentinel parallel-syncs mymaster 1
EOF
chmod 777 sentinel-data
chmod 666 sentinel-data/sentinel.conf
'
vm3 'cd /home/s/redis-ha && mkdir -p sentinel-data && cat > sentinel-data/sentinel.conf <<EOF
port 26379
bind 0.0.0.0
protected-mode no

sentinel monitor mymaster 192.168.122.18 6379 2
sentinel down-after-milliseconds mymaster 5000
sentinel failover-timeout mymaster 60000
sentinel parallel-syncs mymaster 1
EOF
chmod 777 sentinel-data
chmod 666 sentinel-data/sentinel.conf
'
```

---

## 15) Stage 2 — Start Sentinel (ALL redis VMs)

**On VM1**
```bash
cd /home/s/redis-ha

cat >> docker-compose.yml <<'YAML'

  sentinel:
    image: redis:7.2-alpine
    container_name: sentinel1
    network_mode: host
    user: "0:0"
    command: ["redis-server", "/data/sentinel.conf", "--sentinel"]
    volumes:
      - ./sentinel-data:/data
YAML

docker compose up -d
```

**On VM2**
```bash
cd /home/s/redis-ha

cat >> docker-compose.yml <<'YAML'

  sentinel:
    image: redis:7.2-alpine
    container_name: sentinel2
    network_mode: host
    user: "0:0"
    command: ["redis-server", "/data/sentinel.conf", "--sentinel"]
    volumes:
      - ./sentinel-data:/data
YAML

docker compose up -d
```

**On VM3**
```bash
cd /home/s/redis-ha

cat >> docker-compose.yml <<'YAML'

  sentinel:
    image: redis:7.2-alpine
    container_name: sentinel3
    network_mode: host
    user: "0:0"
    command: ["redis-server", "/data/sentinel.conf", "--sentinel"]
    volumes:
      - ./sentinel-data:/data
YAML

docker compose up -d
```

Check (quorum from VM1):
```bash
vm1 'docker exec -it sentinel1 redis-cli -p 26379 SENTINEL sentinels mymaster'
```

---

# C) MongoDB (Replica Set)

## 16) Start MongoDB on all VMs

**On VM1**
```bash
mkdir -p /home/s/mongo-rs
cd /home/s/mongo-rs

cat > docker-compose.yml <<'YAML'
services:
  mongo:
    image: mongo:7
    container_name: mongo1
    restart: unless-stopped
    command: mongod --replSet rs0 --bind_ip_all
    ports:
      - "27017:27017"
    volumes:
      - mongo1_data:/data/db

volumes:
  mongo1_data:
YAML

docker compose up -d
```

**On VM2**
```bash
mkdir -p /home/s/mongo-rs
cd /home/s/mongo-rs

cat > docker-compose.yml <<'YAML'
services:
  mongo:
    image: mongo:7
    container_name: mongo2
    restart: unless-stopped
    command: mongod --replSet rs0 --bind_ip_all
    ports:
      - "27017:27017"
    volumes:
      - mongo2_data:/data/db

volumes:
  mongo2_data:
YAML

docker compose up -d
```

**On VM3**
```bash
mkdir -p /home/s/mongo-rs
cd /home/s/mongo-rs

cat > docker-compose.yml <<'YAML'
services:
  mongo:
    image: mongo:7
    container_name: mongo3
    restart: unless-stopped
    command: mongod --replSet rs0 --bind_ip_all
    ports:
      - "27017:27017"
    volumes:
      - mongo3_data:/data/db

volumes:
  mongo3_data:
YAML

docker compose up -d
```

Check:
```bash
vm1 'docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep mongo'
vm2 'docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep mongo'
vm3 'docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep mongo'
```

---

## 17) Initialize replica set (once from VM1)

**On VM1**
```bash
docker exec -it mongo1 mongosh
```

In mongosh:
```javascript
rs.initiate({
  _id: "rs0",
  members: [
    { _id: 0, host: "192.168.122.18:27017" },
    { _id: 1, host: "192.168.122.233:27017" },
    { _id: 2, host: "192.168.122.246:27017" }
  ]
})
rs.status()
exit
```

---

# D) goAPI VM (connectivity + container)

## 18) Verify network connectivity (API VM)

**On API VM**
```bash
# PostgreSQL nodes
nc -vz 192.168.122.18 5432
nc -vz 192.168.122.233 5432
nc -vz 192.168.122.246 5432

# Redis Sentinel
nc -vz 192.168.122.18 26379
nc -vz 192.168.122.233 26379
nc -vz 192.168.122.246 26379

# MongoDB
nc -vz 192.168.122.18 27017
nc -vz 192.168.122.233 27017
nc -vz 192.168.122.246 27017
```

---

## 19) Confirm current PostgreSQL primary (VM3 monitor)

**On VM3**
```bash
cd /home/s/db/monitor
docker compose exec -u postgres pg-monitor pg_autoctl show state --pgdata /var/lib/postgres/pgaf
```

---

## 20) Create UTF-8 database (once on current Postgres primary)

**On current primary (example: VM3 / pg-node3)**
```bash
docker exec -u postgres -it pg-node3 psql -d postgres -c "CREATE DATABASE appdb_utf8 OWNER postgres TEMPLATE template0 ENCODING 'UTF8' LC_COLLATE 'C' LC_CTYPE 'C';"
```

---

## 21) Allow API VM in pg_hba.conf (ALL Postgres nodes)

**On VM1**
```bash
docker exec -u postgres -it pg-node1 bash -lc '
cat >> /var/lib/postgres/pgaf/pg_hba.conf <<EOF

host  all  postgres  192.168.122.16/32  trust
EOF
'
docker exec -u postgres -it pg-node1 psql -d postgres -c "select pg_reload_conf();"
```

**On VM2**
```bash
docker exec -u postgres -it pg-node2 bash -lc '
cat >> /var/lib/postgres/pgaf/pg_hba.conf <<EOF

host  all  postgres  192.168.122.16/32  trust
EOF
'
docker exec -u postgres -it pg-node2 psql -d postgres -c "select pg_reload_conf();"
```

**On VM3**
```bash
docker exec -u postgres -it pg-node3 bash -lc '
cat >> /var/lib/postgres/pgaf/pg_hba.conf <<EOF

host  all  postgres  192.168.122.16/32  trust
EOF
'
docker exec -u postgres -it pg-node3 psql -d postgres -c "select pg_reload_conf();"
```

---

## 22) Enforce UTF-8 client encoding (once on current primary)

**On current primary**
```bash
docker exec -u postgres -it pg-node3 psql -d postgres -c "ALTER DATABASE appdb_utf8 SET client_encoding TO 'UTF8';"
docker exec -u postgres -it pg-node3 psql -d postgres -c "ALTER ROLE postgres SET client_encoding TO 'UTF8';"
```

---

## 23) Test Postgres HA connectivity (API VM)

**On API VM**
```bash
psql "host=192.168.122.18,192.168.122.233,192.168.122.246 port=5432 dbname=appdb_utf8 user=postgres sslmode=disable target_session_attrs=read-write" \
  -c "select inet_server_addr(), pg_is_in_recovery();"
```

---

## 24) Create API env file (API VM)

**On API VM**
```bash
mkdir -p /home/s/goapi
cd /home/s/goapi

cat > default.env <<'ENV'
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
ENV
```

---

## 25) Start API container (API VM)

**On API VM**
```bash
cd /home/s/goapi

cat > docker-compose.yml <<'YAML'
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
YAML

docker compose up -d
```

Check:
```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep goapi
docker logs -f --tail=200 goapi
```

---

# E) Final checks (all subsystems)

## 26) Postgres (monitor)

**On VM3**
```bash
cd /home/s/db/monitor
docker compose exec -u postgres pg-monitor pg_autoctl show state --pgdata /var/lib/postgres/pgaf
```

## 27) Redis (master discovery)

**On VM1**
```bash
docker exec -it sentinel1 redis-cli -p 26379 SENTINEL get-master-addr-by-name mymaster
```

## 28) Mongo (rs members)

**On VM1**
```bash
docker exec -it mongo1 mongosh --quiet --eval 'rs.status().members.map(m => ({name:m.name, state:m.stateStr}))'
```
