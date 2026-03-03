
import mongoose from 'mongoose';
import dotenv from 'dotenv';
import CuttingOrder from './src/modules/production/cuttingOrderModel.js';

dotenv.config();

async function check() {
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('Connected to MongoDB');

    const plan = await CuttingOrder.findOne({ planId: 'PLN-20260303-0002' });
    if (!plan) {
        console.log('Plan NIRESH_1 not found. Checking all plans...');
        const all = await CuttingOrder.find({});
        all.forEach(p => console.log(`Plan ID: ${p.planId}, Name: ${p.planName}`));
        process.exit(0);
    }

    console.log('--- Plan Details ---');
    console.log('Plan ID:', plan.planId);
    console.log('Cutting Entries (Source):');
    plan.cuttingEntries.forEach(e => {
        if (e.itemName.toLowerCase().includes('niresh')) {
            console.log(`  Item: ${e.itemName}, Sizes:`, e.sizeQuantities);
        }
    });

    console.log('Lot Allocations (Saved):');
    let totalSaved = 0;
    plan.lotAllocations.forEach(a => {
        if (a.itemName.toLowerCase().includes('niresh') && a.size === '85') {
            console.log(`  Alloc: ${a.dozen} doz on ${a.day}`);
            totalSaved += a.dozen;
        }
    });
    console.log('Total saved for NIRESH / 85:', totalSaved);

    process.exit(0);
}

check();
