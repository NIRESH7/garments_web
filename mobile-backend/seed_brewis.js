
import mongoose from 'mongoose';
import dotenv from 'dotenv';
import Assignment from './src/modules/production/assignmentModel.js';
import Inward from './src/modules/inventory/inwardModel.js';
import User from './src/modules/user/model.js';

dotenv.config();

async function seed() {
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('Connected to MongoDB');

    // 1. Find a user to assign as owner
    const user = await User.findOne({});
    if (!user) {
        console.error('No user found in DB. Please create a user first.');
        process.exit(1);
    }

    // 2. Create Assignment for brewis / 85
    await Assignment.deleteMany({ fabricItem: /brewis/i });
    const assignment = await Assignment.create({
        user: user._id,
        fabricItem: 'brewis',
        size: '85',
        dia: '30',
        dozenWeight: 3.5,
        foldingWt: 0.1,
        gsm: '160',
        efficiency: 90
    });
    console.log('Created Assignment for brewis/85');

    // 3. Create Inward Stock for brewis (Dia 30)
    await Inward.deleteMany({ lotName: /brewis/i });

    // We will create a Lot with 33 rolls (3 sets of 11)
    // Avg roll weight 4.2kg
    const setWeights = Array(33).fill(4.2);

    const inward = await Inward.create({
        user: user._id,
        inwardDate: new Date(),
        inTime: '10:00 AM',
        lotName: 'BREWIS FABRIC',
        lotNo: 'LOT-BRW-001',
        inwardNo: 'INW-BREWIS-001',
        fromParty: 'TEST SUPPLIER',
        rate: 150,
        diaEntries: [{
            dia: '30',
            recRoll: 33,
            recWt: 138.6, // 33 * 4.2
            rate: 150
        }],
        storageDetails: {
            dia: '30',
            rows: [{
                setWeights: setWeights
            }],
            racks: Array(33).fill('RACK-A1'),
            pallets: Array(33).fill('P-01')
        }
    });
    console.log('Created Inward Stock for brewis (Dia 30, 33 Rolls)');

    console.log('--- SEEDING COMPLETE ---');
    console.log('Item: brewis');
    console.log('Size: 85');
    console.log('Dia: 30');
    console.log('Available Stock: 138.6 KG (3 Sets of 11)');

    process.exit(0);
}

seed().catch(err => {
    console.error(err);
    process.exit(1);
});
