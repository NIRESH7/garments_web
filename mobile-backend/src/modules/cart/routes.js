import express from 'express';
import { getCart, updateCart, clearCart } from './controller.js';
import { protect } from '../../middleware/authMiddleware.js';

const router = express.Router();

router
    .route('/')
    .get(protect, getCart)
    .post(protect, updateCart)
    .delete(protect, clearCart);

export default router;
