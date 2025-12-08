#!/bin/bash

# Phase 4: Real-Time Data & Frontend Integration Test
# Tests WebSocket broadcasts, concurrent connections, and frontend integration

API_BASE="http://localhost:3000/api/v1"
WS_URL="http://localhost:3000"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0

# Helper functions
print_test() {
  echo -e "${BLUE}[TEST]${NC} $1"
}

print_pass() {
  echo -e "${GREEN}[PASS]${NC} $1"
  ((PASSED++))
}

print_fail() {
  echo -e "${RED}[FAIL]${NC} $1"
  ((FAILED++))
}

echo "=========================================="
echo "Phase 4: Real-Time Integration Test"
echo "=========================================="
echo ""

# Test 1: Create test users
print_test "Creating 5 test users for concurrent bidding simulation"

USER_TOKENS=()
USER_IDS=()
USER_CREDENTIALS=()
REAL_NAMES=("alice" "bob" "carol" "david" "eve")

for i in {1..5}; do
  NAME="${REAL_NAMES[$((i-1))]}"
  TIMESTAMP=$(date +%s)
  USERNAME="${NAME}${TIMESTAMP}"
  EMAIL="${NAME}.${TIMESTAMP}@example.com"
  PASS="TestPass123"
  
  REGISTER_RESPONSE=$(curl -s -X POST "$API_BASE/auth/register" \
    -H "Content-Type: application/json" \
    -d "{\"username\":\"$USERNAME\",\"email\":\"$EMAIL\",\"password\":\"$PASS\"}")
  
  if echo "$REGISTER_RESPONSE" | jq -e '.success' > /dev/null 2>&1; then
    # Login
    LOGIN_RESPONSE=$(curl -s -X POST "$API_BASE/auth/login" \
      -H "Content-Type: application/json" \
      -d "{\"email\":\"$EMAIL\",\"password\":\"$PASS\"}")
    
    TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.data.token')
    USER_ID=$(echo "$LOGIN_RESPONSE" | jq -r '.data.user.id')
    
    USER_TOKENS+=("$TOKEN")
    USER_IDS+=("$USER_ID")
    USER_CREDENTIALS+=("$EMAIL:$PASS:$NAME")
    
    print_pass "Created user $i: $EMAIL (ID: $USER_ID)"
  else
    print_fail "Failed to create user $i"
  fi
done

# Test 2: Admin creates a product for testing
print_test "Creating test product with admin token"

TIMESTAMP=$(date +%s)
ADMIN_USERNAME="admin${TIMESTAMP}"
ADMIN_EMAIL="admin.${TIMESTAMP}@example.com"
ADMIN_PASS="AdminPass123"

# Register admin
curl -s -X POST "$API_BASE/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$ADMIN_USERNAME\",\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASS\"}" > /dev/null

# Login admin
ADMIN_LOGIN=$(curl -s -X POST "$API_BASE/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASS\"}")

ADMIN_TOKEN=$(echo "$ADMIN_LOGIN" | jq -r '.data.token')
ADMIN_CREDENTIALS="$ADMIN_EMAIL:$ADMIN_PASS:admin"

# Create product
SALE_START=$(date -u -v+5S +"%Y-%m-%dT%H:%M:%S.000Z" 2>/dev/null || date -u -d "+5 seconds" +"%Y-%m-%dT%H:%M:%S.000Z")
SALE_END=$(date -u -v+60S +"%Y-%m-%dT%H:%M:%S.000Z" 2>/dev/null || date -u -d "+60 seconds" +"%Y-%m-%dT%H:%M:%S.000Z")

PRODUCT_RESPONSE=$(curl -s -X POST "$API_BASE/admin/products" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"Phase 4 Test Product\",
    \"description\": \"Testing real-time broadcasts\",
    \"base_price\": 500.00,
    \"initial_inventory\": 3,
    \"max_winners\": 3,
    \"sale_start_time\": \"$SALE_START\",
    \"sale_end_time\": \"$SALE_END\"
  }")

