const express = require('express');
const adminController = require('../controllers/adminController');
const authMiddleware = require('../middleware/auth');

const router = express.Router();

// All admin routes require authentication
router.use(authMiddleware);

// Product management
router.post('/products', adminController.createProduct.bind(adminController));
router.put('/products/:id/scoring', adminController.updateScoring.bind(adminController));
router.post('/products/:id/activate', adminController.activateSale.bind(adminController));
router.post('/products/:id/end', adminController.endSale.bind(adminController));

module.exports = router;
