# Stress Testing Suite

Comprehensive load testing for the Real-Time Bidding system using k6.

## Quick Start

```bash
# Run interactive test menu
cd tests/stress
./run-stress-tests.sh

# View test results
./view-results.sh
```

All test results are saved to `./stress-results/` with both detailed JSON and summary files.

## Prerequisites

### Install k6

**macOS:**
```bash
brew install k6
```

**Linux:**
```bash
sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
sudo apt-get update
sudo apt-get install k6
```

**Windows:**
```powershell
choco install k6
```

Or download from: https://k6.io/docs/getting-started/installation/

### Required Tools
- `jq` - JSON processor (for test runner)
- `curl` - HTTP client (for test runner)

## Test Scenarios

### Scenario 1: Thundering Herd
**File:** `scenario1-thundering-herd.js`

Simulates 1000+ users bidding simultaneously when product goes live (flash sale scenario).

**Load Profile:**
- Ramp up: 10s to 100 users, 20s to 1000 users
- Sustain: 30s at 1000 concurrent users
- Ramp down: 10s to 0 users

**Metrics:**
- Bid success rate (target: >80%)
- Response time p95 (target: <2s)
- Error rate (target: <5%)

**Run:**
```bash
./run-stress-tests.sh
# Select option 1
```

Or directly:
```bash
export PRODUCT_ID=<product_id>
k6 run -e API_BASE="http://rtb-alb-1080675720.us-west-2.elb.amazonaws.com/api/v1" \
       -e PRODUCT_ID="$PRODUCT_ID" \
       scenario1-thundering-herd.js
```

---

### Scenario 2: Sustained Load
**File:** `scenario2-sustained-load.js`

Tests system stability under continuous load over 7.5 minutes.

**Load Profile:**
- Warm up: 30s to 100 users
- Ramp: 1m to 500 users
- Sustain: 5m at 500 concurrent users
- Cool down: 1.5m to 0 users

**Test Mix:**
- 70% new bids
- 30% bid updates
- Periodic leaderboard queries (every 3rd iteration)
- Status checks (every 5th iteration)

**Metrics:**
- New bid success rate (target: >70%)
- Update success rate (target: >80%)
- Leaderboard latency p90 (target: <1s)

**Run:**
```bash
./run-stress-tests.sh
# Select option 2
```

---

### Scenario 3: Update Spike
**File:** `scenario3-update-spike.js`

Simulates exponential increase in bid updates as deadline approaches (panic buying).

**Load Profile:**
- Phase 1 (30s): 50 users submit initial bids
- Phase 2 (2m): Exponential spike from 10→200 concurrent updates

**Metrics:**
- Update success rate (target: >60% during spike)
- Redis latency p95 (target: <500ms)
- Conflict rate tracking
- Response time p99 (target: <5s)

**Run:**
```bash
./run-stress-tests.sh
# Select option 3
```

---

## Running Tests

### Quick Start (Recommended)

1. **Ensure AWS deployment is running:**
   ```bash
   curl http://rtb-alb-1080675720.us-west-2.elb.amazonaws.com/health
   ```

2. **Run test suite:**
   ```bash
   cd tests/stress
   ./run-stress-tests.sh
   ```

3. **Select scenario from menu** - Tests run quietly and save results to `./stress-results/`

4. **View results:**
   ```bash
   ./view-results.sh
   ```

### Test Output

All tests now run in **quiet mode** with results saved to files:

- **Detailed metrics:** `stress-results/[test-name]-[timestamp].json`
- **Summary report:** `stress-results/[test-name]-[timestamp]-summary.json`

No console spam! Use `view-results.sh` to review test outcomes.

### Manual Test Execution

**Create test product first:**
```bash
# Login as admin
TOKEN=$(curl -s -X POST http://rtb-alb-1080675720.us-west-2.elb.amazonaws.com/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@test.com","password":"Admin123"}' | jq -r '.data.token')

# Create product
START=$(date -u -v+5S +"%Y-%m-%dT%H:%M:%SZ")
END=$(date -u -v+1H +"%Y-%m-%dT%H:%M:%SZ")

PRODUCT_ID=$(curl -s -X POST http://rtb-alb-1080675720.us-west-2.elb.amazonaws.com/api/v1/admin/products \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"Stress Test Product\",
    \"description\": \"For load testing\",
    \"base_price\": 999,
    \"initial_inventory\": 100,
    \"max_winners\": 50,
    \"sale_start_time\": \"$START\",
    \"sale_end_time\": \"$END\"
  }" | jq -r '.data.id')

# Activate product
curl -s -X POST "http://rtb-alb-1080675720.us-west-2.elb.amazonaws.com/api/v1/admin/products/$PRODUCT_ID/activate" \
  -H "Authorization: Bearer $TOKEN"

echo "Product ID: $PRODUCT_ID"
```

**Run k6 test:**
```bash
k6 run -e PRODUCT_ID="$PRODUCT_ID" scenario1-thundering-herd.js
```

---

## Interpreting Results

### Key Metrics to Watch

