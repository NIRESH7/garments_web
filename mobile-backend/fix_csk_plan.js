import mongoose from 'mongoose';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

dotenv.config();

const cuttingEntrySchema = mongoose.Schema({
    itemName: { type: String, required: true },
    sizeQuantities: { type: Map, of: Number },
    totalDozens: { type: Number, default: 0 },
});

const cuttingOrderSchema = mongoose.Schema({
    planId: String,
    planName: String,
    cuttingEntries: [cuttingEntrySchema],
});

const CuttingOrder = mongoose.model('CuttingOrder', cuttingOrderSchema);

async function fixData() {
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

        console.log('Fixing plan:', plan.planId);

        for (const entry of plan.cuttingEntries) {
            console.log(`Resetting item: ${entry.itemName}`);
            const sizes = ['75', '80', '85', '90', '95', '100', '105', '110'];
            let total = 0;
            sizes.forEach(s => {
                entry.sizeQuantities.set(s, 300);
                total += 300;
            });
            entry.totalDozens = total;
        }

        await plan.save();
        console.log('Plan "csk" reset to 300 dozen per size successfully.');

        await mongoose.disconnect();
    } catch (err) {
        console.error(err);
        process.exit(1);
    }
}

fixData();
