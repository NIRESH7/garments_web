const mongoose = require('mongoose');
const dns = require('dns');
dns.setServers(['8.8.8.8', '8.8.4.4']);
const dotenv = require('dotenv');
const path = require('path');

dotenv.config({ path: path.join(__dirname, '../mobile-backend/.env') });

async function run() {
    try {
        await mongoose.connect(process.env.MONGODB_URI);
        const Outward = mongoose.model('Outward', new mongoose.Schema({}, { collection: 'outwards', strict: false }));
        const docs = await Outward.find({ 
            dcNo: { $in: ['DC-20260416-001', 'DC-20260416-002', 'DC-20260416-003', 'DC-20260416-004'] } 
        });
        
        console.log('DC No | Date Time | Created At');
        console.log('-------------------------------');
        docs.forEach(d => {
            console.log(`${d.dcNo} | ${d.dateTime.toISOString()} | ${d.createdAt.toISOString()}`);
        });
        
        process.exit(0);
    } catch (err) {
        console.error(err);
        process.exit(1);
    }
}
run();
