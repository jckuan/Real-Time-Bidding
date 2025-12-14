#!/bin/bash

# Demo Video Preparation Script
# Run this before recording to ensure everything is ready

set -e

echo "======================================"
echo "DEMO VIDEO PREPARATION"
echo "======================================"
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
ALB_URL="http://YOUR_ALB_DNS"
API_URL="${ALB_URL}/api/v1"

echo -e "${BLUE}Step 1: Verify AWS Services${NC}"
echo "Checking ECS tasks..."
TASK_COUNT=$(aws ecs describe-services \
  --cluster rtb-cluster \
  --services rtb-service \
  --query 'services[0].runningCount' \
  --output text)

echo "✓ ECS Tasks Running: $TASK_COUNT"

if [ "$TASK_COUNT" -lt 3 ]; then
  echo -e "${RED}WARNING: Expected 3 tasks, found $TASK_COUNT${NC}"
fi

echo ""
echo -e "${BLUE}Step 2: Health Check${NC}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "${ALB_URL}/health")
if [ "$HTTP_CODE" -eq 200 ]; then
  echo "✓ API Health Check: OK ($HTTP_CODE)"
else
  echo -e "${RED}✗ API Health Check: FAILED ($HTTP_CODE)${NC}"
  exit 1
fi

echo ""
echo -e "${BLUE}Step 3: Clean Test Data${NC}"
read -p "Do you want to clean the database before demo? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo "Cleaning database..."
  
  # Get admin token
  TOKEN=$(curl -s -X POST "${API_URL}/auth/login" \
    -H "Content-Type: application/json" \
    -d '{"email":"admin@test.com","password":"Admin123"}' | jq -r '.token')
  
  if [ "$TOKEN" != "null" ] && [ -n "$TOKEN" ]; then
    echo "✓ Admin authenticated"
    
    # Delete old products
    PRODUCT_IDS=$(curl -s "${API_URL}/products" | jq -r '.[].id')
    for pid in $PRODUCT_IDS; do
      curl -s -X DELETE "${API_URL}/admin/products/${pid}" \
        -H "Authorization: Bearer $TOKEN" > /dev/null
      echo "  Deleted product $pid"
    done
    
    echo "✓ Database cleaned"
  else
    echo -e "${RED}Failed to authenticate admin${NC}"
  fi
fi

echo ""
echo -e "${BLUE}Step 4: Verify Test Users${NC}"
TEST_USERS=("alice@test.com" "bob@test.com" "charlie@test.com")
for user in "${TEST_USERS[@]}"; do
  RESULT=$(curl -s -X POST "${API_URL}/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$user\",\"password\":\"Test123\"}" | jq -r '.token')
  
  if [ "$RESULT" != "null" ] && [ -n "$RESULT" ]; then
    echo "✓ User exists: $user"
  else
    echo "  Creating user: $user"
    curl -s -X POST "${API_URL}/auth/register" \
      -H "Content-Type: application/json" \
      -d "{\"email\":\"$user\",\"password\":\"Test123\",\"name\":\"Test User\"}" > /dev/null
  fi
done

echo ""
echo -e "${BLUE}Step 5: Open Required Windows${NC}"
echo "Please open these in separate browser tabs/windows:"
echo ""
echo "1. Admin Dashboard: ${ALB_URL}/admin.html"
echo "2. User Dashboard 1: ${ALB_URL}/dashboard.html (alice@test.com)"
echo "3. User Dashboard 2: ${ALB_URL}/dashboard.html (bob@test.com)"
echo "4. AWS ECS Console: https://us-west-2.console.aws.amazon.com/ecs/v2/clusters/rtb-cluster/services/rtb-service"
echo "5. CloudWatch Dashboard: https://us-west-2.console.aws.amazon.com/cloudwatch/home?region=us-west-2"
echo ""

echo -e "${BLUE}Step 6: Prepare Stress Test${NC}"
echo "Terminal command ready:"
echo -e "${GREEN}cd tests/stress && ./run-stress-tests.sh${NC}"
echo ""

echo -e "${BLUE}Step 7: Database Verification Query${NC}"
echo "Keep this query ready for final consistency check:"
echo -e "${GREEN}"
cat << 'EOF'
SELECT 
  p.name,
  p.max_winners,
  COUNT(DISTINCT b.user_id) as total_bidders,
  COUNT(o.id) as actual_orders,
  CASE 
    WHEN COUNT(o.id) <= p.max_winners 
    THEN '✓ NO OVERSELLING' 
    ELSE '✗ OVERSOLD!' 
  END as status
FROM products p
LEFT JOIN bids b ON b.product_id = p.id
LEFT JOIN orders o ON o.product_id = p.id
GROUP BY p.id, p.name, p.max_winners
ORDER BY p.created_at DESC
LIMIT 1;
EOF
echo -e "${NC}"

echo ""
echo "======================================"
echo -e "${GREEN}DEMO PREPARATION COMPLETE!${NC}"
echo "======================================"
echo ""
echo "RECORDING CHECKLIST:"
echo "☐ Screen recorder ready (QuickTime/OBS)"
echo "☐ Microphone tested (or subtitle plan ready)"
echo "☐ All browser windows positioned"
echo "☐ AWS Console logged in"
echo "☐ Terminal window ready"
echo "☐ Database client ready (optional)"
echo ""
echo "DEMO FLOW:"
echo "1. Show ECS Console (3 tasks running)"
echo "2. Admin: Create product 'iPhone 15 Pro' ($999, 50 inventory, 10min)"
echo "3. Users: Alice & Bob login, place bids, show real-time updates"
echo "4. Stress Test: Run option 1 (1000 users)"
echo "5. CloudWatch: Show CPU/Memory metrics during test"
echo "6. Results: Show k6 output (success rate, latency)"
echo "7. Database: Run consistency query"
echo ""
echo -e "${BLUE}Good luck with your recording! 🎬${NC}"
