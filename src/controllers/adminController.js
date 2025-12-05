const productService = require('../services/productService');
const AppError = require('../utils/AppError');

class AdminController {
  // POST /api/v1/admin/products
  async createProduct(req, res, next) {
    try {
      const {
        name,
        description,
        base_price,
        initial_inventory,
        max_winners,
        sale_start_time,
        sale_end_time
      } = req.body;

      // Validation
      if (!name || !base_price || !initial_inventory || !max_winners || !sale_start_time || !sale_end_time) {
        throw new AppError('Missing required fields', 400);
      }

      if (initial_inventory < max_winners) {
        throw new AppError('Initial inventory must be >= max winners', 400);
      }

      const product = await productService.createProduct(req.body);

      res.status(201).json({
        success: true,
        data: product
      });
    } catch (error) {
      next(error);
    }
  }

  // PUT /api/v1/admin/products/:id/scoring
  async updateScoring(req, res, next) {
    try {
      const { alpha, beta, gamma } = req.body;

      if (alpha === undefined || beta === undefined || gamma === undefined) {
        throw new AppError('Alpha, beta, and gamma are required', 400);
      }

      if (alpha < 0 || beta < 0 || gamma < 0) {
        throw new AppError('Parameters must be non-negative', 400);
      }

      const result = await productService.updateScoringParameters(
        req.params.id,
        { alpha, beta, gamma }
      );

      res.status(200).json({
        success: true,
        data: result
      });
    } catch (error) {
      next(error);
    }
  }

  // POST /api/v1/admin/products/:id/activate
  async activateSale(req, res, next) {
    try {
      const product = await productService.activateSale(req.params.id);

      res.status(200).json({
        success: true,
        data: product
      });
    } catch (error) {
      next(error);
    }
  }

  // POST /api/v1/admin/products/:id/end
  async endSale(req, res, next) {
    try {
      const product = await productService.endSale(req.params.id);

      res.status(200).json({
        success: true,
        data: product
      });
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new AdminController();
