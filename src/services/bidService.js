const { query } = require('../database/postgres');
const redisClient = require('../database/redis');
const scoringService = require('./scoringService');
const logger = require('../utils/logger');
const AppError = require('../utils/AppError');

class BidService {
  /**
   * Submit a new bid
   * 
   * @param {object} bidData - {userId, productId, bidPrice}
   * @returns {object} Bid details with score and rank
   */
  async submitBid(bidData) {
    const { userId, productId, bidPrice } = bidData;

    // 1. Get product and validate sale status
    const product = await this.getProductForBidding(productId);
    
    if (!product) {
      throw new AppError('Product not found', 404);
    }

    if (product.status !== 'active') {
      throw new AppError('Product sale is not active', 400);
    }

    const now = new Date();
    const startTime = new Date(product.sale_start_time);
    const endTime = new Date(product.sale_end_time);
    
    logger.debug('Time check for bid submission', {
      now: now.toISOString(),
      saleStart: startTime.toISOString(),
      saleEnd: endTime.toISOString(),
      nowTime: now.getTime(),
      startTimestamp: startTime.getTime(),
      endTimestamp: endTime.getTime()
    });
    
    if (now < startTime) {
      throw new AppError('Sale has not started yet', 400);
    }

    if (now > endTime) {
      throw new AppError('Sale has already ended', 400);
    }

    if (bidPrice < parseFloat(product.base_price)) {
      throw new AppError(`Bid price must be at least ${product.base_price}`, 400);
    }

    // 2. Check if user already has a latest bid for this product
    const existingBid = await this.getUserLatestBid(userId, productId);
    
    if (existingBid) {
      throw new AppError('You already have a bid for this product. Use update instead.', 400);
    }

    // 3. Calculate score
    const scoreResult = await scoringService.calculateBidScore({
      userId,
      productId,
      bidPrice,
      saleStartTime: product.sale_start_time
    });

    // 4. Save to database
    const bidId = await this.saveBid({
      userId,
      productId,
      bidPrice,
      score: scoreResult.score,
      reactionTime: scoreResult.reactionTime,
      memberWeight: scoreResult.memberWeight
    });

    // 5. Update Redis leaderboard
    await this.updateLeaderboard(productId, userId, scoreResult.score);

    // 6. Get user's rank
    const rank = await this.getUserRank(productId, userId);

    logger.info('Bid submitted', {
      bidId,
      userId,
      productId,
      bidPrice,
      score: scoreResult.score,
      rank
    });

    // 7. Emit WebSocket events
    this.emitBidUpdate(productId, userId, {
      bidId,
      bidPrice,
      score: scoreResult.score,
      rank,
      type: 'new_bid'
    });

    return {
      bidId,
      productId,
      bidPrice,
      score: scoreResult.score,
      reactionTime: scoreResult.reactionTime,
      rank,
      timestamp: new Date()
    };
  }

  /**
   * Update an existing bid
   * 
   * @param {object} updateData - {userId, productId, newBidPrice}
   * @returns {object} Updated bid details with score and rank
   */
  async updateBid(updateData) {
    const { userId, productId, newBidPrice } = updateData;

    // 1. Get product and validate
    const product = await this.getProductForBidding(productId);
    
    if (!product) {
      throw new AppError('Product not found', 404);
    }

    if (product.status !== 'active') {
      throw new AppError('Product sale is not active', 400);
    }

    const now = new Date();
    if (now > new Date(product.sale_end_time)) {
      throw new AppError('Sale has already ended', 400);
    }

    if (newBidPrice < parseFloat(product.base_price)) {
      throw new AppError(`Bid price must be at least ${product.base_price}`, 400);
    }

    // 2. Get existing bid
    const existingBid = await this.getUserLatestBid(userId, productId);
    
    if (!existingBid) {
      throw new AppError('No existing bid found. Please submit a new bid.', 404);
    }

    // 3. Validate price increase
    if (newBidPrice <= parseFloat(existingBid.bid_price)) {
      throw new AppError('New bid price must be higher than current bid', 400);
    }

    // 4. Calculate new score
    const scoreResult = await scoringService.calculateBidScore({
      userId,
      productId,
      bidPrice: newBidPrice,
      saleStartTime: product.sale_start_time
    });

    // 5. Mark old bid as not latest
    await this.markBidAsNotLatest(existingBid.id);

    // 6. Save new bid
    const newBidId = await this.saveBid({
      userId,
      productId,
      bidPrice: newBidPrice,
      score: scoreResult.score,
      reactionTime: scoreResult.reactionTime,
      memberWeight: scoreResult.memberWeight
    });

    // 7. Update Redis leaderboard
    await this.updateLeaderboard(productId, userId, scoreResult.score);

    // 8. Get new rank
    const rank = await this.getUserRank(productId, userId);

    logger.info('Bid updated', {
      newBidId,
      oldBidId: existingBid.id,
      userId,
      productId,
      oldPrice: existingBid.bid_price,
      newPrice: newBidPrice,
      oldScore: existingBid.calculated_score,
      newScore: scoreResult.score,
      rank
    });

    // 9. Emit WebSocket events
    this.emitBidUpdate(productId, userId, {
      bidId: newBidId,
      bidPrice: newBidPrice,
      score: scoreResult.score,
      rank,
      type: 'bid_updated'
    });

    return {
      bidId: newBidId,
      productId,
      bidPrice: newBidPrice,
      score: scoreResult.score,
      reactionTime: scoreResult.reactionTime,
      rank,
      timestamp: new Date()
    };
  }

