import mongoose from 'mongoose';

const MONGODB_URI = 'mongodb://127.0.0.1:27017/garments_erp';

const diaEntrySchema = mongoose.Schema({
    dia: { type: String, required: true },
    roll: { type: Number, default: 0 },
    sets: { type: Number, default: 0 },
    delivWt: { type: Number, default: 0 },
    recRoll: { type: Number, default: 0 },
    recWt: { type: Number, default: 0 },
    rate: { type: Number, required: true },
});

const inwardSchema = mongoose.Schema({
    user: { type: mongoose.Schema.Types.ObjectId, required: true },
    inwardDate: { type: Date, required: true },
    inTime: { type: String, required: true },
    lotName: { type: String, required: true },
    lotNo: { type: String, required: true },
    fromParty: { type: String, required: true },
    complaintText: { type: String },
    diaEntries: [diaEntrySchema],
    isComplaintCleared: { type: Boolean, default: false },
});

const Inward = mongoose.model('Inward', inwardSchema);

async function insertTestData() {
    try {
        await mongoose.connect(MONGODB_URI);
        console.log('Connected to MongoDB');

        const validUserId = '6995e2480f77b391a82efa8b';

        const testInward = new Inward({
            user: new mongoose.Types.ObjectId(validUserId),
            inwardDate: new Date(),
            inTime: '10:00 AM',
            lotName: 'TEST LOT COMPLAINT',
            lotNo: 'LOT-COMP-001',
            fromParty: 'Test Party',
            complaintText: 'This is a test complaint for the dropdown.',
            diaEntries: [{ dia: '30', rate: 100 }]
        });

        await testInward.save();
        console.log('Test inward with complaint inserted successfully!');

        process.exit(0);
    } catch (error) {
        console.error('Error inserting test data:', error);
        process.exit(1);
    }
}

insertTestData();
