import mongoose from 'mongoose';
import dotenv from 'dotenv';
import { runFifo } from './src/modules/production/cuttingOrderController.js';
import CuttingOrder from './src/modules/production/cuttingOrderModel.js';
import Inward from './src/modules/inventory/inwardModel.js';
import Outward from './src/modules/inventory/outwardModel.js';

dotenv.config();

async function runTests() {
    try {
        await mongoose.connect(process.env.MONGODB_URI);
        console.log('✅ Connected to MongoDB');

        // --- TEST 1: Small Allocation Rounding (50 Dozen) ---
        console.log('\n--- Test 1: Small Allocation Rounding (50 Dozen) ---');
        // Simulate a small allocation that would normally result in 0.2 sets
        const smallResult = await runFifo({
            dia: '30',
            effDozenWeight: 5, // kg
            targetDozen: 5,   // Very small
            requiredWeight: 25,
            excludedSets: []
        });

        console.log(`Rolls Allocated: ${smallResult.totalRolls}`);
        console.log(`Sets Allocated: ${smallResult.totalSets}`);
        if (smallResult.totalSets >= 1) {
            console.log('✅ SUCCESS: Minimum 1 set allocated for small quantity.');
        } else {
            console.log('❌ FAILURE: 0 sets allocated for small quantity.');
        }

        // --- TEST 2: Dozen Reduction Logic ---
        console.log('\n--- Test 2: Dozen Reduction Logic ---');
        let plan = await CuttingOrder.findOne({ planName: /nireshmaverick/i });
        if (!plan) {
            console.log('Plan "NIRESHMAVERICK" not found, skipping reduction test.');
        } else {
            // Find any item in the plan
            const entry = plan.cuttingEntries[0];
            if (!entry) {
                console.log('No entries found in plan, skipping.');
            } else {
                const itemName = entry.itemName.trim();
                let size = '75';
                let initialQty = 0;

                // Find a size with some quantity
                const sq = entry.sizeQuantities.toJSON();
                for (let s in sq) {
                    if (sq[s] > 0) {
                        size = s;
                        initialQty = sq[s];
                        break;
                    }
                }

                if (initialQty <= 0) {
                    console.log('No positive quantity found for any size, setting size 75 to 100 first.');
                    entry.sizeQuantities.set('75', 100);
                    initialQty = 100;
                }

                const reductionAmount = 10;
                console.log(`Item: "${itemName}", Size: "${size}"`);
                console.log(`Initial Qty: ${initialQty}`);

                // Simulate the logic in saveLotAllocation
                for (const ent of plan.cuttingEntries) {
                    if (ent.itemName && ent.itemName.trim().toLowerCase() === itemName.toLowerCase()) {
                        if (ent.sizeQuantities) {
                            const currentQty = ent.sizeQuantities.get(size) || 0;
                            ent.sizeQuantities.set(size, Math.max(0, currentQty - reductionAmount));
                        }
                        ent.totalDozens = Math.max(0, (ent.totalDozens || 0) - reductionAmount);
                    }
                }
                plan.markModified('cuttingEntries');
                await plan.save();

                const updatedPlan = await CuttingOrder.findById(plan._id);
                const updatedEntry = updatedPlan.cuttingEntries.find(e => e.itemName.trim().toLowerCase() === itemName.toLowerCase());

                if (!updatedEntry) {
                    console.log('❌ FAILURE: Could not find updated entry in database.');
                } else {
                    const updatedSq = updatedEntry.sizeQuantities.toJSON();
                    console.log('Updated Size Quantities:', JSON.stringify(updatedSq));
                    const updatedQty = updatedSq[size];

                    console.log(`Updated Qty: ${updatedQty}`);
                    if (updatedQty === initialQty - reductionAmount) {
                        console.log('✅ SUCCESS: Planned dozen reduced correctly.');
                    } else {
                        console.log('❌ FAILURE: Dozen reduction mismatch.');
                    }
                }
            }
        }

        // --- TEST 3: Shortfall Accuracy ---
        console.log('\n--- Test 3: Shortfall Accuracy ---');
        // Force a shortfall with a large target
        const largeTarget = 1000;
        const shortfallResult = await runFifo({
            dia: 'NOT_EXISTING_DIA',
            effDozenWeight: 10,
            targetDozen: largeTarget,
            requiredWeight: largeTarget * 10,
            excludedSets: []
        });

        console.log(`Required Weight: ${largeTarget * 10}kg`);
        console.log(`Shortfall Weight: ${shortfallResult.shortfall}kg`);
        const shortfallDozens = (shortfallResult.shortfall / 10).toFixed(2);
        console.log(`Shortfall Dozens: ${shortfallDozens}`);

        if (parseFloat(shortfallDozens) === largeTarget) {
            console.log('✅ SUCCESS: Shortfall exactly matches requested amount when no stock found.');
        } else {
            console.log('❌ FAILURE: Shortfall inflated or incorrect.');
        }

        await mongoose.disconnect();
        console.log('\n--- All Tests Completed ---');
    } catch (err) {
        console.error('❌ Test Execution Error:', err);
        process.exit(1);
    }
}

runTests();
