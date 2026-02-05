# VM1 -- PostgreSQL Primary Node


Because it is the **first node to register**, it becomes the
**Primary**: - accepts **read + write** traffic - streams changes to
future standbys - participates in automatic failover decisions via the
monitor



## Role in the Cluster

-   **Role**: Primary (initially shown as `single`)
-   **Writes**: YES
-   **Reads**: YES
-   **Failover**:
    -   If VM1 fails, a standby (VM2 or VM3) will be promoted
    -   VM1 can later rejoin as a standby



## Dependencies

-   Requires the pg_auto_failover **monitor** to be running on VM3

-   Monitor authentication mode: `trust`

-   SSL: disabled



## Tools 


### pg_auto_failover

-   `pg_autoctl create postgres` → initializes & registers the node
-   `pg_autoctl run` → supervises Postgres + HA state
-   `pg_autoctl show state` (from monitor) → shows role



## Network Identity (Important)

### Advertised Address

This node **must advertise the VM IP**, not the Docker IP.



## Authentication & SSL

-   Authentication: `trust`
-   SSL: disabled
-   HBA rules are handled manually (monitor + nodes)


## docker-compose.yml (VM1)

``` yaml
services:
  pg-node:
    image: citusdata/pg_auto_failover:latest
    container_name: pg-node1
    hostname: pg-node1
    restart: unless-stopped

    user: "0:0"

    environment:
      PGDATA: /var/lib/postgres/pgaf
      PGSSLMODE: disable

    ports:
      - "5432:5432"

    volumes:
      - node1_pgdata:/var/lib/postgres/pgaf

    command: >
      bash -lc '
        set -euo pipefail

        mkdir -p /var/lib/postgres/pgaf
        mkdir -p /var/lib/postgres/backup
        chown -R postgres:postgres /var/lib/postgres
        chmod 700 /var/lib/postgres/pgaf
        chmod 700 /var/lib/postgres/backup

        if [ ! -s /var/lib/postgres/pgaf/PG_VERSION ]; then
          su - postgres -c "
            pg_autoctl create postgres \
              --pgdata /var/lib/postgres/pgaf \
              --pgport 5432 \
              --hostname 192.168.122.18 \
              --monitor postgres://autoctl_node@192.168.122.246:5432/pg_auto_failover?sslmode=disable \
              --auth trust \
              --no-ssl
          "
        fi

        exec su - postgres -c "pg_autoctl run --pgdata /var/lib/postgres/pgaf"
      '

volumes:
  node1_pgdata:
```

