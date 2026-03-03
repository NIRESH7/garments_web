
import mongoose from 'mongoose';
import dotenv from 'dotenv';
import CuttingOrder from './src/modules/production/cuttingOrderModel.js';

dotenv.config();

async function reset() {
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('Connected to MongoDB');

    const result = await CuttingOrder.updateOne(
        { planId: 'PLN-20260303-0002' },
        {
            $set: {
                'cuttingEntries.$[e].sizeQuantities.85': 7000,
                lotAllocations: []
            }
        },
        { arrayFilters: [{ 'e.itemName': /NIRESH/i }] }
    );

    console.log('Reset Result:', result);
    process.exit(0);
}

reset();
