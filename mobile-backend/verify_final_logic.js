
import mongoose from 'mongoose';
import dotenv from 'dotenv';
import { runFifo } from './src/modules/production/cuttingOrderController.js';

dotenv.config();

async function verify() {
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('Connected to MongoDB');

    // Test Case: Item with existing stock (Dia 30)
    // We want 50 dozen at 3.5kg = 175kg. 
    // Roll weights on Dia 30 are ~4.14kg.
    // 1 set of 11 = ~45kg. 
    // 175kg / 45kg = ~3.8 sets -> expected 4 sets (44 rolls)

    console.log('\n--- Test 1: Standard 50 Dozen Allocation ---');
    const result1 = await runFifo({
        dia: '30',
        effDozenWeight: 3.5,
        targetDozen: 50,
        requiredWeight: 175,
        excludedSets: []
    });

    console.log(`Target: 175kg, Dozen: 50`);
    console.log(`Allocated Sets: ${result1.totalSets}`);
    console.log(`Allocated Rolls: ${result1.totalRolls}`);
    console.log(`Shortfall: ${result1.shortfall.toFixed(2)}kg`);
    console.log(`Is multiple of 11? ${result1.totalRolls % 11 === 0}`);

    process.exit(0);
}

verify().catch(err => {
    console.error(err);
    process.exit(1);
});
