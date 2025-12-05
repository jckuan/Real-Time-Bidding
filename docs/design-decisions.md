# Design Decisions & Future Options

This document captures design decisions made during development and alternative options for future consideration.

---

## 1. Scoring Parameters Design

### Current Implementation: Per-Product with Global Defaults

**Decision Made:** Phase 1 - December 5, 2025

```sql
CREATE TABLE scoring_parameters (
    id SERIAL PRIMARY KEY,
    product_id INTEGER UNIQUE REFERENCES products(id) ON DELETE CASCADE,
    alpha DECIMAL(10, 6) NOT NULL DEFAULT 1.0,
    beta DECIMAL(10, 6) NOT NULL DEFAULT 100.0,
    gamma DECIMAL(10, 6) NOT NULL DEFAULT 50.0,
    is_active BOOLEAN DEFAULT TRUE,
    ...
);
```

**How it works:**
- `product_id = NULL` → Global defaults (α=1.0, β=100.0, γ=50.0)
- `product_id = X` → Product-specific parameters override globals
- Admins can customize per product via API
- Falls back gracefully to global defaults

**Why this design:**
- ✅ Simple and predictable
- ✅ Different products can have different scoring dynamics
- ✅ Fine-grained control for each flash sale
- ✅ Easy to understand and debug
- ✅ Perfect for MVP

---

### Alternative Options (Future Consideration)

#### Option A: Category-Based Parameters

**Use Case:** Group similar products together (electronics, luxury goods, budget items)

```sql
CREATE TABLE product_categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT
);

CREATE TABLE scoring_parameters (
    id SERIAL PRIMARY KEY,
    category_id INTEGER REFERENCES product_categories(id),
    product_id INTEGER REFERENCES products(id),
    alpha DECIMAL(10, 6) NOT NULL,
    beta DECIMAL(10, 6) NOT NULL,
    gamma DECIMAL(10, 6) NOT NULL,
    priority INTEGER DEFAULT 0,
    ...
);

-- Lookup logic:
-- 1. Check product_id exact match
-- 2. Check category_id
-- 3. Fall back to global defaults
```

**When to implement:** Phase 4+ when you have many products

**Advantages:**
- Reusable parameter sets across similar products
- Easier bulk management
- Category-level A/B testing

**Migration path:**
```sql
ALTER TABLE products ADD COLUMN category_id INTEGER REFERENCES product_categories(id);
ALTER TABLE scoring_parameters ADD COLUMN category_id INTEGER;
```

---

#### Option B: Time-Based Parameters

**Use Case:** Different scoring during different phases of the sale

```sql
CREATE TABLE scoring_parameters (
    id SERIAL PRIMARY KEY,
    product_id INTEGER REFERENCES products(id),
    valid_from TIMESTAMP NOT NULL,
    valid_until TIMESTAMP NOT NULL,
    alpha DECIMAL(10, 6) NOT NULL,
    beta DECIMAL(10, 6) NOT NULL,
    gamma DECIMAL(10, 6) NOT NULL,
    ...
);

-- Example: Emphasize speed early, price later
-- Early: α=0.5, β=200.0, γ=50.0 (reward fast bidders)
-- Late:  α=2.0, β=50.0, γ=50.0  (reward high prices)
```

**When to implement:** Advanced phase for sophisticated sale mechanics

**Advantages:**
- Dynamic scoring during sale progression
- Can create urgency/strategy shifts

**Disadvantages:**
- More complex to configure
- May confuse users

---

#### Option C: A/B Testing Framework

**Use Case:** Test different parameter combinations to optimize engagement

