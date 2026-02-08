import express from 'express';
import { updateOrderToPaid, getPaymentConfig } from './controller.js';
import { protect } from '../../middleware/authMiddleware.js';

const router = express.Router();

router.route('/config').get(protect, getPaymentConfig);
router.route('/:id/pay').put(protect, updateOrderToPaid);

export default router;
