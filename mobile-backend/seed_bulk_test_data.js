/**
 * BULK DATA SEEDER - For Manual UI Testing
 * 
 * This script creates:
 * 1. A Master Lot: "BULK-TEST-FABRIC"
 * 2. A Master Party: "BULK-PARTY"
 * 3. A New Lot Inward: "BATCH-XYZ-999"
 * 4. Mixed Colors: "Royal Blue", "Golden Yellow", "Deep White", "Sky Blue"
 */
import mongoose from 'mongoose';
import dotenv from 'dotenv';

dotenv.config();

const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://127.0.0.1:27017/garments_erp';

async function seedBulkData() {
    console.log('🚀 Connecting to MongoDB...');
    await mongoose.connect(MONGODB_URI);
    const db = mongoose.connection.db;

    const lotName = 'BULK-TEST-FABRIC';
    const lotNo = 'BATCH-XYZ-999';
    const dia = '30';
    const partyName = 'BULK-PARTY';

    // Use a valid User ID for associations
    const user = await db.collection('users').findOne({});
    const userId = user ? user._id : new mongoose.Types.ObjectId();

    console.log(`🧹 Cleaning old data...`);
    await db.collection('inwards').deleteMany({ lotNo });
    await db.collection('lots').deleteMany({ lotNumber: lotName });
    await db.collection('parties').deleteMany({ name: partyName });

    console.log('👤 Ensuring Master Party exists...');
    await db.collection('parties').insertOne({
        name: partyName,
        address: '123 Bulk Street',
        mobileNumber: '9876543210',
        process: 'Production',
        createdAt: new Date(),
        updatedAt: new Date()
    });

    console.log('📦 Ensuring Master Lot exists...');
    await db.collection('lots').insertOne({
        lotNumber: lotName,
        partyName: partyName,
        process: 'Cutting',
        createdAt: new Date(),
        updatedAt: new Date()
    });

    console.log('📥 Creating Inward with 4 Colors...');
    await db.collection('inwards').insertOne({
        user: userId,
        lotName,
        lotNo,
        inwardNo: 'INW-BULK-0016',
        inwardDate: new Date(),
        createdAt: new Date(),
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

    console.log('\n✅ DONE! Bulk data seeded successfully.');
    console.log('--------------------------------------------------');
    console.log('HOW TO TEST IN APP:');
    console.log('1. Go to "Outward" screen.');
    console.log(`2. Select LOT NAME: ${lotName}`);
    console.log(`3. Select DIA: ${dia}`);
    console.log(`4. Select LOT NO (FIFO): ${lotNo}`);
    console.log(`5. Select PARTY NAME: ${partyName}`);
    console.log('6. Click "Set 1" and verify exactly 4 colors list.');
    console.log('--------------------------------------------------\n');

    await mongoose.disconnect();
    process.exit(0);
}

seedBulkData().catch(err => {
    console.error('❌ SEED ERROR:', err);
    process.exit(1);
});
