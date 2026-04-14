const mongoose = require('mongoose');
const dotenv = require('dotenv');
const path = require('path');

dotenv.config({ path: path.join(__dirname, '../.env') });

async function addAssignment() {
    try {
        await mongoose.connect(process.env.MONGODB_URI);
        console.log('Connected to MongoDB');

        const Assignment = mongoose.model('Assignment', new mongoose.Schema({
            fabricItem: String,
            size: String,
            dozenWeight: Number,
            foldingWt: Number,
            dia: String,
            gsm: Number,
            efficiency: Number
        }, { collection: 'assignments' }));

        const itemName = 'TRUNKS';
        const size = '34';

        // Update or Create
        const result = await Assignment.findOneAndUpdate(
            { fabricItem: itemName, size: size },
            {
                fabricItem: itemName,
                size: size,
                dozenWeight: 1.105,
                foldingWt: 0.19,
                dia: '34',
                gsm: 160,
                efficiency: 88.3
            },
            { upsert: true, new: true }
        );

        console.log('Success! Assignment updated/created:');
        console.log(JSON.stringify(result, null, 2));

        process.exit(0);
    } catch (err) {
        console.error('Error:', err);
        process.exit(1);
    }
}

addAssignment();
