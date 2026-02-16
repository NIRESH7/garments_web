import express from 'express';
const router = express.Router();
import { getCompany, updateCompany } from './controller.js';
import { protect } from '../../middleware/authMiddleware.js';
import upload from '../../middleware/uploadMiddleware.js';

router.route('/')
    .get(getCompany)
    .post(protect, upload.single('logo'), updateCompany);

export default router;
