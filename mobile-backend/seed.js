import mongoose from 'mongoose';
import dotenv from 'dotenv';
import User from './src/modules/user/model.js';

dotenv.config();

const seedUser = async () => {
    try {
        await mongoose.connect(process.env.MONGO_URI || 'mongodb://localhost:27017/garments_mobile');

        const userExists = await User.findOne({ email: 'admin@example.com' });
        if (userExists) {
            console.log('User already exists');
            process.exit(0);
        }

        await User.create({
            name: 'Sudha',
            email: 'admin@example.com',
            password: 'password123',
            isAdmin: true,
            isVerified: true
        });

        console.log('Seed User Created: admin@example.com / password123');
        process.exit(0);
    } catch (error) {
        console.error('Error seeding user:', error);
        process.exit(1);
    }
};

seedUser();