```sql
CREATE TABLE scoring_experiments (
    id SERIAL PRIMARY KEY,
    experiment_name VARCHAR(100) NOT NULL,
    product_id INTEGER REFERENCES products(id),
    traffic_percentage DECIMAL(5, 2) NOT NULL,
    alpha DECIMAL(10, 6) NOT NULL,
    beta DECIMAL(10, 6) NOT NULL,
    gamma DECIMAL(10, 6) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE
);

CREATE TABLE experiment_assignments (
    user_id INTEGER REFERENCES users(id),
    experiment_id INTEGER REFERENCES scoring_experiments(id),
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, experiment_id)
);
```

**When to implement:** Phase 5+ once you have significant traffic

**Advantages:**
- Data-driven optimization
- Can test multiple strategies simultaneously

**Disadvantages:**
- Requires analytics infrastructure
- May create fairness concerns

---

### Decision Matrix

| Design | Complexity | Flexibility | Performance | Best For |
|--------|-----------|-------------|-------------|----------|
| **Per-Product (Current)** | Low | Medium | Excellent | MVP, simple sales |
| Category-Based | Medium | High | Good | Many products, bulk management |
| Time-Based | Medium | High | Good | Dynamic sales strategy |
| A/B Testing | High | Very High | Medium | Optimization, data-driven |

**Recommendation:** Start simple (current), evolve based on actual needs.

---

## 2. Member Weight Assignment

### Current Implementation: Random Assignment (Demo/MVP)

**Decision Made:** Phase 2 - December 5, 2025

**Location:** `src/services/authService.js` line 38

```javascript
// Assign member weight (random between 0.5 and 2.0 for demo)
const memberWeight = (Math.random() * 1.5 + 0.5).toFixed(2);
```

**Why this design:**
- ✅ Simple implementation
- ✅ Good for testing scoring algorithm
- ✅ Creates variety in leaderboard
- ✅ Perfect for MVP/demo

**Limitations:**
- Not based on actual user value
- Users can't improve their weight
- No incentive for loyalty

---

### Production-Ready Alternatives

#### Option A: Fixed Tier System

**Use Case:** Subscription-based or membership levels

**When to implement:** Phase 4 (Post-Launch)

```javascript
const MEMBER_TIERS = {
  FREE: 0.80,
  BASIC: 1.00,    // Default
  PREMIUM: 1.50,  // $9.99/month
  VIP: 2.00       // $19.99/month
};
```

**Database Schema:**
```sql
CREATE TABLE user_tiers (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL,
    weight DECIMAL(5, 2) NOT NULL,
    monthly_fee DECIMAL(10, 2),
    benefits TEXT[]
);

ALTER TABLE users ADD COLUMN tier_id INTEGER REFERENCES user_tiers(id);
```

**Advantages:**
- Clear value proposition
- Predictable for users
- Easy to monetize
- Simple to implement

---

#### Option B: Activity-Based Dynamic Weight

**Use Case:** Reward engagement and participation

**When to implement:** Phase 5 (Growth)

```javascript
async calculateMemberWeight(userId) {
  const baseWeight = 1.0;
  
  const accountAge = await getAccountAgeBonus(userId);      // 0-0.3
  const purchaseBonus = await getPurchaseHistoryBonus(userId); // 0-0.5
  const participationBonus = await getParticipationBonus(userId); // 0-0.2
  const reliabilityBonus = await getPaymentReliabilityBonus(userId); // 0-0.2
  
  const totalWeight = baseWeight + accountAge + purchaseBonus 
                      + participationBonus + reliabilityBonus;
  
  return Math.min(totalWeight, 2.0);
}
```

