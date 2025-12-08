const logger = require('../utils/logger');
const bidService = require('./bidService');
const { query } = require('../database/postgres');

/**
 * BroadcastService - Manages periodic broadcasts of leaderboard data
 * Handles efficient broadcasting to 1000+ WebSocket connections
 */
class BroadcastService {
  constructor() {
    this.intervals = new Map(); // productId -> intervalId
    this.broadcastFrequency = 2000; // 2 seconds
  }

  /**
   * Start broadcasting for a specific product
   */
  startBroadcast(productId, io) {
    // Don't start if already broadcasting
    if (this.intervals.has(productId)) {
      logger.debug('Broadcast already running', { productId });
      return;
    }

    logger.info('Starting leaderboard broadcast', { productId });

    const intervalId = setInterval(async () => {
      try {
        await this.broadcastLeaderboard(productId, io);
      } catch (error) {
        logger.error('Broadcast error', { 
          error: error.message, 
          productId,
          stack: error.stack 
        });
      }
    }, this.broadcastFrequency);

    this.intervals.set(productId, intervalId);
  }

  /**
   * Stop broadcasting for a specific product
   */
  stopBroadcast(productId) {
    const intervalId = this.intervals.get(productId);
    
    if (intervalId) {
      clearInterval(intervalId);
      this.intervals.delete(productId);
      logger.info('Stopped leaderboard broadcast', { productId });
    }
  }

  /**
   * Stop all broadcasts
   */
  stopAllBroadcasts() {
    this.intervals.forEach((intervalId, productId) => {
      clearInterval(intervalId);
      logger.info('Stopped broadcast', { productId });
    });
    this.intervals.clear();
  }

  /**
   * Broadcast current leaderboard state to all subscribers
   */
  async broadcastLeaderboard(productId, io) {
    const room = `leaderboard:${productId}`;
    
    // Check if anyone is listening
    const sockets = await io.in(room).allSockets();
    if (sockets.size === 0) {
      // No subscribers, stop broadcasting
      this.stopBroadcast(productId);
      return;
    }

    try {
      // Fetch product details
      const product = await this.getProductDetails(productId);
      if (!product) {
        logger.warn('Product not found for broadcast', { productId });
        this.stopBroadcast(productId);
        return;
      }

      // Check if sale is active
      const now = new Date();
      const saleActive = product.status === 'active' && 
                         now >= product.sale_start_time && 
                         now <= product.sale_end_time;

      // If sale ended, stop broadcasting
      if (product.status === 'completed' || (product.status === 'active' && now > product.sale_end_time)) {
        logger.info('Sale ended, stopping broadcast', { productId });
        this.stopBroadcast(productId);
        
        // Send final update
        io.to(room).emit('sale_ended', {
          productId,
          message: 'Sale has ended',
          timestamp: new Date()
        });
        return;
      }

      // Get top K bidders (max_winners + buffer for display)
      const topK = Math.min(product.max_winners * 2, 100); // Cap at 100 for efficiency
      const leaderboard = await bidService.getTopBidders(productId, topK);

      // Calculate entry threshold (Kth highest score)
      const entryThreshold = leaderboard.length >= product.max_winners 
        ? leaderboard[product.max_winners - 1].score 
        : 0;

      // Get highest bid
      const highestBid = leaderboard.length > 0 ? leaderboard[0].score : 0;

      // Prepare broadcast data
      const broadcastData = {
        productId,
        productName: product.name,
        saleActive,
        maxWinners: product.max_winners,
        currentInventory: product.current_inventory,
        basePrice: parseFloat(product.base_price),
        saleStartTime: product.sale_start_time,
        saleEndTime: product.sale_end_time,
        leaderboard: leaderboard.slice(0, topK), // Top K users
        highestScore: highestBid,
        entryThreshold, // Score needed to be in top K
        totalBidders: leaderboard.length,
        timestamp: new Date()
      };

      // Broadcast to room
      io.to(room).emit('leaderboard_broadcast', broadcastData);

      logger.debug('Broadcast sent', { 
        productId, 
        subscribers: sockets.size,
        bidders: leaderboard.length 
      });
    } catch (error) {
      logger.error('Failed to broadcast leaderboard', { 
        error: error.message, 
        productId,
        stack: error.stack
      });
    }
  }

  /**
   * Get product details
   */
  async getProductDetails(productId) {
    const result = await query(
      `SELECT id, name, status, base_price, max_winners, 
              sale_start_time, sale_end_time, current_inventory
       FROM products 
       WHERE id = $1`,
      [productId]
    );

    return result.rows.length > 0 ? result.rows[0] : null;
  }

  /**
   * Get active broadcasts
   */
  getActiveBroadcasts() {
    return Array.from(this.intervals.keys());
  }
}

module.exports = new BroadcastService();
