import mongoose from 'mongoose';
import dns from 'dns';

// Fix for SRV lookup errors on some networks (e.g. Jio/Reliance)
dns.setServers(['8.8.8.8', '8.8.4.4']);

const connectDB = async () => {
    try {
        const options = {
            serverSelectionTimeoutMS: 30000,
            socketTimeoutMS: 45000,
            connectTimeoutMS: 30000,
            retryWrites: true,
            retryReads: true
        };
        const conn = await mongoose.connect(process.env.MONGODB_URI, options);
        console.log(`MongoDB Connected: ${conn.connection.host}`);
    } catch (error) {
        console.error(`Error: ${error.message}`);
        // Instead of exiting, try to reconnect or just wait
        console.log("Could not connect to MongoDB. Please check your internet connection.");
    }
};

export default connectDB;
