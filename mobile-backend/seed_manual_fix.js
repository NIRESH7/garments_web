import mongoose from 'mongoose';
import dotenv from 'dotenv';
import inwardModel from './src/modules/inventory/inwardModel.js';
import cuttingOrderModel from './src/modules/production/cuttingOrderModel.js';

dotenv.config();

async function seed() {
    try {
        await mongoose.connect(process.env.MONGODB_URI);
        console.log('Connected to MongoDB');

        // 1. Find or Create a User
        const User = mongoose.model('User', new mongoose.Schema({ name: String, email: String }));
        let user = await User.findOne();
        if (!user) {
            user = await User.create({ name: 'Admin', email: 'admin@example.com' });
        }
        const userId = user._id;

        const itemName = 'MASTER_FAB';
        const dia = '32';
        const size = '90';

        // 2. Create Inward Lot with only 1 rack/pallet for multiple sets
        const lotNo = 'LOT-MANUAL-FIX-001';
        await inwardModel.deleteMany({ lotNo });

        // 5 sets (55 rolls)
        await inwardModel.create({
            user: userId,
            inwardDate: new Date(),
            inTime: '10:00 AM',
            lotName: itemName,
            lotNo: lotNo,
            fromParty: 'TEST SUPPLIER',
            diaEntries: [{
                dia: dia,
                recRoll: 55,
                recWt: 1100, // 20kg per roll
                rate: 100
            }],
            storageDetails: {
                dia: dia,
                racks: ['RACK-FIXED-A'], // Only ONE rack
                pallets: ['P-FIXED-A'],  // Only ONE pallet
                rows: [
                    {
                        colour: 'GREY',
                        setWeights: Array(55).fill(20.0)
                    }
                ]
            }
        });
        console.log('Created Manual Test Inward Lot:', lotNo);

        // 3. Create a new Cutting Plan
        const planId = 'PLAN-MANUAL-VERIFY';
        await cuttingOrderModel.deleteMany({ planId });

        await cuttingOrderModel.create({
            user: userId,
            planId: planId,
            planName: 'MANUAL VERIFICATION PLAN',
            planType: 'Monthly',
            planPeriod: '2026-03',
            date: new Date(),
            startDate: new Date(),
            endDate: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
            cuttingEntries: [{
                itemName: itemName,
                sizeQuantities: {
                    [size]: 1000
                },
                totalDozens: 1000
            }],
            lotAllocations: []
        });
        console.log('Created Manual Test Cutting Plan:', planId);

        console.log('\n--- MANUAL TEST SEEDING COMPLETE ---');
        console.log(`Plan: MANUAL VERIFICATION PLAN`);
        console.log(`Item: ${itemName}`);
        console.log(`Size: ${size}`);
        console.log(`Dia: ${dia}`);
        console.log(`Total Sets Seeded: 5 Sets`);
        console.log('-----------------------------------');

        await mongoose.disconnect();
        process.exit(0);
    } catch (err) {
        console.error('Error during seeding:', err);
        process.exit(1);
    }
}

seed();
