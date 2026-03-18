import mongoose from 'mongoose';
import dotenv from 'dotenv';
import bcrypt from 'bcryptjs';

// Load env from the parent directory's .env if needed, or local .env
dotenv.config();

const UserSchema = new mongoose.Schema({
    name: { type: String, required: true },
    email: { type: String, required: true, unique: true },
    password: { type: String, required: true },
    isAdmin: { type: Boolean, default: false },
    isVerified: { type: Boolean, default: true }
}, { timestamps: true });

const User = mongoose.model('User', UserSchema);

const setupAdmin = async () => {
    try {
        const uri = process.env.MONGODB_URI || 'mongodb://localhost:27017/garments_local';
        console.log('Connecting to:', uri);
        await mongoose.connect(uri);
        
        const email = 'admin@example.com';
        const password = 'password123';
        
        // Delete existing if any to reset
        await User.deleteOne({ email });
        
        const hashedPassword = await bcrypt.hash(password, 10);
        
        await User.create({
            name: 'Admin User',
            email,
            password: hashedPassword,
            isAdmin: true,
            isVerified: true
        });
        
        console.log('SUCCESS: Admin user created/reset!');
        console.log('Email: admin@example.com');
        console.log('Password: password123');
        process.exit(0);
    } catch (err) {
        console.error('ERROR:', err);
        process.exit(1);
    }
};

setupAdmin();
