const { query, transaction } = require('../database/postgres');
const config = require('../../config');
const AppError = require('../utils/AppError');
const logger = require('../utils/logger');

class ProductService {
  // Create new product
  async createProduct(productData) {
    try {
      const {
        name,
        description,
        base_price,
        initial_inventory,
        max_winners,
        sale_start_time,
        sale_end_time
      } = productData;

      const result = await query(
        `INSERT INTO products 
         (name, description, base_price, initial_inventory, current_inventory, max_winners, sale_start_time, sale_end_time, status) 
         VALUES ($1, $2, $3, $4, $4, $5, $6, $7, 'pending') 
         RETURNING *`,
        [name, description, base_price, initial_inventory, max_winners, sale_start_time, sale_end_time]
      );

      logger.info('Product created', { productId: result.rows[0].id });
      return result.rows[0];
    } catch (error) {
      logger.error('Create product error', { error: error.message });
      throw new AppError('Failed to create product', 500);
    }
  }

  // Get all products
  async getAllProducts(filters = {}) {
    try {
      const { status, page = 1, limit = 10 } = filters;
      const offset = (page - 1) * limit;

      let queryText = 'SELECT * FROM products';
      const params = [];

      if (status) {
        queryText += ' WHERE status = $1';
        params.push(status);
      }

      queryText += ' ORDER BY created_at DESC LIMIT $' + (params.length + 1) + ' OFFSET $' + (params.length + 2);
      params.push(limit, offset);

      const result = await query(queryText, params);
      
      return result.rows;
    } catch (error) {
      logger.error('Get products error', { error: error.message });
      throw new AppError('Failed to fetch products', 500);
    }
  }

  // Get product by ID
  async getProductById(productId) {
    try {
      const result = await query(
        'SELECT * FROM products WHERE id = $1',
        [productId]
      );

      if (result.rows.length === 0) {
        throw new AppError('Product not found', 404);
      }

      // Get scoring parameters
      const scoringResult = await query(
        `SELECT alpha, beta, gamma FROM scoring_parameters 
         WHERE (product_id = $1 OR product_id IS NULL) AND is_active = true 
         ORDER BY product_id NULLS LAST LIMIT 1`,
        [productId]
      );

      const product = result.rows[0];
      product.scoring_params = scoringResult.rows[0] || {
        alpha: config.scoring.defaultAlpha,
        beta: config.scoring.defaultBeta,
        gamma: config.scoring.defaultGamma
      };

      return product;
    } catch (error) {
      if (error instanceof AppError) throw error;
      logger.error('Get product error', { error: error.message });
      throw new AppError('Failed to fetch product', 500);
    }
  }

  // Update scoring parameters
  async updateScoringParameters(productId, params) {
    try {
      const { alpha, beta, gamma } = params;

      // Check if product exists
      const productResult = await query('SELECT id FROM products WHERE id = $1', [productId]);
      if (productResult.rows.length === 0) {
        throw new AppError('Product not found', 404);
      }

      // Upsert scoring parameters
      const result = await query(
        `INSERT INTO scoring_parameters (product_id, alpha, beta, gamma, is_active) 
         VALUES ($1, $2, $3, $4, true)
         ON CONFLICT (product_id) 
         DO UPDATE SET alpha = $2, beta = $3, gamma = $4, updated_at = CURRENT_TIMESTAMP
         RETURNING *`,
        [productId, alpha, beta, gamma]
      );

      logger.info('Scoring parameters updated', { productId });
      return result.rows[0];
    } catch (error) {
      if (error instanceof AppError) throw error;
      logger.error('Update scoring parameters error', { error: error.message });
      throw new AppError('Failed to update scoring parameters', 500);
    }
  }

  // Activate sale
  async activateSale(productId) {
    try {
      const result = await query(
        `UPDATE products SET status = 'active', updated_at = CURRENT_TIMESTAMP 
         WHERE id = $1 AND status = 'pending' 
         RETURNING *`,
        [productId]
      );

      if (result.rows.length === 0) {
        throw new AppError('Product not found or already active', 404);
      }

      logger.info('Sale activated', { productId });
      return result.rows[0];
    } catch (error) {
      if (error instanceof AppError) throw error;
      throw new AppError('Failed to activate sale', 500);
    }
  }

  // End sale
  async endSale(productId) {
    try {
      const result = await query(
        `UPDATE products SET status = 'ended', updated_at = CURRENT_TIMESTAMP 
         WHERE id = $1 AND status = 'active' 
         RETURNING *`,
        [productId]
      );

      if (result.rows.length === 0) {
        throw new AppError('Product not found or not active', 404);
      }

      logger.info('Sale ended', { productId });
      return result.rows[0];
    } catch (error) {
      if (error instanceof AppError) throw error;
      throw new AppError('Failed to end sale', 500);
    }
  }

  // Get all scoring parameters
  async getAllScoringParameters() {
    try {
      const result = await query(
        `SELECT * FROM scoring_parameters 
         WHERE is_active = true 
         ORDER BY product_id NULLS FIRST`,
        []
      );

      return result.rows;
    } catch (error) {
      logger.error('Get scoring parameters error', { error: error.message });
      throw new AppError('Failed to fetch scoring parameters', 500);
    }
  }
}

module.exports = new ProductService();
