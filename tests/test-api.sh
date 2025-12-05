#!/bin/bash

echo "======================================"
echo "Testing Real-Time Bidding API"
echo "======================================"
echo ""

# Test 1: Health Check
echo "1. Health Check:"
curl -s http://localhost:3000/health
echo -e "\n"

# Test 2: Register User
echo "2. Register User:"
REGISTER_RESPONSE=$(curl -s -X POST http://localhost:3000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123",
    "username": "testuser"
  }')
echo "$REGISTER_RESPONSE"
TOKEN=$(echo "$REGISTER_RESPONSE" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
echo -e "\n"

# Test 3: Login
echo "3. Login:"
curl -s -X POST http://localhost:3000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123"
  }'
echo -e "\n"

# Test 4: Get Profile
echo "4. Get Profile (with token):"
curl -s http://localhost:3000/api/v1/auth/me \
  -H "Authorization: Bearer $TOKEN"
echo -e "\n"

# Test 5: Create Product (Admin)
echo "5. Create Product:"
curl -s -X POST http://localhost:3000/api/v1/admin/products \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "name": "iPhone 15 Pro",
    "description": "Latest flagship smartphone",
    "base_price": 999.00,
    "initial_inventory": 50,
    "max_winners": 50,
    "sale_start_time": "2025-12-10T12:00:00Z",
    "sale_end_time": "2025-12-10T12:30:00Z"
  }'
echo -e "\n"

# Test 6: Get All Products
echo "6. Get All Products:"
curl -s http://localhost:3000/api/v1/products
echo -e "\n"

# Test 7: Get Product by ID
echo "7. Get Product by ID (1):"
curl -s http://localhost:3000/api/v1/products/1
echo -e "\n"

echo "======================================"
echo "Tests Complete!"
echo "======================================"
