#!/bin/bash

# Stress Test Runner for AWS Deployment
# Requires k6 installed: brew install k6

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration
API_BASE="${API_BASE:-http://rtb-alb-1080675720.us-west-2.elb.amazonaws.com/api/v1}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@test.com}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-Admin123}"
RESULTS_DIR="./stress-results"

echo -e "${BLUE}=========================================="
echo "Real-Time Bidding: Stress Test Suite"
echo "==========================================${NC}"
echo ""
echo "API Endpoint: $API_BASE"
echo "Results Directory: $RESULTS_DIR"
echo ""

# Check k6 installation
if ! command -v k6 &> /dev/null; then
  echo -e "${RED}ERROR: k6 is not installed${NC}"
  echo "Install with: brew install k6"
  echo "Or visit: https://k6.io/docs/getting-started/installation/"
  exit 1
fi

# Create results directory
mkdir -p "$RESULTS_DIR"

# Function to create test product
create_test_product() {
  echo -e "${YELLOW}Creating test product for stress testing...${NC}" >&2
  
  # Login as admin
  LOGIN_RESPONSE=$(curl -s -X POST "$API_BASE/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$ADMIN_EMAIL\",\"password\":\"$ADMIN_PASSWORD\"}")
  
  ADMIN_TOKEN=$(echo "$LOGIN_RESPONSE" | jq -r '.data.token')
  
  if [ "$ADMIN_TOKEN" = "null" ] || [ -z "$ADMIN_TOKEN" ]; then
    echo -e "${RED}Failed to login as admin${NC}" >&2
    echo "Response: $LOGIN_RESPONSE" >&2
    exit 1
  fi
  
  # Create product with 6-minute sale window (for scenario 1)
  START_TIME=$(date -u -v+5S +"%Y-%m-%dT%H:%M:%SZ") # Start in 5 seconds
  END_TIME=$(date -u -v+6M +"%Y-%m-%dT%H:%M:%SZ")   # End in 6 minutes
  
  PRODUCT_RESPONSE=$(curl -s -X POST "$API_BASE/admin/products" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -d "{
      \"name\": \"Stress Test iPhone 15 Pro\",
      \"description\": \"Product for load testing\",
      \"base_price\": 999,
      \"initial_inventory\": 100,
      \"max_winners\": 50,
      \"sale_start_time\": \"$START_TIME\",
      \"sale_end_time\": \"$END_TIME\"
    }")
  
  PRODUCT_ID=$(echo "$PRODUCT_RESPONSE" | jq -r '.data.id')
  
  if [ "$PRODUCT_ID" = "null" ] || [ -z "$PRODUCT_ID" ]; then
    echo -e "${RED}Failed to create product${NC}" >&2
    echo "Response: $PRODUCT_RESPONSE" >&2
    exit 1
  fi
  
  echo -e "${GREEN}Product created: ID=$PRODUCT_ID${NC}" >&2
  
  # Activate product
  ACTIVATE_RESPONSE=$(curl -s -X POST "$API_BASE/admin/products/$PRODUCT_ID/activate" \
    -H "Authorization: Bearer $ADMIN_TOKEN")
  
  if echo "$ACTIVATE_RESPONSE" | jq -e '.success' > /dev/null 2>&1; then
    echo -e "${GREEN}Product activated${NC}" >&2
  else
    echo -e "${RED}Failed to activate product${NC}" >&2
    echo "Response: $ACTIVATE_RESPONSE" >&2
    exit 1
  fi
  
  echo "" >&2
  echo "Waiting 5 seconds for sale to start..." >&2
  sleep 6
  echo "" >&2
  
  echo "$PRODUCT_ID"
}

# Menu
echo "Select stress test scenario:"
echo "  0) Validation Test (100 concurrent users)"
echo "  1) Thundering Herd (1000 concurrent bidders)"
echo "  2) Sustained Load (500 users, 5 minutes)"
echo "  3) Update Spike (exponential bid frequency)"
echo "  D) DEMO Mode (1000 users - clean for video) ⭐"
echo "  4) Full Suite (run all scenarios)"
echo "  5) Exit"
echo ""
read -p "Enter choice [0-5 or D]: " choice

