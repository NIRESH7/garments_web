
import mongoose from 'mongoose';
import dotenv from 'dotenv';
import ItemGroup from './src/modules/master/itemGroupModel.js';
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

const debugShadeCard = async () => {
    await connectDB();

    console.log('--- Checking Item Groups ---');
    const groups = await ItemGroup.find({});
    console.log(`Total Item Groups: ${groups.length}`);
    if (groups.length > 0) {
        console.log(JSON.stringify(groups, null, 2));
    } else {
        console.log("NO ITEM GROUPS FOUND!");
    }

    console.log('\n--- Checking Categories (for Colour) ---');
    const categories = await Category.find({});
    const colourCat = categories.find(c => c.name.toLowerCase().includes('colour'));
    if (colourCat) {
        console.log(`Found Colour Category: ${colourCat.name}`);
        console.log(`Values count: ${colourCat.values.length}`);
    } else {
        console.log("COLOUR CATEGORY NOT FOUND");
    }

    console.log('\n--- Simulating Report Logic ---');
    const colorValues = colourCat ? colourCat.values : [];
    const report = groups.map(group => {
        const enrichedColours = (group.colours || []).map(colourName => {
            const detail = colorValues.find(v => v.name.toLowerCase() === colourName.toLowerCase());
            return {
                name: colourName,
                gsm: (detail && detail.gsm) ? detail.gsm : group.gsm,
                photo: detail ? detail.photo : null
            };
        });
        return {
            groupName: group.groupName,
            items: group.itemNames,
            gsm: group.gsm,
            colours: enrichedColours
        };
    });
    console.log(JSON.stringify(report, null, 2));

    process.exit();
};

debugShadeCard();