**Database Schema:**
```sql
CREATE TABLE user_activity_metrics (
    user_id INTEGER PRIMARY KEY REFERENCES users(id),
    account_age_days INTEGER DEFAULT 0,
    total_purchases INTEGER DEFAULT 0,
    successful_bids INTEGER DEFAULT 0,
    participation_rate DECIMAL(5, 2) DEFAULT 0,
    payment_reliability DECIMAL(5, 2) DEFAULT 100.00,
    last_calculated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Advantages:**
- Rewards loyal users naturally
- Encourages engagement
- Fair - based on behavior

**Disadvantages:**
- Complex calculation
- Needs historical data

---

#### Option C: Hybrid Tier + Performance

**Use Case:** Best of both worlds - revenue + engagement

**When to implement:** Phase 6 (Maturity)

```javascript
async calculateMemberWeight(userId) {
  // Base weight from tier
  const tier = await getUserTier(userId);
  const baseWeight = tier.baseWeight; // 0.5, 1.0, 1.5
  
  // Performance multiplier (0.8x to 1.2x)
  const performanceMultiplier = await getPerformanceMultiplier(userId);
  
  const finalWeight = baseWeight * performanceMultiplier;
  return Math.min(finalWeight, 2.0);
}
```

**Advantages:**
- Revenue from tiers
- Rewards performance
- Flexible and fair

---

#### Option D: Referral-Based Bonuses

**Use Case:** Viral growth and community building

```javascript
async calculateMemberWeight(userId) {
  const baseWeight = 1.0;
  
  const referralCount = await getReferralCount(userId);
  const referralBonus = Math.min(referralCount * 0.1, 0.5);
  
  return baseWeight + referralBonus;
}
```

**Database Schema:**
```sql
CREATE TABLE referrals (
    referrer_id INTEGER REFERENCES users(id),
    referred_id INTEGER REFERENCES users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    PRIMARY KEY (referrer_id, referred_id)
);
```

**Advantages:**
- Encourages user acquisition
- Builds community
- Organic growth

---

### Strategy Comparison

| Strategy | Complexity | Fairness | Revenue | Retention | Viral Growth |
|----------|-----------|----------|---------|-----------|--------------|
| **Random (Current)** | Very Low | High | None | Low | None |
| Fixed Tiers | Low | Medium | High | Medium | Low |
| Activity-Based | High | Very High | Low | High | Low |
| Hybrid | Very High | High | High | Very High | Medium |
| Referral-Based | Medium | Medium | Low | High | Very High |

---

### Recommended Implementation Timeline

#### Phase 2-3 (Current)
**Keep random assignment** for MVP testing.

#### Phase 4 (Post-Launch)
**Implement Fixed Tier System:**
- Free tier: 0.80
- Basic: 1.00 (default)
- Premium: 1.50 ($9.99/month)
- VIP: 2.00 ($19.99/month)

#### Phase 5 (Growth)
**Add Activity Bonuses** on top of tiers:
- ±0.20 based on win rate, payment reliability
- Encourages engagement without complexity

#### Phase 6 (Maturity)
**Optional: Referral Bonuses:**
- +0.05 per active referral (max +0.30)
- Drives growth

---

### Migration Path (All Backward Compatible)

```javascript
// Phase 2-3: Random (current)
const memberWeight = (Math.random() * 1.5 + 0.5).toFixed(2);

// Phase 4: Add tiers
const memberWeight = getTierWeight(userTier) || 1.0;

// Phase 5: Add activity bonus
const baseWeight = getTierWeight(userTier) || 1.0;
const activityBonus = await calculateActivityBonus(userId);
const memberWeight = baseWeight + activityBonus;

// Phase 6: Add referrals
const memberWeight = baseWeight + activityBonus + referralBonus;
```

**All changes are additive** - no breaking changes to existing users!

---

## 3. Database Connection Strategy

### Issue Encountered: Phase 2 Testing

**Problem:** Port conflicts between Docker containers and local PostgreSQL/Redis installations.

**Symptoms:**
```
Error: ports are not available: exposing port TCP 0.0.0.0:5432
bind: address already in use
```

---

### Resolution Options

#### Option A: Use Docker for Everything (Recommended)

**Steps:**
1. Stop local PostgreSQL/Redis services
2. Use Docker Compose exclusively
3. Consistent environment across team

**Commands:**
```bash
# Stop local services
brew services stop postgresql
brew services stop redis

