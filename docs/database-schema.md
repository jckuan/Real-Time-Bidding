# Database Schema Design

## Overview

This document defines the database schemas for the Real-Time Bidding & Flash Sale System. The design focuses on:
- **Data consistency** to prevent over-selling
- **High-performance reads** for real-time operations
- **Inventory locking** mechanisms to handle concurrent bids

---

## Schema Diagrams

### Entity Relationship

```
Users (1) ──── (N) Bids (N) ──── (1) Products
  │                                      │
  │                                      │
  └──────── (N) Orders (N) ──────────────┘
```

---

## PostgreSQL Tables

### 1. Users Table

Stores user account information and member weight for scoring.

```sql
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    username VARCHAR(100) NOT NULL,
    member_weight DECIMAL(5, 2) NOT NULL DEFAULT 1.00,
    -- Member weight (W) for scoring formula
    -- Range: 0.50 (basic) to 2.00 (premium)
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Indexes
    INDEX idx_email (email),
    INDEX idx_username (username)
);
```

**Notes:**
- `member_weight` is pre-calculated or assigned based on user tier
- Can be extended with additional profile fields (name, phone, address)

---

### 2. Products Table

Stores product information and inventory for flash sales.

```sql
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    base_price DECIMAL(10, 2) NOT NULL,
    -- Base/starting price for reference
    initial_inventory INTEGER NOT NULL,
    -- Original stock quantity
    current_inventory INTEGER NOT NULL,
    -- Real-time available inventory
    -- CRITICAL: Must be protected with locks
    version INTEGER NOT NULL DEFAULT 0,
    -- Optimistic locking version
    sale_start_time TIMESTAMP NOT NULL,
    sale_end_time TIMESTAMP NOT NULL,
    status VARCHAR(20) DEFAULT 'pending',
    -- pending, active, ended, cancelled
    max_winners INTEGER NOT NULL,
    -- K: Maximum number of winners (Top K)
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CHECK (current_inventory >= 0),
    CHECK (initial_inventory >= max_winners),
    CHECK (sale_end_time > sale_start_time),
    
    -- Indexes
    INDEX idx_status (status),
    INDEX idx_sale_times (sale_start_time, sale_end_time)
);
```

**Notes:**
- `version` column enables optimistic locking for inventory updates
- `current_inventory` must never go negative
- `max_winners` (K) defines how many users can win

---

### 3. Bids Table

Stores all bid attempts with scoring information.

```sql
CREATE TABLE bids (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    bid_price DECIMAL(10, 2) NOT NULL,
    -- P: Price offered by user
    reaction_time DECIMAL(10, 3) NOT NULL,
    -- T: Time in seconds since sale start
    member_weight DECIMAL(5, 2) NOT NULL,
    -- W: Cached from user profile at bid time
    calculated_score DECIMAL(15, 6) NOT NULL,
    -- Final score = α*P + β/(T+1) + γ*W
    bid_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_latest BOOLEAN DEFAULT TRUE,
    -- Flag to mark the latest bid from this user for this product
    status VARCHAR(20) DEFAULT 'active',
    -- active, superseded, withdrawn
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Composite index for finding user's latest bid for a product
    INDEX idx_user_product_latest (user_id, product_id, is_latest),
    INDEX idx_product_score (product_id, calculated_score DESC),
    INDEX idx_bid_timestamp (bid_timestamp),
    
    -- Unique constraint: one latest bid per user per product
    UNIQUE (user_id, product_id, is_latest) 
        WHERE is_latest = TRUE
);
```

**Notes:**
- Only one `is_latest = TRUE` bid per user per product
- When user updates bid, old bid gets `is_latest = FALSE`, new bid gets `is_latest = TRUE`
- `calculated_score` is pre-computed and stored for quick sorting
- `reaction_time` is calculated as `bid_timestamp - product.sale_start_time`

---

### 4. Orders Table

Stores final confirmed purchases (converted from winning bids).

```sql
CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    bid_id INTEGER NOT NULL REFERENCES bids(id) ON DELETE CASCADE,
    final_price DECIMAL(10, 2) NOT NULL,
    -- Price from the winning bid
    final_score DECIMAL(15, 6) NOT NULL,
    -- Score from the winning bid
    rank INTEGER NOT NULL,
    -- User's rank in the Top K (1 = highest score)
    order_status VARCHAR(20) DEFAULT 'confirmed',
    -- confirmed, paid, shipped, cancelled
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Indexes
    INDEX idx_user_orders (user_id),
    INDEX idx_product_orders (product_id),
    INDEX idx_rank (product_id, rank),
    
    -- Constraint: Ensure no duplicate orders for same bid
    UNIQUE (bid_id)
);
```

**Notes:**
- Created only after sale ends and winners are finalized
- `rank` indicates position in leaderboard (1 to K)
- Links back to original bid for audit trail

---

### 5. Scoring Parameters Table

