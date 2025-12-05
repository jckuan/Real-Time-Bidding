const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { query } = require('../database/postgres');
const config = require('../../config');
const AppError = require('../utils/AppError');
const logger = require('../utils/logger');

class AuthService {
  // Generate JWT token
  generateToken(user) {
    return jwt.sign(
      { 
        id: user.id, 
        email: user.email 
      },
      config.jwt.secret,
      { expiresIn: config.jwt.expiresIn }
    );
  }

  // Register new user
  async register(email, password, username) {
    try {
      // Check if user already exists
      const existingUser = await query(
        'SELECT id FROM users WHERE email = $1',
        [email]
      );

      if (existingUser.rows.length > 0) {
        throw new AppError('Email already registered', 409);
      }

      // Hash password
      const passwordHash = await bcrypt.hash(password, 12);

      // Assign member weight (random between 0.5 and 2.0 for demo)
      const memberWeight = (Math.random() * 1.5 + 0.5).toFixed(2);

      // Insert user
      const result = await query(
        `INSERT INTO users (email, password_hash, username, member_weight) 
         VALUES ($1, $2, $3, $4) 
         RETURNING id, email, username, member_weight, created_at`,
        [email, passwordHash, username, memberWeight]
      );

      const user = result.rows[0];
      const token = this.generateToken(user);

      logger.info('User registered', { userId: user.id, email: user.email });

      return {
        user: {
          id: user.id,
          email: user.email,
          username: user.username,
          member_weight: parseFloat(user.member_weight),
          created_at: user.created_at
        },
        token
      };
    } catch (error) {
      if (error instanceof AppError) throw error;
      logger.error('Registration error', { error: error.message });
      throw new AppError('Registration failed', 500);
    }
  }

  // Login user
  async login(email, password) {
    try {
      // Find user
      const result = await query(
        'SELECT id, email, username, password_hash, member_weight FROM users WHERE email = $1 AND is_active = true',
        [email]
      );

      if (result.rows.length === 0) {
        throw new AppError('Invalid credentials', 401);
      }

      const user = result.rows[0];

      // Verify password
      const isValidPassword = await bcrypt.compare(password, user.password_hash);
      
      if (!isValidPassword) {
        throw new AppError('Invalid credentials', 401);
      }

      // Update last login
      await query(
        'UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE id = $1',
        [user.id]
      );

      const token = this.generateToken(user);

      logger.info('User logged in', { userId: user.id, email: user.email });

      return {
        user: {
          id: user.id,
          email: user.email,
          username: user.username,
          member_weight: parseFloat(user.member_weight)
        },
        token
      };
    } catch (error) {
      if (error instanceof AppError) throw error;
      logger.error('Login error', { error: error.message });
      throw new AppError('Login failed', 500);
    }
  }

  // Get user profile
  async getProfile(userId) {
    try {
      const result = await query(
        `SELECT id, email, username, member_weight, created_at, last_login 
         FROM users WHERE id = $1 AND is_active = true`,
        [userId]
      );

      if (result.rows.length === 0) {
        throw new AppError('User not found', 404);
      }

      return result.rows[0];
    } catch (error) {
      if (error instanceof AppError) throw error;
      throw new AppError('Failed to fetch profile', 500);
    }
  }
}

module.exports = new AuthService();