# Start Docker services
docker-compose up -d postgres redis

# Use Docker containers
```

**Advantages:**
- ✅ Consistent across team members
- ✅ Easy cleanup (docker-compose down -v)
- ✅ Matches production environment
- ✅ No port conflicts

---

#### Option B: Use Local Services

**Steps:**
1. Don't start Docker for databases
2. Update `.env` with local credentials
3. Use native PostgreSQL/Redis

**Advantages:**
- ✅ Better performance (no Docker overhead)
- ✅ Familiar tools
- ✅ Persistent data by default

**Disadvantages:**
- ❌ Team members may have different versions
- ❌ Manual setup required
- ❌ Harder to reset state

---

#### Option C: Use Different Ports

**Steps:**
1. Keep both Docker and local services
2. Configure Docker to use different ports

**docker-compose.yml:**
```yaml
postgres:
  ports:
    - "5433:5432"  # Expose on 5433 instead

redis:
  ports:
    - "6380:6379"  # Expose on 6380 instead
```

**.env:**
```
DB_PORT=5433
REDIS_PORT=6380
```

**Advantages:**
- ✅ Both systems available
- ✅ Can test against both

**Disadvantages:**
- ❌ Confusing which is which
- ❌ Uses more resources

---

### Current Setup (Working)

**PostgreSQL:** Local installation on port 5432
**Redis:** Docker container on port 6379

**Status:** ✅ Working correctly, see `.env` configuration

---

## 4. Admin Access Control

### Current Implementation: JWT-Based

**Decision Made:** Phase 2

All admin endpoints require JWT token but no role checking yet.

```javascript
// Admin routes
router.use(authMiddleware); // Only checks for valid JWT

router.post('/products', adminController.createProduct);
router.put('/products/:id/scoring', adminController.updateScoring);
```

**Limitation:** Any authenticated user can access admin endpoints.

---

### Future Option: Role-Based Access Control (RBAC)

**When to implement:** Before production launch

**Database Schema:**
```sql
CREATE TABLE roles (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL
);

CREATE TABLE user_roles (
    user_id INTEGER REFERENCES users(id),
    role_id INTEGER REFERENCES roles(id),
    PRIMARY KEY (user_id, role_id)
);

INSERT INTO roles (name) VALUES ('user'), ('admin'), ('moderator');
```

**Middleware:**
```javascript
const requireRole = (role) => {
  return async (req, res, next) => {
    const userRoles = await getUserRoles(req.user.id);
    if (!userRoles.includes(role)) {
      return next(new AppError('Insufficient permissions', 403));
    }
    next();
  };
};

// Use in routes
router.post('/products', authMiddleware, requireRole('admin'), 
  adminController.createProduct);
```

**Status:** 📝 Planned for Phase 4

---

## Summary

### Active Decisions (Current Implementation)

| Component | Decision | Status | Phase |
|-----------|----------|--------|-------|
| Scoring Parameters | Per-product with global defaults | ✅ Active | Phase 1-3 |
| Member Weight | Random (0.5-2.0) | ✅ Active | Phase 2-3 |
| Database | Mixed (Local PostgreSQL + Docker Redis) | ✅ Working | Phase 2 |
| Admin Access | JWT-only (no role check) | ⚠️ MVP only | Phase 2 |

### Planned Enhancements

| Enhancement | Target Phase | Priority |
|-------------|-------------|----------|
| Fixed tier member weights | Phase 4 | High |
| RBAC for admin endpoints | Phase 4 | High |
| Activity-based weight bonuses | Phase 5 | Medium |
| Category-based scoring | Phase 4+ | Low |
| A/B testing framework | Phase 5+ | Low |

---

## Document Maintenance

**Created:** December 5, 2025
**Last Updated:** December 5, 2025

When making design decisions, add them to this document with:
- What was decided
- Why it was decided
- Alternative options considered
- When to revisit the decision