case $choice in
  0)
    echo -e "${BLUE}Running Validation Test (100 users)...${NC}"
    PRODUCT_ID=$(create_test_product)
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    k6 run --quiet \
      --out json="$RESULTS_DIR/validation-$TIMESTAMP.json" \
      --summary-export="$RESULTS_DIR/validation-$TIMESTAMP-summary.json" \
      -e API_BASE="$API_BASE" \
      -e PRODUCT_ID="$PRODUCT_ID" \
      scenario0-validation.js
    echo -e "${GREEN}✓ Results saved to: $RESULTS_DIR/validation-$TIMESTAMP-summary.json${NC}"
    ;;
  
  1)
    echo -e "${BLUE}Running Thundering Herd Test...${NC}"
    PRODUCT_ID=$(create_test_product)
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    k6 run --quiet \
      --out json="$RESULTS_DIR/thundering-herd-$TIMESTAMP.json" \
      --summary-export="$RESULTS_DIR/thundering-herd-$TIMESTAMP-summary.json" \
      -e API_BASE="$API_BASE" \
      -e PRODUCT_ID="$PRODUCT_ID" \
      scenario1-thundering-herd.js
    echo -e "${GREEN}✓ Results saved to: $RESULTS_DIR/thundering-herd-$TIMESTAMP-summary.json${NC}"
    ;;
  
  2)
    echo -e "${BLUE}Running Sustained Load Test...${NC}"
    PRODUCT_ID=$(create_test_product)
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    k6 run --quiet \
      --out json="$RESULTS_DIR/sustained-load-$TIMESTAMP.json" \
      --summary-export="$RESULTS_DIR/sustained-load-$TIMESTAMP-summary.json" \
      -e API_BASE="$API_BASE" \
      -e PRODUCT_ID="$PRODUCT_ID" \
      scenario2-sustained-load.js
    echo -e "${GREEN}✓ Results saved to: $RESULTS_DIR/sustained-load-$TIMESTAMP-summary.json${NC}"
    ;;
  
  3)
    echo -e "${BLUE}Running Update Spike Test...${NC}"
    PRODUCT_ID=$(create_test_product)
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    k6 run --quiet \
      --out json="$RESULTS_DIR/update-spike-$TIMESTAMP.json" \
      --summary-export="$RESULTS_DIR/update-spike-$TIMESTAMP-summary.json" \
      -e API_BASE="$API_BASE" \
      -e PRODUCT_ID="$PRODUCT_ID" \
      scenario3-update-spike.js
    echo -e "${GREEN}✓ Results saved to: $RESULTS_DIR/update-spike-$TIMESTAMP-summary.json${NC}"
    ;;
  
  D|d)
    echo -e "${BLUE}🎬 Running DEMO Mode (1000 users - optimized for video)...${NC}"
    echo ""
    echo "This test is optimized for demo recording:"
    echo "  - Gradual ramp: 50 → 200 → 500 → 1000 users"
    echo "  - 2-minute sustain at 1000 users (for recording)"
    echo "  - Cleaner output for presentation"
    echo ""
    PRODUCT_ID=$(create_test_product)
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    k6 run --quiet \
      --out json="$RESULTS_DIR/demo-1000users-$TIMESTAMP.json" \
      --summary-export="$RESULTS_DIR/demo-1000users-$TIMESTAMP-summary.json" \
      -e API_BASE_URL="$API_BASE" \
      -e PRODUCT_ID="$PRODUCT_ID" \
      scenario-demo.js
    echo -e "${GREEN}✓ Results saved to: $RESULTS_DIR/demo-1000users-$TIMESTAMP-summary.json${NC}"
    ;;
  
  4)
    echo -e "${BLUE}Running Full Test Suite...${NC}"
    
    # Test 1: Thundering Herd
    echo -e "\n${YELLOW}=== Test 1/3: Thundering Herd ===${NC}\n"
    PRODUCT_ID=$(create_test_product)
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    k6 run --quiet \
      --out json="$RESULTS_DIR/thundering-herd-$TIMESTAMP.json" \
      --summary-export="$RESULTS_DIR/thundering-herd-$TIMESTAMP-summary.json" \
      -e API_BASE="$API_BASE" \
      -e PRODUCT_ID="$PRODUCT_ID" \
      scenario1-thundering-herd.js
    echo -e "${GREEN}✓ Test 1 complete${NC}"
    
    sleep 10
    
    # Test 2: Sustained Load
    echo -e "\n${YELLOW}=== Test 2/3: Sustained Load ===${NC}\n"
    PRODUCT_ID=$(create_test_product)
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    k6 run --quiet \
      --out json="$RESULTS_DIR/sustained-load-$TIMESTAMP.json" \
      --summary-export="$RESULTS_DIR/sustained-load-$TIMESTAMP-summary.json" \
      -e API_BASE="$API_BASE" \
      -e PRODUCT_ID="$PRODUCT_ID" \
      scenario2-sustained-load.js
    echo -e "${GREEN}✓ Test 2 complete${NC}"
    
    sleep 10
    
    # Test 3: Update Spike
    echo -e "\n${YELLOW}=== Test 3/3: Update Spike ===${NC}\n"
    PRODUCT_ID=$(create_test_product)
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    k6 run --quiet \
      --out json="$RESULTS_DIR/update-spike-$TIMESTAMP.json" \
      --summary-export="$RESULTS_DIR/update-spike-$TIMESTAMP-summary.json" \
      -e API_BASE="$API_BASE" \
      -e PRODUCT_ID="$PRODUCT_ID" \
      scenario3-update-spike.js
    echo -e "${GREEN}✓ Test 3 complete${NC}"
    
    echo -e "\n${GREEN}Full test suite completed!${NC}"
    echo -e "${GREEN}All results saved to: $RESULTS_DIR${NC}"
    ;;
  
  5)
    echo "Exiting..."
    exit 0
    ;;
  
  *)
    echo -e "${RED}Invalid choice${NC}"
    exit 1
    ;;
esac

echo ""
echo -e "${GREEN}=========================================="
echo "Stress Test Complete!"
echo "==========================================${NC}"
echo ""
echo "Results saved to: $RESULTS_DIR"
echo ""
echo "To analyze results:"
echo "  1. View JSON metrics in results directory"
echo "  2. Use k6 Cloud for visualization (optional)"
echo "  3. Check CloudWatch metrics in AWS Console"
echo ""
echo "Next steps:"
echo "  - Verify database consistency (bid count vs inventory)"
echo "  - Check ECS task metrics (CPU, memory)"
echo "  - Review RDS performance insights"
echo "  - Analyze Redis latency metrics"
echo ""
