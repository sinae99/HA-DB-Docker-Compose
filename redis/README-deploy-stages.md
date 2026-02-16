# Redis HA -- Deployment Stages


## Repository Structure Reference

    .
    ├── README.md
    ├── redis-nodes
    │   ├── vm1
    │   │   └── docker-compose.yml
    │   ├── vm2
    │   │   └── docker-compose.yml
    │   └── vm3
    │       └── docker-compose.yml
    └── sentinel
        ├── config
        │   └── sentinel.conf
        ├── vm1
        │   └── docker-compose.yml
        ├── vm2
        │   └── docker-compose.yml
        └── vm3
            └── docker-compose.yml

------------------------------------------------------------------------

## Deployment Philosophy

Deployment is intentionally split into **two stages**:

1.  **Redis Bootstrap (data plane)**
2.  **Sentinel Enablement (control plane)**

------------------------------------------------------------------------

## Stage 1 --- Redis

### Goal

Establish a stable Redis replication topology: - 1 master - 2 replicas

At this stage, **Sentinel is NOT running**.

------------------------------------------------------------------------

### Step 1.1 --- Deploy Redis master (VM1)

On your local machine:

``` bash
scp redis-nodes/vm1/docker-compose.yml vm1:/home/s/redis-ha/docker-compose.yml
```

On **VM1**:

``` bash
cd /home/s/redis-ha
docker compose up -d
```

Verify:

``` bash
docker exec -it redis1 redis-cli INFO replication
```

Expected:

    role:master

------------------------------------------------------------------------

### Step 1.2 --- Deploy Redis replica (VM2)

``` bash
scp redis-nodes/vm2/docker-compose.yml vm2:/home/s/redis-ha/docker-compose.yml
```

On **VM2**:

``` bash
docker compose up -d
docker exec -it redis2 redis-cli INFO replication
```

Expected: - `role:slave` - `master_host` points to VM1

------------------------------------------------------------------------

### Step 1.3 --- Deploy Redis replica (VM3)

``` bash
scp redis-nodes/vm3/docker-compose.yml vm3:/home/s/redis-ha/docker-compose.yml
```

On **VM3**:

``` bash
docker compose up -d
docker exec -it redis3 redis-cli INFO replication
```

Expected: - `role:slave` - `master_host` points to VM1

------------------------------------------------------------------------

### Step 1.4 --- Validate replication

On **VM1**:

``` bash
docker exec -it redis1 redis-cli INFO replication
```

Expected: - `connected_slaves:2`

Only proceed to Stage 2 after this is correct.

------------------------------------------------------------------------

## Stage 2 --- Enable High Availability (Sentinel)

### Goal

Enable automatic failover and master re-election using Redis Sentinel.

------------------------------------------------------------------------

### Step 2.1 --- Deploy Sentinel configuration

On each VM, create the Sentinel data directory and config:

``` bash
mkdir -p /home/s/redis-ha/sentinel-data
```

Copy the config:

``` bash
scp sentinel/config/sentinel.conf vmX:/home/s/redis-ha/sentinel-data/sentinel.conf
```

> Each VM must have its **own writable copy** of `sentinel.conf`.

------------------------------------------------------------------------

### Step 2.2 --- Replace compose files with Sentinel-enabled versions

On your local machine:

``` bash
scp sentinel/vm1/docker-compose.yml vm1:/home/s/redis-ha/docker-compose.yml
scp sentinel/vm2/docker-compose.yml vm2:/home/s/redis-ha/docker-compose.yml
scp sentinel/vm3/docker-compose.yml vm3:/home/s/redis-ha/docker-compose.yml
```

------------------------------------------------------------------------

### Step 2.3 --- Start Sentinel on all VMs

On **each VM**:

``` bash
cd /home/s/redis-ha
docker compose up -d
```

Verify Sentinel is running:

``` bash
docker ps
```

------------------------------------------------------------------------

### Step 2.4 --- Verify Sentinel quorum

On **VM1**:

``` bash
docker exec -it sentinel1 redis-cli -p 26379 SENTINEL sentinels mymaster
```

Expected: - Two other Sentinels listed - Quorum achieved

------------------------------------------------------------------------

## Stage 3 --- Failover Test (MANDATORY)

### Step 3.1 --- Identify current master

``` bash
docker exec -it sentinel2 redis-cli -p 26379 SENTINEL get-master-addr-by-name mymaster
```

------------------------------------------------------------------------

### Step 3.2 --- Simulate master failure

On the master VM:

``` bash
docker stop redis1
```

------------------------------------------------------------------------

### Step 3.3 --- Observe new master election

``` bash
docker exec -it sentinel2 redis-cli -p 26379 SENTINEL get-master-addr-by-name mymaster
```

Expected: - Master IP changes to VM2 or VM3

------------------------------------------------------------------------

### Step 3.4 --- Verify roles

On the new master:

``` bash
docker exec -it redisX redis-cli INFO replication
```

Expected:

    role:master

On replicas:

    role:slave

------------------------------------------------------------------------

## Stage 4 --- Rejoin Old Master

``` bash
docker start redis1
```

Verify it rejoined as a replica:

``` bash
docker exec -it redis1 redis-cli ROLE
```

Expected:

    slave