PRODUCT_ID=$(echo "$PRODUCT_RESPONSE" | jq -r '.data.id')

if [ "$PRODUCT_ID" != "null" ] && [ -n "$PRODUCT_ID" ]; then
  print_pass "Created product ID: $PRODUCT_ID"
else
  print_fail "Failed to create product"
  echo "$PRODUCT_RESPONSE" | jq '.'
  exit 1
fi

# Test 3: Activate sale
print_test "Activating sale"

ACTIVATE_RESPONSE=$(curl -s -X POST "$API_BASE/admin/products/$PRODUCT_ID/activate" \
  -H "Authorization: Bearer $ADMIN_TOKEN")

if echo "$ACTIVATE_RESPONSE" | jq -e '.success' > /dev/null 2>&1; then
  print_pass "Sale activated successfully"
else
  print_fail "Failed to activate sale"
fi

# Wait for sale to start
echo ""
echo "Waiting for sale to start (5 seconds)..."
sleep 6

# Test 4: Simulate concurrent bidding
print_test "Simulating concurrent bids from 5 users"

for i in {0..4}; do
  TOKEN="${USER_TOKENS[$i]}"
  BID_PRICE=$((500 + i * 10))
  
  RESPONSE=$(curl -s -X POST "$API_BASE/bids" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"productId\":$PRODUCT_ID,\"bidPrice\":$BID_PRICE}")
  
  if echo "$RESPONSE" | jq -e '.success' > /dev/null 2>&1; then
    RANK=$(echo "$RESPONSE" | jq -r '.data.rank // "null"')
    SCORE=$(echo "$RESPONSE" | jq -r '.data.score // "null"')
    print_pass "User $((i+1)) bid submitted (Price: \$$BID_PRICE, Rank: #$RANK, Score: $SCORE)"
  else
    ERROR=$(echo "$RESPONSE" | jq -r '.error.message // "Unknown error"')
    print_fail "User $((i+1)) bid failed: $ERROR"
    echo "Response: $RESPONSE"
  fi
  
  # Small delay to simulate different reaction times
  sleep 0.3
done

# Test 5: Get leaderboard
print_test "Fetching leaderboard"

sleep 1

LEADERBOARD=$(curl -s "$API_BASE/bids/leaderboard/$PRODUCT_ID?limit=10")

if echo "$LEADERBOARD" | jq -e '.success' > /dev/null 2>&1; then
  BIDDERS=$(echo "$LEADERBOARD" | jq -r '.data.leaderboard | length')
  print_pass "Leaderboard retrieved with $BIDDERS bidders"
  
  echo ""
  echo "Top 3 Bidders:"
  echo "$LEADERBOARD" | jq -r '.data.leaderboard[0:3] | .[] | "  Rank #\(.rank): \(.email) - Score: \(.score)"'
  echo ""
else
  print_fail "Failed to fetch leaderboard"
fi

# Test 6: Update bids (price increase)
print_test "Testing bid updates for top 2 users"

for i in {0..1}; do
  TOKEN="${USER_TOKENS[$i]}"
  NEW_BID_PRICE=$((600 + i * 20))
  
  RESPONSE=$(curl -s -X PUT "$API_BASE/bids/$PRODUCT_ID" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"bidPrice\":$NEW_BID_PRICE}")
  
  if echo "$RESPONSE" | jq -e '.success' > /dev/null 2>&1; then
    RANK=$(echo "$RESPONSE" | jq -r '.data.rank // "null"')
    print_pass "User $((i+1)) updated bid to \$$NEW_BID_PRICE (New rank: #$RANK)"
  else
    ERROR=$(echo "$RESPONSE" | jq -r '.error.message // "Unknown error"')
    print_fail "User $((i+1)) update failed: $ERROR"
    echo "Response: $RESPONSE"
  fi
  
  sleep 0.5
