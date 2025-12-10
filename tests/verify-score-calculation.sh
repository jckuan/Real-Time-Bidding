#!/bin/bash

# Score Verification Script
# Displays all parameters needed to manually verify score calculation
# Formula: Score = α·P + β/(T+1) + γ·W

echo "================================================"
echo "Score Calculation Verification"
echo "================================================"
echo ""

# Get the most recent product
PRODUCT_ID=$(psql -d rtb_database -t -c "SELECT id FROM products ORDER BY id ASC LIMIT 1;" | xargs)

if [ -z "$PRODUCT_ID" ]; then
  echo "❌ No products found in database"
  exit 1
fi

echo "Checking Product ID: $PRODUCT_ID"
echo ""

# Get scoring parameters (α, β, γ)
echo "================================================"
echo "Scoring Parameters (α, β, γ)"
echo "================================================"
psql -d rtb_database -c "
  SELECT 
    alpha,
    beta,
    gamma
  FROM scoring_parameters 
  ORDER BY id DESC 
  LIMIT 1;
"

# Get product details
echo ""
echo "================================================"
echo "Product Details"
echo "================================================"
psql -d rtb_database -c "
  SELECT 
    id,
    name,
    sale_start_time,
    sale_end_time,
    status
  FROM products 
  WHERE id = $PRODUCT_ID;
"

# Get all bids with calculation details
echo ""
echo "================================================"
echo "Bids with Score Calculation Details"
echo "================================================"
echo "Formula: Score = α·P + β/(T+1) + γ·W"
echo ""

psql -d rtb_database -c "
  SELECT 
    b.id as bid_id,
    u.username,
    b.bid_price as P,
    ROUND(b.reaction_time::numeric, 2) as T,
    ROUND(b.member_weight::numeric, 4) as W,
    b.calculated_score as stored_score,
    sp.alpha as alpha,
    sp.beta as beta,
    sp.gamma as gamma,
    -- Manual calculation for verification
    ROUND(
      (sp.alpha * b.bid_price) + 
      (sp.beta / (b.reaction_time + 1)) + 
      (sp.gamma * b.member_weight)
    , 6) as manual_score,
    -- Difference
    ROUND(
      ABS(b.calculated_score - 
        ((sp.alpha * b.bid_price) + 
         (sp.beta / (b.reaction_time + 1)) + 
         (sp.gamma * b.member_weight))
      )
    , 6) as difference
  FROM bids b
  JOIN users u ON b.user_id = u.id
  CROSS JOIN (
    SELECT alpha, beta, gamma 
    FROM scoring_parameters 
    ORDER BY id DESC 
    LIMIT 1
  ) sp
  WHERE b.product_id = $PRODUCT_ID
  ORDER BY b.calculated_score DESC;
"

echo ""
echo "================================================"
echo "Verification Instructions"
echo "================================================"
echo ""
echo "For each bid, verify:"
echo "  Score = α·P + β/(T+1) + γ·W"
echo ""
echo "Example calculation for first bid:"
echo "  1. Get α, β, γ from Scoring Parameters table"
echo "  2. Get P, T, W from the bid row"
echo "  3. Calculate: α×P + β/(T+1) + γ×W"
echo "  4. Compare with 'stored_score' column"
echo "  5. Check 'difference' column (should be ~0)"
echo ""
echo "If 'difference' > 0.01, there may be a calculation error"
echo "================================================"
