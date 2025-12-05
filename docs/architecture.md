# System Architecture

## Overview

The Real-Time Bidding & Flash Sale System is designed to handle high-concurrency traffic during flash sales while maintaining data consistency and providing real-time leaderboard updates.

**Key Design Principles:**
- **Scalability:** Horizontal scaling via containerization and orchestration
- **Consistency:** No over-selling through atomic operations and locks
- **Performance:** Sub-second bid processing and real-time updates
- **Reliability:** High availability with redundancy and failover

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                          Client Layer                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ Web Browser  │  │ Mobile App   │  │ Admin Panel  │          │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘          │
│         │                  │                  │                   │
│         └──────────────────┴──────────────────┘                   │
│                            │                                      │
└────────────────────────────┼──────────────────────────────────────┘
                             │
                   ┌─────────▼─────────┐
                   │  Load Balancer    │
                   │  (ALB/Nginx)      │
                   └─────────┬─────────┘
                             │
┌────────────────────────────┼──────────────────────────────────────┐
│                 Application Layer (Kubernetes Cluster)            │
│                            │                                      │
│         ┌──────────────────┴──────────────────┐                  │
│         │                                      │                  │
│    ┌────▼────┐  ┌─────────┐  ┌──────────┐  ┌─▼──────────┐      │
│    │ REST    │  │ REST    │  │ REST     │  │ WebSocket  │      │
│    │ API Pod │  │ API Pod │  │ API Pod  │  │ Server Pod │      │
│    └────┬────┘  └────┬────┘  └────┬─────┘  └─────┬──────┘      │
│         │            │             │               │              │
│         └────────────┴─────────────┴───────────────┘              │
│                            │                                      │
└────────────────────────────┼──────────────────────────────────────┘
                             │
            ┌────────────────┴────────────────┐
            │                                  │
┌───────────▼──────────┐          ┌───────────▼──────────┐
│   Data Layer         │          │   Cache Layer         │
│                      │          │                       │
│  ┌───────────────┐  │          │  ┌─────────────────┐ │
│  │ PostgreSQL    │  │          │  │ Redis Cluster   │ │
│  │ (Primary)     │  │          │  │                 │ │
│  │               │  │          │  │ - ZSET (Board)  │ │
│  │ - Users       │  │◄─────────┤  │ - Cache         │ │
│  │ - Products    │  │  Sync    │  │ - Sessions      │ │
│  │ - Bids        │  │          │  │ - Pub/Sub       │ │
│  │ - Orders      │  │          │  └─────────────────┘ │
│  └───────┬───────┘  │          │                       │
│          │          │          └───────────────────────┘
│  ┌───────▼───────┐  │
│  │ PostgreSQL    │  │
│  │ (Read Replica)│  │
│  └───────────────┘  │
│                      │
└──────────────────────┘

            Optional: Message Queue Layer
            ┌─────────────────────────┐
            │ Redis Streams / RabbitMQ│
            │                         │
            │ - Async bid persistence │
            │ - Event notifications   │
            └─────────────────────────┘
```

---

## Component Details

### 1. Client Layer

**Components:**
- Web Browser (React/Vue.js SPA)
- Mobile App (React Native/Flutter)
- Admin Panel (Internal dashboard)

**Responsibilities:**
- User interface for bidding
- Real-time leaderboard display via WebSocket
- Admin controls for product/sale management

---

### 2. Load Balancer

**Technology:** AWS ALB / GCP Load Balancer / Nginx

**Responsibilities:**
- Distribute incoming HTTP/HTTPS requests across API pods
- SSL/TLS termination
- Health checks for backend pods
- Session affinity for WebSocket connections (sticky sessions)

**Configuration:**
```yaml
# Example: ALB target group settings
HealthCheck:
  Path: /health
  Interval: 30s
  Timeout: 5s
  HealthyThreshold: 2
  UnhealthyThreshold: 3
```

---

### 3. Application Layer (Node.js Pods)

#### 3.1 REST API Pods

**Technology:** Node.js + Express/Fastify

**Responsibilities:**
- Handle authentication (JWT)
- Process bid submissions and updates
- Query leaderboard data
- Admin operations (CRUD for products, parameters)

**Scaling Strategy:**
- Horizontal Pod Autoscaler (HPA) based on CPU/Memory
- Target: 60-70% CPU utilization
- Min replicas: 3, Max replicas: 20

**Key Operations:**
```javascript
// Bid submission flow
1. Authenticate user (JWT middleware)
2. Validate product and sale status
3. Calculate reaction time (T)
4. Fetch user's member_weight (W)
5. Calculate score: α*P + β/(T+1) + γ*W
6. Update Redis ZSET atomically
7. Publish update event to WebSocket subscribers
8. Queue bid for async PostgreSQL persistence
9. Return response with rank and score
```

---

#### 3.2 WebSocket Server Pods

**Technology:** Socket.io / ws library

**Responsibilities:**
- Maintain persistent connections with clients
- Broadcast leaderboard updates to subscribers
- Handle room-based pub/sub (per product)
- Send personalized bid status to users

**Connection Management:**
```javascript
// Room structure
Product ID: 1 → Room "leaderboard:1"
  ├─ User A (Socket ID: abc123)
  ├─ User B (Socket ID: def456)
  └─ User C (Socket ID: ghi789)

