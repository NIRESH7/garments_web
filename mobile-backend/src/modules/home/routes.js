import express from 'express';
import { getHomeData, getSplashConfig } from './controller.js';
import { protect } from '../../middleware/authMiddleware.js';

const router = express.Router();

router.get('/', protect, getHomeData);
router.get('/splash', getSplashConfig);

export default router;
