import dotenv from 'dotenv';
import mongoose from 'mongoose';
import dns from 'dns';
import Inward from './src/modules/inventory/inwardModel.js';
import Party from './src/modules/master/partyModel.js';

dotenv.config();

// Fix for SRV lookup errors
dns.setServers(['8.8.8.8', '8.8.4.4']);

async function testConnection() {
    console.log('Connecting to:', process.env.MONGODB_URI);
    try {
        await mongoose.connect(process.env.MONGODB_URI);
        console.log('Connected successfully!');

        const inwardCount = await Inward.countDocuments();
        console.log('Total Inwards in Live DB:', inwardCount);

        const partyCount = await Party.countDocuments();
        console.log('Total Parties in Live DB:', partyCount);

        const recentInward = await Inward.findOne().sort({ inwardDate: -1 });
        if (recentInward) {
            console.log('Recent Inward Lot:', recentInward.lotNo, 'from', recentInward.fromParty);
        }

        process.exit(0);
    } catch (err) {
        console.error('Connection failed:', err);
        process.exit(1);
    }
}

testConnection();
