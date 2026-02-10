
import mongoose from 'mongoose';
import dotenv from 'dotenv';
import Inward from '../src/modules/inventory/inwardModel.js';
import path from 'path';

// Load env vars from parent directory (mobile-backend)
dotenv.config({ path: path.resolve(process.cwd(), '.env') });

const migrate = async () => {
    try {
        await mongoose.connect(process.env.MONGODB_URI);
        console.log('MongoDB Connected');

        // Find all inwards without inwardNo
        const inwards = await Inward.find({ inwardNo: { $exists: false } }).sort({ inwardDate: 1, createdAt: 1 });

        console.log(`Found ${inwards.length} inwards to migrate.`);

        // Group by date to generate sequential IDs per date
        // However, the original logic in controller is:
        // INW-YYYYMMDD-XXX
        // The count is based on documents created on that day.
        // For backfilling, we should group by inwardDate (or createdAt?) and assign sequence.
        // Let's use inwardDate as the date part of ID, which respects the business logic.

        // We need to keep track of counts per date to generate the sequence
        const dateCounts = {};

        // FIRST, we need to know existing counts if any (in case partial migration or mixed data)
        // But here we are migrating docs that DON'T have inwardNo.
        // There might be docs WITH inwardNo for the same existing dates.
        // So we should query ALL docs to establish the correct counters, but only Update the missing ones.

        // Let's fetch ALL inwards to build the counters correctly
        const allInwards = await Inward.find({}).sort({ inwardDate: 1, createdAt: 1 });

        console.log(`Total inwards in DB: ${allInwards.length}`);

        let updatedCount = 0;

        for (const inward of allInwards) {
            // Determine date string from inwardDate
            const dateStr = new Date(inward.inwardDate).toISOString().slice(0, 10).replace(/-/g, '');

            // Initialize count for this date if new
            if (!dateCounts[dateStr]) {
                dateCounts[dateStr] = 0;
            }

            // Increment count for this date
            dateCounts[dateStr]++;

            if (!inward.inwardNo || (inward.diaEntries && inward.diaEntries.some(e => e.rate === undefined || e.rate === null))) {
                if (!inward.inwardNo) {
                    const seq = dateCounts[dateStr].toString().padStart(3, '0');
                    inward.inwardNo = `INW-${dateStr}-${seq}`;
                }

                // Patch missing rate in diaEntries to satisfy validation
                if (inward.diaEntries) {
                    inward.diaEntries.forEach(entry => {
                        if (entry.rate === undefined || entry.rate === null) {
                            entry.rate = 0;
                        }
                    });
                }

                await inward.save({ validateModifiedOnly: true }); // Try to validate only modified paths if possible, but mongoose validates full doc usually. 
                // Actually, just save() triggers full validation. By fixing the data we should be good.                console.log(`Updated Inward: ${inward._id} -> ${inward.inwardNo}`);
                updatedCount++;
            } else {
                // If it already has one, ensure our counter respects it (or just count it as we did)
                // We just counted it above, so the next one will be +1.
                // NOTE: If existing IDs are out of order or gaps exist, this simple counting might clash if we insist on strictly following the sequence.
                // But since we are iterating sorted by date, we are effectively re-simulating the sequence generation.
                // If the existing inwardNo doesn't match our expected sequence, we might leave it alone but increment our counter.
                // The safest is to rely on the counter we build up.
                // Wait, if an existing record has INW-20231027-005, and we are at count 3, we should probably jump or just accept that we are counting "Nth document of the day".
                // The Controller logic uses `countDocuments` for that day. So it effectively says "if there are 5 docs today, next is 6".
                // So relying on `dateCounts` incrementing for every doc encountered is consistent with `countDocuments`.
            }
        }

        console.log(`Migration completed. Updated ${updatedCount} documents.`);
        process.exit();

    } catch (error) {
        console.error(`Error: ${error.message}`);
        process.exit(1);
    }
};

migrate();
