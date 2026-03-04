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
        const User = mongoose.model('User', new mongoose.Schema({ name: String }));
        let user = await User.findOne();
        if (!user) {
            user = await User.create({ name: 'Admin', email: 'admin@example.com' });
        }
        const userId = user._id;

        const itemName = 'MASTER_FAB';
        const dia = '32'; // Updated to 32 as per user's UI selection

        // 2. Create high-value Inward Lots
        const lot1 = 'LOT-FIFO-HIGH-001';
        const lot2 = 'LOT-FIFO-HIGH-002';

        await inwardModel.deleteMany({ lotNo: { $in: [lot1, lot2] } });

        // Lot 1 (Earlier date) - 5 sets (55 rolls)
        await inwardModel.create({
            user: userId,
            inwardDate: new Date(Date.now() - 24 * 60 * 60 * 1000), // Yesterday
            inTime: '09:00 AM',
            lotName: itemName,
            lotNo: lot1,
            fromParty: 'SUPPLIER A',
            diaEntries: [{
                dia: dia,
                recRoll: 55,
                recWt: 275, // 5kg per roll
                rate: 160
            }],
            storageDetails: {
                dia: dia,
                racks: Array(5).fill('RACK-HIGH-A'),
                pallets: Array(5).fill('P-HIGH-A'),
                rows: [
                    {
                        colour: 'WHITE',
                        setWeights: Array(55).fill(5.0)
                    }
                ]
            }
        });
        console.log('Created High-Value Inward Lot 1:', lot1);

        // Lot 2 (Later date) - 5 sets (55 rolls)
        await inwardModel.create({
            user: userId,
            inwardDate: new Date(), // Today
            inTime: '11:00 AM',
            lotName: itemName,
            lotNo: lot2,
            fromParty: 'SUPPLIER B',
            diaEntries: [{
                dia: dia,
                recRoll: 55,
                recWt: 330, // 6kg per roll
                rate: 165
            }],
            storageDetails: {
                dia: dia,
                racks: Array(5).fill('RACK-HIGH-B'),
                pallets: Array(5).fill('P-HIGH-B'),
                rows: [
                    {
                        colour: 'BLUE',
                        setWeights: Array(55).fill(6.0)
                    }
                ]
            }
        });
        console.log('Created High-Value Inward Lot 2:', lot2);

        // 3. Create a new Cutting Plan with high dozens
        const planId = 'PLAN-FIFO-HIGH-VALUE';
        await cuttingOrderModel.deleteMany({ planId });

        await cuttingOrderModel.create({
            user: userId,
            planId: planId,
            planName: 'HIGH VALUE FIFO TEST PLAN',
            planType: 'Monthly',
            planPeriod: '2026-03',
            date: new Date(),
            startDate: new Date(),
            endDate: new Date(Date.now() + 14 * 24 * 60 * 60 * 1000),
            cuttingEntries: [{
                itemName: itemName,
                sizeQuantities: {
                    '75': 0, '80': 0, '85': 0, '90': 500, '95': 0, '100': 500, '105': 0, '110': 0
                },
                totalDozens: 1000 // High value test
            }],
            lotAllocations: []
        });
        console.log('Created High-Value Cutting Plan:', planId);

        console.log('\n--- SEEDING COMPLETE ---');
        console.log(`Plan: HIGH VALUE FIFO TEST PLAN`);
        console.log(`Item: ${itemName}`);
        console.log(`Dia: ${dia}`);
        console.log(`Total Sets Seeded: 10 Sets (5 in each lot)`);
        console.log('------------------------');

        await mongoose.disconnect();
        process.exit(0);
    } catch (err) {
        console.error('Error during seeding:', err);
        process.exit(1);
    }
}

seed();
