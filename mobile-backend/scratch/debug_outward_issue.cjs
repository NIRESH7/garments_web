const mongoose = require('mongoose');
const dotenv = require('dotenv');
const path = require('path');
const dns = require('dns');

// Fix for SRV lookup errors
dns.setServers(['8.8.8.8', '8.8.4.4']);

dotenv.config({ path: path.join(__dirname, '../.env') });

async function checkStock() {
    try {
        await mongoose.connect(process.env.MONGODB_URI);
        console.log('Connected to MongoDB');

        const Inward = mongoose.model('Inward', new mongoose.Schema({
            lotNo: String,
            storageDetails: mongoose.Schema.Types.Mixed
        }, { collection: 'inwards' }));

        const Outward = mongoose.model('Outward', new mongoose.Schema({
            lotNo: String,
            dia: String,
            dcNo: String,
            items: mongoose.Schema.Types.Mixed
        }, { collection: 'outwards' }));

        const lotNo = '2526/00106';
        const dia = '30';
        const targetSet = 'S-2';
        const targetColour = 'NAVY';

        console.log(`\n--- Investigating Lot: ${lotNo}, DIA: ${dia}, Set: ${targetSet}, Colour: ${targetColour} ---`);

        const inwards = await Inward.find({ lotNo });
        console.log(`Found ${inwards.length} Inward docs.`);

        let totalInwardWt = 0;
        inwards.forEach(inw => {
            if (inw.storageDetails && Array.isArray(inw.storageDetails)) {
                inw.storageDetails.forEach(sd => {
                    if (sd.dia === dia) {
                        const rows = Array.isArray(sd.rows) ? sd.rows : [sd];
                        rows.forEach(row => {
                            if (row.colour && row.colour.toLowerCase() === targetColour.toLowerCase()) {
                                const weights = row.setWeights || row.stickerDetails || [];
                                weights.forEach((w, idx) => {
                                    const setNo = row.setNo && Array.isArray(row.setNo) ? row.setNo[idx] : (row.setNo || `S-${idx + 1}`);
                                    if (setNo === targetSet) {
                                        totalInwardWt += parseFloat(w) || 0;
                                        console.log(`Inward Match: ${totalInwardWt} (from ${w})`);
                                    }
                                });
                            }
                        });
                    }
                });
            }
        });

        const outwards = await Outward.find({ lotNo, dia });
        console.log(`Found ${outwards.length} Outward docs.`);

        let totalOutwardWt = 0;
        outwards.forEach(out => {
            if (out.items && Array.isArray(out.items)) {
                out.items.forEach(item => {
                    if (item.set_no === targetSet && item.colours) {
                        item.colours.forEach(c => {
                            if (c.colour.toLowerCase() === targetColour.toLowerCase()) {
                                totalOutwardWt += parseFloat(c.weight) || 0;
                                console.log(`Outward Match (DC: ${out.dcNo}): ${c.weight}`);
                            }
                        });
                    }
                });
            }
        });

        console.log(`\nResults:`);
        console.log(`Total Inward Weight: ${totalInwardWt}`);
        console.log(`Total Outward Weight: ${totalOutwardWt}`);
        console.log(`Balance: ${totalInwardWt - totalOutwardWt}`);

        process.exit(0);
    } catch (err) {
        console.error(err);
        process.exit(1);
    }
}

checkStock();
