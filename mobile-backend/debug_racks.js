import mongoose from 'mongoose';
import dotenv from 'dotenv';
dotenv.config();

async function check() {
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('Connected:', process.env.MONGODB_URI);

    const db = mongoose.connection.db;

    // Find LOT-MSD-99 specifically
    const msdLot = await db.collection('inwards').findOne({ lotNo: 'LOT-MSD-99' });

    if (msdLot) {
        console.log(`\n=== Found LOT-MSD-99 ===`);
        console.log(`  Lot Name: ${msdLot.lotName}`);

        const diaEntries = msdLot.diaEntries || [];
        console.log(`  diaEntries: ${JSON.stringify(diaEntries)}`);

        const storageDetails = msdLot.storageDetails;
        console.log(`  storageDetails type: ${typeof storageDetails}`);

        if (Array.isArray(storageDetails)) {
            console.log(`  storageDetails count: ${storageDetails.length}`);
            storageDetails.forEach((sd, sdIdx) => {
                console.log(`  [${sdIdx}] Dia: ${sd.dia}`);
                console.log(`     racks: ${JSON.stringify(sd.racks)}`);
                console.log(`     pallets: ${JSON.stringify(sd.pallets)}`);
                if (Array.isArray(sd.rows)) {
                    sd.rows.forEach((row, ri) => {
                        console.log(`     row[${ri}] colour=${row.colour}, setWeights=${JSON.stringify(row.setWeights)}`);
                    });
                }
            });
        } else {
            console.log(`  storageDetails is NOT an array: ${JSON.stringify(storageDetails)}`);
        }
    } else {
        console.log('\nLOT-MSD-99 not found');
    }

    // Also check all lots for Dia 30 again, but very safely
    const inwards = await db.collection('inwards').find({ 'diaEntries.dia': '30' }).toArray();
    console.log(`\nFound ${inwards.length} inward(s) with Dia 30\n`);

    inwards.forEach(inw => {
        if (inw.lotNo === 'LOT-MSD-99') return; // already checked
        console.log(`Lot: ${inw.lotNo} | ${inw.lotName} | storageDetails type: ${typeof inw.storageDetails}`);
    });

    process.exit(0);
}
check().catch(e => { console.error(e); process.exit(1); });
