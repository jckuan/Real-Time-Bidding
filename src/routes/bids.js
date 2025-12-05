const express = require('express');
const router = express.Router();
const bidController = require('../controllers/bidController');
const { authenticate, optionalAuth } = require('../middleware/auth');
const { body, param, query } = require('express-validator');
const { validate } = require('../middleware/validator');

/**
 * Validation rules
 */
const bidValidation = [
  body('productId')
    .isInt({ min: 1 })
    .withMessage('Product ID must be a positive integer'),
  body('bidPrice')
    .isFloat({ min: 0.01 })
    .withMessage('Bid price must be a positive number')
];

const updateBidValidation = [
  param('productId')
    .isInt({ min: 1 })
    .withMessage('Product ID must be a positive integer'),
  body('bidPrice')
    .isFloat({ min: 0.01 })
    .withMessage('Bid price must be a positive number')
];

const statusValidation = [
  param('productId')
    .isInt({ min: 1 })
    .withMessage('Product ID must be a positive integer')
];

const leaderboardValidation = [
  param('productId')
    .isInt({ min: 1 })
    .withMessage('Product ID must be a positive integer'),
  query('limit')
    .optional()
    .isInt({ min: 1, max: 100 })
    .withMessage('Limit must be between 1 and 100')
];

/**
 * Routes
 */

// Submit a new bid
router.post(
  '/',
  authenticate,
  bidValidation,
  validate,
  bidController.submitBid
);

// Update existing bid
router.put(
  '/:productId',
  authenticate,
  updateBidValidation,
  validate,
  bidController.updateBid
);

// Get user's bid status
router.get(
  '/my-status/:productId',
  authenticate,
  statusValidation,
  validate,
  bidController.getMyBidStatus
);

// Get leaderboard (public or authenticated)
router.get(
  '/leaderboard/:productId',
  optionalAuth,
  leaderboardValidation,
  validate,
  bidController.getLeaderboard
);

module.exports = router;
