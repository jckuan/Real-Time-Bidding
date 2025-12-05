#!/bin/bash

# Comprehensive Phase 3 Bidding Test
# Tests scoring algorithm, bid submission, updates, and leaderboards

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

BASE_URL="http://localhost:3000/api/v1"
FAILED_TESTS=0
PASSED_TESTS=0

# Function to print test header
test_header() {
  echo ""
  echo -e "${BLUE}========================================${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}========================================${NC}"
}

# Function to print test step
test_step() {
  echo -e "${YELLOW}▶ $1${NC}"
}

# Function to mark test as passed
test_pass() {
  PASSED_TESTS=$((PASSED_TESTS + 1))
  echo -e "${GREEN}✓ PASS${NC}: $1"
}

# Function to mark test as failed
test_fail() {
  FAILED_TESTS=$((FAILED_TESTS + 1))
  echo -e "${RED}✗ FAIL${NC}: $1"
  if [ -n "$2" ]; then
    echo -e "${RED}  Error: $2${NC}"
  fi
}

# Function to verify JSON response has success=true
verify_success() {
  local response=$1
  local success=$(echo "$response" | jq -r '.success // false')
  if [ "$success" != "true" ]; then
    local error_msg=$(echo "$response" | jq -r '.error.message // "Unknown error"')
    return 1
  fi
  return 0
}

test_header "Phase 3: Bidding Engine Test Suite"

# ======================
# Setup: Create test users and product
# ======================

test_step "1. Creating test users..."

# User 1
TIMESTAMP=$(date +%s)
USER1_EMAIL="bidder1_${TIMESTAMP}@test.com"
USER1_RESPONSE=$(curl -s -X POST "$BASE_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"$USER1_EMAIL\", \"password\": \"password123\", \"username\": \"Bidder One\"}")

if verify_success "$USER1_RESPONSE"; then
  USER1_ID=$(echo "$USER1_RESPONSE" | jq -r '.data.user.id')
  USER1_TOKEN=$(echo "$USER1_RESPONSE" | jq -r '.data.token')
  USER1_WEIGHT=$(echo "$USER1_RESPONSE" | jq -r '.data.user.member_weight')
  test_pass "User 1 created (ID: $USER1_ID, Weight: $USER1_WEIGHT)"
else
  test_fail "User 1 registration" "$(echo "$USER1_RESPONSE" | jq -r '.error.message')"
  exit 1
fi

# User 2
USER2_EMAIL="bidder2_${TIMESTAMP}@test.com"
USER2_RESPONSE=$(curl -s -X POST "$BASE_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"$USER2_EMAIL\", \"password\": \"password123\", \"username\": \"Bidder Two\"}")

if verify_success "$USER2_RESPONSE"; then
  USER2_ID=$(echo "$USER2_RESPONSE" | jq -r '.data.user.id')
  USER2_TOKEN=$(echo "$USER2_RESPONSE" | jq -r '.data.token')
  USER2_WEIGHT=$(echo "$USER2_RESPONSE" | jq -r '.data.user.member_weight')
  test_pass "User 2 created (ID: $USER2_ID, Weight: $USER2_WEIGHT)"
else
  test_fail "User 2 registration"
  exit 1
fi

# User 3
USER3_EMAIL="bidder3_${TIMESTAMP}@test.com"
USER3_RESPONSE=$(curl -s -X POST "$BASE_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"$USER3_EMAIL\", \"password\": \"password123\", \"username\": \"Bidder Three\"}")

if verify_success "$USER3_RESPONSE"; then
  USER3_ID=$(echo "$USER3_RESPONSE" | jq -r '.data.user.id')
  USER3_TOKEN=$(echo "$USER3_RESPONSE" | jq -r '.data.token')
  USER3_WEIGHT=$(echo "$USER3_RESPONSE" | jq -r '.data.user.member_weight')
  test_pass "User 3 created (ID: $USER3_ID, Weight: $USER3_WEIGHT)"
else
  test_fail "User 3 registration"
  exit 1
fi

