#!/bin/bash

# Simple focused test for bidding
BASE_URL="http://localhost:3000/api/v1"

# Use unique email based on timestamp
UNIQUE_EMAIL="testbid$(date +%s)@example.com"

echo "=== Simple Bidding Test ==="
echo ""

# Register and login
echo "1. Register user ($UNIQUE_EMAIL)..."
REG=$(curl -s -X POST "$BASE_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"$UNIQUE_EMAIL\", \"password\": \"password123\", \"username\": \"Test Bidder\"}")
echo "$REG" | jq -r '.data.user | "User created: ID=\(.id), Weight=\(.member_weight)"'

TOKEN=$(echo "$REG" | jq -r '.data.token')

# Create product with times NOW-1min to NOW+30min to ensure it's active
PAST_START=$(node -e "console.log(new Date(Date.now() - 60000).toISOString())")
FUTURE_END=$(node -e "console.log(new Date(Date.now() + 1800000).toISOString())")

echo ""
echo "2. Create product..."
echo "   Start: $PAST_START"
echo "   End: $FUTURE_END"

PROD=$(curl -s -X POST "$BASE_URL/admin/products" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{
    \"name\": \"Test Product\",
    \"description\": \"Testing bidding\",
    \"base_price\": 100,
    \"initial_inventory\": 10,
    \"max_winners\": 5,
    \"sale_start_time\": \"$PAST_START\",
    \"sale_end_time\": \"$FUTURE_END\"
  }")

PRODUCT_ID=$(echo "$PROD" | jq -r '.data.id')
echo "Product created: ID=$PRODUCT_ID"

echo ""
echo "3. Activate sale..."
ACT=$(curl -s -X POST "$BASE_URL/admin/products/$PRODUCT_ID/activate" \
  -H "Authorization: Bearer $TOKEN")
STATUS=$(echo "$ACT" | jq -r '.data.status')
echo "Status: $STATUS"

echo ""
echo "4. Submit bid..."
BID=$(curl -s -X POST "$BASE_URL/bids" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d "{\"productId\": $PRODUCT_ID, \"bidPrice\": 150}")

echo "$BID" | jq '.'

RANK=$(echo "$BID" | jq -r '.data.rank // "ERROR"')
SCORE=$(echo "$BID" | jq -r '.data.score // "ERROR"')

echo ""
if [ "$RANK" != "ERROR" ] && [ "$RANK" != "null" ]; then
  echo "✓ SUCCESS! Rank: $RANK, Score: $SCORE"
else
  echo "✗ FAILED - Check error above"
fi

echo ""
echo "5. Get leaderboard..."
BOARD=$(curl -s -X GET "$BASE_URL/bids/leaderboard/$PRODUCT_ID" \
  -H "Authorization: Bearer $TOKEN")
echo "$BOARD" | jq '.data.leaderboard'

echo ""
echo "=== Test Complete ==="
