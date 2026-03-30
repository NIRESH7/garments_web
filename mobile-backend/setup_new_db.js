import mongoose from 'mongoose';
import dotenv from 'dotenv';
import dns from 'dns';
import User from './src/modules/user/model.js';
import Menu from './src/modules/menu/model.js';
import Category from './src/modules/master/categoryModel.js';
import Party from './src/modules/master/partyModel.js';
import ItemGroup from './src/modules/master/itemGroupModel.js';

dotenv.config();

// Fix for SRV lookup errors on some networks (e.g. Jio/Reliance)
dns.setServers(['8.8.8.8', '8.8.4.4']);

const NEW_DB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/omvinayagar_garments_prod';

const setupNewDB = async () => {
    try {
        console.log(`Connecting to new database: ${NEW_DB_URI}`);
        await mongoose.connect(NEW_DB_URI);
        console.log('Connected to MongoDB!');

        // 1. Create User: niresh@gmail.com / Admin@123
        const userEmail = 'niresh@gmail.com';
        let user = await User.findOne({ email: userEmail });
        if (!user) {
            user = await User.create({
                name: 'Niresh Admin',
                email: userEmail,
                password: 'Admin@123',
                isAdmin: true,
                isVerified: true,
                role: 'admin'
            });
            console.log(`Created admin user: ${userEmail}`);
        } else {
            user.password = 'Admin@123'; // Update password if user exists
            user.isAdmin = true;
            user.role = 'admin';
            await user.save();
            console.log(`Admin user ${userEmail} already exists, password updated.`);
        }

        // 2. Clear and Create Menu details
        await Menu.deleteMany({});
        const menuItems = [
            {
                title: 'Setup',
                icon: 'settings-outline',
                children: [
                    { title: 'Categories', icon: 'list-outline', route: '/setup/categories' }
                ]
            },
            {
                title: 'Master',
                icon: 'cube-outline',
                route: '/master'
            },
            {
                title: 'Lot Inward',
                icon: 'download-outline',
                route: '/inventory/inward'
            },
            {
                title: 'Lot Outward',
                icon: 'upload-outline',
                route: '/inventory/outward'
            }
        ];
        await Menu.insertMany(menuItems);
        console.log('Menu details inserted successfully.');

        // 3. Seed initial master data (Categories, Parties, Item Groups)
        // This addresses "many details" in the request.
        
        // Categories
        const categories = [
            { name: 'Fabric', description: 'Raw fabric material' },
            { name: 'Yarn', description: 'Yarn for weaving' },
            { name: 'Accessories', description: 'Buttons, zippers, etc.' }
        ];
        for (const cat of categories) {
            if (!await Category.findOne({ name: cat.name })) {
                await Category.create(cat);
            }
        }
        console.log('Initial categories seeded.');

        // Parties
        const parties = [
            { name: 'Sri Vinayagar Textiles', address: 'Tirupur', mobileNumber: '9001234567', process: 'Knitting', rate: 45 },
            { name: 'Om Dyeing Unit', address: 'Erode', mobileNumber: '9112345678', process: 'Dyeing', rate: 30 }
        ];
        for (const p of parties) {
            if (!await Party.findOne({ name: p.name })) {
                await Party.create(p);
            }
        }
        console.log('Initial parties seeded.');

        // Item Groups
        const itemGroups = [
            { groupName: 'Cotton 40s', itemNames: ['Body', 'Rib'], gsm: '160', colours: ['White', 'Black'], rate: 480 },
            { groupName: 'PC Sinker', itemNames: ['Body'], gsm: '220', colours: ['Navy'], rate: 510 }
        ];
        for (const ig of itemGroups) {
            if (!await ItemGroup.findOne({ groupName: ig.groupName })) {
                await ItemGroup.create(ig);
            }
        }
        console.log('Initial item groups seeded.');

        console.log('Database initialization completed successfully!');
        process.exit(0);
    } catch (error) {
        console.error('Error setting up database:', error);
        process.exit(1);
    }
};

setupNewDB();
