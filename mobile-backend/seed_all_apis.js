import mongoose from 'mongoose';
import dotenv from 'dotenv';
import User from './src/modules/user/model.js';
import Category from './src/modules/master/categoryModel.js';
import Party from './src/modules/master/partyModel.js';
import ItemGroup from './src/modules/master/itemGroupModel.js';
import Lot from './src/modules/master/lotModel.js';
import StockLimit from './src/modules/master/stockLimitModel.js';
import Inward from './src/modules/inventory/inwardModel.js';
import Outward from './src/modules/inventory/outwardModel.js';
import Task from './src/modules/task/taskModel.js';
import Assignment from './src/modules/production/assignmentModel.js';
import CuttingOrder from './src/modules/production/cuttingOrderModel.js';

dotenv.config();

const seedData = async () => {
    try {
        await mongoose.connect(process.env.MONGODB_URI);
        console.log(`Connected to MongoDB [${mongoose.connection.name}] for comprehensive seeding...`);

        // 1. Users
        const admins = [
            { name: 'Admin One', email: 'admin@example.com', password: 'password123', isAdmin: true, isVerified: true, role: 'admin' },
            { name: 'Admin Two', email: 'admin1@example.com', password: 'password123', isAdmin: true, isVerified: true, role: 'admin' }
        ];

        let adminUser;
        for (const adminData of admins) {
            let user = await User.findOne({ email: adminData.email });
            if (!user) {
                user = await User.create(adminData);
                console.log(`Created admin: ${adminData.email}`);
            } else {
                user.password = adminData.password;
                user.isAdmin = true;
                user.role = 'admin';
                await user.save();
            }
            if (adminData.email === 'admin@example.com') adminUser = user;
        }

        // 2. Categories
        const categories = [
            { name: 'Fabric', description: 'Raw material' },
            { name: 'Threads', description: 'Sewing threads' }
        ];
        for (const cat of categories) {
            if (!await Category.findOne({ name: cat.name })) await Category.create(cat);
        }

        // 3. Parties
        const parties = [
            { name: 'Global Textiles', address: 'Mumbai', mobileNumber: '9876543210', process: 'Weaving', rate: 50 },
            { name: 'Sark Fabrics', address: 'Surat', mobileNumber: '9123456789', process: 'Dyeing', rate: 30 }
        ];
        for (const p of parties) {
            if (!await Party.findOne({ name: p.name })) await Party.create(p);
        }

        // 4. Item Groups
        const itemGroups = [
            { groupName: 'Cotton Sinker', itemNames: ['Body', 'Rib'], gsm: '160', colours: ['White', 'Black'], rate: 450 }
        ];
        for (const ig of itemGroups) {
            if (!await ItemGroup.findOne({ groupName: ig.groupName })) await ItemGroup.create(ig);
        }

        // 5. Lots
        await Lot.findOneAndUpdate(
            { lotNumber: 'LOT-001' },
            { partyName: 'Global Textiles', process: 'Weaving', remarks: 'High priority' },
            { upsert: true }
        );

        // 6. Stock Limits
        await StockLimit.findOneAndUpdate(
            { lotName: 'LOT-001', dia: '24' },
            { minWeight: 50, maxWeight: 500, minRolls: 5, maxRolls: 50 },
            { upsert: true }
        );

        // 7. Inward
        let inward = await Inward.findOne({ lotNo: 'LOT-001' });
        if (!inward) {
            inward = await Inward.create({
                user: adminUser._id,
                inwardDate: new Date(),
                inTime: '09:00 AM',
                lotName: 'Global Lot',
                lotNo: 'LOT-001',
                inwardNo: 'INW-001',
                fromParty: 'Global Textiles',
                process: 'Weaving',
                rate: 50,
                gsm: '160',
                diaEntries: [{ dia: '24', roll: 20, sets: 2, delivWt: 400, recRoll: 20, recWt: 400, rate: 50 }]
            });
            console.log('Created Inward');
        }

        // 8. Outward
        if (!await Outward.findOne({ dcNo: 'DC-001' })) {
            await Outward.create({
                user: adminUser._id,
                dcNo: 'DC-001',
                lotName: 'Global Lot',
                dateTime: new Date(),
                dia: '24',
                lotNo: 'LOT-001',
                partyName: 'Fashion Apparels',
                process: 'Cutting',
                items: [{ set_no: 'SET-1', total_weight: 100, colours: [{ colour: 'White', weight: 100, no_of_rolls: 5 }] }]
            });
            console.log('Created Outward');
        }

        // 9. Tasks
        if (!await Task.findOne({ title: 'Check Fabric Quality' })) {
            await Task.create({
                admin: adminUser._id,
                title: 'Check Fabric Quality',
                description: 'Please verify the latest lot from Global Textiles',
                priority: 'High',
                status: 'To Do'
            });
            console.log('Created Task');
        }

        // 10. Production Assignment
        if (!await Assignment.findOne({ fabricItem: 'Cotton Sinker' })) {
            await Assignment.create({
                user: adminUser._id,
                fabricItem: 'Cotton Sinker',
                size: 'M',
                dia: '24',
                lotName: 'LOT-001',
                efficiency: 85,
                dozenWeight: 2.5,
                layLength: 5.0,
                layPcs: 40,
                wastePercentage: 2
            });
            console.log('Created Assignment');
        }

        // 11. Cutting Order (Plan)
        if (!await CuttingOrder.findOne({ planId: 'PLAN-2026-03' })) {
            await CuttingOrder.create({
                user: adminUser._id,
                planId: 'PLAN-2026-03',
                planName: 'March 2026 Production',
                planType: 'Monthly',
                planPeriod: '2026-03',
                date: new Date(),
                cuttingEntries: [{ itemName: 'Polo Shirt', totalDozens: 100 }]
            });
            console.log('Created Cutting Order');
        }

        console.log('COMPREHENSIVE SEEDING COMPLETED!');
        process.exit();
    } catch (error) {
        console.error('Error seeding database:', error);
        process.exit(1);
    }
};

seedData();
