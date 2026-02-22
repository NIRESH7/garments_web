import express from 'express';
import {
    authUser,
    registerUser,
    verifyOTP,
    forgotPassword,
    createAdmin,
} from './controller.js';

const router = express.Router();

router.post('/login', authUser);
router.post('/register', registerUser);
router.post('/verify-otp', verifyOTP);
router.post('/forgot-password', forgotPassword);
router.post('/create-admin', createAdmin);

export default router;
