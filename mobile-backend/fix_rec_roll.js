import mongoose from 'mongoose';
import dotenv from 'dotenv';
import dns from 'dns';
import path from 'path';

// Fix for SRV lookup errors
dns.setServers(['8.8.8.8', '8.8.4.4']);

dotenv.config();

const InwardSchema = new mongoose.Schema({
    inwardNo: String,
    diaEntries: Array
}, { collection: 'inwards' });

const Inward = mongoose.model('Inward', InwardSchema);

async function run() {
    try {
        await mongoose.connect(process.env.MONGODB_URI, { family: 4 });
        console.log('Connected to DB');

        const inwardNo = 'INW-20260313-014';
        const doc = await Inward.findOne({ inwardNo });

        if (doc) {
            console.log('Current Doc:', JSON.stringify(doc.diaEntries[0], null, 2));
            if (doc.diaEntries && doc.diaEntries[0]) {
                doc.diaEntries[0].recRoll = 180;
                doc.markModified('diaEntries');
                await doc.save();
                console.log('Successfully updated recRoll to 180');
            } else {
                console.log('No diaEntries found in doc');
            }
        } else {
            console.log('No document found with inwardNo:', inwardNo);
        }
    } catch (err) {
        console.error('Error:', err);
    } finally {
        await mongoose.disconnect();
    }
}

run();
