const mongoose = require('mongoose');
const dotenv = require('dotenv');
const path = require('path');
const dns = require('dns');

// Fix for SRV lookup errors
dns.setServers(['8.8.8.8', '8.8.4.4']);

// Load env
dotenv.config({ path: path.join(__dirname, '../.env') });

async function check() {
    try {
        if (!process.env.MONGODB_URI) {
            console.error('MONGODB_URI is not defined');
            process.exit(1);
        }
        await mongoose.connect(process.env.MONGODB_URI);
        console.log('Connected to DB');

        const Outward = mongoose.model('Outward', new mongoose.Schema({}, { strict: false }));
        const Inward = mongoose.model('Inward', new mongoose.Schema({}, { strict: false }));

        console.log('--- Outwards containing Tesla ---');
        const outs = await Outward.find({ lotName: /Tesla/i });
        outs.forEach(o => {
            console.log(`ID: ${o._id}, LotName: "${o.lotName}", LotNo: "${o.lotNo}"`);
        });

        console.log('\n--- Inwards containing Tesla ---');
        const inws = await Inward.find({ lotName: /Tesla/i });
        inws.forEach(i => {
            console.log(`ID: ${i._id}, LotName: "${i.lotName}", LotNo: "${i.lotNo}"`);
        });

        process.exit(0);
    } catch (err) {
        console.error(err);
        process.exit(1);
    }
}

check();
