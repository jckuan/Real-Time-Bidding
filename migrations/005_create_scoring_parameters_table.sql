-- Migration: Create scoring_parameters table
-- Created: 2025-12-05

CREATE TABLE IF NOT EXISTS scoring_parameters (
    id SERIAL PRIMARY KEY,
    product_id INTEGER UNIQUE REFERENCES products(id) ON DELETE CASCADE,
    alpha DECIMAL(10, 6) NOT NULL DEFAULT 1.0,
    beta DECIMAL(10, 6) NOT NULL DEFAULT 100.0,
    gamma DECIMAL(10, 6) NOT NULL DEFAULT 50.0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CHECK (alpha >= 0),
    CHECK (beta >= 0),
    CHECK (gamma >= 0)
);

CREATE INDEX idx_scoring_params_product ON scoring_parameters(product_id, is_active);

CREATE TRIGGER update_scoring_parameters_updated_at BEFORE UPDATE ON scoring_parameters
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insert global defaults (product_id = NULL)
INSERT INTO scoring_parameters (product_id, alpha, beta, gamma, is_active)
VALUES (NULL, 1.0, 100.0, 50.0, TRUE)
ON CONFLICT DO NOTHING;
