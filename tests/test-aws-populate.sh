#!/bin/bash

# AWS Phase 4 Test - Populate database with test data
# Points to AWS ALB endpoint

API_BASE="http://rtb-alb-1080675720.us-west-2.elb.amazonaws.com/api/v1"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
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
echo "AWS Database Population Test"
echo "Endpoint: $API_BASE"
echo "=========================================="
echo ""

# Test 1: Create test users
print_test "Creating 5 test users"

USER_TOKENS=()
USER_IDS=()
REAL_NAMES=("alice" "bob" "carol" "david" "eve")

for i in {1..5}; do
  NAME="${REAL_NAMES[$((i-1))]}"
  TIMESTAMP=$(date +%s)
  USERNAME="${NAME}"
  EMAIL="${NAME}@test.com"
  PASS="Test123"
  
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
    MEMBER_WEIGHT=$(echo "$LOGIN_RESPONSE" | jq -r '.data.user.memberWeight')
    
    USER_TOKENS+=("$TOKEN")
    USER_IDS+=("$USER_ID")
    
    print_pass "Created user: $EMAIL (ID: $USER_ID, Weight: $MEMBER_WEIGHT)"
  else
    ERROR=$(echo "$REGISTER_RESPONSE" | jq -r '.error.message // "Unknown error"')
    print_fail "Failed to create user $EMAIL: $ERROR"
  fi
  sleep 0.5
done

echo ""
print_test "Creating admin user"

ADMIN_USERNAME="admin"
ADMIN_EMAIL="admin@test.com"
ADMIN_PASS="Admin123"

# Register admin
ADMIN_REGISTER=$(curl -s -X POST "$API_BASE/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$ADMIN_USERNAME\",\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASS\"}")

if echo "$ADMIN_REGISTER" | jq -e '.success' > /dev/null 2>&1; then
  print_pass "Admin registered: $ADMIN_EMAIL"
else
  print_fail "Admin registration failed (may already exist)"
fi

# Login admin
ADMIN_LOGIN=$(curl -s -X POST "$API_BASE/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASS\"}")

ADMIN_TOKEN=$(echo "$ADMIN_LOGIN" | jq -r '.data.token')

if [ "$ADMIN_TOKEN" != "null" ] && [ -n "$ADMIN_TOKEN" ]; then
  print_pass "Admin logged in successfully"
else
  print_fail "Admin login failed"
  exit 1
fi

# Test 2: Set scoring parameters
echo ""
print_test "Setting scoring parameters (α=1.0, β=100.0, γ=50.0)"

PARAMS_RESPONSE=$(curl -s -X POST "$API_BASE/admin/scoring-parameters" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"alpha\":1.0,\"beta\":100.0,\"gamma\":50.0}")

if echo "$PARAMS_RESPONSE" | jq -e '.success' > /dev/null 2>&1; then
  print_pass "Scoring parameters configured"
else
  print_fail "Failed to set scoring parameters"
fi

# Test 3: Create a test product
echo ""
print_test "Creating test product: iPhone 15 Pro"

# Calculate timestamps (macOS compatible)
if [[ "$OSTYPE" == "darwin"* ]]; then
  SALE_START=$(date -u -v+10S +"%Y-%m-%dT%H:%M:%S.000Z")
  SALE_END=$(date -u -v+3600S +"%Y-%m-%dT%H:%M:%S.000Z")  # 1 hour from now
else
  SALE_START=$(date -u -d "+10 seconds" +"%Y-%m-%dT%H:%M:%S.000Z")
  SALE_END=$(date -u -d "+1 hour" +"%Y-%m-%dT%H:%M:%S.000Z")
fi

