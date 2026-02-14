import asyncHandler from 'express-async-handler';
import User from '../user/model.js';
import generateToken from '../../utils/generateToken.js';

// @desc    Auth user & get token (Login Screen)
// @route   POST /api/auth/login
// @access  Public
const authUser = asyncHandler(async (req, res) => {
    try {
        const { email, password } = req.body;
        console.log('Login attempt with email:', email);
        const user = await User.findOne({ email });
        console.log('User found:', user);

        if (user && (await user.matchPassword(password))) {
            res.json({
                _id: user._id,
                name: user.name,
                email: user.email,
                isAdmin: user.isAdmin,
                role: user.role,
                isVerified: user.isVerified,
                token: generateToken(user._id),
            });
        } else {
            console.log('Password mismatch or user not found');
            res.status(401);
            throw new Error('Invalid email or password');
        }
    } catch (error) {
        console.error('Error in authUser:', error);
        res.status(500);
        throw error;
    }
});

// @desc    Register a new user (Register Screen)
// @route   POST /api/auth/register
// @access  Public
const registerUser = asyncHandler(async (req, res) => {
    const { name, email, password } = req.body;

    const userExists = await User.findOne({ email });

    if (userExists) {
        res.status(400);
        throw new Error('User already exists');
    }

    const user = await User.create({
        name,
        email,
        password,
    });

    if (user) {
        res.status(201).json({
            _id: user._id,
            name: user.name,
            email: user.email,
            isAdmin: user.isAdmin,
            isVerified: user.isVerified,
            token: generateToken(user._id),
        });
    } else {
        res.status(400);
        throw new Error('Invalid user data');
    }
});

// @desc    Verify OTP (OTP Screen)
// @route   POST /api/auth/verify-otp
// @access  Public
const verifyOTP = asyncHandler(async (req, res) => {
    const { email, otp } = req.body;

    // Implementation for OTP verification would go here
    // For demo, we just verify any 6-digit OTP
    if (otp.length === 6) {
        const user = await User.findOne({ email });
        if (user) {
            user.isVerified = true;
            await user.save();
            res.json({ message: 'Email verified successfully', isVerified: true });
        } else {
            res.status(404);
            throw new Error('User not found');
        }
    } else {
        res.status(400);
        throw new Error('Invalid OTP');
    }
});

// @desc    Forgot Password (Forgot Password Screen)
// @route   POST /api/auth/forgot-password
// @access  Public
const forgotPassword = asyncHandler(async (req, res) => {
    const { email } = req.body;
    const user = await User.findOne({ email });

    if (user) {
        // Send reset email logic here
        res.json({ message: 'Password reset link sent to your email' });
    } else {
        res.status(404);
        throw new Error('User not found with this email');
    }
});

export { authUser, registerUser, verifyOTP, forgotPassword };