**HTTP Metrics:**
- `http_req_duration`: Request latency (check p95, p99)
- `http_req_failed`: Error rate (should be <5-10%)
- `http_reqs`: Total requests per second

**Custom Metrics:**
- `bid_success_rate`: Successful bid submissions
- `bid_update_success_rate`: Successful bid updates
- `leaderboard_latency`: Redis query performance
- `login_latency`: Authentication overhead

**Thresholds:**
All scenarios include predefined thresholds. Test fails if thresholds not met.

### Example Output

```
✓ bid submitted successfully
✓ bid returns rank
✓ leaderboard retrieved

checks.........................: 95.43% ✓ 2863    ✗ 137
data_received..................: 8.1 MB  135 kB/s
data_sent......................: 3.4 MB  57 kB/s
http_req_duration..............: avg=847ms  p(95)=1.8s   p(99)=3.2s
http_req_failed................: 3.12%  ✓ 137     ✗ 4263
http_reqs......................: 4400   73.33/s
bid_success_rate...............: 856    
```

### AWS Monitoring

**During tests, monitor:**

1. **ECS Service Metrics (CloudWatch):**
   - CPUUtilization (target: <70%)
   - MemoryUtilization (target: <80%)
   - Active task count

2. **RDS Performance Insights:**
   - Database load (connections, queries/sec)
   - Top SQL queries
   - Wait events

3. **ElastiCache Metrics:**
   - CacheHits vs CacheMisses
   - CPU utilization
   - Network throughput

4. **ALB Metrics:**
   - Request count
   - Target response time
   - HTTP 5xx errors

---

## Consistency Verification

After stress tests, verify data consistency:

```bash
# Get total bids for product
TOTAL_BIDS=$(curl -s "http://rtb-alb-1080675720.us-west-2.elb.amazonaws.com/api/v1/bids/leaderboard/$PRODUCT_ID?limit=1000" \
  -H "Authorization: Bearer $TOKEN" | jq '.data.total')

# Check inventory
MAX_WINNERS=$(curl -s "http://rtb-alb-1080675720.us-west-2.elb.amazonaws.com/api/v1/products/$PRODUCT_ID" | jq '.data.max_winners')

echo "Total bids: $TOTAL_BIDS"
echo "Max winners: $MAX_WINNERS"
echo "Consistency: $([ "$TOTAL_BIDS" -ge "$MAX_WINNERS" ] && echo 'PASS' || echo 'FAIL')"
```

**Database verification (via EC2 bastion or local with DB credentials):**
```sql
-- Connect to RDS
psql -h rtb-db.cxs8mgm8ufcp.us-west-2.rds.amazonaws.com -U postgres -d rtb_database

-- Check bid counts
SELECT 
  product_id,
  COUNT(*) as total_bids,
  COUNT(DISTINCT user_id) as unique_bidders
FROM bids
WHERE product_id = <PRODUCT_ID> AND is_latest = true
GROUP BY product_id;

-- Verify no overselling
SELECT 
  p.name,
  p.max_winners,
  COUNT(b.id) as total_latest_bids,
  CASE 
    WHEN COUNT(b.id) > p.max_winners THEN 'OVERSOLD'
    ELSE 'OK'
  END as status
FROM products p
LEFT JOIN bids b ON b.product_id = p.id AND b.is_latest = true
WHERE p.id = <PRODUCT_ID>
GROUP BY p.id, p.name, p.max_winners;
```

---

## Troubleshooting

### High Error Rate (>10%)

**Possible causes:**
- Database connection pool exhausted
- Redis max connections reached
- ECS tasks hitting CPU/memory limits
- Network timeouts

**Solutions:**
- Increase ECS task count (scale out)
- Increase task CPU/memory allocation
- Tune PostgreSQL max_connections
- Optimize database queries (add indexes)

### Slow Response Times (p95 >3s)

**Check:**
- RDS Performance Insights for slow queries
- ElastiCache hit rate (should be >90%)
- ECS CPU utilization
- Network latency (ALB → ECS → RDS/Redis)

**Solutions:**
- Add database indexes
- Implement query result caching
- Use Redis for hot data
- Enable ALB connection pooling

### Memory Leaks

**Symptoms:**
- Memory utilization steadily increasing
- Tasks being killed and restarted

**Debug:**
- Add heap snapshots to Node.js app
- Check for unclosed database connections
- Review event listeners (potential memory leaks)

---

## Next Steps

After stress testing:

1. **Document Results:**
   - Create summary report with graphs
   - Note peak throughput achieved
   - Identify bottlenecks

2. **Optimize:**
   - Address performance issues found
   - Tune database queries
   - Adjust AWS resource allocation

3. **Re-test:**
   - Validate optimizations
   - Push limits further

4. **Production Readiness:**
   - Set up auto-scaling policies based on metrics
   - Configure CloudWatch alarms
   - Document capacity planning

---

## References

- [k6 Documentation](https://k6.io/docs/)
- [k6 Best Practices](https://k6.io/docs/testing-guides/test-types/)
- [AWS ECS Monitoring](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/cloudwatch-metrics.html)
- [RDS Performance Insights](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_PerfInsights.html)
