import mongoose from 'mongoose';
import dotenv from 'dotenv';
import User from './src/modules/user/model.js';

dotenv.config();

const seedUser = async () => {
    try {
        await mongoose.connect(process.env.MONGO_URI || 'mongodb://localhost:27017/garments_mobile');

        await User.create({
            name: 'Admin',
            email: 'garments@gmail.com',
            password: 'Admin@123',
            isAdmin: true,
            isVerified: true
        });

        console.log('Seed User Created: garments@gmail.com / Admin@123');
        process.exit(0);
    } catch (error) {
        console.error('Error seeding user:', error);
        process.exit(1);
    }
};

seedUser();
