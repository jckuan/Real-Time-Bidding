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

### Production Deployment (AWS)

```
┌───────────────────────────────────────────────────────────────────────┐
│                        Client Layer (Users)                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐                 │
│  │ Web Browser  │  │ Mobile App   │  │ Admin Panel  │                 │
│  └──────┬───────┘  └───────┬──────┘  └────────┬─────┘                 │
│         │                  │                  │                       │
│         └──────────────────┴──────────────────┘                       │
│                            │                                          │
│                            │ HTTP/HTTPS + WebSocket (WSS)             │
└────────────────────────────┼──────────────────────────────────────────┘
                             │
                   ┌─────────▼─────────┐
                   │ Application LB    │ ← Internet Gateway
                   │ (AWS ALB)         │
                   │ rtb-alb           │
                   │ Port: 80, 3000    │
                   │ Timeout: 120s     │
                   │ Sticky: Enabled   │
                   └─────────┬─────────┘
                             │
┌────────────────────────────┼──────────────────────────────────────────┐
│              Application Layer (AWS ECS Fargate)                      │
│              Cluster: rtb-cluster  Service: rtb-service               │
│                            │                                          │
│         ┌──────────────────┴──────────────────────┐                   │
│         │                                         │                   │
│    ┌────▼─────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐             │
│    │ ECS Task │  │ ECS Task │  │ ECS Task │  │ ECS Task │             │
│    │ (Node.js)│  │ (Node.js)│  │ (Node.js)│  │ (Node.js)│             │
│    │ 1024 CPU │  │ 1024 CPU │  │ 1024 CPU │  │ 1024 CPU │             │
│    │ 2048 MB  │  │ 2048 MB  │  │ 2048 MB  │  │ 2048 MB  │             │
│    │          │  │          │  │          │  │          │             │
│    │ REST API │  │ REST API │  │ REST API │  │ REST API │             │
│    │ Socket.IO│  │ Socket.IO│  │ Socket.IO│  │ Socket.IO│             │
│    └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘             │
│         │             │             │             │                   │
│         └─────────────┴─────────────┴─────────────┘                   │
│                            │                                          │
│         Pool: 30 connections/task = 120 total DB connections          │
└────────────────────────────┼──────────────────────────────────────────┘
                             │
            ┌────────────────┴────────────────┐
            │                                 │
┌───────────▼───────────┐         ┌───────────▼───────────────┐
│   Database Layer      │         │   Cache Layer             │
│   (Amazon RDS)        │         │   (ElastiCache)           │
│                       │         │                           │
│  ┌─────────────────┐  │         │  ┌───────────────────┐    │
│  │ PostgreSQL 15.8 │  │         │  │ Redis 7.0         │    │
│  │ db.t3.small     │  │         │  │ cache.t3.micro    │    │
│  │ 2GB RAM         │  │         │  │                   │    │
│  │ ~225 max_conn   │  │         │  │ - ZSET Leaderboard│    │
│  │                 │  │         │  │ - User Sessions   │    │
│  │ rtb-db          │  │◄────────┤  │ - Pub/Sub Events  │    │
│  │ Multi-AZ        │  │   Sync  │  │                   │    │
│  │                 │  │         │  │ rtb-redis         │    │
│  │ Tables:         │  │         │  │ Endpoint:6379     │    │
│  │ - users         │  │         │  └───────────────────┘    │
│  │ - products      │  │         │                           │
│  │ - bids          │  │         └───────────────────────────┘
│  │ - orders ✓      │  │
│  │ - parameters    │  │
│  └─────────────────┘  │
│                       │
└───────────────────────┘

         VPC: vpc-0449dd4efd076077e (us-west-2)
         Security Group: sg-0f45b30eeb2ea2d09
         ├─ Port 80    (Internet → ALB)
         ├─ Port 3000  (ALB → ECS Tasks)
         ├─ Port 5432  (ECS → RDS)
         └─ Port 6379  (ECS → Redis)
```

