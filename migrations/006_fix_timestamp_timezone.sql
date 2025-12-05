-- Migration: Fix timestamp columns to use timezone
-- Created: 2025-12-05
-- Issue: TIMESTAMP without timezone causes issues with UTC vs local time comparisons

-- Update products table timestamps
ALTER TABLE products 
  ALTER COLUMN sale_start_time TYPE TIMESTAMP WITH TIME ZONE,
  ALTER COLUMN sale_end_time TYPE TIMESTAMP WITH TIME ZONE,
  ALTER COLUMN created_at TYPE TIMESTAMP WITH TIME ZONE,
  ALTER COLUMN updated_at TYPE TIMESTAMP WITH TIME ZONE;

-- Update bids table timestamps  
ALTER TABLE bids
  ALTER COLUMN bid_timestamp TYPE TIMESTAMP WITH TIME ZONE,
  ALTER COLUMN created_at TYPE TIMESTAMP WITH TIME ZONE;

-- Update orders table timestamps
ALTER TABLE orders
  ALTER COLUMN created_at TYPE TIMESTAMP WITH TIME ZONE,
  ALTER COLUMN updated_at TYPE TIMESTAMP WITH TIME ZONE;

-- Update users table timestamps
ALTER TABLE users
  ALTER COLUMN created_at TYPE TIMESTAMP WITH TIME ZONE,
  ALTER COLUMN updated_at TYPE TIMESTAMP WITH TIME ZONE,
  ALTER COLUMN last_login TYPE TIMESTAMP WITH TIME ZONE;

-- Update scoring_parameters table timestamps
ALTER TABLE scoring_parameters
  ALTER COLUMN created_at TYPE TIMESTAMP WITH TIME ZONE,
  ALTER COLUMN updated_at TYPE TIMESTAMP WITH TIME ZONE;
