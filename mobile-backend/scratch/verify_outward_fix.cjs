const mongoose = require('mongoose');
const dotenv = require('dotenv');
const path = require('path');
const dns = require('dns');

// Fix for SRV lookup errors
dns.setServers(['8.8.8.8', '8.8.4.4']);

dotenv.config({ path: path.join(__dirname, '../.env') });

async function verifyFix() {
    try {
        await mongoose.connect(process.env.MONGODB_URI);
        console.log('Connected to MongoDB');

        const Inward = mongoose.model('Inward', new mongoose.Schema({
            lotNo: String,
            storageDetails: mongoose.Schema.Types.Mixed,
            diaEntries: mongoose.Schema.Types.Mixed
        }, { collection: 'inwards' }));

        const Outward = mongoose.model('Outward', new mongoose.Schema({
            lotNo: String,
            dia: String,
            dcNo: String,
            items: mongoose.Schema.Types.Mixed
        }, { collection: 'outwards' }));

        // Data from previous investigation
        const lotNo = '2526/00106';
        const dia = '30';
        const targetSet = 'S-2';
        const targetColour = 'NAVY';
        const requestedWeight = 2.254;

        // Mock functions from controller.js
        const normalizeText = (value) => value?.toString().trim() ?? '';
        const escapeRegex = (value) => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
        const canonicalSet = (s) => {
            const normalized = normalizeText(s).toLowerCase().replace(/^set/i, '');
            const numericPart = normalized.replace(/[^0-9]/g, '');
            if (numericPart && !isNaN(numericPart)) return parseInt(numericPart, 10).toString();
            return normalized.replace(/[^a-z0-9]/g, '');
        };
        const canonicalColour = (c) => normalizeText(c).toLowerCase().replace(/[^a-z0-9]/g, '');
        const canonicalKey = (setNo, colour) => `${canonicalSet(setNo)}|${canonicalColour(colour)}`;
        const getSetIdentifierFromRow = (row, idx) => {
            const labels = Array.isArray(row?.setLabels) ? row.setLabels : [];
            const label = normalizeText(labels[idx]);
            return label || (idx + 1).toString();
        };

        console.log(`\n--- Verification for Lot: ${lotNo}, DIA: ${dia}, Set: ${targetSet}, Colour: ${targetColour} ---`);

        const normalizedLotNo = normalizeText(lotNo);
        const normalizedDia = normalizeText(dia);
        const lotRegex = new RegExp(`^\\s*${escapeRegex(normalizedLotNo)}\\s*$`, 'i');
        const diaRegex = new RegExp(`^\\s*${escapeRegex(normalizedDia)}\\s*$`, 'i');

        const [inwards, existingOutwards] = await Promise.all([
            Inward.find({ lotNo: lotRegex, 'diaEntries.dia': diaRegex }),
            Outward.find({ lotNo: lotRegex, dia: diaRegex })
        ]);

        const balanceMap = {};

        inwards.forEach(inw => {
            if (inw.storageDetails && Array.isArray(inw.storageDetails)) {
                inw.storageDetails.forEach(sdOrRow => {
                    const rows = Array.isArray(sdOrRow.rows) ? sdOrRow.rows : [sdOrRow];
                    rows.forEach(row => {
                        const rowDia = normalizeText(row.dia || sdOrRow.dia);
                        if (rowDia && !new RegExp(`^\\s*${escapeRegex(normalizedDia)}\\s*$`, 'i').test(rowDia)) return;

                        const rawColour = normalizeText(row.colour);
                        const weightsArray = row.setWeights || row.stickerDetails;
                        if (weightsArray && Array.isArray(weightsArray)) {
                            weightsArray.forEach((weight, idx) => {
                                const inWeight = parseFloat(weight) || 0;
                                if (inWeight <= 0) return;
                                const rawSetNo = getSetIdentifierFromRow(row, idx);
                                const key = canonicalKey(rawSetNo, rawColour);
                                if (!balanceMap[key]) balanceMap[key] = { weight: 0 };
                                balanceMap[key].weight += inWeight;
                            });
                        }
                    });
                });
            }
        });

        existingOutwards.forEach(out => {
            if (out.items && Array.isArray(out.items)) {
                out.items.forEach(item => {
                    const rawSetNo = normalizeText(item.set_no);
                    if (item.colours && Array.isArray(item.colours)) {
                        item.colours.forEach(c => {
                            const rawColour = normalizeText(c.colour);
                            const outWeight = parseFloat(c.weight) || 0;
                            const key = canonicalKey(rawSetNo, rawColour);
                            if (balanceMap[key]) {
                                balanceMap[key].weight -= outWeight;
                            }
                        });
                    }
                });
            }
        });

        const key = canonicalKey(targetSet, targetColour);
        const available = balanceMap[key] ? balanceMap[key].weight : 0;

        console.log(`Available Balance: ${available.toFixed(3)} KG`);
        console.log(`Requested Weight: ${requestedWeight.toFixed(3)} KG`);

        if (requestedWeight > available + 0.01) {
            console.error('FAILED: Validation would reject this request!');
        } else {
            console.log('PASSED: Validation would accept this request.');
        }

        process.exit(0);
    } catch (err) {
        console.error(err);
        process.exit(1);
    }
}

verifyFix();