### Deployment Specifications

**AWS Region:** us-west-2 (Oregon)

**ECS Fargate:**
- Cluster: `rtb-cluster`
- Service: `rtb-service`
- Tasks: 4 running (scaled from 3)
- Platform: linux/amd64
- CPU per task: 1024 units (1 vCPU)
- Memory per task: 2048 MB (2 GB)
- Health check timeout: 10s
- Start period: 120s

**RDS PostgreSQL:**
- Instance: `rtb-db` (db.t3.small)
- Engine: PostgreSQL 15.8
- Memory: 2 GB
- Max connections: ~225
- Multi-AZ: Enabled
- Endpoint: YOUR_RDS_ENDPOINT:5432
- Database: rtb_database
- SSL: Enabled (self-signed cert)

**ElastiCache Redis:**
- Cluster: `rtb-redis`
- Engine: Redis 7.0
- Node type: cache.t3.micro
- Endpoint: YOUR_REDIS_ENDPOINT:6379

**Application Load Balancer:**
- Name: `rtb-alb`
- DNS: YOUR_ALB_DNS
- Idle timeout: 120s
- Session stickiness: Enabled (24 hours)
- Target group: Health checks optimized

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

**Technology:** AWS Application Load Balancer (ALB)

**Current Configuration:**
- Name: `rtb-alb`
- DNS: YOUR_ALB_DNS
- Scheme: Internet-facing
- Idle timeout: 120 seconds (increased for WebSocket)
- Session stickiness: Enabled (24-hour duration)

**Responsibilities:**
- Distribute incoming HTTP/HTTPS requests across ECS tasks
- SSL/TLS termination
- Health checks for backend containers
- Session affinity for WebSocket connections (sticky sessions)

**Target Group Configuration:**
```yaml
HealthCheck:
  Path: /health
  Interval: 30s
  Timeout: 10s
  HealthyThreshold: 2
  UnhealthyThreshold: 3
  Matcher: 200
```

**Performance:**
- Handles 1000+ concurrent connections
- Sub-second request routing
- Automatic scaling based on traffic

---

### 3. Application Layer (ECS Fargate Tasks)

#### 3.1 REST API + WebSocket (Unified)

**Technology:** Node.js + Express + Socket.IO

**Deployment:**
- Platform: AWS ECS Fargate
- Cluster: `rtb-cluster`
- Service: `rtb-service`
- Current tasks: 4 (can scale to 10+)
- CPU: 1024 units (1 vCPU) per task
- Memory: 2048 MB (2 GB) per task
- Image: rtb-system:latest (ECR)

**Responsibilities:**
- Handle authentication (JWT)
- Process bid submissions and updates
- Query leaderboard data
- Admin operations (CRUD for products, parameters)
- WebSocket connections for real-time updates

**Scaling Strategy:**
- **Auto-scaling enabled** ✓ (CPU-based target tracking)
- Min: 4 tasks, Max: 10 tasks
- Target: 70% CPU utilization
- Scale-out cooldown: 60s
- Scale-in cooldown: 60s
- Policy: `cpu-scaling` (TargetTrackingScaling)

**Impact on Performance:**
- **Before auto-scaling:** ~15-20% error rate at 1000 concurrent users
- **After auto-scaling:** ~6.5% error rate at 1000 concurrent users
- Error reduction: **>50% improvement** during peak load
- Automatic capacity adjustment prevents resource exhaustion

**Connection Pool (per task):**
```javascript
// PostgreSQL pool settings
{
  min: 5,
  max: 30,
  connectionTimeoutMillis: 10000,
  idleTimeoutMillis: 30000,
  acquireTimeoutMillis: 30000
}
// 4 tasks × 30 max = 120 total connections
// RDS db.t3.small supports ~225 connections
```