Stores dynamic scoring formula parameters (α, β, γ).

```sql
CREATE TABLE scoring_parameters (
    id SERIAL PRIMARY KEY,
    product_id INTEGER UNIQUE REFERENCES products(id) ON DELETE CASCADE,
    -- If NULL, these are global defaults
    alpha DECIMAL(10, 6) NOT NULL DEFAULT 1.0,
    -- Weight for Price (P)
    beta DECIMAL(10, 6) NOT NULL DEFAULT 100.0,
    -- Weight for Time component (1/(T+1))
    gamma DECIMAL(10, 6) NOT NULL DEFAULT 50.0,
    -- Weight for Member Weight (W)
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Constraints
    CHECK (alpha >= 0),
    CHECK (beta >= 0),
    CHECK (gamma >= 0),
    
    -- Index
    INDEX idx_product_params (product_id, is_active)
);

-- Insert global defaults
INSERT INTO scoring_parameters (product_id, alpha, beta, gamma, is_active)
VALUES (NULL, 1.0, 100.0, 50.0, TRUE);
```

**Notes:**
- Global parameters when `product_id IS NULL`
- Product-specific parameters override global defaults
- Can be updated in real-time for A/B testing

---

## Inventory Locking Strategy

### Option 1: Optimistic Locking (Recommended for Flash Sale End)

When finalizing orders at sale end:

```sql
-- Attempt to decrement inventory
UPDATE products
SET 
    current_inventory = current_inventory - 1,
    version = version + 1
WHERE 
    id = :product_id 
    AND version = :expected_version
    AND current_inventory > 0;

-- Check affected rows
-- If 0 rows affected, retry with new version or abort
```

**Pros:**
- No locks during bidding phase
- Fast concurrent reads
- Prevents race conditions via version check

**Cons:**
- Requires retry logic
- May have contention at high concurrency

---

### Option 2: Redis-based Inventory Control (Recommended for Real-time)

Use Redis atomic operations during bidding:

```lua
-- Lua script to check and decrement inventory atomically
local product_key = KEYS[1]
local inventory = tonumber(redis.call('GET', product_key))

if inventory > 0 then
    redis.call('DECR', product_key)
    return 1
else
    return 0
end
```

**Workflow:**
1. Sync inventory from PostgreSQL to Redis at sale start
2. During sale: All bid validations check Redis inventory
3. At sale end: Reconcile Redis → PostgreSQL with final winner list

**Pros:**
- Sub-millisecond performance
- True atomic operations
- Handles extreme concurrency

**Cons:**
- Requires Redis-PostgreSQL synchronization
- More complex architecture

---

## Data Consistency Guarantees

### No Over-Selling

**Rule:** `COUNT(orders WHERE product_id = X) <= products.max_winners`

**Implementation:**
1. **During bidding:** Redis tracks tentative Top K (leaderboard only)
2. **At sale end:** 
   - Query Top K bids by score
   - Create orders in transaction
   - Decrement inventory with optimistic lock
   - Verify `current_inventory >= 0`

**Transaction example:**

```sql
BEGIN;

-- Lock product row
SELECT current_inventory, version 
FROM products 
WHERE id = :product_id 
FOR UPDATE;

-- Insert orders for Top K winners
INSERT INTO orders (user_id, product_id, bid_id, final_price, final_score, rank)
SELECT 
    b.user_id, b.product_id, b.id, b.bid_price, b.calculated_score,
    ROW_NUMBER() OVER (ORDER BY b.calculated_score DESC) as rank
FROM bids b
WHERE 
    b.product_id = :product_id 
    AND b.is_latest = TRUE
ORDER BY b.calculated_score DESC
LIMIT :max_winners;

-- Decrement inventory
UPDATE products
SET 
    current_inventory = current_inventory - :winner_count,
    version = version + 1,
    status = 'ended'
WHERE id = :product_id;

COMMIT;
```

---

## Indexes Summary

| Table | Index | Purpose |
|-------|-------|---------|
| users | idx_email | Fast login lookup |
| products | idx_status | Filter active sales |
| products | idx_sale_times | Find current/upcoming sales |
| bids | idx_user_product_latest | Get user's current bid |
| bids | idx_product_score | Sort by score for Top K |
| orders | idx_user_orders | User order history |
| orders | idx_rank | Leaderboard display |

---

## Migration Strategy

1. **Development:** Run migrations with tools like `node-pg-migrate` or `Flyway`
2. **Production:** Zero-downtime migrations with backward-compatible changes
3. **Rollback plan:** Keep migration files versioned and reversible

---

## Future Enhancements

- **Partitioning:** Partition `bids` table by `product_id` for multi-product support
- **Archiving:** Move old bids/orders to archive tables after sale ends
- **Read replicas:** Offload reporting queries to PostgreSQL read replicas
- **Audit logging:** Track all inventory changes with triggers
