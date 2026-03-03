import mongoose from 'mongoose';
import dotenv from 'dotenv';
import User from './src/modules/user/model.js';
import CuttingOrder from './src/modules/production/cuttingOrderModel.js';
import Assignment from './src/modules/production/assignmentModel.js';
import Category from './src/modules/master/categoryModel.js';

dotenv.config();

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/garments_erp';

async function seedTestPlan() {
    console.log('🚀 Connecting to MongoDB...');
    await mongoose.connect(MONGODB_URI);

    try {
        const user = await User.findOne({ email: 'admin@example.com' });
        const userId = user ? user._id : new mongoose.Types.ObjectId();

        console.log('🧹 Adding "Test Item" to Categories to prevent Flutter crash...');

        // 1. Ensure "Test Item" is in "Item Name"
        let itemNameCat = await Category.findOne({ name: 'Item Name' });
        if (itemNameCat) {
            if (!itemNameCat.values.some(v => v.name === 'Test Item')) {
                itemNameCat.values.push({ name: 'Test Item' });
                await itemNameCat.save();
                console.log('✅ Added "Test Item" to "Item Name" category');
            }
        }

        // 2. Ensure "100" is in "Size"
        let sizeCat = await Category.findOne({ name: 'Size' });
        if (sizeCat) {
            if (!sizeCat.values.some(v => v.name === '100')) {
                sizeCat.values.push({ name: '100' });
                await sizeCat.save();
                console.log('✅ Added "100" to "Size" category');
            }
        }

        // 3. Ensure "30" is in "Dia"
        let diaCat = await Category.findOne({ name: 'Dia' });
        if (diaCat) {
            if (!diaCat.values.some(v => v.name === '30')) {
                diaCat.values.push({ name: '30' });
                await diaCat.save();
                console.log('✅ Added "30" to "Dia" category');
            }
        }

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

    } catch (err) {
        console.error('❌ SEED ERROR:', err);
    } finally {
        await mongoose.disconnect();
        process.exit(0);
    }
}

seedTestPlan();
