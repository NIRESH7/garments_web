
import mongoose from 'mongoose';
import dotenv from 'dotenv';
import dns from 'dns';

dotenv.config();

console.log('Testing MongoDB Connection...');
console.log('URI:', process.env.MONGODB_URI ? 'Present' : 'Missing');

dns.setServers(['8.8.8.8', '8.8.4.4']);

const test = async () => {
    try {
        console.log('Connecting to MongoDB...');
        const start = Date.now();
        await mongoose.connect(process.env.MONGODB_URI, {
            serverSelectionTimeoutMS: 5000,
        });
        console.log('Connected successfully in', Date.now() - start, 'ms');
        process.exit(0);
    } catch (err) {
        console.error('Connection failed!');
        console.error('Error Name:', err.name);
        console.error('Error Message:', err.message);
        console.error('Error Code:', err.code);
        process.exit(1);
    }
};

test();
