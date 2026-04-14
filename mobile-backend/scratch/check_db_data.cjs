const mongoose = require('mongoose');
const dotenv = require('dotenv');
const path = require('path');

dotenv.config({ path: path.join(__dirname, '../.env') });

async function checkData() {
    try {
        await mongoose.connect(process.env.MONGODB_URI);
        console.log('Connected to MongoDB');

        const Inward = mongoose.model('Inward', new mongoose.Schema({
            lotName: String,
            lotNo: String,
            diaEntries: [{ dia: String, recRoll: Number, recWt: Number, sets: Number }],
            storageDetails: mongoose.Schema.Types.Mixed
        }, { collection: 'inwards' }));

        const Assignment = mongoose.model('Assignment', new mongoose.Schema({
            fabricItem: String,
            size: String,
            dozenWeight: Number,
            foldingWt: Number,
            dia: String
        }, { collection: 'assignments' }));

        const itemName = 'TRUNKS';
        const size = '34';

        const assignment = await Assignment.findOne({
            fabricItem: { $regex: new RegExp(`^${itemName}$`, 'i') },
            size: size
        });
        console.log('\n--- Assignment for TRUNKS size 34 ---');
        console.log(JSON.stringify(assignment, null, 2));

        const inwards = await Inward.find({
            lotNo: '2526/00140'
        });
        console.log('\n--- Inwards for Lot 2526/00140 ---');
        console.log(JSON.stringify(inwards, null, 2));

        process.exit(0);
    } catch (err) {
        console.error(err);
        process.exit(1);
    }
}

checkData();
