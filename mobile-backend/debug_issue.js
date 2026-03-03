
import mongoose from 'mongoose';
import dotenv from 'dotenv';
import Assignment from './src/modules/production/assignmentModel.js';
import Inward from './src/modules/inventory/inwardModel.js';

dotenv.config();

async function check() {
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('Connected to MongoDB');

    const assignment = await Assignment.findOne({
        fabricItem: { $regex: new RegExp('^NIRESH$', 'i') },
        size: '85'
    });
    console.log('Assignment for NIRESH / 85:', assignment);

    const inwards = await Inward.find({ 'diaEntries.dia': '67' });
    console.log('Inwards for Dia 67 count:', inwards.length);
    if (inwards.length > 0) {
        inwards.forEach(inw => {
            const entry = inw.diaEntries.find(e => e.dia === '67');
            console.log(`Lot ${inw.lotNo}: ${entry.recWt}kg available`);
        });
    }

    process.exit(0);
}

check();