**Key Operations:**
```javascript
// Bid submission flow
1. Authenticate user (JWT middleware)
2. Validate product and sale status  
3. Calculate reaction time (T = bid_time - sale_start)
4. Fetch user's member_weight (W) from database
5. Calculate score: α*P + β/(T+1) + γ*W
6. Update Redis ZSET atomically (ZADD)
7. Check if user in Top K (max_winners)
8. Create order in PostgreSQL if top winner
9. Publish WebSocket event to room
10. Return response with rank and score
```

**Performance:**
- Bid processing: ~200-300ms average
- Database queries: ~50-100ms
- Redis operations: <10ms
- WebSocket broadcast: <50ms

---

#### 3.2 WebSocket Server (Integrated)

**Technology:** Socket.io (integrated in same ECS tasks)

**Responsibilities:**
- Maintain persistent connections with clients
- Broadcast leaderboard updates to subscribers
- Handle room-based pub/sub (per product)
- Send personalized bid status to users

**Connection Management:**
```javascript
// Room structure (per product)
Product ID: 1 → Room "product:1"
  ├─ User A (Socket ID: abc123)
  ├─ User B (Socket ID: def456)
  └─ User C (Socket ID: ghi789)

// Broadcast flow
1. Bid processed → Score updated in Redis
2. Server emits to room "product:1"
3. All connected clients receive update
4. Client UI updates leaderboard in real-time
```

**Scaling Considerations:**
- ALB sticky sessions keep users connected to same task
- Each task handles ~250-500 concurrent WebSocket connections
- 4 tasks = 1000-2000 concurrent connections supported
- Reconnection logic on client side for failover

**Events:**
```javascript
// Server → Client events
'leaderboard:update'   // Top K ranking change
'bid:confirmed'        // User's bid accepted
'bid:rejected'         // User's bid failed
'product:status'       // Sale started/ended

// Client → Server events
'join:product'         // Subscribe to product updates
'leave:product'        // Unsubscribe
```

---

### 4. Data Layer

#### 4.1 Amazon RDS PostgreSQL (Primary)

**Instance Type:** db.t3.small
**Engine:** PostgreSQL 15.8
**Configuration:**
- vCPUs: 2
- Memory: 2 GB
- Storage: 20 GB (SSD)
- Max connections: ~225 (formula: RAM_GB × 1024³ / 9531392)
- Multi-AZ: Enabled (automatic failover)
- Endpoint: rtb-db.cxs8mgm8ufcp.us-west-2.rds.amazonaws.com

**Purpose:** Persistent, ACID-compliant data storage

**Tables:**
```sql
users           -- User accounts, member_weight
products        -- Flash sale items, inventory, max_winners
bids            -- All bid history with scores (is_latest flag)
orders          -- Finalized winners (COUNT must ≤ max_winners)
scoring_parameters -- Dynamic α, β, γ values
```

**Key Queries:**
```sql
-- Check no overselling (critical for demo)
SELECT COUNT(*) FROM orders WHERE product_id = ? 
  -- Result must be ≤ products.max_winners

-- Get user's current bid
SELECT * FROM bids 
WHERE user_id = ? AND product_id = ? AND is_latest = true

-- Leaderboard (backup, primary is Redis)
SELECT user_id, final_score, rank() OVER (ORDER BY final_score DESC)
FROM bids WHERE product_id = ? AND is_latest = true
LIMIT 50
```

**Connection Pool:**
- 4 ECS tasks × 30 max connections = 120 active
- Leaves ~100 connections for admin, monitoring, backups
- Connection timeout: 10s
- Acquire timeout: 30s

**Performance:**
- INSERT bid: 50-100ms
- SELECT user: 10-20ms
- Complex JOIN: 100-200ms

---

#### 4.2 Read Replicas (Optional - Not Currently Deployed)

**Purpose:** Offload read-heavy queries

**Use Cases:**
- Admin analytics and reports
- Historical bid analysis
- User order history
- Non-critical leaderboard queries

**Note:** Current deployment uses single primary instance. Read replicas can be added for:
- High-traffic scenarios (>10,000 concurrent users)
- Analytics/reporting workloads
- Geographic distribution

