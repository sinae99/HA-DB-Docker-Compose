# Redis HA on 3 VMs with Docker Compose (Redis + Sentinel)

------------------------------------------------------------------------


-   **3 Redis servers** (one per VM)
    -   1 master
    -   2 replicas
-   **3 Redis Sentinel processes** (one per VM)
    -   quorum = 2
    -   automatic failover and reconfiguration

------------------------------------------------------------------------

## VM Inventory


  VM1 ----> 192.168.122.18 ---->     Redis + Sentinel
  VM2 ----> 192.168.122.233 ---->    Redis + Sentinel
  VM3 ----> 192.168.122.246 ---->    Redis + Sentinel

### Ports

-   Redis: **6379**
-   Sentinel: **26379**

------------------------------------------------------------------------

## Prerequisites (ALL VMs)

-   Docker installed
-   Docker Compose installed
-   Private networking between VMs
-   Ports 6379 and 26379 open between VMs

### Kernel setting (recommended)

``` bash
sudo sysctl -w vm.overcommit_memory=1
echo 'vm.overcommit_memory=1' | sudo tee /etc/sysctl.d/99-redis.conf
sudo sysctl --system
```

------------------------------------------------------------------------

## Directory Layout

Used on **every VM**:

    /home/s/redis-ha/
    ├── docker-compose.yml
    └── sentinel-data/
        └── sentinel.conf

------------------------------------------------------------------------

## Step 1 --- Start Redis MASTER (VM1)

``` bash
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

Verify:

``` bash
docker exec -it redis1 redis-cli -p 6379 INFO replication
```

Expected:

    role:master

------------------------------------------------------------------------

## Step 2 --- Start Redis REPLICA (VM2)

``` bash
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

Verify:

``` bash
docker exec -it redis2 redis-cli -p 6379 INFO replication
```

------------------------------------------------------------------------

## Step 3 --- Start Redis REPLICA (VM3)

Same as VM2, but pointing to VM1:

``` bash
--replicaof 192.168.122.18 6379
```

------------------------------------------------------------------------

## Step 4 --- Add Sentinel (ALL VMs)

Sentinel must be able to **write its config** at runtime.

### Create writable Sentinel config

``` bash
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

### Add Sentinel service

Example (VM1):

``` yaml
sentinel:
  image: redis:7.2-alpine
  container_name: sentinel1
  network_mode: host
  user: "0:0"
  command: ["redis-server", "/data/sentinel.conf", "--sentinel"]
  volumes:
    - ./sentinel-data:/data
```

Repeat for VM2 (`sentinel2`) and VM3 (`sentinel3`).

------------------------------------------------------------------------

## Step 5 --- Verify Sentinel Quorum

On VM1:

``` bash
docker exec -it sentinel1 redis-cli -p 26379 SENTINEL sentinels mymaster
```

Expected: **2 other sentinels detected**.

------------------------------------------------------------------------

## Step 6 --- Failover Test

### Stop master

``` bash
docker stop redis1
```

### Observe promotion

``` bash
docker exec -it sentinel2 redis-cli -p 26379 SENTINEL get-master-addr-by-name mymaster
```

Expected: master changes to VM2 or VM3.

### Verify roles

``` bash
docker exec -it redis2 redis-cli INFO replication
```

Expected:

    role:master

------------------------------------------------------------------------

## Step 7 --- Bring Old Master Back

``` bash
docker start redis1
```

Verify it rejoined as replica:

``` bash
docker exec -it redis1 redis-cli ROLE
```

Expected:

    slave

------------------------------------------------------------------------

## Why Sentinel is Started LAST

Sentinel does **not** create Redis replication.

Correct order:

1.  Start Redis master
2.  Add replicas
3.  Verify replication
4.  Start Sentinel
5.  Test failover

Sentinel is **control plane**, Redis is **data plane**.

