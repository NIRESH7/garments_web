const mongoose = require('mongoose');
const dotenv = require('dotenv');
const path = require('path');

// Load .env from mobile-backend
dotenv.config({ path: path.join(__dirname, 'mobile-backend', '.env') });

const uri = process.env.MONGODB_URI;

console.log('Attempting to connect to MongoDB...');
console.log('URI:', uri.replace(/:([^:@]{1,})@/, ':****@')); // Hide password

mongoose.connect(uri)
    .then(() => {
        console.log('Successfully connected to MongoDB!');
        process.exit(0);
    })
    .catch((err) => {
        console.error('Connection error:', err);
        process.exit(1);
    });
