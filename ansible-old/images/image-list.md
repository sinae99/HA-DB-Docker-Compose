# Docker images used 

## 1. List of all images

| # | Image | Used for | Where |
|---|--------|-----------|--------|
| 1 | `citusdata/pg_auto_failover:latest` | pg_auto_failover monitor + PostgreSQL nodes (vm1, vm2, vm3) | pg_monitor, pg_node roles |
| 2 | `redis:7.2-alpine` | Redis server + Sentinel | redis role (vm1, vm2, vm3) |
| 3 | `mongo:7` | MongoDB replica set nodes | mongo role (vm1, vm2, vm3) |
| 4 | `harbor.arcaptcha.ir/backend/test/api-test:0.0.1` | API (goapi) | api role |
| 5 | `harbor.arcaptcha.ir/backend/test/captcha-test:0.0.1` | Captcha service (optional; commented in Ansible) | db-ha/api only |

---

**Pull:**
```bash
docker pull citusdata/pg_auto_failover:latest
docker pull redis:7.2-alpine
docker pull mongo:7
docker pull harbor.arcaptcha.ir/backend/test/api-test:0.0.1
docker pull harbor.arcaptcha.ir/backend/test/captcha-test:0.0.1
```

**Save:**
```bash
docker save -o citusdata-pg_auto_failover-latest.tar citusdata/pg_auto_failover:latest
docker save -o redis-7.2-alpine.tar redis:7.2-alpine
docker save -o mongo-7.tar mongo:7
docker save -o api-test-0.0.1.tar harbor.arcaptcha.ir/backend/test/api-test:0.0.1
docker save -o captcha-test-0.0.1.tar harbor.arcaptcha.ir/backend/test/captcha-test:0.0.1
```

**Load on destination, after copying the `.tar` files):**
```bash
docker load -i citusdata-pg_auto_failover-latest.tar
docker load -i redis-7.2-alpine.tar
docker load -i mongo-7.tar
docker load -i api-test-0.0.1.tar
docker load -i captcha-test-0.0.1.tar
```
