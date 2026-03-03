import mongoose from 'mongoose';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

dotenv.config();

// Temporary model definition
const cuttingEntrySchema = mongoose.Schema({
    itemName: { type: String, required: true },
    sizeQuantities: {
        type: Map,
        of: Number
    },
    totalDozens: { type: Number, default: 0 },
});

const cuttingOrderSchema = mongoose.Schema({
    planId: String,
    planName: String,
    cuttingEntries: [cuttingEntrySchema],
    lotAllocations: [mongoose.Schema.Types.Mixed]
});

const CuttingOrder = mongoose.model('CuttingOrder', cuttingOrderSchema);

async function checkData() {
    try {
        await mongoose.connect(process.env.MONGODB_URI);
        console.log('Connected to MongoDB');

        const plan = await CuttingOrder.findOne({
            $or: [
                { planName: /csk/i },
                { planId: /csk/i }
            ]
        });

        if (!plan) {
            console.log('Plan "csk" not found');
            process.exit(0);
        }

        console.log('Plan found:', plan.planId, plan.planName);
        console.log('\nCutting Entries:');
        plan.cuttingEntries.forEach(entry => {
            console.log(`- Item: ${entry.itemName}`);
            console.log(`  Total Dozens: ${entry.totalDozens}`);
            console.log(`  Size Quantities:`, JSON.stringify(entry.sizeQuantities));
        });

        await mongoose.disconnect();
    } catch (err) {
        console.error(err);
        process.exit(1);
    }
}

checkData();
