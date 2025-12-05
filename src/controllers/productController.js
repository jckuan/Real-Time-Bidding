const productService = require('../services/productService');
const AppError = require('../utils/AppError');

class ProductController {
  // GET /api/v1/products
  async getAllProducts(req, res, next) {
    try {
      const { status, page, limit } = req.query;
      const products = await productService.getAllProducts({ status, page, limit });

      res.status(200).json({
        success: true,
        data: {
          products,
          pagination: {
            page: parseInt(page) || 1,
            limit: parseInt(limit) || 10,
            total: products.length
          }
        }
      });
    } catch (error) {
      next(error);
    }
  }

  // GET /api/v1/products/:id
  async getProductById(req, res, next) {
    try {
      const product = await productService.getProductById(req.params.id);

      res.status(200).json({
        success: true,
        data: product
      });
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new ProductController();