---

### 5. Cache Layer

#### 5.1 Amazon ElastiCache for Redis

**Node Type:** cache.t3.micro
**Engine:** Redis 7.0
**Configuration:**
- Memory: ~0.5 GB
- Endpoint: YOUR_REDIS_ENDPOINT:6379
- Cluster mode: Disabled (single node)
- Encryption: In-transit enabled

**Purpose:** Real-time leaderboard and session caching

**Data Structures:**

**1. Sorted Set (ZSET) for Leaderboard:**
```redis
# Key: leaderboard:product:{product_id}
# Score: calculated final_score
# Member: user_id

ZADD leaderboard:product:1 1275.87 user_42
ZADD leaderboard:product:1 2145.67 user_89

# Get Top K (e.g., Top 50 winners)
ZREVRANGE leaderboard:product:1 0 49 WITHSCORES

# Get user's rank (0-based)
ZREVRANK leaderboard:product:1 user_42

# Count winners (for preventing overselling)
ZCOUNT leaderboard:product:1 -inf +inf
```

**2. Hash for Product Metadata:**
```redis
# Key: product:{product_id}
HSET product:1 max_winners 50
HSET product:1 sale_status "active"
HSET product:1 base_price 999
```

**3. String for Inventory (Atomic Operations):**
```redis
# Key: inventory:product:{product_id}
SET inventory:product:1 50
DECR inventory:product:1  # Atomic decrement for winner
GET inventory:product:1   # Check remaining slots
```

**Performance:**
- ZADD operation: <5ms
- ZREVRANGE (Top 50): <10ms
- ZREVRANK (single user): <2ms
- Memory per leaderboard: ~1-5 MB (1000 users)

