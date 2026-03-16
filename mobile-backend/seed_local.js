import mongoose from 'mongoose';
import dotenv from 'dotenv';
import User from './src/modules/user/model.js';
import Category from './src/modules/master/categoryModel.js';
import Party from './src/modules/master/partyModel.js';

dotenv.config();

const seedData = async () => {
    try {
        await mongoose.connect(process.env.MONGODB_URI);
        console.log('Connected to MongoDB for seeding...');

        // 1. Create Admins
        const admins = [
            { name: 'Admin One', email: 'admin@example.com', password: 'password123', isAdmin: true, isVerified: true },
            { name: 'Admin Two', email: 'admin1@example.com', password: 'password123', isAdmin: true, isVerified: true }
        ];

        for (const adminData of admins) {
            const exists = await User.findOne({ email: adminData.email });
            if (!exists) {
                await User.create(adminData);
                console.log(`Created admin: ${adminData.email}`);
            } else {
                console.log(`Admin exists: ${adminData.email}`);
            }
        }

        // 2. Add some Categories (Many details)
        const categories = [
            { name: 'Fabric', description: 'Raw fabric material' },
            { name: 'Threads', description: 'Sewing threads' },
            { name: 'Buttons', description: 'Fastening buttons' },
            { name: 'Zippers', description: 'Fastening zippers' }
        ];

        for (const cat of categories) {
            const exists = await Category.findOne({ name: cat.name });
            if (!exists) {
                await Category.create(cat);
                console.log(`Created category: ${cat.name}`);
            }
        }

        // 3. Add some Parties
        const parties = [
            { 
                name: 'Global Textiles', 
                address: '123 Cotton St, Mumbai',
                mobileNumber: '9876543210',
                process: 'Weaving',
                rate: 50.5
            },
            { 
                name: 'Fashion Retailers Inc', 
                address: '456 Trend Ave, Delhi',
                mobileNumber: '8765432109',
                process: 'Cutting',
                rate: 25.0
            }
        ];

        for (const party of parties) {
            const exists = await Party.findOne({ name: party.name });
            if (!exists) {
                await Party.create(party);
                console.log(`Created party: ${party.name}`);
            }
        }

        console.log('Seeding completed successfully!');
        process.exit();
    } catch (error) {
        console.error('Error seeding database:', error);
        process.exit(1);
    }
};

seedData();
