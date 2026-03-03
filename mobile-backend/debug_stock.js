
import mongoose from 'mongoose';
import dotenv from 'dotenv';
import Assignment from './src/modules/production/assignmentModel.js';
import Inward from './src/modules/inventory/inwardModel.js';

dotenv.config();

async function check() {
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('Connected to MongoDB');

    console.log('--- Assignments for NIRESH ---');
    const assignments = await Assignment.find({ fabricItem: /NIRESH/i });
    assignments.forEach(a => {
        console.log(`Size: ${a.size}, Dia: ${a.dia}, DozWt: ${a.dozenWeight}`);
    });

    console.log('--- Inward Stock for Dia 67 ---');
    const inwards = await Inward.find({ 'diaEntries.dia': '67' });
    if (inwards.length === 0) {
        console.log('No inwards found for Dia 67');
    } else {
        inwards.forEach(inw => {
            const entry = inw.diaEntries.find(e => e.dia === '67');
            console.log(`Lot: ${inw.lotNo}, Dia: 67, RecWt: ${entry.recWt}, RecRoll: ${entry.recRoll}`);
        });
    }

    console.log('--- Inward Stock for Dia 30 ---');
    const inwards30 = await Inward.find({ 'diaEntries.dia': '30' });
    inwards30.forEach(inw => {
        const entry = inw.diaEntries.find(e => e.dia === '30');
        console.log(`Lot: ${inw.lotNo}, Dia: 30, RecWt: ${entry.recWt}, RecRoll: ${entry.recRoll}`);
    });

    process.exit(0);
}

check();
