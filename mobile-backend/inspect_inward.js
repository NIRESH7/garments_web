import mongoose from 'mongoose';
import dotenv from 'dotenv';
dotenv.config();

const Inward = mongoose.model('Inward', new mongoose.Schema({}, { strict: false }));

async function inspect() {
    await mongoose.connect(process.env.MONGODB_URI);
    const doc = await Inward.findOne({ lotNo: 'test_1' });
    console.log(JSON.stringify(doc, null, 2));
    process.exit(0);
}

inspect();
