const authService = require('../services/authService');
const AppError = require('../utils/AppError');

class AuthController {
  // POST /api/v1/auth/register
  async register(req, res, next) {
    try {
      const { email, password, username } = req.body;

      // Validation
      if (!email || !password || !username) {
        throw new AppError('Email, password, and username are required', 400);
      }

      if (password.length < 6) {
        throw new AppError('Password must be at least 6 characters', 400);
      }

      const result = await authService.register(email, password, username);

      res.status(201).json({
        success: true,
        data: result
      });
    } catch (error) {
      next(error);
    }
  }

  // POST /api/v1/auth/login
  async login(req, res, next) {
    try {
      const { email, password } = req.body;

      if (!email || !password) {
        throw new AppError('Email and password are required', 400);
      }

      const result = await authService.login(email, password);

      res.status(200).json({
        success: true,
        data: result
      });
    } catch (error) {
      next(error);
    }
  }

  // GET /api/v1/auth/me
  async getMe(req, res, next) {
    try {
      const profile = await authService.getProfile(req.user.id);

      res.status(200).json({
        success: true,
        data: profile
      });
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new AuthController();