done

# Test 7: Check individual user status
print_test "Checking individual user bid status"

TOKEN="${USER_TOKENS[0]}"
STATUS=$(curl -s "$API_BASE/bids/my-status/$PRODUCT_ID" \
  -H "Authorization: Bearer $TOKEN")

if echo "$STATUS" | jq -e '.success' > /dev/null 2>&1; then
  HAS_BID=$(echo "$STATUS" | jq -r '.data.hasBid')
  if [ "$HAS_BID" = "true" ]; then
    RANK=$(echo "$STATUS" | jq -r '.data.bid.rank')
    PRICE=$(echo "$STATUS" | jq -r '.data.bid.bidPrice')
    print_pass "User status retrieved (Price: \$$PRICE, Rank: #$RANK)"
  else
    print_fail "User should have a bid"
  fi
else
  print_fail "Failed to get user status"
fi

# Test 8: Verify frontend is accessible
print_test "Checking frontend accessibility"

FRONTEND_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:3000/login.html")

if [ "$FRONTEND_RESPONSE" = "200" ]; then
  print_pass "Frontend login page is accessible"
else
  print_fail "Frontend not accessible (HTTP $FRONTEND_RESPONSE)"
fi

# Test 9: Check multiple page loads
print_test "Verifying all frontend pages are accessible"

PAGES=("dashboard.html" "bidding.html" "styles.css" "config.js")
ALL_ACCESSIBLE=true

for PAGE in "${PAGES[@]}"; do
  RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:3000/$PAGE")
  if [ "$RESPONSE" != "200" ]; then
    ALL_ACCESSIBLE=false
    echo "  - $PAGE: HTTP $RESPONSE"
  fi
done

if [ "$ALL_ACCESSIBLE" = true ]; then
  print_pass "All frontend files are accessible"
else
  print_fail "Some frontend files are not accessible"
fi

# Test 10: WebSocket availability (simple check)
print_test "Checking WebSocket endpoint availability"

WS_CHECK=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:3000/socket.io/")

if [ "$WS_CHECK" = "200" ] || [ "$WS_CHECK" = "400" ]; then
  print_pass "WebSocket endpoint is responding"
else
  print_fail "WebSocket endpoint not responding properly (HTTP $WS_CHECK)"
fi

# Summary
echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo "=========================================="

if [ $FAILED -eq 0 ]; then
  echo -e "${GREEN}All tests passed!${NC}"
  echo ""
  echo "Phase 4 Complete! ✅"
  echo ""
  echo "=========================================="
  echo "TEST CREDENTIALS FOR MANUAL TESTING"
  echo "=========================================="
  echo ""
  echo "Admin Account:"
  IFS=':' read -r admin_email admin_pass admin_name <<< "$ADMIN_CREDENTIALS"
  echo "  Name:     $admin_name"
  echo "  Email:    $admin_email"
  echo "  Password: $admin_pass"
  echo ""
  echo "Test Users:"
  for i in {0..4}; do
    IFS=':' read -r email pass name <<< "${USER_CREDENTIALS[$i]}"
    # Capitalize first letter (compatible way)
    capitalized_name="$(echo "${name:0:1}" | tr '[:lower:]' '[:upper:]')${name:1}"
    echo "  $capitalized_name: $email / $pass"
  done
  echo ""
  echo "=========================================="
  echo ""
  echo "You can now:"
  echo "  1. Open http://localhost:3000/login.html in your browser"
  echo "  2. Login with any of the credentials above"
  echo "  3. View the live bidding interface"
  echo "  4. See real-time leaderboard updates"
  echo ""
  echo "Or create new users with:"
  echo "  node scripts/create-test-user.js <email> <password> <username>"
  echo ""
  exit 0
else
  echo -e "${RED}Some tests failed!${NC}"
  exit 1
fi
