import mongoose from 'mongoose';
import Inward from './src/modules/inventory/inwardModel.js';
import dotenv from 'dotenv';
dotenv.config();

const test = async () => {
    try {
        await mongoose.connect(process.env.MONGODB_URI);
        const inw = await Inward.findOne({ lotNo: '2425/00074' }).lean();
        if (inw) {
            console.log(JSON.stringify(inw.storageDetails, null, 2));
        } else {
            console.log("Not found");
        }
        process.exit(0);
    } catch (err) {
        console.error(err);
        process.exit(1);
    }
};

test();
