import mongoose from 'mongoose';
import dotenv from 'dotenv';
import User from './src/modules/user/model.js';

dotenv.config();

const seedUser = async () => {
    try {
        await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/garments_erp');

        const email = 'garments@gmail.com';
        const password = 'Admin@123';

        let user = await User.findOne({ email });
        if (user) {
            user.name = 'Admin';
            user.password = password;
            user.isAdmin = true;
            user.isVerified = true;
            await user.save();
            console.log('Admin user updated: garments@gmail.com / Admin@123');
        } else {
            await User.create({
                name: 'Admin',
                email,
                password,
                isAdmin: true,
                role: 'admin',
                isVerified: true,
            });
            console.log('Seed User Created: garments@gmail.com / Admin@123');
        }

        // MD User
        const mdEmail = 'md@garments.com';
        if (!await User.findOne({ email: mdEmail })) {
            await User.create({
                name: 'MD User',
                email: mdEmail,
                password: 'password123',
                isAdmin: false,
                role: 'md',
                isVerified: true,
            });
            console.log('MD User Created: md@garments.com / password123');
        }

        // Lot Incharge User
        const inchargeEmail = 'incharge@garments.com';
        if (!await User.findOne({ email: inchargeEmail })) {
            await User.create({
                name: 'Lot Incharge',
                email: inchargeEmail,
                password: 'password123',
                isAdmin: false,
                role: 'lot_inward',
                isVerified: true,
            });
            console.log('Lot Incharge User Created: incharge@garments.com / password123');
        }

        // Authorized User
        const authorizedEmail = 'authorized@garments.com';
        if (!await User.findOne({ email: authorizedEmail })) {
            await User.create({
                name: 'Authorized Signatory',
                email: authorizedEmail,
                password: 'password123',
                isAdmin: false,
                role: 'authorized',
                isVerified: true,
            });
            console.log('Authorized User Created: authorized@garments.com / password123');
        }

        process.exit(0);
    } catch (error) {
        console.error('Error seeding user:', error);
        process.exit(1);
    }
};

seedUser();
