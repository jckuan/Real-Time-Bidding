const { query } = require('../database/postgres');
const logger = require('../utils/logger');
const orderService = require('../services/orderService');

/**
 * ProductStatusJob - Automatically updates product status when sales end
 * Runs periodically to mark ended sales as 'completed' and finalize orders
 */
class ProductStatusJob {
  constructor() {
    this.intervalId = null;
    this.checkInterval = 30000; // Check every 30 seconds
  }

  /**
   * Start the job
   */
  start() {
    if (this.intervalId) {
      logger.warn('ProductStatusJob already running');
      return;
    }

    logger.info('Starting ProductStatusJob', { checkInterval: this.checkInterval });

    // Run immediately on start
    this.checkAndUpdateStatuses();

    // Then run periodically
    this.intervalId = setInterval(() => {
      this.checkAndUpdateStatuses();
    }, this.checkInterval);
  }

  /**
   * Stop the job
   */
  stop() {
    if (this.intervalId) {
      clearInterval(this.intervalId);
      this.intervalId = null;
      logger.info('ProductStatusJob stopped');
    }
  }

  /**
   * Check and update product statuses
   * Also finalizes orders for newly completed sales
   */
  async checkAndUpdateStatuses() {
    try {
      // Update products where sale_end_time has passed but status is still 'active'
      const result = await query(
        `UPDATE products 
         SET status = 'completed', 
             updated_at = NOW()
         WHERE status = 'active' 
           AND sale_end_time < NOW()
         RETURNING id, name, sale_end_time`,
        []
      );

      if (result.rows.length > 0) {
        logger.info('Auto-completed ended sales', { 
          count: result.rows.length,
          products: result.rows.map(p => ({ id: p.id, name: p.name }))
        });

        // Finalize orders for each completed sale
        for (const product of result.rows) {
          try {
            const orderResult = await orderService.finalizeOrders(product.id);
            logger.info('Orders finalized for completed sale', {
              productId: product.id,
              productName: product.name,
              ordersCreated: orderResult.ordersCreated
            });
          } catch (error) {
            logger.error('Failed to finalize orders for product', {
              productId: product.id,
              productName: product.name,
              error: error.message
            });
          }
        }
      }
    } catch (error) {
      logger.error('Failed to update product statuses', { 
        error: error.message,
        stack: error.stack 
      });
    }
  }
}

module.exports = new ProductStatusJob();
