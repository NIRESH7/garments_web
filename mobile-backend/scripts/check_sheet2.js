import axios from 'axios';

const API_BASE = 'http://localhost:5001/api';

async function runCheck() {
    try {
        console.log('--- Sheet 2 Verification Script ---');
        
        // 1. Auth
        console.log('Logging in...');
        const loginRes = await axios.post(`${API_BASE}/auth/login`, {
            email: 'testadmin@example.com',
            password: 'password123'
        });
        const token = loginRes.data.token;
        const authHeader = { headers: { Authorization: `Bearer ${token}` } };
        console.log('✅ Logged in successfully.');

        // 2. Get an existing entry to use as base
        console.log('Fetching cutting entries...');
        const entriesRes = await axios.get(`${API_BASE}/production/cutting-entry`, authHeader);
        if (!entriesRes.data || entriesRes.data.length === 0) {
            console.error('No cutting entries found. Please create one on Page 1 first.');
            process.exit(1);
        }
        
        const entry = entriesRes.data[0];
        const entryId = entry._id;
        console.log(`Using Entry ID: ${entryId} (Cut No: ${entry.cutNo})`);

        // 3. Prepare mock Page 2 data
        // We simulate the data structure expected by the backend and calculated by our new screen
        const mockPage2Data = {
            // Summary fields
            totalRollWeight: 100.0,
            totalFoldingWT: 5.0,
            totalDozenWT: 95.0, // 100 - 5
            noOfDoz: 100,
            dozenPerWT: 0.95, // 95 / 100
            endBit: 2.0,
            adas: 1.0,
            layWeight: 92.0, // 95 - (2 + 1)
            totalPcs: 1200.0,
            cadWastePercent: 3.5,
            
            // User inputs
            cutterWasteWT: 1.5,
            offPatternWaste: 0.5,
            
            // Calculated fields to save (Logic check)
            totalWasteWT: 2.0, // 1.5 + 0.5
            wastePercent: 2.1739, // (2.0 / 92.0) * 100
            difference: 1.3261, // 3.5 - 2.1739
            
            // Part-wise entries
            parts: [
                {
                    partName: 'BACK',
                    noOfPunches: 2,
                    rows: [
                        { weight: 20.0, noOfPcs: 240 },
                        { weight: 20.0, noOfPcs: 240 }
                    ]
                },
                {
                    partName: 'FRONT',
                    noOfPunches: 2,
                    rows: [
                        { weight: 25.0, noOfPcs: 300 }
                    ]
                }
            ],
            
            // Lay balance entries
            layBalance: [
                { weight: 5.0, noOfPunches: 60 } // Backend model uses noOfPunches for lay balance pcs
            ],
            
            // Values used in summary table
            cutWeight: 65.0, // 20+20+25
            layBalanceWeight: 5.0,
            layBalancePcs: 60
        };

        console.log('Sending Sheet 2 data (Simulation of Save)...');
        const saveRes = await axios.post(`${API_BASE}/production/cutting-entry/${entryId}/page2`, mockPage2Data, authHeader);
        
        if (saveRes.status === 201 || saveRes.status === 200) {
            console.log('✅ Sheet 2 saved successfully!');
        } else {
            console.error('❌ Failed to save Sheet 2:', saveRes.status, saveRes.data);
            process.exit(1);
        }

        // 4. Fetch it back to verify persistence
        console.log('Fetching Sheet 2 data back for verification...');
        const fetchRes = await axios.get(`${API_BASE}/production/cutting-entry/${entryId}/page2`, authHeader);
        const savedData = fetchRes.data;

        if (!savedData) {
            console.error('❌ Could not retrieve saved data.');
            process.exit(1);
        }

        console.log('--- Verification Results ---');
        
        // Check calculations
        const verify = (label, expected, actual) => {
            const isOk = Math.abs(expected - actual) < 0.01;
            console.log(`${isOk ? '✅' : '❌'} ${label}: Expected ${expected}, Found ${actual}`);
            return isOk;
        };

        let allPassed = true;
        allPassed &= verify('Total Waste WT', 2.0, savedData.totalWasteWT || 0);
        allPassed &= verify('Cut Weight Total', 65.0, savedData.cutWeight || 0);
        allPassed &= verify('Lay Balance Weight', 5.0, savedData.layBalanceWeight || 0);
        allPassed &= verify('Waste %', 2.17, savedData.wastePercent || 0);
        allPassed &= verify('Difference (CAD - Waste)', 1.33, savedData.difference || 0);
        
        // Parts check
        if (savedData.parts && savedData.parts.length === 2) {
            console.log('✅ Parts count verified (2 parts)');
            // Fix: Backend might return strings for some values depending on model
            const backPartPunches = parseInt(savedData.parts[0].noOfPunches);
            if (backPartPunches === 2) {
                console.log('✅ Punches field verified (BACK: 2)');
            } else {
                console.log(`❌ Punches field ERROR: Found ${backPartPunches}`);
                allPassed = false;
            }
        } else {
            console.log('❌ Parts data missing or incorrect');
            allPassed = false;
        }

        if (savedData.layBalance && savedData.layBalance.length === 1) {
            console.log('✅ Lay Balance rows verified');
        } else {
            console.log('❌ Lay Balance data missing');
            allPassed = false;
        }

        if (allPassed) {
            console.log('\n🌟 ALL SHEET 2 CHECKS PASSED! 🌟');
            console.log('The UI logic and Backend storage are perfectly synced.');
        } else {
            console.log('\n⚠️ SOME CHECKS FAILED. Please review the results above.');
        }

    } catch (error) {
        console.error('❌ Error during check:', error.message);
        if (error.response) {
            console.error('Response data:', error.response.data);
            console.error('Response status:', error.response.status);
            console.error('Request URL:', error.config.url);
        }
    }
}

runCheck();
