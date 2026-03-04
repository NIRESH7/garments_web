import mongoose from 'mongoose';
import dotenv from 'dotenv';
import ItemGroup from './src/modules/master/itemGroupModel.js';
import Category from './src/modules/master/categoryModel.js';

dotenv.config();

async function seed() {
    try {
        await mongoose.connect(process.env.MONGODB_URI);
        console.log('Connected to MongoDB');

        const colors = [
            'FIRE RED',
            'OCEAN BLUE',
            'EMERALD GREEN',
            'SUNSET ORANGE',
            'DEEP PURPLE',
            'LEMON YELLOW',
            'SKY BLUE',
            'NAVY BLUE',
            'CHARCOAL',
            'MAROON'
        ];

        // 1. Update Colours Category
        let colorCat = await Category.findOne({ name: 'Colours' });
        if (!colorCat) {
            colorCat = await Category.create({ name: 'Colours', values: [] });
        }

        for (const color of colors) {
            if (!colorCat.values.find(v => v.name === color)) {
                colorCat.values.push({ name: color, gsm: '160' });
            }
        }
        await colorCat.save();
        console.log(`Updated Colours Category with ${colors.length} colors`);

        // 2. Update Lot Name Category to include "MASTER_FAB"
        let lotNameCat = await Category.findOne({ name: 'Lot Name' });
        if (!lotNameCat) {
            lotNameCat = await Category.create({ name: 'Lot Name', values: [] });
        }
        if (!lotNameCat.values.find(v => v.name === 'MASTER_FAB')) {
            lotNameCat.values.push({ name: 'MASTER_FAB' });
            await lotNameCat.save();
            console.log('Added "MASTER_FAB" to Lot Name Category');
        }

        // 3. Create/Update Item Group with many colors
        const groupName = 'PREMIUM FABRIC';
        const itemName = 'MASTER_FAB';

        await ItemGroup.deleteMany({ groupName });
        await ItemGroup.create({
            groupName: groupName,
            itemNames: [itemName],
            gsm: '165',
            colours: colors,
            rate: 550
        });
        console.log(`Created Item Group "${groupName}" with ${colors.length} colors`);

        console.log('\n--- COLOR SEEDING COMPLETE ---');
        console.log('You can now test Lot Inward with "MASTER_FAB"');
        console.log('------------------------------');

        await mongoose.disconnect();
        process.exit(0);
    } catch (err) {
        console.error('Error during seeding:', err);
        process.exit(1);
    }
}

seed();
