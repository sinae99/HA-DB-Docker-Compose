# db-ha Ansible Lab Runbook



## Assumptions

-   You have 3 Ubuntu VMs:
    -   VM1 (vm1) = `192.168.x.x`
    -   VM2 (vm2) = `192.168.x.x`
    -   VM3 (vm3) = `192.168.x.x`
-   Optional API VM:
    -   apivm = `192.168.x.x`
-   You can SSH from your laptop to all VMs as **user `s`** (SSH keys
    configured).
-   Docker + Docker Compose are already installed on all VMs.
-   **User `s` can run sudo without a password (recommended)**.

## What it deploys

-   **PostgreSQL HA**: pg_auto_failover monitor on VM3 + Postgres nodes
    on VM1/VM2/VM3
-   **Redis HA**: master on VM1, replicas on VM2/VM3, Sentinel on all 3
-   **MongoDB HA**: replica set `rs0` across VM1/VM2/VM3
-   **API VM**: goapi container (if `apivm` is present in inventory)
-   **Final report**: per-VM status summary

## Usage

### 1) Enter Ansible directory

``` bash
cd db-ha/ansible
```

### 2) Configure inventory

Edit: - `inventory/hosts.ini` - `inventory/group_vars/*.yml`

Set correct IPs for `vm1`, `vm2`, `vm3` (and `apivm` if used).

### 3) Verify connectivity

``` bash
ansible all -m ping
```

### 4) Run full deployment

``` bash
ansible-playbook playbooks/lab.yml
```

### 5) Run only final report (safe anytime)

``` bash
ansible-playbook playbooks/lab.yml --tags report
```

## Notes

-   The playbook is idempotent and safe to re-run.
-   All reporting tasks are read-only.
