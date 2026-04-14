import mongoose from 'mongoose';
import dns from 'dns';

// Fix for SRV lookup errors on some networks (e.g. Jio/Reliance)
dns.setServers(['8.8.8.8', '8.8.4.4']);

const connectDB = async () => {
    try {
        console.log('Connecting to MongoDB Registry...');
        const options = {
            serverSelectionTimeoutMS: 30000,
            socketTimeoutMS: 45000,
            connectTimeoutMS: 30000,
            retryWrites: true,
            retryReads: true
        };
        
        if (!process.env.MONGODB_URI) {
            throw new Error('MONGODB_URI is not defined in environment variables');
        }

        const conn = await mongoose.connect(process.env.MONGODB_URI, options);
        console.log(`MongoDB Connected: ${conn.connection.host}`);
        return conn;
    } catch (error) {
        console.error(`FATAL Database Error: ${error.message}`);
        console.log("Check your internet connection and verify if your IP is whitelisted on MongoDB Atlas.");
        // We throw the error so server.js can handle it or stop startup
        throw error;
    }
};

export default connectDB;
