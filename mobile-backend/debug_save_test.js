
import mongoose from 'mongoose';
import fetch from 'node-fetch'; // if available, or dynamic import

// Constants
const API_URL = 'http://localhost:5001/api';
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb://localhost:27017/garments_mobile';

async function run() {
    try {
        console.log('Connecting to MongoDB...');
        await mongoose.connect(MONGODB_URI);
        console.log('Connected to MongoDB');

        // 1. Login
        console.log('Logging in...');
        const loginRes = await fetch(`${API_URL}/auth/login`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ email: 'admin@example.com', password: 'password123' })
        });
        const loginData = await loginRes.json();
        if (!loginRes.ok) throw new Error(`Login failed: ${JSON.stringify(loginData)}`);
        const token = loginData.token;
        console.log('Logged in successfully based on token presence: ', !!token);

        // 2. Find an Inward
        const Inward = mongoose.connection.collection('inwards');
        let inward = await Inward.findOne({});

        if (!inward) {
            console.log('No inward found, creating one via API...');
            // Simplified creation for test if needed...
            // But let's assume there is one since user has data. 
            // If not found, we can't reproduce easily without mocking more data.
            console.log('Cannot proceed without existing Inward data for reproduction.');
            return;
        }

        console.log(`Found Inward: ${inward._id} (Lot: ${inward.lotNo})`);

        // 3. Test Update Complaint Solution
        const updateData = {
            complaintReply: 'Test Reply via script',
            complaintResolution: 'ACCEPT',
            complaintFindDate: new Date().toISOString(),
            complaintCompletionDate: new Date().toISOString(),
            complaintArrestLotNo: '999',
            isComplaintCleared: true
        };

        console.log('Updating Complaint Solution...');
        const updateRes = await fetch(`${API_URL}/inventory/inward/${inward._id}/complaint-solution`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${token}`
            },
            body: JSON.stringify(updateData)
        });

        const updateDataRes = await updateRes.json();
        console.log('Update Status:', updateRes.status);
        console.log('Update Response:', JSON.stringify(updateDataRes, null, 2));

        if (updateRes.ok) {
            console.log('✅ Complaint Solution Updated Successfully!');
        } else {
            console.log('❌ Failed to update Complaint Solution');
        }

    } catch (error) {
        console.error('Error:', error);
    } finally {
        await mongoose.disconnect();
    }
}

// Check for fetch availability or polyfill
if (!globalThis.fetch) {
    import('node-fetch').then(mod => {
        globalThis.fetch = mod.default;
        run();
    }).catch(err => {
        console.log('node-fetch not found, trying native fetch (Node 18+)...');
        run();
    });
} else {
    run();
}
