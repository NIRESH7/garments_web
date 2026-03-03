import mongoose from 'mongoose';
import dotenv from 'dotenv';
import User from './src/modules/user/model.js';
import CuttingOrder from './src/modules/production/cuttingOrderModel.js';
import Assignment from './src/modules/production/assignmentModel.js';

dotenv.config();

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/garments_erp';

async function seedTestPlan() {
    console.log('🚀 Connecting to MongoDB...');
    await mongoose.connect(MONGODB_URI);

    try {
        const user = await User.findOne({ email: 'admin@example.com' });
        const userId = user ? user._id : new mongoose.Types.ObjectId();

        console.log('🧹 Clearing old test plans and assignments...');
        await CuttingOrder.deleteMany({ planName: 'Test Calculation Plan' });
        await Assignment.deleteMany({ fabricItem: 'Test Item' });

        console.log('📝 Creating test Assignment...');
        await Assignment.create({
            user: userId,
            fabricItem: 'Test Item',
            size: '100',
            dia: '30',
            dozenWeight: 15.00, // 15kg per dozen
            foldingWt: 0.0,
            efficiency: 90,
            wastePercentage: 10,
            layLength: 5,
            layPcs: 10
        });

        console.log('📐 Creating test Cutting Order (Plan)...');
        await CuttingOrder.create({
            user: userId,
            planId: `PLAN-TEST-${Date.now()}`,
            planName: 'Test Calculation Plan',
            planType: 'Monthly',
            planPeriod: '2026-03',
            date: new Date(),
            cuttingEntries: [
                {
                    itemName: 'Test Item',
                    sizeQuantities: {
                        '75': 0,
                        '80': 0,
                        '85': 0,
                        '90': 0,
                        '95': 0,
                        '100': 130, // 130 dozens
                        '105': 0,
                        '110': 0
                    },
                    totalDozens: 130
                }
            ]
        });

        console.log('✅ Test Plan Seeded Successfully!');
        console.log('--------------------------------------------------');
        console.log('Go to "Lot Requirement Allocation" screen');
        console.log('Select Plan: Test Calculation Plan');
        console.log('Item: Test Item | Size: 100');
        console.log('Dozen: 130');
        console.log('Calculation should show:');
        console.log('- Required Wt: 130 * 15 = 1950.00 KG');
        console.log('- Rolls Needed (Wt / 20): 1950 / 20 = 97.5 (~98 Rolls)');
        console.log('- Sets Required (Rolls / 11): 98 / 11 = 8.9 (~9 Sets)');
        console.log('--------------------------------------------------');

    } catch (err) {
        console.error('❌ SEED ERROR:', err);
    } finally {
        await mongoose.disconnect();
        process.exit(0);
    }
}

seedTestPlan();
