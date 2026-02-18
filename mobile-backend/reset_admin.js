import mongoose from 'mongoose';
import dotenv from 'dotenv';
import User from './src/modules/user/model.js';

dotenv.config();

const connectDB = async () => {
    try {
        const conn = await mongoose.connect(process.env.MONGODB_URI);
        console.log(`MongoDB Connected: ${conn.connection.host}`);
    } catch (error) {
        console.error(`Error: ${error.message}`);
        process.exit(1);
    }
};

const resetPassword = async () => {
    try {
        await connectDB();

        const email = 'admin@example.com';
        const newPassword = 'password123';

        const user = await User.findOne({ email });

        if (user) {
            user.password = newPassword; // Will be hashed by pre-save middleware
            await user.save();
            console.log(`Password for ${email} updated to ${newPassword}`);
        } else {
            console.log(`User ${email} not found. Creating it...`);
            await User.create({
                name: 'Admin',
                email: email,
                password: newPassword,
                role: 'admin',
                isAdmin: true,
                isVerified: true,
            });
            console.log(`User ${email} created with password ${newPassword}`);
        }

        process.exit(0);
    } catch (error) {
        console.error(`Error: ${error.message}`);
        process.exit(1);
    }
};

resetPassword();
