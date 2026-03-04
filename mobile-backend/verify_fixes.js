import mongoose from 'mongoose';
import dotenv from 'dotenv';
dotenv.config();

// Simulation of the fixed logic
function simulateRunFifo(inw, dia) {
    const ROLLS_PER_SET = 11;

    // Fixed storageDetails logic
    let sd = null;
    if (inw.storageDetails) {
        if (Array.isArray(inw.storageDetails)) {
            sd = inw.storageDetails.find(s => s.dia === dia);
        } else if (inw.storageDetails.dia === dia) {
            sd = inw.storageDetails;
        }
    }

    if (!sd) return "SD NOT FOUND";

    const results = [];
    // Mocking the set allocation for Set 1 (index 0) and Set 2 (index 11)
    [0, 11].forEach(setIndexInLot => {
        const setPositionIndex = Math.floor(setIndexInLot / ROLLS_PER_SET);
        let rackName = 'N/A';
        let palletNumber = 'N/A';
        if (sd) {
            if (sd.racks && sd.racks[setPositionIndex]) rackName = sd.racks[setPositionIndex];
            if (sd.pallets && sd.pallets[setPositionIndex]) palletNumber = sd.pallets[setPositionIndex];
        }
        results.push({ setIndexInLot, setPositionIndex, rackName, palletNumber });
    });

    return results;
}

async function verify() {
    await mongoose.connect(process.env.MONGODB_URI);
    const db = mongoose.connection.db;

    // Test with LOT-MSD-99 (which is an Object)
    const msdLot = await db.collection('inwards').findOne({ lotNo: 'LOT-MSD-99' });
    console.log("--- Verification for LOT-MSD-99 (Object structure) ---");
    if (msdLot) {
        const results = simulateRunFifo(msdLot, "30");
        console.log(JSON.stringify(results, null, 2));

        // Assertions
        const set2 = results.find(r => r.setIndexInLot === 11);
        if (set2 && set2.rackName !== 'N/A' && set2.palletNumber !== 'N/A') {
            console.log("✅ SUCCESS: Rack/Pallet found for Set 2 in Object structure!");
        } else {
            console.log("❌ FAILED: Rack/Pallet still N/A for Set 2");
        }
    } else {
        console.log("LOT-MSD-99 not found in DB");
    }

    process.exit(0);
}

verify().catch(e => { console.error(e); process.exit(1); });
