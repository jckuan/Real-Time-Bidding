#!/bin/bash

# Quick Database Consistency Check
# Run this during demo recording to verify no overselling

set -e

echo "======================================"
echo "DATABASE CONSISTENCY CHECK"
echo "======================================"
echo ""

# RDS connection details
DB_HOST="YOUR_RDS_ENDPOINT"
DB_USER="admin_user"
DB_NAME="rtb_database"

# Prompt for password if not set
if [ -z "$DB_PASSWORD" ]; then
  echo "Enter database password:"
  read -s DB_PASSWORD
  echo ""
fi

export PGPASSWORD="$DB_PASSWORD"

echo "Connecting to RDS..."
echo ""

# Main consistency query - CHECK ORDERS TABLE
psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" << 'EOF'
\pset border 2
\pset format wrapped

-- Quick Consistency Check (ORDERS = ACTUAL WINNERS)
SELECT 
  '📊 CONSISTENCY VERIFICATION (ORDERS TABLE)' as "CHECK",
  '' as "RESULT";

SELECT 
  p.name as "Product Name",
  p.max_winners as "Max Winners",
  COUNT(DISTINCT b.user_id) as "Total Bidders",
  COUNT(o.id) as "Actual Orders Created",
  CASE 
    WHEN COUNT(o.id) <= p.max_winners 
    THEN '✅ NO OVERSELLING' 
    ELSE '❌ OVERSOLD!' 
  END as "Status"
FROM products p
LEFT JOIN bids b ON b.product_id = p.id
LEFT JOIN orders o ON o.product_id = p.id
WHERE p.created_at >= NOW() - INTERVAL '1 hour'
GROUP BY p.id, p.name, p.max_winners
ORDER BY p.created_at DESC
LIMIT 1;

-- Summary Statistics
SELECT '' as ""; -- blank line
SELECT '📈 SUMMARY STATISTICS' as "METRIC", '' as "VALUE";

SELECT 
  'Total Products (last hour)' as "METRIC",
  COUNT(*)::text as "VALUE"
FROM products
WHERE created_at >= NOW() - INTERVAL '1 hour'
UNION ALL
SELECT 
  'Total Users',
  COUNT(DISTINCT user_id)::text
FROM bids
WHERE created_at >= NOW() - INTERVAL '1 hour'
UNION ALL
SELECT 
  'Total Bids',
  COUNT(*)::text
FROM bids
WHERE created_at >= NOW() - INTERVAL '1 hour'
UNION ALL
SELECT 
  'Active Bids (latest only)',
  COUNT(*)::text
FROM bids
WHERE is_latest = true
  AND created_at >= NOW() - INTERVAL '1 hour'
UNION ALL
SELECT 
  'Active Bids (latest only)',
  COUNT(*)::text
FROM bids
WHERE is_latest = true
  AND created_at >= NOW() - INTERVAL '1 hour'
UNION ALL
SELECT
  'Total Orders (Actual Winners)',
  COUNT(*)::text
FROM orders
WHERE created_at >= NOW() - INTERVAL '1 hour'
UNION ALL
SELECT
  'Average Bid Amount',
  '$' || ROUND(AVG(amount))::text
FROM bids
WHERE created_at >= NOW() - INTERVAL '1 hour';

-- Top 5 Actual Winners (from orders table)
SELECT '' as ""; -- blank line
SELECT '🏆 TOP 5 WINNERS (FROM ORDERS)' as "RANK", '' as "EMAIL", '' as "WINNING BID", '' as "FINAL SCORE";

SELECT 
  o.rank::text as "RANK",
  u.email as "EMAIL",
  '$' || o.final_price::text as "WINNING BID",
  ROUND(o.final_score, 2)::text as "FINAL SCORE"
FROM orders o
JOIN users u ON o.user_id = u.id
WHERE o.product_id = (SELECT id FROM products ORDER BY created_at DESC LIMIT 1)
ORDER BY o.rank ASC
LIMIT 5;

EOF

echo ""
echo "======================================"
echo "✅ Consistency check complete!"
echo "======================================"
