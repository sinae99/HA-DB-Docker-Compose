# Postgres HA Notes

## Overview
**PostgreSQL + pg_auto_failover** to provide **high availability (HA)** across three virtual machines (**no kubernetes**)



No external proxy is used

---

## Infrastructure

### Virtual Machines
| VM | Hostname | IP |
|----|----------|----|
| VM1 | ubuntu-server-1 | 192.168.122.18 |
| VM2 | ubuntu-server-2 | 192.168.122.233 |
| VM3 | ubuntu-server-3 | 192.168.122.246 |

All VMs run Ubuntu and Docker.

---

## Components

### pg_auto_failover Monitor
- Runs **only on VM3**
- Responsible for:
  - Tracking node health
  - Managing primary/standby roles
  - Orchestrating automatic failover
- Does **not** store application data

### PostgreSQL Nodes
- One PostgreSQL instance per VM
- Roles:
  - **Primary**: exactly one node, accepts read + write
  - **Standby (Replica)**: one or more nodes, read-only
- Standbys continuously replicate data from the primary

---

## Data & Replication Model

- There is **one logical database**, not three independent databases
- Writes happen **only on the Primary**
- Replicas receive data automatically via PostgreSQL replication
- All nodes eventually contain the same data

### Write Flow
1. Application sends a write query
2. Query is executed on the **Primary**
3. Changes are streamed to all Replicas

### Read Flow
- Reads may be served from:
  - Primary (default)
  - Replicas (optional, if application chooses)

---

## Failover Behavior

- If the Primary node becomes unavailable:
  1. pg_auto_failover detects failure
  2. One Standby is promoted to **Primary**
  3. Remaining nodes reconfigure as Standbys
- No manual intervention required
- No data loss (within PostgreSQL replication guarantees)

---

## Application Connectivity

### Application Stack
- Language: **Go**
- ORM: **GORM**
- Driver: `gorm.io/driver/postgres` (uses pgx internally)
- Connection format: **libpq-style DSN**

### Connection Strategy (No VIP, No Proxy)
The application connects using a **multi-host DSN**:

- All database node IPs are listed
- The client automatically selects the current Primary
- This works using:
  ```
  target_session_attrs=read-write
  ```

### Example (write connection)
```
host=192.168.122.18,192.168.122.233,192.168.122.246
port=5432
user=...
password=...
dbname=...
sslmode=disable
target_session_attrs=read-write
```

---

## SSL
- SSL is **disabled** for this setup
- All traffic is assumed to be on a trusted internal network

---

## Directory Layout (per VM)

### Monitor (VM3 only)
```
/home/s/db/monitor
├── docker-compose.yml
└── data/
```

### Node (VM1, VM2, VM3)
```
/home/s/db/node
├── docker-compose.yml
└── data/
```

---

## Bring-up Order

1. Start monitor on VM3
2. Start node on VM1 → becomes Primary
3. Start node on VM2 → Standby
4. Start node on VM3 → Standby
5. Verify state from monitor

---

## Key Concepts

- **Availability**: database remains usable if one VM fails
- **Primary**: only node that can write
- **Replica**: read-only copy of the primary
- **Failover**: automatic promotion of a replica
- **DSN**: database connection string


