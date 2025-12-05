-- Migration: Create bids table
-- Created: 2025-12-05

CREATE TABLE IF NOT EXISTS bids (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    product_id INTEGER NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    bid_price DECIMAL(10, 2) NOT NULL,
    reaction_time DECIMAL(10, 3) NOT NULL,
    member_weight DECIMAL(5, 2) NOT NULL,
    calculated_score DECIMAL(15, 6) NOT NULL,
    bid_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_latest BOOLEAN DEFAULT TRUE,
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_bids_user_product_latest ON bids(user_id, product_id, is_latest);
CREATE INDEX idx_bids_product_score ON bids(product_id, calculated_score DESC);
CREATE INDEX idx_bids_timestamp ON bids(bid_timestamp);

-- Unique constraint: one latest bid per user per product
CREATE UNIQUE INDEX idx_bids_user_product_unique_latest 
    ON bids(user_id, product_id) 
    WHERE is_latest = TRUE;