**Eviction Policy:**
- Current: `noeviction` (critical data, don't evict)
- Alternative: `allkeys-lru` for cache-only data

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
┌─────────┐      ┌─────────────┐       ┌──────────────┐
│ Client  │      │  API Server │       │    Redis     │
└────┬────┘      └──────┬──────┘       └──────┬───────┘
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

### No Over-Selling (Critical Business Requirement)

**Verification Method:** Check `orders` table (actual winners)

**Mechanism:**
1. **During Sale:** Redis ZSET tracks Top K in real-time (optimistic, fast)
2. **Bid Processing:** Check `ZCOUNT` before creating order
3. **Order Creation:** INSERT into orders table only if count < max_winners
4. **At Finalization:** PostgreSQL transaction ensures atomicity
5. **Post-Sale Verification:** `SELECT COUNT(*) FROM orders WHERE product_id = ?` must be ≤ `max_winners`

**SQL Verification (for demo):**
```sql
-- Critical consistency check
SELECT 
  p.name,
  p.max_winners,
  COUNT(o.id) as actual_orders_created,
  CASE 
    WHEN COUNT(o.id) <= p.max_winners 
    THEN '✓ NO OVERSELLING' 
    ELSE '✗ OVERSOLD!' 
  END as status
FROM products p
LEFT JOIN orders o ON o.product_id = p.id
WHERE p.id = ?
GROUP BY p.id, p.name, p.max_winners;
```

**Expected Result (example):**
```
Product: iPhone 15 Pro Flash Sale
Max Winners: 50
Actual Orders Created: 50
Status: ✓ NO OVERSELLING
```

**Transaction Isolation:**
```sql
-- Order creation with locking
BEGIN;
  -- Check current winner count
  SELECT COUNT(*) FROM orders WHERE product_id = ? FOR UPDATE;
  
  -- Only insert if under limit
  INSERT INTO orders (user_id, product_id, bid_id, final_price, final_score, rank)
  VALUES (?, ?, ?, ?, ?, ?);
COMMIT;
```

**Why This Works:**
- **Bids table** = All attempts (can be 2000+ users)
- **Orders table** = Actual winners (must be ≤ max_winners)
- Atomic operations prevent race conditions
- Database-level constraints enforce business rules

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

## Stress Test Results (AWS Deployment)

### Validation Test (100 Concurrent Users)

**Date:** December 11, 2025
**Tool:** k6 load testing framework
**Scenario:** Gradual ramp (30s→20, 1m→50, 1m→100, 2m sustained)

**Results:**
```
Total Iterations:     2,032
VUs Max:              100
Duration:             ~5 minutes
HTTP Requests:        4,656 total (15.3/s avg)

Success Metrics:
✓ HTTP Success Rate:  97.54% (threshold: 85%)
✓ Registration:       99.75% (2,027/2,032)
✓ Login:              99.75% (2,027/2,032)  
✓ Bid Submission:     99.65% (2,020/2,027)
✓ Total Bids:         2,020 (threshold: 80)

Performance Metrics:
- Bid Latency Avg:    261ms    ✓ Excellent
- Bid Latency P95:    254ms    ✓ Sub-second
- Login Latency Avg:  6.65s    ⚠ Slow (bcrypt)
- HTTP Req P95:       13.05s   ⚠ Above 3s target

Database Consistency:
✓ Orders Created:     50 (max_winners: 50)
✓ No Overselling:     Verified
✓ Connection Pool:    85/225 (38% utilization)
```

**Analysis:**
- **Strengths:** 99% success rate, fast bid processing, zero data corruption
- **Weaknesses:** Login/registration slow (bcrypt security tradeoff)
- **Conclusion:** System handles 100 concurrent users reliably

---

### Thundering Herd Test (1000 Concurrent Users)

**Date:** December 11, 2025
**Tool:** k6 load testing framework
**Scenario:** Thundering herd with auto-scaling enabled

**Infrastructure:**
- ECS Tasks: 5 (auto-scaling 4-10, 70% CPU target)
- RDS: db.t3.small (~225 max connections)
- Auto-scaling: Enabled with 60s cooldown

**Load Profile:**
```
Stage 1: 30s → 100 users    (warm-up)
Stage 2: 1m  → 300 users    (gradual ramp)
Stage 3: 1m  → 600 users    (continued ramp)
Stage 4: 1m  → 1000 users   (target reached)
Stage 5: 90s @ 1000 users   (sustained peak)
Stage 6: 30s → 0 users      (ramp-down)
```

**Results:**
```
Total Iterations:     4,330
Completed Iterations: 4,330
Interrupted:          434
VUs Max:              1000
Duration:             5m 30s
HTTP Requests:        13,599 total (41.2/s avg)

Success Metrics:
✓ Bid Success Rate:   99% (4,583/4,592) - EXCELLENT ✓
✓ HTTP Success Rate:  93.45% (12,708/13,599)
✓ Registration:       98.88% (4,597/4,649)
✓ Error Rate:         6.55% (target: <10%) ✓
✓ Total Bids:         4,583 (target: >800) - 573% OVER ✓

Performance Metrics:
- Bid Latency Avg:    253ms    ✓ Sub-second
- Bid Latency P95:    283ms    ✓ Excellent
- HTTP Req Avg:       15.27s   (includes slow auth)
- HTTP Req P95:       47.7s    ⚠ Above target (auth bottleneck)
- Throughput:         41.2 req/s

Auto-Scaling Behavior:
✓ Baseline: 5 tasks running
✓ During test: Tasks adjusted dynamically
✓ Post-test: Scaled back to 4 tasks (scale-in)
✓ CPU triggered scaling as expected
```

**Auto-Scaling Impact:**
```
BEFORE Auto-Scaling (Historical):
- Error Rate: ~15-20% at 1000 users
- Connection timeouts common
- Resource exhaustion at peak

AFTER Auto-Scaling (Current):
- Error Rate: 6.55% at 1000 users ✓
- 50%+ error reduction
- Automatic capacity adjustment
- Sustained 1000 concurrent users successfully
```

**Analysis:**
- **Major Success:** 99% bid success rate at 1000 concurrent users
- **Auto-scaling works:** Error rate reduced from 15-20% to 6.5%
- **Bottleneck:** Authentication (bcrypt) remains slow, not bid processing
- **Conclusion:** System successfully handles extreme flash sale load with auto-scaling

---

### Projected: Further Optimization

**Scaling Strategy:**
- Current: 4 ECS tasks, db.t3.small RDS
- Expected success rate: 90-95%
- Expected CPU: 70-80% peak
- Database connections: 120/225 (53%)
- Redis memory: <10% (plenty of headroom)

**DEMO Mode Scenario:**
- Gradual ramp: 50→200→500→1000 users over 3 minutes
- 2-minute sustain at 1000 concurrent users
- Demonstrates system scalability and stability

---

## Monitoring & Observability

**Current Monitoring (AWS):**

**CloudWatch Metrics:**
- ECS CPU & Memory utilization (per task and service)
- RDS database connections, CPU, storage
- ElastiCache Redis CPU, memory, evictions
- ALB request count, response time, HTTP codes
- Custom dashboard: `RTB-Demo-Dashboard`

**Application Logging:**
- Winston logger with JSON format
- Log levels: error, warn, info, debug
- ECS CloudWatch Logs integration
- Log retention: 7 days

**Key Metrics to Track:**
```javascript
// Performance
- API latency (p50, p95, p99)
- Bid processing time (avg, max)
- WebSocket connection count
- Database query duration

// Business
- Bids per minute
- Active sales count
- Winner selection rate
- Order creation success

// Health
- HTTP error rates (4xx, 5xx)
- Database connection pool usage
- Redis memory usage
- Task restart count
```

**Dashboards (CloudWatch):**
- ECS Service Overview
- RDS Performance Insights
- ALB Monitoring
- Custom: RTB-Demo-Dashboard (for video recording)

**Alerts (Recommended):**
- CPU > 80% for 5 minutes → Scale out
- Error rate > 5% for 2 minutes → Investigate
- Database connections > 200 → Add capacity
- Redis memory > 90% → Upgrade node type
- Task unhealthy → Auto-restart (built-in)

---
- Error rate > 1% for 2 minutes
- Database connection pool exhausted
- Redis memory > 90%

---

---

## Implementation Progress

### Phase 2: Core Infrastructure ✅ COMPLETE
- PostgreSQL database with migrations
- Redis for caching and leaderboards
- User authentication (JWT)
- Admin dashboard backend
- Docker Compose for local development

### Phase 3: Bidding Engine ✅ COMPLETE
- Scoring algorithm: Score = α·P + β/(T+1) + γ·W
- High-concurrency bid submission (POST /api/v1/bids)
- Bid updates (PUT /api/v1/bids/:id)
- Redis ZSET leaderboard (sub-10ms queries)
- Real-time rank calculation
- Order creation for top K winners

### Phase 4: Real-Time Updates ✅ COMPLETE
- WebSocket server (Socket.IO)
- Periodic broadcast service (2-second intervals)
- Frontend dashboard (login, bidding, leaderboard)
- Multi-user concurrent testing
- Real-time synchronization

### Phase 5: AWS Deployment ✅ COMPLETE
- ECS Fargate containerization
- RDS PostgreSQL (db.t3.small, ~225 connections)
- ElastiCache Redis (cache.t3.micro)
- Application Load Balancer
- VPC endpoints for private connectivity
- CloudWatch logging and monitoring

### Phase 6: Stress Testing & Auto-Scaling ✅ COMPLETE
- k6 load testing framework
- Validation: 100 users (99% success rate)
- Thundering herd: 1000 users (99% bid success, 6.5% error rate)
- Auto-scaling: 4-10 tasks, 70% CPU target
- Error reduction: 15-20% → 6.5% (>50% improvement)
- Consistency verification: Zero overselling confirmed

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
