import mongoose from 'mongoose';
import dotenv from 'dotenv';
import User from './src/modules/user/model.js';

dotenv.config();

const createAdmin = async () => {
    try {
        await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/garments_erp');

        const userExists = await User.findOne({ email: 'admin@example.com' });
        if (userExists) {
            userExists.password = 'password123';
            await userExists.save();
            console.log('Admin user password updated');
            process.exit();
        }

        const admin = await User.create({
            name: 'Admin User',
            email: 'admin@example.com',
            password: 'password123',
            isAdmin: true,
            isVerified: true
        });

        console.log('Admin User Created:', admin.email);
        process.exit();
    } catch (error) {
        console.error('Error creating admin:', error);
        process.exit(1);
    }
};

createAdmin();
