import express from 'express';
import { getNotifications, markAsRead, clearAll } from './controller.js';
import { protect } from '../../middleware/authMiddleware.js';

const router = express.Router();

router.route('/').get(protect, getNotifications);
router.route('/clear').put(protect, clearAll);
router.route('/:id').put(protect, markAsRead);

export default router;