// Broadcast flow
1. Bid processed → Score updated in Redis
2. Trigger Redis pub/sub event
3. WebSocket server subscribes to Redis channel
4. Broadcast to room "leaderboard:1"
5. Clients receive real-time update
```

**Scaling Considerations:**
- Sticky sessions via load balancer
- Redis pub/sub for cross-pod messaging
- Reconnection logic on client side

---

### 4. Data Layer

#### 4.1 PostgreSQL (Primary)

**Purpose:** Persistent, ACID-compliant data storage

**Tables:**
- `users` - User accounts and member weights
- `products` - Flash sale items and inventory
- `bids` - All bid history with scores
- `orders` - Finalized orders for winners
- `scoring_parameters` - Dynamic α, β, γ values

**Configuration:**
- Connection pooling (pg-pool): 20-50 connections
- Read replicas for reporting queries
- Automated backups (daily snapshots)
- Point-in-time recovery enabled

---

#### 4.2 PostgreSQL (Read Replica)

**Purpose:** Offload read-heavy queries

**Use Cases:**
- Admin analytics and reports
- Historical bid analysis
- User order history
- Non-critical leaderboard queries

**Replication:**
- Streaming replication with minimal lag (<1s)
- Automatic failover to promote replica if primary fails

---

### 5. Cache Layer (Redis)

#### 5.1 Redis Cluster

**Purpose:** Real-time leaderboard and caching

**Data Structures:**

**Sorted Set (ZSET) for Leaderboard:**
```redis
# Key: leaderboard:product:{product_id}
# Score: calculated_score
# Member: user_id

ZADD leaderboard:product:1 1275.87 user_42
ZADD leaderboard:product:1 2145.67 user_89

# Get Top K (e.g., Top 50)
ZREVRANGE leaderboard:product:1 0 49 WITHSCORES

# Get user's rank
ZREVRANK leaderboard:product:1 user_42

# Get score by threshold
ZREVRANGEBYSCORE leaderboard:product:1 +inf 1250.00
```

**Hash for User Session:**
```redis
# Key: session:user:{user_id}
HSET session:user:42 member_weight 1.50
HSET session:user:42 current_bid_id 124
```

**String for Inventory:**
```redis
# Key: inventory:product:{product_id}
SET inventory:product:1 50
DECR inventory:product:1  # Atomic decrement
```

**Pub/Sub for Real-time Updates:**
```redis
# Channel: leaderboard_update:{product_id}
PUBLISH leaderboard_update:1 '{"rank":1,"score":2145.67}'
```

**Configuration:**
- Persistence: RDB + AOF (fsync every second)
- Eviction policy: `allkeys-lru` for cache, `noeviction` for critical data
- Replication: Master-Slave with Sentinel for failover

---

### 6. Message Queue (Optional)

**Technology:** Redis Streams or RabbitMQ

**Purpose:** Decouple real-time operations from database writes

**Workflow:**
```
Bid Submitted
    │
    ├─ Immediate: Update Redis ZSET (for leaderboard)
    │
    └─ Async: Push to Queue
              │
              └─ Consumer Worker
                     │
                     └─ Persist to PostgreSQL
```

**Benefits:**
- Reduces latency for bid submission response
- Handles burst traffic without overwhelming PostgreSQL
- Retry logic for failed writes

**Consumer Configuration:**
- Consumer group: 3-5 workers
- Batch processing: Insert bids in batches (50-100 records)
- Dead letter queue for failed messages

---

## Data Flow

### Scenario 1: User Submits Bid

```
┌─────────┐      ┌─────────────┐      ┌──────────────┐
│ Client  │      │  API Server │      │    Redis     │
└────┬────┘      └──────┬──────┘      └──────┬───────┘
     │                  │                     │
     │ POST /bids       │                     │
     ├─────────────────►│                     │
     │                  │                     │
     │              Validate                  │
     │              Calculate Score           │
     │                  │                     │
     │                  │ ZADD (update score) │
     │                  ├────────────────────►│
     │                  │                     │
     │                  │ ZREVRANK (get rank) │
     │                  ├────────────────────►│
     │                  │◄────────────────────┤
     │                  │                     │
     │                  │ PUBLISH event       │
     │                  ├────────────────────►│
     │                  │                     │
     │◄─────────────────┤                     │
     │ 201 + rank/score │                     │
     │                  │                     │
     │                  │ Queue to DB (async) │
     │                  ├────────────────────►│
     │                  │                     │

