const { query } = require('../database/postgres');
const config = require('../../config');
const logger = require('../utils/logger');

class ScoringService {
  /**
   * Calculate bid score using the formula:
   * Score = α * P + β / (T + 1) + γ * W
   * 
   * @param {number} bidPrice - P: Price offered by user
   * @param {number} reactionTime - T: Time in seconds since sale start
   * @param {number} memberWeight - W: User's member weight
   * @param {object} params - Scoring parameters {alpha, beta, gamma}
   * @returns {number} Calculated score
   */
  calculateScore(bidPrice, reactionTime, memberWeight, params) {
    const { alpha, beta, gamma } = params;
    
    const priceComponent = alpha * bidPrice;
    const timeComponent = beta / (reactionTime + 1);
    const weightComponent = gamma * memberWeight;
    
    const score = priceComponent + timeComponent + weightComponent;
    
    logger.debug('Score calculated', {
      bidPrice,
      reactionTime,
      memberWeight,
      alpha,
      beta,
      gamma,
      priceComponent: priceComponent.toFixed(2),
      timeComponent: timeComponent.toFixed(2),
      weightComponent: weightComponent.toFixed(2),
      finalScore: score.toFixed(6)
    });
    
    return parseFloat(score.toFixed(6));
  }

  /**
   * Get scoring parameters for a product
   * Falls back to global defaults if product-specific params don't exist
   * 
   * @param {number} productId - Product ID
   * @returns {object} {alpha, beta, gamma}
   */
  async getScoringParameters(productId) {
    try {
      const result = await query(
        `SELECT alpha, beta, gamma 
         FROM scoring_parameters 
         WHERE (product_id = $1 OR product_id IS NULL) AND is_active = true 
         ORDER BY product_id NULLS LAST 
         LIMIT 1`,
        [productId]
      );

      if (result.rows.length > 0) {
        return {
          alpha: parseFloat(result.rows[0].alpha),
          beta: parseFloat(result.rows[0].beta),
          gamma: parseFloat(result.rows[0].gamma)
        };
      }

      // Ultimate fallback to config defaults
      return {
        alpha: config.scoring.defaultAlpha,
        beta: config.scoring.defaultBeta,
        gamma: config.scoring.defaultGamma
      };
    } catch (error) {
      logger.error('Failed to get scoring parameters', { error: error.message, productId });
      // Return config defaults on error
      return {
        alpha: config.scoring.defaultAlpha,
        beta: config.scoring.defaultBeta,
        gamma: config.scoring.defaultGamma
      };
    }
  }

  /**
   * Calculate reaction time (T) in seconds since sale started
   * 
   * @param {Date} saleStartTime - When the sale started
   * @param {Date} bidTime - When the bid was placed (defaults to now)
   * @returns {number} Reaction time in seconds
   */
  calculateReactionTime(saleStartTime, bidTime = new Date()) {
    const startTime = new Date(saleStartTime);
    const currentTime = new Date(bidTime);
    
    const diffMs = currentTime - startTime;
    const diffSeconds = diffMs / 1000;
    
    // Ensure non-negative
    return Math.max(0, parseFloat(diffSeconds.toFixed(3)));
  }

  /**
   * Get user's member weight
   * 
   * @param {number} userId - User ID
   * @returns {number} Member weight
   */
  async getMemberWeight(userId) {
    try {
      const result = await query(
        'SELECT member_weight FROM users WHERE id = $1',
        [userId]
      );

      if (result.rows.length === 0) {
        logger.warn('User not found for member weight lookup', { userId });
        return 1.0; // Default weight
      }

      return parseFloat(result.rows[0].member_weight);
    } catch (error) {
      logger.error('Failed to get member weight', { error: error.message, userId });
      return 1.0; // Default weight on error
    }
  }

  /**
   * Calculate complete bid score with all components
   * 
   * @param {object} bidData - {userId, productId, bidPrice, saleStartTime}
   * @returns {object} {score, reactionTime, memberWeight, params}
   */
  async calculateBidScore(bidData) {
    const { userId, productId, bidPrice, saleStartTime } = bidData;

    // Get all required data in parallel
    const [memberWeight, params] = await Promise.all([
      this.getMemberWeight(userId),
      this.getScoringParameters(productId)
    ]);

    // Calculate reaction time
    const reactionTime = this.calculateReactionTime(saleStartTime);

    // Calculate final score
    const score = this.calculateScore(bidPrice, reactionTime, memberWeight, params);

    return {
      score,
      reactionTime,
      memberWeight,
      params
    };
  }
}

module.exports = new ScoringService();
