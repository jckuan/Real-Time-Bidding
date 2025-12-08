const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const http = require('http');
const { Server } = require('socket.io');
const path = require('path');

const config = require('../config');
const logger = require('./utils/logger');
const errorHandler = require('./middleware/errorHandler');
const broadcastService = require('./services/broadcastService');
const productStatusJob = require('./jobs/productStatusJob');

// Import database connections
require('./database/postgres');
require('./database/redis');

const app = express();
const server = http.createServer(app);

// Initialize Socket.IO
const io = new Server(server, {
  cors: {
    origin: config.app.corsOrigin,
    methods: ['GET', 'POST']
  }
});

// Middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      scriptSrc: ["'self'", "https://cdn.socket.io"],
      connectSrc: ["'self'", "ws:", "wss:"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      imgSrc: ["'self'", "data:", "https:"],
      fontSrc: ["'self'", "data:"],
    },
  },
}));
app.use(cors({ origin: config.app.corsOrigin }));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(morgan('combined', { stream: { write: message => logger.info(message.trim()) }}));

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'OK', timestamp: new Date().toISOString() });
});

// Serve frontend static files
app.use(express.static(path.join(__dirname, '../frontend')));

// API routes
app.get('/api/v1', (req, res) => {
  res.json({ message: 'Real-Time Bidding API v1' });
});

// Import routes
const authRoutes = require('./routes/auth');
const productRoutes = require('./routes/products');
const adminRoutes = require('./routes/admin');
const bidRoutes = require('./routes/bids');

// Use routes
app.use('/api/v1/auth', authRoutes);
app.use('/api/v1/products', productRoutes);
app.use('/api/v1/admin', adminRoutes);
app.use('/api/v1/bids', bidRoutes);

// WebSocket connection handling
io.on('connection', (socket) => {
  logger.info('New WebSocket connection', { socketId: socket.id });

  // Subscribe to product leaderboard
  socket.on('subscribe_leaderboard', (productId) => {
    const room = `leaderboard:${productId}`;
    socket.join(room);
    logger.info('User subscribed to leaderboard', { socketId: socket.id, productId, room });
    
    // Start periodic broadcast for this product
    broadcastService.startBroadcast(productId, io);
    
    socket.emit('subscribed', { productId, room });
  });

  // Unsubscribe from product leaderboard
  socket.on('unsubscribe_leaderboard', (productId) => {
    const room = `leaderboard:${productId}`;
    socket.leave(room);
    logger.info('User unsubscribed from leaderboard', { socketId: socket.id, productId, room });
    
    socket.emit('unsubscribed', { productId, room });
  });

  socket.on('disconnect', () => {
    logger.info('WebSocket disconnected', { socketId: socket.id });
  });
});

// Make io available to routes and services
app.set('io', io);
global.io = io; // Also make it globally accessible

// 404 handler
app.use((req, res) => {
  res.status(404).json({ success: false, error: { message: 'Route not found' }});
});

// Error handling middleware (must be last)
app.use(errorHandler);

// Start server
const PORT = config.app.port;
server.listen(PORT, () => {
  logger.info(`Server running on port ${PORT} in ${config.app.env} mode`);
  
  // Start background jobs
  productStatusJob.start();
});

// Graceful shutdown
process.on('SIGTERM', () => {
  logger.info('SIGTERM received, shutting down gracefully');
  productStatusJob.stop();
  broadcastService.stopAllBroadcasts();
  server.close(() => {
    logger.info('Server closed');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  logger.info('SIGINT received, shutting down gracefully');
  productStatusJob.stop();
  broadcastService.stopAllBroadcasts();
  server.close(() => {
    logger.info('Server closed');
    process.exit(0);
  });
});

module.exports = { app, io };
