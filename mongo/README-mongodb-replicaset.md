# MongoDB Replica Set 


## Architecture

-   VM1 → `192.168.122.18` → mongo1\
-   VM2 → `192.168.122.233` → mongo2\
-   VM3 → `192.168.122.246` → mongo3

Replica set name: `rs0`\
Port: `27017`

------------------------------------------------------------------------

## Docker Compose (run on each VM)

> Same file on all VMs, only the volume name + container name differ.

### VM1 (`192.168.122.18`)

``` yaml
services:
  mongo:
    image: mongo:7
    container_name: mongo1
    restart: unless-stopped
    command: mongod --replSet rs0 --bind_ip_all
    ports:
      - "27017:27017"
    volumes:
      - mongo1_data:/data/db

volumes:
  mongo1_data:
```

### VM2 / VM3

Change only: - `container_name` → `mongo2` / `mongo3` - volume name →
`mongo2_data` / `mongo3_data`

------------------------------------------------------------------------

## Start MongoDB (on all VMs)

``` bash
docker compose up -d
```

------------------------------------------------------------------------

## Initialize the Replica Set (run once, from VM1)

``` bash
docker exec -it mongo1 mongosh
```

``` js
rs.initiate({
  _id: "rs0",
  members: [
    { _id: 0, host: "192.168.122.18:27017" },
    { _id: 1, host: "192.168.122.233:27017" },
    { _id: 2, host: "192.168.122.246:27017" }
  ]
})
```

Verify:

``` js
rs.status()
```

------------------------------------------------------------------------

## Application Connection String

``` text
mongodb://192.168.122.18:27017,192.168.122.233:27017,192.168.122.246:27017/?replicaSet=rs0
```

------------------------------------------------------------------------

## HA Test

Stop the primary:

``` bash
docker stop mongo1
```

A secondary will be promoted automatically.

------------------------------------------------------------------------