┌─────────────┐
│ WebSocket   │
│ Subscribers │
└──────┬──────┘
       │
       │ SUBSCRIBE leaderboard_update:1
       ├────────────────────────────────────►
       │
       │◄────────────────────────────────────┤
       │ Broadcast: leaderboard_update       │
```

---

### Scenario 2: Sale Finalization (Creating Orders)

```
┌─────────┐      ┌──────────────┐      ┌────────────┐
│  Admin  │      │  API Server  │      │ PostgreSQL │
└────┬────┘      └──────┬───────┘      └─────┬──────┘
     │                  │                     │
     │ POST /admin/     │                     │
     │ products/1/      │                     │
     │ finalize         │                     │
     ├─────────────────►│                     │
     │                  │                     │
     │              Validate                  │
     │              (sale ended?)             │
     │                  │                     │
     │                  │ BEGIN TRANSACTION   │
     │                  ├────────────────────►│
     │                  │                     │
     │                  │ SELECT Top K bids   │
     │                  │ (by score DESC)     │
     │                  ├────────────────────►│
     │                  │◄────────────────────┤
     │                  │                     │
     │                  │ INSERT INTO orders  │
     │                  ├────────────────────►│
     │                  │                     │
     │                  │ UPDATE products     │
     │                  │ SET inventory = 0   │
     │                  ├────────────────────►│
     │                  │                     │
     │                  │ COMMIT              │
     │                  ├────────────────────►│
     │                  │◄────────────────────┤
     │                  │                     │
     │◄─────────────────┤                     │
     │ 200 + summary    │                     │
```

---

## Scalability Strategy

### Horizontal Scaling

**API Pods:**
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-server-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api-server
  minReplicas: 3
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

**Database:**
- Vertical scaling: Increase instance size (CPU/RAM)
- Read replicas: Offload SELECT queries
- Connection pooling: Reuse connections efficiently

**Redis:**
- Redis Cluster mode for partitioning
- Multiple master nodes with sharding

---

### Traffic Handling

**Expected Load:**
- 1,000-10,000 concurrent users during peak
- 5,000-50,000 bids per flash sale event
- 1,000+ WebSocket connections per pod

**Capacity Planning:**
- Each API pod: ~500 req/s
- 10 pods = 5,000 req/s sustained
- Redis: 100,000+ ops/s
- PostgreSQL: 10,000 writes/s (with batching)

---

## Consistency Guarantees

### No Over-Selling

**Mechanism:**
1. **During Sale:** Redis tracks Top K in real-time (optimistic)
2. **At Finalization:** PostgreSQL transaction with locking
3. **Verification:** `SELECT COUNT(*) FROM orders WHERE product_id = X` must equal `max_winners`

**Transaction Isolation:**
```sql
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
BEGIN;
-- Create orders
-- Decrement inventory
COMMIT;
```

---

## High Availability

**Database:**
- Multi-AZ deployment with automatic failover
- Replica promotion in case of primary failure
- RPO (Recovery Point Objective): <1 minute
- RTO (Recovery Time Objective): <5 minutes

**Redis:**
- Redis Sentinel for automatic failover
- Master-Slave replication
- Persistence enabled (RDB + AOF)

**Application:**
- Multi-zone pod distribution
- Health checks with auto-restart
- Circuit breakers for degraded dependencies

---

## Monitoring & Observability

**Metrics to Track:**
- API latency (p50, p95, p99)
- Redis operations per second
- PostgreSQL connection pool usage
- WebSocket connection count
- Bid processing time
- Error rates (4xx, 5xx)

**Dashboards:**
- Grafana for real-time metrics
- CloudWatch/Stackdriver for cloud metrics
- Custom dashboard for business metrics (bids/min, Top K changes)

**Alerts:**
- CPU > 80% for 5 minutes
- Error rate > 1% for 2 minutes
- Database connection pool exhausted
- Redis memory > 90%

---

## Security Considerations

**Authentication:**
- JWT tokens with expiration (1 hour)
- Refresh token mechanism
- Rate limiting per user/IP

**Data Protection:**
- HTTPS/TLS for all client communication
- WSS (WebSocket Secure) for real-time connections
- Database encryption at rest
- Environment variables for secrets (no hardcoding)

**DDoS Protection:**
- CloudFlare or AWS Shield
- Rate limiting at load balancer level
- CAPTCHA for registration/login

---

## Disaster Recovery

**Backup Strategy:**
- PostgreSQL: Automated daily snapshots
- Redis: RDB snapshots every 5 minutes
- Point-in-time recovery for PostgreSQL

**Failover Procedures:**
1. Database primary fails → Promote replica
2. Redis master fails → Sentinel promotes slave
3. API pod crashes → Kubernetes auto-restarts
4. Region failure → Multi-region active-active (future)

---

## Future Enhancements

- **Multi-region deployment** for global availability
- **GraphQL API** for flexible data querying
- **Machine learning** for fraud detection
- **Event sourcing** for complete audit trail
- **Service mesh** (Istio) for advanced traffic management
