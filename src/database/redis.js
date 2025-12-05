const redis = require('redis');
const config = require('../../config');
const logger = require('../utils/logger');

// Create Redis client
const redisClient = redis.createClient({
  socket: {
    host: config.redis.host,
    port: config.redis.port
  }
});

// Event handlers
redisClient.on('connect', () => {
  logger.info('Redis connected successfully');
});

redisClient.on('error', (err) => {
  logger.error('Redis error', { error: err.message });
});

redisClient.on('ready', () => {
  logger.info('Redis client ready');
});

// Connect to Redis
(async () => {
  try {
    await redisClient.connect();
  } catch (error) {
    logger.error('Failed to connect to Redis', { error: error.message });
    process.exit(1);
  }
})();

module.exports = redisClient;
