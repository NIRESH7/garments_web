import axios from 'axios';

const API_BASE = 'http://127.0.0.1:5001/api';
const LOGIN_PAYLOAD = {
    email: 'admin@example.com',
    password: 'password123'
};

async function verify() {
    try {
        console.log('Logging in...');
        const loginRes = await axios.post(`${API_BASE}/auth/login`, LOGIN_PAYLOAD);
        const token = loginRes.data.token;
        const authHeader = { headers: { Authorization: `Bearer ${token}` } };

        const lotNo = 'REFINE-' + Date.now();
        const lotName = 'Refined Jersey';

        console.log(`Step 1: Creating inward with sticker Roll No`);
        const inward = {
            lotNo,
            lotName,
            fromParty: 'Compact Fabrics',
            inwardDate: new Date().toISOString().split('T')[0],
            inTime: '10:00 AM',
            diaEntries: JSON.stringify([{
                dia: '30',
                roll: 1,
                delivWt: 200, // Matching the user's example image
                recRoll: 1,
                recWt: 200,
                rate: 50
            }]),
            storageDetails: JSON.stringify([{
                dia: '30',
                racks: ['RACK-1'],
                pallets: ['PALLET-1'],
                rows: [{
                    colour: 'Yellow',
                    rollNo: '555', // Sticker Roll No
                    gsm: '4',
                    setWeights: ['200'],
                    totalWeight: 200
                }]
            }])
        };

        await axios.post(`${API_BASE}/inventory/inward`, inward, authHeader);
        console.log('Inward created.');

        console.log('Step 2: Verifying persistence');
        const allInwards = await axios.get(`${API_BASE}/inventory/inward?lotNo=${lotNo}`, authHeader);
        const savedInward = allInwards.data.find(i => i.lotNo === lotNo);

        console.log('Saved Inward DIA Entries:', JSON.stringify(savedInward.diaEntries, null, 2));
        console.log('Saved Storage Details:', JSON.stringify(savedInward.storageDetails, null, 2));

        const entry = savedInward.diaEntries[0];
        if (entry.delivWt === 200) {
            console.log('SUCCESS: delivWt correctly persisted as 200.');
        } else {
            console.log('FAILURE: delivWt is ' + entry.delivWt);
        }

        const stickerRow = savedInward.storageDetails[0].rows[0];
        if (stickerRow.rollNo === '555') {
            console.log('SUCCESS: Sticker Roll No persisted as 555.');
        } else {
            console.log('FAILURE: Sticker Roll No is ' + stickerRow.rollNo);
        }

    } catch (error) {
        console.error('Verification failed:', error.response?.data || error.message);
    }
}

verify();
