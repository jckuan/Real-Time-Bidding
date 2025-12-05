const { validationResult } = require('express-validator');
const AppError = require('../utils/AppError');

/**
 * Validation middleware
 * Checks for validation errors from express-validator
 */
exports.validate = (req, res, next) => {
  const errors = validationResult(req);
  
  if (!errors.isEmpty()) {
    const errorMessages = errors.array().map(err => err.msg);
    return next(new AppError(errorMessages.join(', '), 400));
  }
  
  next();
};
