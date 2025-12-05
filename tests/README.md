# Test Suite

This directory contains all test scripts for the Real-Time Bidding system.

## Test Files

### `test-bidding.sh`
**Main comprehensive test suite for Phase 3 bidding engine**

Tests cover:
- User registration with random member weights
- Product creation and activation
- Bid submission with scoring algorithm (Score = α·P + β/(T+1) + γ·W)
- Bid updates with validation
- Leaderboard functionality (Redis ZSET)
- Real-time rank tracking
- Input validation (duplicate bids, price restrictions, etc.)

**Usage:**
```bash
./tests/test-bidding.sh
```

**Requirements:**
- Server running on port 3000
- PostgreSQL database configured
- Redis running on port 6379
- `jq` installed for JSON parsing
- `node` available for timestamp generation

**Expected Output:**
- All 17 tests should pass
- Displays current leaderboard with rankings
- Shows scoring breakdown for each bid

---

### `test-api.sh`
**Phase 2 API test suite**

Tests core infrastructure:
- Health check endpoint
- User registration and login
- JWT authentication
- Product CRUD operations
- Admin endpoints

**Usage:**
```bash
./tests/test-api.sh
```


---

### `test-simple-bid.sh`
**Quick smoke test for bidding functionality**

Minimal test for rapid verification:
- Single user registration
- Product creation
- One bid submission
- Leaderboard fetch

**Usage:**
```bash
./tests/test-simple-bid.sh
```

---

## Running Tests

### Prerequisites

1. **Install jq** (JSON processor):
   ```bash
   brew install jq  # macOS
   ```

2. **Start the server**:
   ```bash
   node src/server.js
   ```

3. **Ensure databases are running**:
   - PostgreSQL: `psql rtb_database -c "SELECT 1;"`
   - Redis: `redis-cli ping`


### Run Individual Test

```bash
cd tests
./test-bidding.sh
```

## Test Output

Tests use color-coded output:
- 🟢 **Green** - Passed tests
- 🔴 **Red** - Failed tests  
- 🟡 **Yellow** - Test steps/headers
- 🔵 **Blue** - Section headers

Example output:
```
========================================
Phase 3: Bidding Engine Test Suite
========================================
▶ 1. Creating test users...
✓ PASS: User 1 created (ID: 17, Weight: 0.82)
✓ PASS: User 2 created (ID: 18, Weight: 1.95)
...
```

## Troubleshooting

### Server Not Running
```
curl: (7) Failed to connect to localhost port 3000
```
**Solution:** Start the server with `node src/server.js`

### Database Connection Failed
```
error: connect ECONNREFUSED 127.0.0.1:5432
```
**Solution:** Start PostgreSQL and verify connection

### Redis Connection Failed
```
error: Redis connection to localhost:6379 failed
```
**Solution:** Start Redis with `docker-compose up -d redis` or `redis-server`

### Timezone Issues
If you see "Sale has already ended" errors, ensure the migration `006_fix_timestamp_timezone.sql` has been applied:
```bash
psql rtb_database < migrations/006_fix_timestamp_timezone.sql
```

### Token Expired
Tokens expire after 1 hour. If tests fail with "Token expired", simply re-run the test.

## CI/CD Integration

To integrate with CI/CD pipelines:

```bash
#!/bin/bash
# ci-test.sh

# Start services
docker-compose up -d postgres redis

# Wait for services
sleep 5

# Run migrations
node src/database/migrate.js

# Start server in background
node src/server.js &
SERVER_PID=$!

# Wait for server
sleep 3

# Run tests
./tests/test-bidding.sh
TEST_RESULT=$?

# Cleanup
kill $SERVER_PID
docker-compose down

exit $TEST_RESULT
```

## Test Coverage

| Feature | test-bidding.sh | test-api.sh | test-phase3.sh |
|---------|----------------|-------------|----------------|
| User Auth | ✅ | ✅ | ✅ |
| Product CRUD | ✅ | ✅ | ✅ |
| Bid Submission | ✅ | ❌ | ✅ |
| Bid Updates | ✅ | ❌ | ✅ |
| Scoring Algorithm | ✅ | ❌ | ✅ |
| Leaderboard | ✅ | ❌ | ✅ |
| Redis ZSET | ✅ | ❌ | ✅ |
| Validation | ✅ | ❌ | ✅ |
| WebSocket | ⏳ | ❌ | ⏳ |

✅ Covered | ❌ Not covered | ⏳ Partial/Future

## Future Enhancements

- [ ] WebSocket connection testing
- [ ] Load testing scripts
- [ ] Performance benchmarks
- [ ] Unit tests (Jest/Mocha)
- [ ] Integration with test frameworks
- [ ] Automated screenshot generation
- [ ] API response time tracking
