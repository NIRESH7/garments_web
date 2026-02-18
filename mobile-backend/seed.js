import mongoose from 'mongoose';
import dotenv from 'dotenv';
import User from './src/modules/user/model.js';
import Category from './src/modules/master/categoryModel.js';

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

const seedData = async () => {
    try {
        await connectDB();

        // Seed Admin User
        const userExists = await User.findOne({ email: 'garments@gmail.com' });
        if (userExists) {
            userExists.password = 'Admin@123';
            await userExists.save();
            console.log('Admin user password updated');
        } else {
            await User.create({
                name: 'Admin',
                email: 'garments@gmail.com',
                password: 'Admin@123',
                role: 'admin',
                isAdmin: true,
                isVerified: true,
            });
            console.log('Admin user created');
        }

        // Seed Master Categories
        const categories = [
            { name: 'Colours', values: [] },
            { name: 'Dia', values: [] },
            { name: 'Item', values: [] },
            { name: 'Item Name', values: [] },
            { name: 'Lot Name', values: [] },
            { name: 'GSM', values: [] },
            { name: 'Size', values: [] },
            { name: 'Efficiency', values: [] },
            { name: 'Dyeing', values: [] },
            { name: 'Process', values: [] },
            { name: 'Party Name', values: [] },
            { name: 'Rack Name', values: [] },
            { name: 'Pallet No', values: [] },
        ];

        for (const cat of categories) {
            const exists = await Category.findOne({ name: cat.name });
            if (!exists) {
                await Category.create(cat);
                console.log(`Category created: ${cat.name}`);
            }
        }

        process.exit(0);
    } catch (error) {
        console.error(`Error: ${error.message}`);
        process.exit(1);
    }
};

seedData();
