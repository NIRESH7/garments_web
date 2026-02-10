import mongoose from 'mongoose';
import dotenv from 'dotenv';

dotenv.config();

const checkCategories = async () => {
    try {
        await mongoose.connect(process.env.Mongo_URI || 'mongodb://localhost:27017/garments_mobile');
        console.log('Connected to MongoDB');

        // Use a generic schema or define one if you prefer
        const CategorySchema = new mongoose.Schema({ name: String, values: [String] }, { strict: false });
        const Category = mongoose.models.Category || mongoose.model('Category', CategorySchema, 'categories');

        const categories = await Category.find({});
        console.log('--- Categories Found ---');
        categories.forEach(c => {
            console.log(`Name: '${c.name}'`);
            console.log(`Values: ${JSON.stringify(c.values)}`);
            console.log('------------------------');
        });

        process.exit(0);
    } catch (e) {
        console.error(e);
        process.exit(1);
    }
};

checkCategories();