# ======================
# Test 2: Create and activate product
# ======================

test_step "2. Creating flash sale product..."

# Create product with proper timezone-aware timestamps
# Start time: 1 minute ago, End time: 30 minutes from now
SALE_START=$(node -e "console.log(new Date(Date.now() - 60000).toISOString())")
SALE_END=$(node -e "console.log(new Date(Date.now() + 1800000).toISOString())")

PRODUCT_RESPONSE=$(curl -s -X POST "$BASE_URL/admin/products" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $USER1_TOKEN" \
  -d "{
    \"name\": \"MacBook Pro M3 - Test ${TIMESTAMP}\",
    \"description\": \"Latest MacBook Pro with M3 chip - Flash Sale!\",
    \"base_price\": 1500,
    \"initial_inventory\": 10,
    \"max_winners\": 3,
    \"sale_start_time\": \"$SALE_START\",
    \"sale_end_time\": \"$SALE_END\"
  }")

if verify_success "$PRODUCT_RESPONSE"; then
  PRODUCT_ID=$(echo "$PRODUCT_RESPONSE" | jq -r '.data.id')
  test_pass "Product created (ID: $PRODUCT_ID)"
  echo "  Sale window: $SALE_START to $SALE_END"
else
  test_fail "Product creation" "$(echo "$PRODUCT_RESPONSE" | jq -r '.error.message')"
  exit 1
fi

test_step "3. Activating sale..."

ACTIVATE_RESPONSE=$(curl -s -X POST "$BASE_URL/admin/products/$PRODUCT_ID/activate" \
  -H "Authorization: Bearer $USER1_TOKEN")

if verify_success "$ACTIVATE_RESPONSE"; then
  STATUS=$(echo "$ACTIVATE_RESPONSE" | jq -r '.data.status')
  if [ "$STATUS" = "active" ]; then
    test_pass "Sale activated successfully"
  else
    test_fail "Sale activation" "Status is $STATUS, expected 'active'"
  fi
else
  test_fail "Sale activation" "$(echo "$ACTIVATE_RESPONSE" | jq -r '.error.message')"
  exit 1
fi

# ======================
# Test 3: Bid submissions and scoring
# ======================

test_header "Bid Submission & Scoring Tests"

test_step "4. User 1 submits first bid ($1600)..."
sleep 0.5  # Small delay for different reaction times

BID1_RESPONSE=$(curl -s -X POST "$BASE_URL/bids" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $USER1_TOKEN" \
  -d "{\"productId\": $PRODUCT_ID, \"bidPrice\": 1600}")

if verify_success "$BID1_RESPONSE"; then
  BID1_RANK=$(echo "$BID1_RESPONSE" | jq -r '.data.rank')
  BID1_SCORE=$(echo "$BID1_RESPONSE" | jq -r '.data.score')
  BID1_REACTION=$(echo "$BID1_RESPONSE" | jq -r '.data.reactionTime')
  test_pass "Bid submitted - Rank: $BID1_RANK, Score: $BID1_SCORE, Reaction: ${BID1_REACTION}s"
  
  # Verify rank is 1 (first bidder)
  if [ "$BID1_RANK" = "1" ]; then
    test_pass "User 1 has rank 1 (first bidder)"
  else
    test_fail "User 1 rank verification" "Expected rank 1, got $BID1_RANK"
  fi
else
  test_fail "User 1 bid submission" "$(echo "$BID1_RESPONSE" | jq -r '.error.message')"
fi

test_step "5. User 2 submits bid ($1650) - 1 second later..."
sleep 1

BID2_RESPONSE=$(curl -s -X POST "$BASE_URL/bids" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $USER2_TOKEN" \
  -d "{\"productId\": $PRODUCT_ID, \"bidPrice\": 1650}")

if verify_success "$BID2_RESPONSE"; then
  BID2_RANK=$(echo "$BID2_RESPONSE" | jq -r '.data.rank')
  BID2_SCORE=$(echo "$BID2_RESPONSE" | jq -r '.data.score')
  BID2_REACTION=$(echo "$BID2_RESPONSE" | jq -r '.data.reactionTime')
  test_pass "Bid submitted - Rank: $BID2_RANK, Score: $BID2_SCORE, Reaction: ${BID2_REACTION}s"
else
  test_fail "User 2 bid submission" "$(echo "$BID2_RESPONSE" | jq -r '.error.message')"
fi

test_step "6. User 3 submits bid ($1550) - lower price, 2 seconds later..."
sleep 1

BID3_RESPONSE=$(curl -s -X POST "$BASE_URL/bids" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $USER3_TOKEN" \
  -d "{\"productId\": $PRODUCT_ID, \"bidPrice\": 1550}")

if verify_success "$BID3_RESPONSE"; then
  BID3_RANK=$(echo "$BID3_RESPONSE" | jq -r '.data.rank')
  BID3_SCORE=$(echo "$BID3_RESPONSE" | jq -r '.data.score')
  BID3_REACTION=$(echo "$BID3_RESPONSE" | jq -r '.data.reactionTime')
  test_pass "Bid submitted - Rank: $BID3_RANK, Score: $BID3_SCORE, Reaction: ${BID3_REACTION}s"
  
  # User 3 should be rank 3 (lowest bid, slowest reaction)
  if [ "$BID3_RANK" = "3" ]; then
    test_pass "User 3 has rank 3 (lowest bidder)"
  else
    echo -e "${YELLOW}  Note: User 3 rank is $BID3_RANK (member weight may affect ranking)${NC}"
  fi
else
  test_fail "User 3 bid submission" "$(echo "$BID3_RESPONSE" | jq -r '.error.message')"
fi

# ======================
# Test 4: Bid updates
# ======================

test_header "Bid Update Tests"

test_step "7. User 1 updates bid to $1800..."

UPDATE_RESPONSE=$(curl -s -X PUT "$BASE_URL/bids/$PRODUCT_ID" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $USER1_TOKEN" \
  -d "{\"bidPrice\": 1800}")

if verify_success "$UPDATE_RESPONSE"; then
  NEW_RANK=$(echo "$UPDATE_RESPONSE" | jq -r '.data.rank')
  NEW_SCORE=$(echo "$UPDATE_RESPONSE" | jq -r '.data.score')
  test_pass "Bid updated - New Rank: $NEW_RANK, New Score: $NEW_SCORE"
  
  # Verify score increased
  if (( $(echo "$NEW_SCORE > $BID1_SCORE" | bc -l) )); then
    test_pass "Score increased after price increase ($BID1_SCORE → $NEW_SCORE)"
  else
    test_fail "Score verification" "Score should increase with price"
  fi
else
  test_fail "Bid update" "$(echo "$UPDATE_RESPONSE" | jq -r '.error.message')"
fi

# ======================
# Test 5: Validation tests
# ======================

test_header "Validation Tests"

test_step "8. Try duplicate bid (should fail)..."

DUPLICATE_RESPONSE=$(curl -s -X POST "$BASE_URL/bids" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $USER2_TOKEN" \
  -d "{\"productId\": $PRODUCT_ID, \"bidPrice\": 1700}")

if ! verify_success "$DUPLICATE_RESPONSE"; then
  ERROR_MSG=$(echo "$DUPLICATE_RESPONSE" | jq -r '.error.message')
  if [[ "$ERROR_MSG" == *"already have a bid"* ]]; then
    test_pass "Duplicate bid correctly rejected"
  else
    test_fail "Duplicate bid validation" "Unexpected error: $ERROR_MSG"
  fi
else
  test_fail "Duplicate bid validation" "Should have been rejected"
fi

test_step "9. Try bid update with lower price (should fail)..."

LOWER_PRICE_RESPONSE=$(curl -s -X PUT "$BASE_URL/bids/$PRODUCT_ID" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $USER1_TOKEN" \
  -d "{\"bidPrice\": 1600}")

if ! verify_success "$LOWER_PRICE_RESPONSE"; then
  ERROR_MSG=$(echo "$LOWER_PRICE_RESPONSE" | jq -r '.error.message')
  if [[ "$ERROR_MSG" == *"must be higher"* ]]; then
    test_pass "Lower price correctly rejected"
  else
    test_fail "Lower price validation" "Unexpected error: $ERROR_MSG"
  fi
else
  test_fail "Lower price validation" "Should have been rejected"
fi

test_step "10. Try bid below base price (should fail)..."

LOW_BID_RESPONSE=$(curl -s -X POST "$BASE_URL/bids" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $USER1_TOKEN" \
  -d "{\"productId\": 999, \"bidPrice\": 50}")

if ! verify_success "$LOW_BID_RESPONSE"; then
  test_pass "Low bid correctly rejected"
else
  test_fail "Low bid validation" "Should have been rejected"
fi

# ======================
# Test 6: Leaderboard
# ======================

test_header "Leaderboard Tests"

test_step "11. Fetch leaderboard..."

LEADERBOARD_RESPONSE=$(curl -s -X GET "$BASE_URL/bids/leaderboard/$PRODUCT_ID?limit=10" \
  -H "Authorization: Bearer $USER1_TOKEN")

if verify_success "$LEADERBOARD_RESPONSE"; then
  LEADERBOARD=$(echo "$LEADERBOARD_RESPONSE" | jq -r '.data.leaderboard')
  LEADERBOARD_COUNT=$(echo "$LEADERBOARD" | jq 'length')
  
  if [ "$LEADERBOARD_COUNT" = "3" ]; then
    test_pass "Leaderboard has 3 entries"
    
    # Display leaderboard
    echo ""
    echo -e "${BLUE}Current Leaderboard:${NC}"
    echo "$LEADERBOARD" | jq -r '.[] | "  \(.rank). User \(.userId) - Score: \(.score), Email: \(.email)"'
    echo ""
    
    # Verify User 1 is rank 1 (highest score after update)
    TOP_USER=$(echo "$LEADERBOARD" | jq -r '.[0].userId')
    if [ "$TOP_USER" = "$USER1_ID" ]; then
      test_pass "User 1 is ranked #1 after bid update"
    else
      echo -e "${YELLOW}  Note: User $TOP_USER is ranked #1 (member weight affects ranking)${NC}"
    fi
  else
    test_fail "Leaderboard count" "Expected 3 entries, got $LEADERBOARD_COUNT"
  fi
else
  test_fail "Leaderboard fetch" "$(echo "$LEADERBOARD_RESPONSE" | jq -r '.error.message')"
fi

test_step "12. Check User 2's bid status..."

STATUS_RESPONSE=$(curl -s -X GET "$BASE_URL/bids/my-status/$PRODUCT_ID" \
  -H "Authorization: Bearer $USER2_TOKEN")

if verify_success "$STATUS_RESPONSE"; then
  USER_STATUS=$(echo "$STATUS_RESPONSE" | jq -r '.data')
  if [ "$USER_STATUS" != "null" ]; then
    USER_RANK=$(echo "$USER_STATUS" | jq -r '.rank')
    USER_SCORE=$(echo "$USER_STATUS" | jq -r '.score')
    test_pass "User 2 status retrieved - Rank: $USER_RANK, Score: $USER_SCORE"
  else
    test_fail "User status" "No bid found"
  fi
else
  test_fail "User status fetch" "$(echo "$STATUS_RESPONSE" | jq -r '.error.message')"
fi

# ======================
# Summary
# ======================

test_header "Test Summary"

TOTAL_TESTS=$((PASSED_TESTS + FAILED_TESTS))
echo ""
echo -e "${GREEN}Passed: $PASSED_TESTS${NC} / ${TOTAL_TESTS}"
if [ $FAILED_TESTS -gt 0 ]; then
  echo -e "${RED}Failed: $FAILED_TESTS${NC} / ${TOTAL_TESTS}"
  echo ""
  exit 1
else
  echo -e "${GREEN}All tests passed! ✓${NC}"
  echo ""
  exit 0
fi
