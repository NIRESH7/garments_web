import mongoose from 'mongoose';
import dotenv from 'dotenv';

dotenv.config();

const checkItemGroups = async () => {
    try {
        await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/garments_mobile');
        console.log('Connected to MongoDB');

        const ItemGroup = mongoose.model('ItemGroup', new mongoose.Schema({}, { strict: false }), 'itemgroups');

        const groups = await ItemGroup.find({});
        console.log('--- Item Groups Found ---');
        groups.forEach(g => {
            console.log(`Name: '${g.groupName}', GSM: '${g.gsm}', Rate: '${g.rate}'`);
        });

        process.exit(0);
    } catch (e) {
        console.error(e);
        process.exit(1);
    }
};

checkItemGroups();
