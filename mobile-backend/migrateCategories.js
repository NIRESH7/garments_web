import mongoose from 'mongoose';
import dotenv from 'dotenv';
import Category from './src/modules/master/categoryModel.js';

dotenv.config();

const migrateCategories = async () => {
    try {
        await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/garments_erp');

        const categories = await Category.find({});
        console.log(`Found ${categories.length} categories`);

        for (const cat of categories) {
            let updated = false;
            const newValues = cat.values.map(val => {
                if (typeof val === 'string') {
                    updated = true;
                    return { name: val, photo: '', gsm: '' };
                }
                return val;
            });

            if (updated) {
                cat.values = newValues;
                await cat.save();
                console.log(`Migrated category: ${cat.name}`);
            }
        }

        console.log('Migration completed successfully');
        process.exit();
    } catch (error) {
        console.error('Migration failed:', error);
        process.exit(1);
    }
};

migrateCategories();
