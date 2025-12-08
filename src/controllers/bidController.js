const bidService = require('../services/bidService');
const logger = require('../utils/logger');

/**
 * Submit a new bid
 * POST /api/v1/bids
 */
exports.submitBid = async (req, res, next) => {
  try {
    const { productId, bidPrice } = req.body;
    const userId = req.user.id;

    const result = await bidService.submitBid({
      userId,
      productId,
      bidPrice
    });

    res.status(201).json({
      success: true,
      data: result
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Update an existing bid
 * PUT /api/v1/bids/:productId
 */
exports.updateBid = async (req, res, next) => {
  try {
    const { productId } = req.params;
    const { bidPrice } = req.body;
    const userId = req.user.id;

    const result = await bidService.updateBid({
      userId,
      productId: parseInt(productId),
      newBidPrice: bidPrice
    });

    res.json({
      success: true,
      data: result
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Get user's current bid status for a product
 * GET /api/v1/bids/my-status/:productId
 */
exports.getMyBidStatus = async (req, res, next) => {
  try {
    const { productId } = req.params;
    const userId = req.user.id;

    const status = await bidService.getUserBidStatus(userId, parseInt(productId));

    res.json({
      success: true,
      data: {
        productId: parseInt(productId),
        hasBid: status !== null,
        bid: status
      }
    });
  } catch (error) {
    next(error);
  }
};

/**
 * Get leaderboard for a product
 * GET /api/v1/leaderboard/:productId
 */
exports.getLeaderboard = async (req, res, next) => {
  try {
    const { productId } = req.params;
    const limit = parseInt(req.query.limit) || 50;
    const userId = req.user?.id; // Optional - might not be authenticated

    const leaderboard = await bidService.getTopBidders(parseInt(productId), limit);

    // Add user's own position if authenticated
    let myStatus = null;
    if (userId) {
      myStatus = await bidService.getUserBidStatus(userId, parseInt(productId));
    }

    res.json({
      success: true,
      data: {
        productId: parseInt(productId),
        leaderboard,
        myStatus,
        limit
      }
    });
  } catch (error) {
    next(error);
  }
};
