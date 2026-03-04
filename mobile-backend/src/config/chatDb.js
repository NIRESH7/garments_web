import mongoose from 'mongoose';
import dotenv from 'dotenv';

dotenv.config();

const chatDbUri = process.env.CHAT_MONGODB_URI;

if (!chatDbUri) {
    console.error('CHAT_MONGODB_URI is not defined in .env');
}

const chatDbConnection = mongoose.createConnection(chatDbUri);

chatDbConnection.on('connected', () => {
    console.log(`AI Chatbot connected to DB: ${chatDbUri}`);
});

chatDbConnection.on('error', (err) => {
    console.error(`AI Chatbot DB Connection Error: ${err}`);
});

export default chatDbConnection;
