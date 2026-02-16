# My Notes
## What I have
- I have **3 virtual machines**
  - ubuntu24.04-1
  - ubuntu24.04-2
  - ubuntu24.04-3
- All of them:
  - Can SSH to each other
  - Can reach each other over the network
  - Have **Docker + Docker Compose**

- I want **PostgreSQL High Availability (HA)**


## Initial confusion I had
- I thought:
  - Maybe PostgreSQL can be “HA” just by running multiple containers
  - Maybe data can be written to all nodes
  - Maybe Docker Compose examples on GitHub are enough
- wasn’t sure that:
  - What pg_auto_failover actually is
  - Whether it’s a container, a binary, or something else
  - How nodes discover each other
  - How reads and writes really work in HA Postgres

---

## Important clarification
### Replication ≠ HA
- Simple Docker Compose (primary + replica):
  - No automatic failover
  - Manual promotion
  - Not production HA

- **HA requires a “brain”** that decides:
  - Who is primary
  - When to promote a standby

---

## What is pg_auto_failover ?
- An **official PostgreSQL HA solution**
- Provides:
  - Single-primary PostgreSQL
  - Automatic failover

- It is:
  - A PostgreSQL extension
  - A control process (`pg_autoctl`)

- It is **not**:
  - Multi-master
  - Write-to-all-nodes
  - A load balancer

---

## The image I use
```
citusdata/pg_auto_failover:15
```

Why:
- Already includes:
  - PostgreSQL
  - pg_auto_failover
  - pg_autoctl
- No need to build custom images
- This is the correct and intended way

---

## What PGDATA is (very important)
- `PGDATA` = **where PostgreSQL stores everything**
  - Databases
  - WAL files
  - Metadata
- If PGDATA is gone → data is gone
- In Docker:
  - PGDATA **must be mounted as a volume**
- pg_auto_failover **controls PGDATA**
  - I must NOT init or start Postgres manually

---

## Final architecture I chose

### Machines and roles

| VM | What runs |
|----|----------|
| ubuntu24.04-1 | PostgreSQL node (data) |
| ubuntu24.04-2 | PostgreSQL node (data) |
| ubuntu24.04-3 | PostgreSQL node (data) + **Monitor** |

---

## Containers per VM

### VM1
- `pg_node1`
  - PostgreSQL + pg_auto_failover
  - Becomes **PRIMARY** initially

### VM2
- `pg_node2`
  - PostgreSQL + pg_auto_failover
  - **STANDBY**

### VM3
- `pg_node3`
  - PostgreSQL + pg_auto_failover
  - **STANDBY**
- `pg_monitor`
  - PostgreSQL monitor database

---

## How nodes find each other
- Everything goes through the **monitor**
- The monitor is the **single source of truth**

---

## How configuration happens
- Docker Compose starts containers
- HA setup is done via:
```
docker exec -it <container> pg_autoctl ...
```

---

## Write behavior
- Writes go to **ONE node only**
- Always the **current primary**
- WAL is streamed to standbys

---

## Read behavior
- Read from primary (simple)
- Or read from standbys (needs routing)

---

## Failover behavior
- Monitor detects failure
- Standby is promoted
- Cluster heals automatically

---

## Final decision / plan
- Use **pg_auto_failover**
- Use **citusdata/pg_auto_failover:15**
- One Docker Compose file per VM
- Monitor on VM3
- Configure via `pg_autoctl`


