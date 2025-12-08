const { query } = require('../database/postgres');
const logger = require('../utils/logger');

/**
 * Order Service
 * Handles order creation and management for winning bids
 */
class OrderService {
  /**
   * Finalize orders for a completed sale
   * Creates order records for top N winners based on max_winners
   * @param {number} productId - The product ID
   * @returns {Promise<Object>} Result with created orders count
   */
  async finalizeOrders(productId) {
    try {
      // Get product details
      const productResult = await query(
        `SELECT id, name, max_winners, status 
         FROM products 
         WHERE id = $1`,
        [productId]
      );

      if (productResult.rows.length === 0) {
        throw new Error(`Product ${productId} not found`);
      }

      const product = productResult.rows[0];

      // Only finalize if product is completed
      if (product.status !== 'completed') {
        logger.info('Product not completed yet, skipping order finalization', { 
          productId, 
          status: product.status 
        });
        return { ordersCreated: 0, message: 'Product not completed' };
      }

      // Check if orders already created for this product
      const existingOrders = await query(
        'SELECT COUNT(*) as count FROM orders WHERE product_id = $1',
        [productId]
      );

      if (parseInt(existingOrders.rows[0].count) > 0) {
        logger.info('Orders already exist for this product', { productId });
        return { ordersCreated: 0, message: 'Orders already exist' };
      }

      // Get top N winning bids by score
      const winnersResult = await query(
        `SELECT 
          b.id as bid_id,
          b.user_id,
          b.product_id,
          b.bid_price,
          b.calculated_score,
          ROW_NUMBER() OVER (ORDER BY b.calculated_score DESC, b.created_at ASC) as rank
         FROM bids b
         WHERE b.product_id = $1
         ORDER BY b.calculated_score DESC, b.created_at ASC
         LIMIT $2`,
        [productId, product.max_winners]
      );

      const winners = winnersResult.rows;

      if (winners.length === 0) {
        logger.info('No bids found for product', { productId });
        return { ordersCreated: 0, message: 'No bids to finalize' };
      }

      // Create orders for winners
      let ordersCreated = 0;
      for (const winner of winners) {
        try {
          await query(
            `INSERT INTO orders 
             (user_id, product_id, bid_id, final_price, final_score, rank, order_status)
             VALUES ($1, $2, $3, $4, $5, $6, $7)`,
            [
              winner.user_id,
              winner.product_id,
              winner.bid_id,
              winner.bid_price,
              winner.calculated_score,
              winner.rank,
              'confirmed'
            ]
          );
          ordersCreated++;
        } catch (error) {
          logger.error('Failed to create order for winner', {
            productId,
            bidId: winner.bid_id,
            error: error.message
          });
        }
      }

      logger.info('Orders finalized successfully', {
        productId,
        productName: product.name,
        ordersCreated,
        maxWinners: product.max_winners
      });

      return {
        ordersCreated,
        maxWinners: product.max_winners,
        productName: product.name,
        message: 'Orders created successfully'
      };

    } catch (error) {
      logger.error('Error finalizing orders', {
        productId,
        error: error.message,
        stack: error.stack
      });
      throw error;
    }
  }

  /**
   * Get orders for a specific product
   * @param {number} productId - The product ID
   * @returns {Promise<Array>} List of orders
   */
  async getOrdersByProduct(productId) {
    const result = await query(
      `SELECT 
        o.*,
        u.username,
        u.email,
        p.name as product_name
       FROM orders o
       JOIN users u ON o.user_id = u.id
       JOIN products p ON o.product_id = p.id
       WHERE o.product_id = $1
       ORDER BY o.rank ASC`,
      [productId]
    );

    return result.rows;
  }

  /**
   * Get orders for a specific user
   * @param {number} userId - The user ID
   * @returns {Promise<Array>} List of user's orders
   */
  async getOrdersByUser(userId) {
    const result = await query(
      `SELECT 
        o.*,
        p.name as product_name,
        p.description
       FROM orders o
       JOIN products p ON o.product_id = p.id
       WHERE o.user_id = $1
       ORDER BY o.created_at DESC`,
      [userId]
    );

    return result.rows;
  }
}

module.exports = new OrderService();
