# VM3 - pg_auto_failover Monitor Node



The monitor: decides which node is **primary** vs
**standby** 

All application traffic goes **directly to Postgres nodes**, never to
the monitor.



## Architecture Role

**VM3** : runs the pg_auto_failover **monitor**

The monitor runs: - its own small PostgreSQL instance - the
`pgautofailover` extension - the `pg_autoctl`



## Tools


### pg_auto_failover

-   `pg_autoctl create monitor` → initializes monitor
-   `pg_autoctl run` → keeps monitor running
-   `pg_autoctl show state` → shows cluster state




## Monitor Container 

### Image

    citusdata/pg_auto_failover:latest

Important: - This image **defaults to a tmux demo** - We explicitly
override the command to avoid tmux


## Data Directory

Inside container:

    /var/lib/postgres/pgaf

Backed by:

    Docker named volume: monitor_pgdata

Actual host path (Docker-managed, do not edit manually):

    /var/lib/docker/volumes/monitor_monitor_pgdata/_data



## Authentication & SSL

-   Authentication mode: `trust`
-   SSL: **disabled** 


------------------------------------------------------------------------

## docker-compose.yml (Monitor)

``` yaml
services:
  pg-monitor:
    image: citusdata/pg_auto_failover:latest
    container_name: pg-monitor
    hostname: pg-monitor
    restart: unless-stopped

    user: "0:0"

    environment:
      PGDATA: /var/lib/postgres/pgaf
      PGSSLMODE: disable

    ports:
      - "5432:5432"

    volumes:
      - monitor_pgdata:/var/lib/postgres/pgaf

    command: >
      bash -lc '
        set -euo pipefail

        mkdir -p /var/lib/postgres/pgaf
        chown -R postgres:postgres /var/lib/postgres/pgaf
        chmod 700 /var/lib/postgres/pgaf

        if [ ! -s /var/lib/postgres/pgaf/PG_VERSION ]; then
          su - postgres -c "
            pg_autoctl create monitor \
              --pgdata /var/lib/postgres/pgaf \
              --pgport 5432 \
              --auth trust \
              --no-ssl
          "
        fi

        exec su - postgres -c "pg_autoctl run --pgdata /var/lib/postgres/pgaf"
      '

volumes:
  monitor_pgdata:
```



## Monitor Inspection Commands

Always run pg_autoctl **as postgres user**, not root.

### Show cluster state

``` bash
docker compose exec -u postgres pg-monitor \
  pg_autoctl show state --pgdata /var/lib/postgres/pgaf
```

