# final – DB-only HA playbook

**PostgreSQL** (pg_auto_failover), **Redis** (+ Sentinel), **MongoDB** (replica set). No API.

## What you need

- **3 IPs** (your gateway VMs)
- SSH as `ubuntu` with sudo on all three
- Docker and Docker Compose installed on each VM

## Deploy (one place to edit)

1. **Edit only the inventory** – put your 3 IPs in `inventory/hosts.ini`:

   ```ini
   [all]
   vm1 ansible_host=YOUR_IP_1
   vm2 ansible_host=YOUR_IP_2
   vm3 ansible_host=YOUR_IP_3
   ```

2. **Run the playbook**:

   ```bash
   cd final
   ansible all -m ping
   ansible-playbook playbooks/all.yml
   ```

No hardcoded IPs anywhere else: ports, paths, and DSNs are derived from inventory or set in `inventory/group_vars/all.yml` (paths under `/home/ubuntu/`).

## Clean (remove all lab containers/volumes)

```bash
ansible-playbook playbooks/clean.yml --tags nuke
```

## Layout

| Path | Purpose |
|------|--------|
| `inventory/hosts.ini` | **Only file you edit** – 3 IPs and group assignments |
| `inventory/group_vars/all.yml` | Ports and paths (derived from inventory where possible) |
| `playbooks/all.yml` | Single playbook: monitor → PG nodes → Redis → Mongo → appdb_utf8 → report |
| `playbooks/clean.yml` | Tear-down (containers + volumes) |
| `roles/` | pg_monitor, pg_node, redis, mongo, report (no api role) |
