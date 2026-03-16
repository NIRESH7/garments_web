import mongoose from 'mongoose';
import dotenv from 'dotenv';
import User from './src/modules/user/model.js';
import Category from './src/modules/master/categoryModel.js';
import Party from './src/modules/master/partyModel.js';
import ItemGroup from './src/modules/master/itemGroupModel.js';
import Lot from './src/modules/master/lotModel.js';
import Inward from './src/modules/inventory/inwardModel.js';

dotenv.config();

const seedData = async () => {
    try {
        await mongoose.connect(process.env.MONGODB_URI);
        console.log(`Connected to MongoDB [${mongoose.connection.name}] for seeding...`);

        // 1. Create Admins
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
                console.log(`Admin exists: ${adminData.email}`);
                // Ensure password is correct and isAdmin is true
                user.password = adminData.password;
                user.isAdmin = true;
                user.role = 'admin';
                await user.save();
            }
            if (adminData.email === 'admin@example.com') adminUser = user;
        }

        // 2. Categories
        const categories = [
            { name: 'Fabric', description: 'Raw cotton and synthetic fabric' },
            { name: 'Threads', description: 'Polyester and cotton threads' },
            { name: 'Buttons', description: 'Plastic and metal buttons' }
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
            { groupName: 'Cotton Sinker', itemNames: ['Body', 'Rib'], gsm: '160', colours: ['White', 'Black', 'Navy'], rate: 450 },
            { groupName: 'Interlock', itemNames: ['Body'], gsm: '220', colours: ['Red', 'Blue'], rate: 520 }
        ];
        for (const ig of itemGroups) {
            if (!await ItemGroup.findOne({ groupName: ig.groupName })) await ItemGroup.create(ig);
        }

        // 5. Lots
        const lots = [
            { lotNumber: 'LOT-001', partyName: 'Global Textiles', process: 'Weaving', remarks: 'High priority' },
            { lotNumber: 'LOT-002', partyName: 'Sark Fabrics', process: 'Dyeing', remarks: 'Sample lot' }
        ];
        for (const l of lots) {
            if (!await Lot.findOne({ lotNumber: l.lotNumber })) await Lot.create(l);
        }

        // 6. Inward (Detailed transaction)
        const inwardExists = await Inward.findOne({ lotNo: 'LOT-001' });
        if (!inwardExists) {
            await Inward.create({
                user: adminUser._id,
                inwardDate: new Date(),
                inTime: '10:00 AM',
                lotName: 'Global Lot',
                lotNo: 'LOT-001',
                inwardNo: 'INW-20260316-001',
                fromParty: 'Global Textiles',
                process: 'Weaving',
                rate: 50,
                gsm: '160',
                vehicleNo: 'MH-01-AB-1234',
                partyDcNo: 'DC-999',
                diaEntries: [
                    { dia: '24', roll: 10, sets: 1, delivWt: 200, recRoll: 10, recWt: 200, rate: 50 }
                ]
            });
            console.log('Created detailed Inward entry');
        }

        console.log('Detailed seeding completed successfully!');
        process.exit();
    } catch (error) {
        console.error('Error seeding database:', error);
        process.exit(1);
    }
};

seedData();
