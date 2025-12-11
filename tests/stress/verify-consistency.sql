-- Consistency Verification Query
-- Use this to verify no overselling occurred after stress test
-- IMPORTANT: Checks ORDERS table (actual winners) not just bids

-- Check most recent product's consistency
SELECT 
  p.id,
  p.name,
  p.base_price,
  p.initial_inventory,
  p.max_winners,
  p.sale_start_time,
  p.sale_end_time,
  COUNT(DISTINCT b.user_id) as total_unique_bidders,
  COUNT(b.id) as total_bid_count,
  COUNT(o.id) as actual_orders_created,
  MAX(b.amount) as highest_bid,
  MIN(b.amount) as lowest_bid,
  AVG(b.amount)::numeric(10,2) as average_bid,
  CASE 
    WHEN COUNT(o.id) <= p.max_winners 
    THEN '✓ NO OVERSELLING' 
    ELSE '✗ OVERSOLD - CRITICAL ERROR!' 
  END as consistency_status,
  CASE
    WHEN COUNT(o.id) > p.max_winners
    THEN COUNT(o.id) - p.max_winners
    ELSE 0
  END as oversold_count
FROM products p
LEFT JOIN bids b ON b.product_id = p.id
LEFT JOIN orders o ON o.product_id = p.id
WHERE p.created_at >= NOW() - INTERVAL '1 hour'  -- Products from last hour
GROUP BY p.id, p.name, p.base_price, p.initial_inventory, p.max_winners, p.sale_start_time, p.sale_end_time
ORDER BY p.created_at DESC
LIMIT 1;

-- Additional verification: Check order and bid statistics
SELECT 
  p.name as product_name,
  COUNT(DISTINCT b.id) as total_bids,
  COUNT(DISTINCT o.id) as total_orders,
  p.max_winners,
  COUNT(o.id)::float / NULLIF(p.max_winners, 0) * 100 as fill_rate_percent,
  MIN(o.final_score) as min_winning_score,
  MAX(o.final_score) as max_winning_score,
  AVG(o.final_score)::numeric(10,2) as avg_winning_score
FROM products p
LEFT JOIN bids b ON b.product_id = p.id AND b.is_latest = true
LEFT JOIN orders o ON o.product_id = p.id
WHERE p.id = (SELECT id FROM products ORDER BY created_at DESC LIMIT 1)
GROUP BY p.id, p.name, p.max_winners;

-- Top 10 actual winners (from orders table)
SELECT 
  o.rank,
  u.email,
  o.final_price as winning_bid,
  o.final_score,
  o.order_status,
  o.created_at as order_time,
  EXTRACT(EPOCH FROM (b.created_at - p.sale_start_time))::int as bid_seconds_after_start
FROM orders o
JOIN users u ON o.user_id = u.id
JOIN bids b ON o.bid_id = b.id
JOIN products p ON o.product_id = p.id
WHERE o.product_id = (SELECT id FROM products ORDER BY created_at DESC LIMIT 1)
ORDER BY o.rank ASC
LIMIT 10;

-- Summary statistics for demo
SELECT 
  'Total Products' as metric,
  COUNT(*)::text as value
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
  'Active Bids',
  COUNT(*)::text
FROM bids
WHERE is_latest = true
  AND created_at >= NOW() - INTERVAL '1 hour'
UNION ALL
SELECT
  'Total Orders (Winners)',
  COUNT(*)::text
FROM orders
WHERE created_at >= NOW() - INTERVAL '1 hour'
UNION ALL
SELECT
  'Avg Bid Amount',
  '$' || ROUND(AVG(amount))::text
FROM bids
WHERE created_at >= NOW() - INTERVAL '1 hour';
