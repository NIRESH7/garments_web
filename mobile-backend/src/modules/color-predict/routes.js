import express from 'express';
const router = express.Router();
import { predictColor, detectColorFromImage } from './controller.js';
import { protect } from '../../middleware/authMiddleware.js';

// POST /api/color-predict
router.post('/', protect, predictColor);

// POST /api/color-predict/from-image
router.post('/from-image', protect, detectColorFromImage);

export default router;
