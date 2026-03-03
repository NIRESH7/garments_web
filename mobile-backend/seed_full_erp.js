import mongoose from 'mongoose';
import dotenv from 'dotenv';
import Inward from './src/modules/inventory/inwardModel.js';
import Outward from './src/modules/inventory/outwardModel.js';
import Party from './src/modules/master/partyModel.js';
import ItemGroup from './src/modules/master/itemGroupModel.js';
import User from './src/modules/user/model.js';
import Task from './src/modules/task/taskModel.js';
import CuttingOrder from './src/modules/production/cuttingOrderModel.js';

dotenv.config();

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/garments_erp';

async function seedChatbotData() {
    try {
        await mongoose.connect(MONGODB_URI);
        console.log('Connected to Local MongoDB');

        // 1. Clear existing data
        await Inward.deleteMany({});
        await Outward.deleteMany({});
        await Party.deleteMany({});
        await ItemGroup.deleteMany({});
        await Task.deleteMany({});
        await CuttingOrder.deleteMany({});
        console.log('Cleared existing data');

        // 2. Get/Create a user
        let user = await User.findOne({ email: 'admin@garments.com' });
        if (!user) {
            user = await User.create({
                name: 'Admin',
                email: 'admin@garments.com',
                password: 'password123',
                role: 'admin'
            });
        }

        // 3. Create Parties
        const parties = await Party.insertMany([
            { name: 'SRI BALAJI TEX', mobileNumber: '9842711111', process: 'Supplier', address: 'Tirupur', rate: 10 },
            { name: 'SKV KNITTING', mobileNumber: '9842722222', process: 'Knitting', address: 'Avinashi', rate: 15 },
            { name: 'VELAN PRINTING', mobileNumber: '9842733333', process: 'Printing', address: 'Tirupur', rate: 20 },
            { name: 'JAYAM DYEING', mobileNumber: '9842744444', process: 'Dyeing', address: 'Perundurai', rate: 25 },
            { name: 'GLOBAL EXPORTS', mobileNumber: '9842755555', process: 'Customer', address: 'Chennai', rate: 0 }
        ]);
        console.log('Seeded Parties');

        // 4. Create Item Groups
        const itemGroups = await ItemGroup.insertMany([
            {
                groupName: 'SINKER FABRIC',
                itemNames: ['30s Sinker', '40s Sinker', '20s Sinker'],
                colours: ['Royal Blue', 'Deep White', 'Jet Black', 'Golden Yellow'],
                gsm: '160',
                rate: 350
            },
            {
                groupName: 'INTERLOCK',
                itemNames: ['Cotton Interlock', 'Poly Interlock'],
                colours: ['Sky Blue', 'Light Green', 'Rose', 'Grey'],
                gsm: '220',
                rate: 450
            },
            {
                groupName: 'RIB FABRIC',
                itemNames: ['1x1 Rib', '2x1 Rib'],
                colours: ['Navy Blue', 'Maroon', 'Charcoal'],
                gsm: '240',
                rate: 400
            }
        ]);
        console.log('Seeded Item Groups');

        // 5. Create Inwards (20+ entries)
        const inwards = [];
        const lots = ['LOT-201', 'LOT-202', 'LOT-203', 'LOT-204', 'LOT-205'];
        const dias = ['20', '22', '24', '26', '30'];
        const colors = ['Royal Blue', 'Deep White', 'Jet Black', 'Sky Blue', 'Navy Blue'];

        for (let i = 1; i <= 25; i++) {
            const lot = lots[i % lots.length];
            const dia = dias[i % dias.length];
            const color = colors[i % colors.length];
            const party = parties[i % parties.length].name;

            inwards.push({
                user: user._id,
                inwardDate: new Date(2025, 1, i),
                inTime: '10:00 AM',
                lotName: itemGroups[i % itemGroups.length].groupName,
                lotNo: `${lot}-${i}`,
                inwardNo: `INW-202502${i.toString().padStart(2, '0')}-001`,
                fromParty: party,
                rate: 150 + i,
                diaEntries: [{
                    dia: dia,
                    roll: 10 + i,
                    recRoll: 10 + i,
                    recWt: 50 + (i * 2),
                    rate: 150 + i
                }]
            });
        }
        await Inward.insertMany(inwards);
        console.log('Seeded 25 Inward entries');

        // 6. Create Outwards (15 entries)
        const outwards = [];
        for (let i = 1; i <= 15; i++) {
            const lot = lots[i % lots.length];
            const dia = dias[i % dias.length];
            const color = colors[i % colors.length];
            const party = parties[i % parties.length].name;

            outwards.push({
                user: user._id,
                dcNo: `DC-202503${i.toString().padStart(2, '0')}-001`,
                lotName: itemGroups[i % itemGroups.length].groupName,
                dateTime: new Date(),
                dia: dia,
                lotNo: `${lot}-${i}`,
                partyName: party,
                process: 'Outward',
                items: [{
                    set_no: `SET-${i}`,
                    colours: [{
                        colour: color,
                        weight: 20 + i,
                        no_of_rolls: 2,
                        roll_weight: 10 + (i / 2)
                    }],
                    total_weight: 20 + i
                }]
            });
        }
        await Outward.insertMany(outwards);
        console.log('Seeded 15 Outward entries');

        // 7. Create Tasks (5 entries)
        await Task.insertMany([
            { admin: user._id, title: 'Check Quality in LOT-201', description: 'Ensure GSM is 160+', priority: 'High', status: 'To Do' },
            { admin: user._id, title: 'Inward for Balaji Tex', description: 'EXPECTED BY EVENING', priority: 'Medium', status: 'In Progress' },
            { admin: user._id, title: 'Verify Washing Status', status: 'Completed', priority: 'Low' },
            { admin: user._id, title: 'Send Samples to Global', priority: 'High', status: 'To Do' }
        ]);
        console.log('Seeded Tasks');

        // 8. Create Cutting Plans with Rack Info
        await CuttingOrder.insertMany([
            {
                user: user._id,
                planId: 'PLAN-001',
                planName: 'Summer T-Shirt Collection',
                planType: 'Monthly',
                planPeriod: '2026-03',
                date: new Date(),
                lotAllocations: [
                    { itemName: '30s Sinker', size: 'M', dozen: 100, rackName: 'RACK-A1', palletNumber: 'P-10' },
                    { itemName: '30s Sinker', size: 'L', dozen: 150, rackName: 'RACK-A2', palletNumber: 'P-11' }
                ]
            },
            {
                user: user._id,
                planId: 'PLAN-002',
                planName: 'Winter Hoodie Batch',
                planType: 'Monthly',
                planPeriod: '2026-04',
                date: new Date(),
                lotAllocations: [
                    { itemName: 'Cotton Interlock', size: 'XL', dozen: 50, rackName: 'RACK-B5', palletNumber: 'P-22' }
                ]
            }
        ]);
        console.log('Seeded Cutting Plans and Racks');

        console.log('\n--- Seeding Completed Successfully ---');
        console.log(`Summary:`);
        console.log(`- Item Groups: ${itemGroups.length}`);
        console.log(`- Parties: ${parties.length}`);
        console.log(`- Inwards: ${inwards.length}`);
        console.log(`- Outwards: ${outwards.length}`);

        process.exit(0);
    } catch (err) {
        console.error('Seeding Error:', err);
        process.exit(1);
    }
}

seedChatbotData();
