import mongoose from 'mongoose';
import dotenv from 'dotenv';
import User from './src/modules/user/model.js';

dotenv.config();

const seedUser = async () => {
    try {
        await mongoose.connect(process.env.MONGO_URI || 'mongodb://localhost:27017/garments_mobile');

        const email = 'garments@gmail.com';
        const password = '123456';

        let user = await User.findOne({ email });
        if (user) {
            user.name = 'Admin';
            user.password = password;
            user.isAdmin = true;
            user.isVerified = true;
            await user.save();
            console.log('Admin user updated: garments@gmail.com / 123456');
        } else {
            await User.create({
                name: 'Admin',
                email,
                password,
                isAdmin: true,
                isVerified: true,
            });
            console.log('Seed User Created: garments@gmail.com / 123456');
        }

        process.exit(0);
    } catch (error) {
        console.error('Error seeding user:', error);
        process.exit(1);
    }
};

seedUser();
