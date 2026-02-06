# Failover Test — pg_auto_failover


## Cluster

| VM | IP | Container |
|---|---|---|
| VM1 | 192.168.122.18 | `pg-node1` |
| VM2 | 192.168.122.233 | `pg-node2` |
| VM3 | 192.168.122.246 | `pg-monitor` (monitor) + `pg-node3` (node) |

- Monitor: VM3 `pg-monitor` on host port **5432**
- VM3 node: `pg-node3` on host port **5433**
- Nodes use Postgres internal port **5432**.

---

## Goal

Prove that when the **current primary** goes down, **pg_auto_failover promotes a standby** to primary automatically.

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

## Rejoin the old primary as a standby

Because the old primary may have diverged, the simplest clean rejoin is to wipe its node volume and re-add it.

### On the old primary VM (example: VM1)
```bash
cd /home/s/db/node
docker compose down
docker volume rm node_node1_pgdata 2>/dev/null || true
docker compose up -d
docker logs -f --tail=200 pg-node1
```

### Verify final state (VM3 monitor)
```bash
cd /home/s/db/monitor
docker compose exec -u postgres pg-monitor pg_autoctl show state --pgdata /var/lib/postgres/pgaf
```

Expected end state:
- 1 primary
- 2 secondaries
