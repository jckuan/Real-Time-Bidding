const express = require('express');
const adminController = require('../controllers/adminController');
const authMiddleware = require('../middleware/auth');
const adminAuth = require('../middleware/adminAuth');

const router = express.Router();

// All admin routes require authentication AND admin role
router.use(authMiddleware);
router.use(adminAuth);

// Product management
router.post('/products', adminController.createProduct.bind(adminController));
router.put('/products/:id/scoring', adminController.updateScoring.bind(adminController));
router.post('/products/:id/activate', adminController.activateSale.bind(adminController));
router.post('/products/:id/end', adminController.endSale.bind(adminController));

// Scoring parameters
router.get('/scoring-parameters', adminController.getScoringParameters.bind(adminController));

module.exports = router;
