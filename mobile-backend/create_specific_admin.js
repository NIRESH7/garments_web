import mongoose from 'mongoose';
import dotenv from 'dotenv';
import User from './src/modules/user/model.js';

dotenv.config();

const createAdmin1 = async () => {
    try {
        await mongoose.connect(process.env.MONGODB_URI);

        const email = 'admin1@example.com';
        const userExists = await User.findOne({ email });
        if (userExists) {
            userExists.password = 'password123';
            await userExists.save();
            console.log('User admin1@example.com password updated');
        } else {
            await User.create({
                name: 'Admin 1',
                email: email,
                password: 'password123',
                isAdmin: true,
                isVerified: true,
                role: 'admin'
            });
            console.log('User admin1@example.com created');
        }
        process.exit();
    } catch (error) {
        console.error('Error:', error);
        process.exit(1);
    }
};

createAdmin1();
