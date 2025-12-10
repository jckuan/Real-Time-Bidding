#!/bin/bash

# Test Rate Limiting
# Attempts rapid bid updates to verify rate limiting works

API_BASE="http://localhost:3000/api/v1"

echo "================================================"
echo "Rate Limit Test"
echo "================================================"
echo ""

# Create user
TIMESTAMP=$(date +%s)
USER_EMAIL="ratelimit.${TIMESTAMP}@example.com"
USER_PASS="TestPass123"

curl -s -X POST "$API_BASE/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"ratelimit${TIMESTAMP}\",\"email\":\"$USER_EMAIL\",\"password\":\"$USER_PASS\"}" > /dev/null

LOGIN=$(curl -s -X POST "$API_BASE/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$USER_EMAIL\",\"password\":\"$USER_PASS\"}")

TOKEN=$(echo "$LOGIN" | jq -r '.data.token')

echo "✅ User created and logged in"

# Create admin and product
ADMIN_EMAIL="admin.${TIMESTAMP}@example.com"
ADMIN_PASS="AdminPass123"

curl -s -X POST "$API_BASE/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"admin${TIMESTAMP}\",\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASS\"}" > /dev/null

ADMIN_LOGIN=$(curl -s -X POST "$API_BASE/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASS\"}")

ADMIN_TOKEN=$(echo "$ADMIN_LOGIN" | jq -r '.data.token')

SALE_START=$(date -u -v+2S +"%Y-%m-%dT%H:%M:%S.000Z" 2>/dev/null || date -u -d "+2 seconds" +"%Y-%m-%dT%H:%M:%S.000Z")
SALE_END=$(date -u -v+60S +"%Y-%m-%dT%H:%M:%S.000Z" 2>/dev/null || date -u -d "+60 seconds" +"%Y-%m-%dT%H:%M:%S.000Z")

PRODUCT=$(curl -s -X POST "$API_BASE/admin/products" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"Rate Limit Test Product\",
    \"description\": \"Testing rate limiting\",
    \"base_price\": 100,
    \"initial_inventory\": 10,
    \"max_winners\": 3,
    \"sale_start_time\": \"$SALE_START\",
    \"sale_end_time\": \"$SALE_END\"
  }")

PRODUCT_ID=$(echo "$PRODUCT" | jq -r '.data.id')

curl -s -X POST "$API_BASE/admin/products/$PRODUCT_ID/activate" \
  -H "Authorization: Bearer $ADMIN_TOKEN" > /dev/null

echo "✅ Product created and activated (ID: $PRODUCT_ID)"
echo ""
sleep 3

# Submit initial bid
echo "Submitting initial bid at \$100..."
BID=$(curl -s -X POST "$API_BASE/bids" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"productId\":$PRODUCT_ID,\"bidPrice\":100}")

if echo "$BID" | jq -e '.success' > /dev/null 2>&1; then
  echo "✅ Initial bid submitted"
else
  echo "❌ Failed to submit initial bid"
  echo "$BID"
  exit 1
fi

echo ""
echo "Testing rapid updates (should trigger rate limit)..."
echo ""

# Try to update 5 times rapidly
for i in {1..5}; do
  PRICE=$((100 + i * 10))
  echo -n "Update $i (\$$PRICE): "
  
  RESPONSE=$(curl -s -X PUT "$API_BASE/bids/$PRODUCT_ID" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"bidPrice\":$PRICE}")
  
  SUCCESS=$(echo "$RESPONSE" | jq -r '.success')
  
  if [ "$SUCCESS" = "true" ]; then
    echo "✅ Accepted"
  else
    ERROR=$(echo "$RESPONSE" | jq -r '.error.message')
    echo "⏱️  Rate limited - $ERROR"
  fi
  
  sleep 0.5
done

echo ""
echo "================================================"
echo "Waiting 3 seconds and trying again..."
echo "================================================"
sleep 3

FINAL_RESPONSE=$(curl -s -X PUT "$API_BASE/bids/$PRODUCT_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"bidPrice\":200}")

if echo "$FINAL_RESPONSE" | jq -e '.success' > /dev/null 2>&1; then
  echo "✅ Update succeeded after waiting (rate limit expired)"
else
  ERROR=$(echo "$FINAL_RESPONSE" | jq -r '.error.message')
  echo "❌ Update failed: $ERROR"
fi

echo ""
echo "================================================"
echo "Test Complete"
echo "================================================"
