const logger = require('../utils/logger');

const errorHandler = (err, req, res, next) => {
  err.statusCode = err.statusCode || 500;
  err.status = err.status || 'error';

  if (process.env.NODE_ENV === 'development') {
    logger.error('Error:', {
      message: err.message,
      stack: err.stack,
      statusCode: err.statusCode
    });

    res.status(err.statusCode).json({
      success: false,
      error: {
        message: err.message,
        stack: err.stack,
        statusCode: err.statusCode
      }
    });
  } else {
    // Production: Don't leak error details
    logger.error('Error:', { message: err.message, statusCode: err.statusCode });

    if (err.isOperational) {
      res.status(err.statusCode).json({
        success: false,
        error: {
          message: err.message
        }
      });
    } else {
      // Programming or unknown errors
      res.status(500).json({
        success: false,
        error: {
          message: 'Something went wrong'
        }
      });
    }
  }
};

module.exports = errorHandler;
