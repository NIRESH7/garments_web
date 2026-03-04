import express from 'express';
import multer from 'multer';
import { protect } from '../../middleware/authMiddleware.js';
import { chatWithAI, transcribeAudio } from './controller.js';

const router = express.Router();
const uploadMemory = multer({ storage: multer.memoryStorage() });

router.post('/chat', protect, chatWithAI);
router.post('/transcribe', protect, uploadMemory.single('audio'), transcribeAudio);

export default router;
