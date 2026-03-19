import mongoose from 'mongoose';

// Mocking User ID - In a real scenario, you'd get this from the DB
const MOCK_USER_ID = new mongoose.Types.ObjectId();

const outwardSchema = new mongoose.Schema({
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    dcNo: { type: String, required: true, unique: true },
    lotName: { type: String, required: true },
    dateTime: { type: Date, required: true },
    dia: { type: String, required: true },
    lotNo: { type: String, required: true },
    partyName: { type: String, required: true },
    process: { type: String },
    vehicleNo: { type: String },
    items: [{
        set_no: { type: String },
        rack_name: { type: String },
        pallet_number: { type: String },
        colours: [{
            colour: String,
            weight: Number,
            no_of_rolls: Number,
            roll_weight: Number
        }]
    }],
    authorizedSignature: { type: String }
});

const Outward = mongoose.model('Outward', outwardSchema);

async function insertTestData() {
    try {
        await mongoose.connect('mongodb://localhost:27017/garments_local');
        console.log('Connected to garments_local');

        // Clear existing test data to avoid unique constraint error
        await Outward.deleteOne({ dcNo: 'DC-TEST-101' });

        const testOutward = new Outward({
            user: MOCK_USER_ID,
            dcNo: 'DC-TEST-101',
            lotName: 'PREMIUM-COTTON-01',
            dateTime: new Date(),
            dia: '24',
            lotNo: 'LOT-2024-X1',
            partyName: 'ABC TEXTILES',
            process: 'Dyeing & Compacting',
            vehicleNo: 'TN-37-AB-1234',
            items: [
                {
                    set_no: 'SET-A',
                    rack_name: 'GROUND-FLOOR-A1',
                    pallet_number: 'P-505',
                    colours: [
                        { colour: 'RED', weight: 120.5, no_of_rolls: 5, roll_weight: 24.1 },
                        { colour: 'BLUE', weight: 80.0, no_of_rolls: 4, roll_weight: 20.0 }
                    ]
                }
            ],
            authorizedSignature: 'John Doe (Auditor)' // This will auto-fill Slip Checked By
        });

        await testOutward.save();
        console.log('Sample Outward data inserted successfully: DC-TEST-101');
        
        // Also insert Category/Rack values if they don't exist in master
        // (Assuming you have a Category model, but usually these come from the Outward itself in your current auto-fill logic)

        process.exit(0);
    } catch (err) {
        console.error('Error inserting test data:', err);
        process.exit(1);
    }
}

insertTestData();
