import mongoose from 'mongoose';
import dotenv from 'dotenv';

dotenv.config();

const maskMongoUri = (uri) => {
    if (!uri) return '';
    return uri.replace(/\/\/([^:]+):([^@]+)@/, '//***:***@');
};

const testConnection = async () => {
    console.log(`Connecting to: ${maskMongoUri(process.env.MONGODB_URI)}`);
    try {
        await mongoose.connect(process.env.MONGODB_URI, {
            serverSelectionTimeoutMS: 5000, // Timeout after 5s
        });
        console.log('✅ MongoDB Connection Successful!');
        process.exit(0);
    } catch (error) {
        console.error('❌ MongoDB Connection Failed:');
        console.error(error.message);
        process.exit(1);
    }
};

testConnection();