  /**
   * Get product details for bidding validation
   */
  async getProductForBidding(productId) {
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
   * Get user's latest bid for a product
   */
  async getUserLatestBid(userId, productId) {
    const result = await query(
      `SELECT id, bid_price, calculated_score, bid_timestamp 
       FROM bids 
       WHERE user_id = $1 AND product_id = $2 AND is_latest = true`,
      [userId, productId]
    );

    return result.rows.length > 0 ? result.rows[0] : null;
  }

  /**
   * Save bid to database
   */
  async saveBid({ userId, productId, bidPrice, score, reactionTime, memberWeight }) {
    const result = await query(
      `INSERT INTO bids (user_id, product_id, bid_price, calculated_score, reaction_time, member_weight, is_latest)
       VALUES ($1, $2, $3, $4, $5, $6, true)
       RETURNING id`,
      [userId, productId, bidPrice, score, reactionTime, memberWeight]
    );

    return result.rows[0].id;
  }

  /**
   * Mark a bid as not latest
   */
  async markBidAsNotLatest(bidId) {
    await query(
      'UPDATE bids SET is_latest = false WHERE id = $1',
      [bidId]
    );
  }

  /**
   * Update Redis leaderboard (ZSET)
   */
  async updateLeaderboard(productId, userId, score) {
    const leaderboardKey = `leaderboard:product:${productId}`;
    
    try {
      await redisClient.zAdd(leaderboardKey, { score, value: userId.toString() });
      
      // Set expiration to 7 days
      await redisClient.expire(leaderboardKey, 60 * 60 * 24 * 7);
      
      logger.debug('Leaderboard updated in Redis', { productId, userId, score });
    } catch (error) {
      logger.error('Failed to update Redis leaderboard', { 
        error: error.message, 
        productId, 
        userId, 
        score 
      });
      // Don't throw - Redis failure shouldn't block bid submission
    }
  }

  /**
   * Get user's rank in leaderboard
   */
  async getUserRank(productId, userId) {
    const leaderboardKey = `leaderboard:product:${productId}`;
    
    try {
      // ZREVRANK returns 0-based rank (0 = highest score)
      const rank = await redisClient.zRevRank(leaderboardKey, userId.toString());
      
      // Return 1-based rank, or null if not found
      return rank !== null && rank !== undefined ? rank + 1 : null;
    } catch (error) {
      logger.error('Failed to get rank from Redis', { 
        error: error.message, 
        productId, 
        userId 
      });
      return null;
    }
  }

  /**
   * Get top K users from leaderboard
   */
  async getTopBidders(productId, limit = 50) {
    const leaderboardKey = `leaderboard:product:${productId}`;
    
    try {
      // Get top K with scores (REV = descending order)
      const results = await redisClient.zRangeWithScores(
        leaderboardKey, 
        0, 
        limit - 1,
        { REV: true }
      );

      // Parse results: array of {value: userId, score: score}
      const leaderboard = results.map((entry, index) => ({
        userId: parseInt(entry.value),
        score: entry.score,
        rank: index + 1
      }));

      // Enrich with user details
      if (leaderboard.length > 0) {
        const userIds = leaderboard.map(entry => entry.userId);
        const userDetails = await this.getUserDetails(userIds);
        
        leaderboard.forEach(entry => {
          const user = userDetails.find(u => u.id === entry.userId);
          if (user) {
            entry.email = user.email;
            entry.memberWeight = parseFloat(user.member_weight);
          }
        });
      }

      return leaderboard;
    } catch (error) {
      logger.error('Failed to get top bidders from Redis', { 
        error: error.message, 
        productId 
      });
      throw new AppError('Failed to retrieve leaderboard', 500);
    }
  }

  /**
   * Get user details in batch
   */
  async getUserDetails(userIds) {
    if (userIds.length === 0) return [];

    const placeholders = userIds.map((_, i) => `$${i + 1}`).join(',');
    const result = await query(
      `SELECT id, email, member_weight FROM users WHERE id IN (${placeholders})`,
      userIds
    );

    return result.rows;
  }

  /**
   * Get user's current bid status for a product
   */
  async getUserBidStatus(userId, productId) {
    const latestBid = await this.getUserLatestBid(userId, productId);
    
    if (!latestBid) {
      return null;
    }

    const rank = await this.getUserRank(productId, userId);

    return {
      bidId: latestBid.id,
      bidPrice: parseFloat(latestBid.bid_price),
      score: parseFloat(latestBid.calculated_score),
      rank,
      timestamp: latestBid.bid_timestamp
    };
  }

  /**
   * Emit WebSocket events for bid updates
   */
  emitBidUpdate(productId, userId, bidData) {
    try {
      if (!global.io) {
        logger.warn('Socket.io not available for bid update broadcast');
        return;
      }

      const room = `leaderboard:${productId}`;
      
      // Broadcast to leaderboard room (all subscribers)
      global.io.to(room).emit('leaderboard_update', {
        productId,
        userId,
        ...bidData,
        timestamp: new Date()
      });

      logger.debug('WebSocket bid update emitted', { room, userId, productId });
    } catch (error) {
      logger.error('Failed to emit bid update via WebSocket', { 
        error: error.message, 
        productId, 
        userId 
      });
    }
  }
}

module.exports = new BidService();
