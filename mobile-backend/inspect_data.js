import mongoose from 'mongoose';
import dotenv from 'dotenv';
import Inward from './src/modules/inventory/inwardModel.js';
import Outward from './src/modules/inventory/outwardModel.js';

dotenv.config();

const lotNo = "test_1";
const dia = "test";

const inspect = async () => {
    try {
        console.log(`Connecting to ${process.env.MONGODB_URI}...`);
        await mongoose.connect(process.env.MONGODB_URI);
        console.log('Connected.');

        const inwards = await Inward.find({ lotNo, 'diaEntries.dia': dia });
        console.log(`\n=== INWARDS Found (${inwards.length}) ===`);
        inwards.forEach(inw => {
            console.log(`- INW: ${inw.inwardNo || inw._id}`);
            inw.storageDetails?.forEach(sd => {
                if (sd.dia === dia) {
                    sd.rows?.forEach(row => {
                        console.log(`  Row: ${row.colour}`);
                        row.setWeights?.forEach((wt, idx) => {
                            const labels = row.setLabels || [];
                            console.log(`    Set[${idx}]: ${labels[idx] || (idx+1)} = ${wt}kg`);
                        });
                    });
                }
            });
        });

        const outwards = await Outward.find({ lotNo, dia });
        console.log(`\n=== OUTWARDS Found (${outwards.length}) ===`);
        outwards.forEach(out => {
            console.log(`- DC: ${out.dcNo}`);
            out.items?.forEach(item => {
                console.log(`  Set: ${item.set_no}`);
                item.colours?.forEach(c => {
                    console.log(`    Colour: ${c.colour} = ${c.weight}kg`);
                });
            });
        });

        process.exit(0);
    } catch (err) {
        console.error(err);
        process.exit(1);
    }
};

inspect();
