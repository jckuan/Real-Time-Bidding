const jwt = require('jsonwebtoken');
const config = require('../../config');
const AppError = require('../utils/AppError');

/**
 * Required authentication middleware
 */
const authenticate = async (req, res, next) => {
  try {
    // Get token from header
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return next(new AppError('No token provided', 401));
    }

    const token = authHeader.split(' ')[1];

    // Verify token
    const decoded = jwt.verify(token, config.jwt.secret);
    
    // Attach user info to request
    req.user = {
      id: decoded.id,
      email: decoded.email
    };

    next();
  } catch (error) {
    if (error.name === 'JsonWebTokenError') {
      return next(new AppError('Invalid token', 401));
    }
    if (error.name === 'TokenExpiredError') {
      return next(new AppError('Token expired', 401));
    }
    next(error);
  }
};

/**
 * Optional authentication middleware
 * Doesn't fail if no token is provided
 */
const optionalAuth = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      // No token, but continue without user
      return next();
    }

    const token = authHeader.split(' ')[1];

    try {
      const decoded = jwt.verify(token, config.jwt.secret);
      req.user = {
        id: decoded.id,
        email: decoded.email
      };
    } catch (err) {
      // Invalid token, continue without user
    }

    next();
  } catch (error) {
    next(error);
  }
};

module.exports = authenticate;
module.exports.authenticate = authenticate;
module.exports.optionalAuth = optionalAuth;
