import mongoose from 'mongoose';
import dotenv from 'dotenv';
dotenv.config();

const Inward = mongoose.model('Inward', new mongoose.Schema({}, { strict: false }));

async function inspect() {
    await mongoose.connect(process.env.MONGODB_URI);
    const doc = await Inward.findOne({ 'storageDetails': { $exists: true } });
    console.log(JSON.stringify(doc?.storageDetails, null, 2));
    process.exit(0);
}

inspect();
