# HA Database Lab (PostgreSQL, Redis, MongoDB)

------------------------------------------------------------------------

## Topology Overview

  
  VM              IP                Services
  --------------- ----------------- ---------------------------------------
  VM1 ----> 192.168.122.18 ----> Postgres, Redis + Sentinel, MongoDB

  VM2 ----> 192.168.122.233 ----> Postgres, Redis + Sentinel, MongoDB

  VM3 ----> 192.168.122.246 ----> Postgres + pg_auto_failover monitor, Redis + Sentinel, MongoDB

  API VM ----> 192.168.122.16 ----> API client




------------------------------------------------------------------------

## Repository Structure

    db-ha/
    ├── postgres/   # PostgreSQL HA using pg_auto_failover
    ├── redis/      # Redis HA using replication + Sentinel
    ├── mongo/      # MongoDB Replica Set
    ├── api/        # API connectivity to all HA backends
    └── README.md   # (this file)




## PostgreSQL

**Technology:** pg_auto_failover\
**Pattern:** One primary, multiple standbys, automatic failover


`postgres/README.md` ---> architecture and deployment

`postgres/README-failover-test.md` ---> failover and rejoin procedures



## Redis

**Technology:** Redis Replication + Sentinel\
**Pattern:** 1 master, 2 replicas, Sentinel quorum = 2




`redis/README.md` ---> end-to-end Redis HA setup

`redis/README-deploy-stages.md` ---> staged deployment philosophy



## MongoDB

**Technology:** MongoDB Replica Set\
**Pattern:** Automatic primary election


`mongo/README-mongodb-replicaset.md`




## goapi --- Client Connectivity

The API consumes **all three HA systems simultaneously**.



`api/README-api-connectivity.md`

Includes: - Network verification - PostgreSQL HA connection string -
Redis Sentinel configuration - MongoDB replica set URI - API Docker
Compose configuration




## next step : /Ansible




