-- Migration: Create products table
-- Created: 2025-12-05

CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    base_price DECIMAL(10, 2) NOT NULL,
    initial_inventory INTEGER NOT NULL,
    current_inventory INTEGER NOT NULL,
    version INTEGER NOT NULL DEFAULT 0,
    sale_start_time TIMESTAMP NOT NULL,
    sale_end_time TIMESTAMP NOT NULL,
    status VARCHAR(20) DEFAULT 'pending',
    max_winners INTEGER NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CHECK (current_inventory >= 0),
    CHECK (initial_inventory >= max_winners),
    CHECK (sale_end_time > sale_start_time)
);

CREATE INDEX idx_products_status ON products(status);
CREATE INDEX idx_products_sale_times ON products(sale_start_time, sale_end_time);

CREATE TRIGGER update_products_updated_at BEFORE UPDATE ON products
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
