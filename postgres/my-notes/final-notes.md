# Final Note




## Goal

a **simple, reliable PostgreSQL High Availability setup** with the following constraints:

- No Kubernetes
- No external proxy (HAProxy, PgBouncer, VIP, etc.)
- Deterministic behavior

The system must:
- Survive the loss of **any single VM**
- Automatically promote a new primary
- Allow the old primary to rejoin safely
- Be observable and debuggable at all times

---

## Chosen Architecture

### Components
- **pg_auto_failover monitor**
  - Runs on VM3 only
  - Stores *cluster state*, not application data
  - Decides who is primary and when to fail over

- **PostgreSQL nodes**
  - One node per VM
  - Exactly one primary
  - One or more standbys
  - Streaming replication

### VM Layout
| VM | Role |
|----|-----|
| VM1 | PostgreSQL node |
| VM2 | PostgreSQL node |
| VM3 | Monitor + PostgreSQL node |

VM3 runs **two containers**:
- Monitor on host port `5432`
- PostgreSQL node on host port `5433`


---

## Why pg_auto_failover

pg_auto_failover was chosen because:

- It uses **native PostgreSQL replication**
- It does not require a proxy
- It works well with libpq multi-host DSNs


---

## Application Connectivity Strategy

There is **no proxy** and **no VIP**.

Instead, applications:
- Use a **multi-host libpq DSN**
- Include multiple node IPs
- Set `target_session_attrs=read-write`

This guarantees:
- Writes always go to the current primary
- Clients automatically reconnect after failover

VM3 is **not included** in the main DSN because its Postgres runs on host port `5433`, while libpq multi-host DSNs assume a single port.

---

## Bring-up Philosophy

Order matters.

1. Monitor first
2. First node → becomes primary
3. Second node → joins as standby
4. Third node → joins as standby

Every node is created with:
- `pg_autoctl create postgres`
- `--hostname` set to the VM IP
- Trust auth
- No SSL

All orchestration logic lives in pg_auto_failover.

---

## Docker Layout

### Critical Rule
**Never mount a volume directly on PGDATA when using pg_auto_failover standbys.**

Why:
- pg_auto_failover deletes and recreates PGDATA during standby init
- Docker cannot delete a mountpoint directory
- This causes "Device or resource busy" errors

### Correct Pattern
```text
/var/lib/postgres      ← volume mounted here
└── pgaf               ← PGDATA lives here
```

---

## Failover Behavior (What Actually Happens)

When the primary disappears:

1. Monitor marks it unreachable (`read-write !`)
2. Standbys report their LSNs
3. Monitor selects the safest candidate
4. Timeline increments (e.g. TLI 1 → 2)
5. One standby is promoted
6. Remaining nodes follow the new primary
7. Old primary is marked `demoted`

This process is **stateful and visible** via:
```bash
pg_autoctl show state
```

---

## Rejoining the Old Primary

Two possibilities:

### Best Case
- Old primary rejoins automatically as a standby
- pg_auto_failover rewinds it safely

### Worst Case (Normal in tests)
- Timeline divergence
- Old data must be discarded

Solution:
- Stop the container
- Delete its data volume
- Restart → base backup from new primary


---