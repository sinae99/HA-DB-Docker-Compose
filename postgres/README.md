# PostgreSQL + pg_auto_failover + 3 VM + Docker Compose

High-availability PostgreSQL using **pg_auto_failover** across **3 Ubuntu VMs**, running on **Docker Compose**.
No Kubernetes

---

## Architecture

- **VM1 (192.168.122.18)**
  PostgreSQL node (`pg-node1`) — primary or standby

- **VM2 (192.168.122.233)**
  PostgreSQL node (`pg-node2`) — primary or standby

- **VM3 (192.168.122.246)**
  - pg_auto_failover **Monitor** (`pg-monitor`) on port **5432**
  - PostgreSQL node (`pg-node3`) exposed on host port **5433**

Exactly **one primary**, others are **standbys**.
Failover is **automatic**.

---

## Repository Structure

```
postgres/
├── README.md
├── env/
├── configs/
├── scripts/
└── docs/
```

---

## Bring-up Order

### 0) Copy docker-compose files
Copy the correct compose file to each VM:

| VM | Source | Destination |
|----|-------|-------------|
| VM3 (monitor) | `configs/monitor/docker-compose.yml` | `/home/s/db/monitor/docker-compose.yml` |
| VM1 (node) | `configs/node-vm1/docker-compose.yml` | `/home/s/db/node/docker-compose.yml` |
| VM2 (node) | `configs/node-vm2/docker-compose.yml` | `/home/s/db/node/docker-compose.yml` |
| VM3 (node) | `configs/node-vm3/docker-compose.yml` | `/home/s/db/node3/docker-compose.yml` |

---

### 1) Start monitor (VM3)
```bash
bash scripts/10-monitor-vm3.sh
```

### 2) Start VM1 node
```bash
bash scripts/20-node-vm1.sh
```

### 3) Start VM2 node
```bash
bash scripts/30-node-vm2.sh
```

### 4) Start VM3 node
```bash
bash scripts/40-node-vm3.sh
```

---

## Verify Cluster
Run on **VM3**:
```bash
bash scripts/50-verify.sh
```

Or directly:
```bash
cd /home/s/db/monitor
docker compose exec -u postgres pg-monitor pg_autoctl show state --pgdata /var/lib/postgres/pgaf
```

Expected:
- 1 primary
- 2 secondaries

---

## Failover Test
Stop the current primary container on its VM:
```bash
bash scripts/60-failover-test.sh vm1
```

Watch promotion from the monitor:
```bash
cd /home/s/db/monitor
docker compose exec -u postgres pg-monitor pg_autoctl show state --pgdata /var/lib/postgres/pgaf
```

---

## Rejoin Old Primary
On the old primary VM:
```bash
bash scripts/70-rejoin-old-primary.sh pg-node1 soft
```

If needed (destructive, guaranteed):
```bash
bash scripts/70-rejoin-old-primary.sh pg-node1 clean
```

---

## Application Connectivity

**No proxy, no VIP.**
Use a **multi-host libpq DSN** with `target_session_attrs=read-write`.


Example DSN for app that want to connect to postgres :
```
host=192.168.122.18,192.168.122.233
port=5432
sslmode=disable
target_session_attrs=read-write
```

---

## Reset Everything
On any VM:
```bash
bash scripts/99-clean-reset.sh
```

