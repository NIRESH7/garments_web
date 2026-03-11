import mongoose from 'mongoose';
import dns from 'dns';
import dotenv from 'dotenv';
dotenv.config();

dns.setServers(['8.8.8.8', '8.8.4.4']);

async function listCollections() {
    try {
        await mongoose.connect(process.env.MONGODB_URI);
        const colls = await mongoose.connection.db.listCollections().toArray();
        console.log(colls.map(c => c.name));
        process.exit(0);
    } catch (err) {
        console.error(err);
        process.exit(1);
    }
}

listCollections();
