# Failover Test — pg_auto_failover


## Cluster

| VM | IP | Container |
|---|---|---|
| VM1 | ip = 192.168.122.18 | `pg-node1` |
| VM2 | ip = 192.168.122.233 | `pg-node2` |
| VM3 | ip = 192.168.122.246 | `pg-monitor` (monitor) + `pg-node3` (node) |

- Monitor: VM3 `pg-monitor` on host port **5500**
- Nodes use Postgres internal port **5432**.

---

## Goal

Prove that when the **current primary** goes down, **pg_auto_failover promotes a standby** to primary automatically.

psql "postgres://autoctl_node@192.168.122.246:5500/pg_auto_failover?sslmode=disable" -c "select 1;"


---

## 1) Identify the current primary (run on VM3)

```bash
cd /home/s/db/monitor
docker compose exec -u postgres pg-monitor pg_autoctl show state --pgdata /var/lib/postgres/pgaf
```

### Example output (before failover)
```text
node_68  192.168.122.18:5432  primary
node_69  192.168.122.233:5432  secondary
node_70  192.168.122.246:5432  secondary
```
---

## 2) Stop the primary node container (run on the primary VM)

### If primary is VM1:
```bash
docker stop pg-node1
```

(If the primary is VM2 instead, stop `pg-node2` on VM2.)

---

## 3) Watch the monitor promote a new primary (run on VM3)

Run this command repeatedly:

```bash
cd /home/s/db/monitor
docker compose exec -u postgres pg-monitor pg_autoctl show state --pgdata /var/lib/postgres/pgaf
```

### What you should see

Typical transitions on the old primary:
- `primary` → `draining` → `demoted`

Then a standby becomes:
- `secondary` → `primary`

### Example output (after failover)
```text
node_68  192.168.122.18:5432  demoted
node_69  192.168.122.233:5432  primary
node_70  192.168.122.246:5432  secondary
```

In our test:
- **VM2 (192.168.122.233) was promoted to primary**
- Timeline changed from **TLI 1 → TLI 2**

---

## 4) Confirm roles using SQL (no writes)

### On the new primary VM (example: VM2)
```bash
docker exec -it pg-node2 psql -U postgres -d postgres -c "select pg_is_in_recovery();"
```

Expected:
- `f` (false) = primary

### On a standby VM (example: VM3 node)
```bash
docker exec -it pg-node3 psql -U postgres -d postgres -c "select pg_is_in_recovery();"
```

Expected:
- `t` (true) = standby

---

# Rejoining 

### Step 1 — Identify stale node metadata (Monitor)

On **VM3**:

```bash
cd /home/s/db/monitor
docker compose exec -u postgres pg-monitor psql -d pg_auto_failover -c "
select nodeid, nodename, nodehost, nodeport, reportedstate, goalstate
from pgautofailover.node
order by nodeid;
"
```

Example stale entry:

```
nodeid | nodehost           | nodeport | goalstate
------+--------------------+----------+-----------
1      | 192.168.122.18    | 5432     | demoted
```

---
### ( if "pgdata" is gone and there is need to a new registration )

## Step 2 — Delete the old node from the monitor

On **VM3**:

```bash
docker compose exec -u postgres pg-monitor psql -d pg_auto_failover -c "
delete from pgautofailover.node
where nodehost = '192.168.122.18'
  and nodeport = 5432;
"
```

Confirm removal:

```bash
docker compose exec -u postgres pg-monitor \
  pg_autoctl show state --pgdata /var/lib/postgres/pgaf
```

The node must no longer appear.

---

### Step 3 — Recreate the node container

On the **former primary VM**:

```bash
cd /home/s/db/node
docker compose down
docker volume rm node_node1_pgdata 2>/dev/null || true
docker compose up -d
```

Follow logs:

```bash
docker logs -f --tail=200 pg-node1
```

Expected log sequence:

- Node registered with the monitor
- State: `wait_standby`
- `pg_basebackup` from current primary
- `catchingup → secondary`

---

### Step 4 — Verify final cluster state

On **VM3**:

```bash
cd /home/s/db/monitor
docker compose exec -u postgres pg-monitor \
  pg_autoctl show state --pgdata /var/lib/postgres/pgaf
```

Expected end state:

- 1 primary
- 2 secondaries
- Correct ports:
  - VM1 → 5432
  - VM2 → 5432
  - VM3 → 5432



Note: The monitor’s PostgreSQL runs on port 5432 inside the container, but is exposed on host port 5500.
Nodes connect to the monitor using 192.168.122.246:5500.


---

