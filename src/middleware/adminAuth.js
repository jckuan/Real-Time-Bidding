const AppError = require('../utils/AppError');

// Middleware to check if user is an admin
const adminAuth = (req, res, next) => {
  // First, regular auth middleware should have already verified the token
  // and attached user info to req.user
  
  if (!req.user) {
    throw new AppError('Authentication required', 401);
  }

  if (req.user.role !== 'admin') {
    throw new AppError('Admin access required', 403);
  }

  next();
};

module.exports = adminAuth;