PRODUCT_RESPONSE=$(curl -s -X POST "$API_BASE/admin/products" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"iPhone 15 Pro\",
    \"description\": \"Latest flagship phone with 256GB storage\",
    \"base_price\": 999.00,
    \"initial_inventory\": 5,
    \"max_winners\": 5,
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

# Test 4: Activate sale
echo ""
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
echo -e "${YELLOW}Waiting for sale to start (10 seconds)...${NC}"
sleep 11

# Test 5: Submit bids from all users
echo ""
print_test "Submitting bids from 5 users"

BID_PRICES=(1200 1100 1300 1250 1150)

for i in {0..4}; do
  TOKEN="${USER_TOKENS[$i]}"
  BID_PRICE="${BID_PRICES[$i]}"
  NAME="${REAL_NAMES[$i]}"
  
  RESPONSE=$(curl -s -X POST "$API_BASE/bids" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"productId\":$PRODUCT_ID,\"bidPrice\":$BID_PRICE}")
  
  if echo "$RESPONSE" | jq -e '.success' > /dev/null 2>&1; then
    RANK=$(echo "$RESPONSE" | jq -r '.data.rank // "?"')
    SCORE=$(echo "$RESPONSE" | jq -r '.data.score // "?"')
    print_pass "$NAME bid \$$BID_PRICE (Rank: #$RANK, Score: $SCORE)"
  else
    ERROR=$(echo "$RESPONSE" | jq -r '.error.message // "Unknown error"')
    print_fail "$NAME bid failed: $ERROR"
  fi
  
  sleep 0.5
done

# Test 6: Get leaderboard
echo ""
print_test "Fetching leaderboard"

sleep 1

LEADERBOARD=$(curl -s "$API_BASE/bids/leaderboard/$PRODUCT_ID?limit=10")

if echo "$LEADERBOARD" | jq -e '.success' > /dev/null 2>&1; then
  BIDDERS=$(echo "$LEADERBOARD" | jq -r '.data.leaderboard | length')
  print_pass "Leaderboard retrieved with $BIDDERS bidders"
  
  echo ""
  echo -e "${YELLOW}Current Leaderboard:${NC}"
  echo "$LEADERBOARD" | jq -r '.data.leaderboard[] | "  Rank #\(.rank): \(.email) - Bid: $\(.bidPrice) - Score: \(.score)"'
  echo ""
else
  print_fail "Failed to fetch leaderboard"
fi

# Test 7: Update a bid
echo ""
print_test "Updating bob's bid to \$1400"

BOB_TOKEN="${USER_TOKENS[1]}"
NEW_BID=1400

UPDATE_RESPONSE=$(curl -s -X PUT "$API_BASE/bids/$PRODUCT_ID" \
  -H "Authorization: Bearer $BOB_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"bidPrice\":$NEW_BID}")

if echo "$UPDATE_RESPONSE" | jq -e '.success' > /dev/null 2>&1; then
  NEW_RANK=$(echo "$UPDATE_RESPONSE" | jq -r '.data.rank')
  NEW_SCORE=$(echo "$UPDATE_RESPONSE" | jq -r '.data.score')
  print_pass "Bob's bid updated (New Rank: #$NEW_RANK, Score: $NEW_SCORE)"
else
  ERROR=$(echo "$UPDATE_RESPONSE" | jq -r '.error.message // "Unknown error"')
  print_fail "Bid update failed: $ERROR"
fi

# Summary
echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "${GREEN}Passed:${NC} $PASSED"
echo -e "${RED}Failed:${NC} $FAILED"
echo ""
echo -e "${YELLOW}Test Data Created:${NC}"
echo "  - 5 users: alice, bob, carol, david, eve (password: Test123)"
echo "  - 1 admin: admin (password: Admin123)"
echo "  - 1 product: iPhone 15 Pro (ID: $PRODUCT_ID)"
echo "  - 5 bids submitted"
echo ""
echo -e "${BLUE}You can now:${NC}"
echo "  1. Open frontend/admin.html and login as admin@test.com / Admin123"
echo "  2. Open frontend/bidding.html and login as any user"
echo "  3. Open frontend/dashboard.html to see the leaderboard"
echo ""
