/**
 * BULK DATA SEEDER - v3 (Bypass FIFO)
 * 
 * This script ensures the test data appears as the OLDEST lot
 * so you don't get the "FIFO Violation" error.
 */
import mongoose from 'mongoose';
import dotenv from 'dotenv';

dotenv.config();

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/garments_erp';

async function seedBulkDataV3() {
    console.log('🚀 Connecting to MongoDB...');
    await mongoose.connect(MONGODB_URI);
    const db = mongoose.connection.db;

    const lotName = 'BULK-TEST-FABRIC';
    const lotNo = 'BATCH-XYZ-999';
    const dia = '30';
    const partyName = 'BULK-PARTY';

    const user = await db.collection('users').findOne({});
    const userId = user ? user._id : new mongoose.Types.ObjectId();

    console.log('👤 Ensuring Master Party exists...');
    await db.collection('parties').deleteMany({ name: partyName });
    await db.collection('parties').insertOne({
        name: partyName,
        address: '123 Bulk Street',
        mobileNumber: '9876543210',
        process: 'Production',
        createdAt: new Date(),
        updatedAt: new Date()
    });

    console.log('🏷️  Updating Master Categories...');
    await db.collection('categories').updateOne(
        { name: 'Lot Name' },
        { $addToSet: { values: { name: lotName, photo: null, gsm: null } } }
    );
    await db.collection('categories').updateOne(
        { name: 'Dia' },
        { $addToSet: { values: { name: dia, photo: null, gsm: null } } }
    );
    await db.collection('categories').updateOne(
        { name: 'dia' },
        { $addToSet: { values: { name: dia, photo: null, gsm: null } } }
    );

    console.log('📦 Creating Inward Lot (Setting date to 2020 to bypass FIFO)...');
    await db.collection('inwards').deleteMany({ lotNo });
    // IMPORTANT: Setting date to 2020-01-01 so it's the oldest lot for Dia 30
    const oldDate = new Date('2020-01-01');

    await db.collection('inwards').insertOne({
        user: userId,
        lotName,
        lotNo,
        inwardNo: 'INW-BULK-V3',
        inwardDate: oldDate,
        createdAt: oldDate,
        updatedAt: new Date(),
        fromParty: partyName,
        diaEntries: [{
            dia,
            recWt: 500,
            recRoll: 44
        }],
        storageDetails: [{
            dia,
            racks: ['RACK-A', 'RACK-B', 'RACK-C', 'RACK-D'],
            pallets: ['P-101', 'P-102', 'P-103', 'P-104'],
            rows: [
                { colour: 'Royal Blue', setWeights: [15.5] },
                { colour: 'Golden Yellow', setWeights: [12.0] },
                { colour: 'Deep White', setWeights: [20.0] },
                { colour: 'Sky Blue', setWeights: [10.5] }
            ]
        }]
    });

    console.log('\n✅ DONE! I set the date to be the OLDEST lot.');
    console.log('--------------------------------------------------');
    console.log('PLEASE RE-LOGIN OR REFRESH THE SCREEN IN THE APP:');
    console.log(`1. LOT NAME: ${lotName}`);
    console.log(`2. DIA: ${dia}`);
    console.log(`3. LOT NO (FIFO): ${lotNo}`);
    console.log(`4. PARTY NAME: ${partyName}`);
    console.log('5. Select Set 1 - Now it will NOT show FIFO violation!');
    console.log('--------------------------------------------------\n');

    await mongoose.disconnect();
    process.exit(0);
}

seedBulkDataV3().catch(err => {
    console.error('❌ SEED ERROR:', err);
    process.exit(1);
});
