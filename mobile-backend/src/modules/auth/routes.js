import express from 'express';
import {
    authUser,
    registerUser,
    verifyOTP,
    forgotPassword,
} from './controller.js';

const router = express.Router();

router.post('/login', authUser);
router.post('/register', registerUser);
router.post('/verify-otp', verifyOTP);
router.post('/forgot-password', forgotPassword);

export default router;
