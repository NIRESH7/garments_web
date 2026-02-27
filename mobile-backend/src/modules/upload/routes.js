import express from 'express';
import upload from '../../middleware/uploadMiddleware.js';

const router = express.Router();

router.post('/', upload.single('image'), (req, res) => {
    // If uploaded to S3, req.file.location will contain the S3 URL
    // Otherwise, use req.file.path for local storage
    const filePath = req.file.location || `/${req.file.path.replace(/\\/g, '/')}`;
    res.send(filePath);
});

export default router;
