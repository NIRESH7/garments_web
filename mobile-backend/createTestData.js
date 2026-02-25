
import mongoose from 'mongoose';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

dotenv.config({ path: path.join(__dirname, '.env') });

import User from './src/modules/user/model.js';
import CuttingOrder from './src/modules/production/cuttingOrderModel.js';
import Inward from './src/modules/inventory/inwardModel.js';

async function seed() {
    try {
        await mongoose.connect(process.env.MONGODB_URI);
        console.log('Connected to MongoDB');

        // 1. Get a user
        let user = await User.findOne();
        if (!user) {
            user = await User.create({
                name: 'Test User',
                email: 'test@example.com',
                password: 'password123',
                role: 'admin'
            });
            console.log('Created test user');
        }

        const itemName = 'Test Item';
        const size = '6';
        const dia = '4';

        // 2. Clear old test data
        await CuttingOrder.deleteMany({ planId: 'TEST-PLAN-FLOW' });
        await Inward.deleteMany({ lotNo: 'TEST-LOT-FIFO' });

        // 3. Create CuttingOrder (Plan)
        // Note: sizeQuantities is an object in the schema
        const plan = await CuttingOrder.create({
            user: user._id,
            planId: 'TEST-PLAN-FLOW',
            planType: 'Monthly',
            planPeriod: '2026-02',
            date: new Date(),
            cuttingEntries: [{
                itemName: itemName,
                sizeQuantities: {
                    [size]: 100
                },
                totalDozens: 100
            }]
        });
        console.log('Created CuttingOrder with 100 dozen');

        // 4. Create Inward (Stock)
        await Inward.create({
            user: user._id,
            inwardDate: new Date(),
            inTime: '10:00 AM',
            lotName: 'Test Fabric',
            lotNo: 'TEST-LOT-FIFO',
            fromParty: 'Test Supplier',
            diaEntries: [{
                dia: dia,
                roll: 50,
                sets: 5,
                recRoll: 50,
                recWt: 500, // Enough for 100 dozen (100 * 3kg = 300kg)
                rate: 100
            }],
            storageDetails: [
                {
                    dia: dia,
                    racks: ['R-1'],
                    pallets: ['P-1']
                }
            ]
        });
        console.log('Created Inward stock (500 KG)');

        process.exit(0);
    } catch (error) {
        console.error('Error seeding data:', error);
        process.exit(1);
    }
}

seed();
