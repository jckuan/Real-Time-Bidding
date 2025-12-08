#!/bin/bash

# Manual Testing Setup Script
# Creates a new product and provides test credentials for manual bidding

API_BASE="http://localhost:3000/api/v1"

echo "================================================"
echo "Manual Bidding Test Setup"
echo "================================================"
echo ""

# Create and login as admin
echo "Creating admin user..."
TIMESTAMP=$(date +%s)
ADMIN_USERNAME="admin${TIMESTAMP}"
ADMIN_EMAIL="admin.${TIMESTAMP}@example.com"
ADMIN_PASS="AdminPass123"

curl -s -X POST "$API_BASE/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"username\":\"$ADMIN_USERNAME\",\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASS\"}" > /dev/null

echo "Logging in as admin..."
ADMIN_LOGIN=$(curl -s -X POST "$API_BASE/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASS\"}")

ADMIN_TOKEN=$(echo "$ADMIN_LOGIN" | jq -r '.data.token')

if [ "$ADMIN_TOKEN" = "null" ] || [ -z "$ADMIN_TOKEN" ]; then
  echo "❌ Failed to login as admin"
  echo "Response: $ADMIN_LOGIN"
  exit 1
fi

echo "✅ Admin logged in"
echo ""

# Create product
echo "Creating new product..."
SALE_START=$(date -u -v+5S +"%Y-%m-%dT%H:%M:%S.000Z" 2>/dev/null || date -u -d "+5 seconds" +"%Y-%m-%dT%H:%M:%S.000Z")
SALE_END=$(date -u -v+30S +"%Y-%m-%dT%H:%M:%S.000Z" 2>/dev/null || date -u -d "+30 seconds" +"%Y-%m-%dT%H:%M:%S.000Z")

PRODUCT=$(curl -s -X POST "$API_BASE/admin/products" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"iPhone 15 Pro Max\",
    \"description\": \"Latest iPhone with A17 Pro chip, 256GB storage\",
    \"base_price\": 999,
    \"initial_inventory\": 10,
    \"max_winners\": 5,
    \"sale_start_time\": \"$SALE_START\",
    \"sale_end_time\": \"$SALE_END\"
  }")

PRODUCT_ID=$(echo "$PRODUCT" | jq -r '.data.id')

if [ "$PRODUCT_ID" = "null" ] || [ -z "$PRODUCT_ID" ]; then
  echo "❌ Failed to create product"
  echo "Response: $PRODUCT"
  exit 1
fi

echo "✅ Product Created!"
echo "   Product ID: $PRODUCT_ID"
echo "   Name: $(echo "$PRODUCT" | jq -r '.data.name')"
echo "   Base Price: \$$(echo "$PRODUCT" | jq -r '.data.base_price')"
echo "   Sale Start: $(echo "$PRODUCT" | jq -r '.data.sale_start_time')"
echo "   Sale End: $(echo "$PRODUCT" | jq -r '.data.sale_end_time')"
echo ""

# Activate the sale
echo "Activating sale..."
ACTIVATE=$(curl -s -X POST "$API_BASE/admin/products/$PRODUCT_ID/activate" \
  -H "Authorization: Bearer $ADMIN_TOKEN")

if echo "$ACTIVATE" | jq -e '.success' > /dev/null 2>&1; then
  echo "✅ Sale activated successfully!"
else
  echo "❌ Failed to activate sale"
  echo "Response: $ACTIVATE"
  exit 1
fi

echo ""
echo "================================================"
echo "✅ READY TO TEST BIDDING!"
echo "================================================"
echo ""
echo "Test User Credentials:"
echo "  Email:    testuser1@example.com"
echo "  Password: TestPass123"
echo ""
echo "Product Details:"
echo "  ID:           $PRODUCT_ID"
echo "  Name:         iPhone 15 Pro Max"
echo "  Min Bid:      \$999"
echo ""
echo "Manual Testing Steps:"
echo "  1. Open http://localhost:3000/login.html in your browser"
echo "  2. Login with: testuser1@example.com / TestPass123"
echo "  3. Click 'View Details' on the iPhone 15 Pro Max"
echo "  4. Submit a bid (amount must be ≥ \$999)"
echo "  5. Watch the real-time leaderboard update!"
echo "  6. Try updating your bid to a higher amount"
echo ""
echo "Optional: Create more test users with:"
echo "  node scripts/create-test-user.js <email> <password> <username>"
echo ""
echo "Then login with different users to compete in bidding!"
echo "================================================"
