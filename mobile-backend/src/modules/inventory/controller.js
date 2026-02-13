import asyncHandler from 'express-async-handler';
import Inward from './inwardModel.js';
import Outward from './outwardModel.js';

// --- INWARD HANDLERS ---

// @desc    Create a new inward entry (Lot Inward Entry)
// @route   POST /api/inventory/inward
// @access  Private
const createInward = asyncHandler(async (req, res) => {
    try {
        const {
            inwardNo,
            inwardDate,
            inTime,
            outTime,
            lotName,
            lotNo,
            fromParty,
            process,
            rate,
            gsm,
            vehicleNo,
            partyDcNo,
            diaEntries,
            storageDetails,
            qualityStatus,
            qualityImage,
            gsmStatus,
            gsmImage,
            shadeStatus,
            shadeImage,
            washingStatus,
            washingImage,
            complaintText,
            complaintImage,
            balanceImage,
        } = req.body;

        // Handle file uploads for signatures
        let finalLotInchargeSignature = req.body.lotInchargeSignature;
        let finalAuthorizedSignature = req.body.authorizedSignature;
        let finalMdSignature = req.body.mdSignature;

        if (req.files) {
            if (req.files.lotInchargeSignature) {
                finalLotInchargeSignature = req.files.lotInchargeSignature[0].path.replace(/\\/g, '/');
            }
            if (req.files.authorizedSignature) {
                finalAuthorizedSignature = req.files.authorizedSignature[0].path.replace(/\\/g, '/');
            }
            if (req.files.mdSignature) {
                finalMdSignature = req.files.mdSignature[0].path.replace(/\\/g, '/');
            }
        }

        // --- FIX: Parse JSON strings for diaEntries and storageDetails ---
        let processedDiaEntries = diaEntries;
        if (typeof diaEntries === 'string') {
            try {
                processedDiaEntries = JSON.parse(diaEntries);
            } catch (e) {
                console.error('Failed to parse diaEntries JSON:', e);
            }
        }

        let processedStorageDetails = storageDetails;
        if (typeof storageDetails === 'string') {
            try {
                processedStorageDetails = JSON.parse(storageDetails);
            } catch (e) {
                console.error('Failed to parse storageDetails JSON:', e);
            }
        }

        // Generate Inward No if not provided
        let finalInwardNo = inwardNo;
        if (!finalInwardNo) {
            const dateStr = new Date().toISOString().slice(0, 10).replace(/-/g, '');
            const count = await Inward.countDocuments({
                createdAt: {
                    $gte: new Date(new Date().setHours(0, 0, 0, 0)),
                    $lt: new Date(new Date().setHours(23, 59, 59, 999))
                }
            });
            finalInwardNo = `INW-${dateStr}-${(count + 1).toString().padStart(3, '0')}`;
        }

        const inward = await Inward.create({
            user: req.user._id,
            inwardNo: finalInwardNo,
            inwardDate,
            inTime,
            outTime,
            lotName,
            lotNo,
            fromParty,
            process,
            rate: Number(rate) || 0,
            gsm,
            vehicleNo,
            partyDcNo,
            diaEntries: processedDiaEntries,
            storageDetails: processedStorageDetails,
            qualityStatus,
            qualityImage,
            gsmStatus,
            gsmImage,
            shadeStatus,
            shadeImage,
            washingStatus,
            washingImage,
            complaintText,
            complaintImage,
            balanceImage,
            lotInchargeSignature: finalLotInchargeSignature,
            authorizedSignature: finalAuthorizedSignature,
            mdSignature: finalMdSignature,
        });

        res.status(201).json(inward);
    } catch (error) {
        console.error('Error creating inward:', error);
        res.status(500);
        throw new Error(`Failed to create inward: ${error.message}`);
    }
});

// @desc    Get all inward entries
// @route   GET /api/inventory/inward
// @access  Private
const getInwards = asyncHandler(async (req, res) => {
    const { startDate, endDate, fromParty, lotName } = req.query;

    let query = {};
    if (startDate || endDate) {
        query.inwardDate = {};
        if (startDate) query.inwardDate.$gte = startDate;
        if (endDate) query.inwardDate.$lte = endDate;
    }
    if (fromParty) query.fromParty = { $regex: new RegExp(fromParty, 'i') };
    if (lotName) query.lotName = { $regex: new RegExp(lotName, 'i') };

    const inwards = await Inward.find(query).sort({ inwardDate: -1 });
    res.json(inwards);
});

// @desc    Get Lots by DIA for FIFO
// @route   GET /api/inventory/inward/fifo
const getLotsFifo = asyncHandler(async (req, res) => {
    const { dia } = req.query;
    const inwards = await Inward.find({ 'diaEntries.dia': dia }).sort({ inwardDate: 1 });
    const lotNos = [...new Set(inwards.map(i => i.lotNo))];
    res.json(lotNos);
});

// @desc    Get Balanced Sets for Lot and DIA
// @route   GET /api/inventory/inward/balanced-sets
const getBalancedSets = asyncHandler(async (req, res) => {
    const { lotNo, dia } = req.query;
    const inwards = await Inward.find({ lotNo, 'diaEntries.dia': dia });

    // Aggregate sets from storageDetails
    let allSets = [];
    inwards.forEach(inward => {
        if (inward.storageDetails && inward.storageDetails.length > 0) {
            inward.storageDetails.forEach(sd => {
                if (sd.dia === dia) {
                    sd.rows.forEach(row => {
                        row.setWeights.forEach((wt, idx) => {
                            allSets.push({
                                set_no: idx + 1,
                                colour: row.colour,
                                weight: parseFloat(wt) || 0
                            });
                        });
                    });
                }
            });
        }
    });

    // Subtract weights from Outwards
    const outwards = await Outward.find({ lotNo, dia });
    outwards.forEach(outward => {
        outward.items.forEach(item => {
            const setIndex = allSets.findIndex(s => s.set_no === item.set_no && s.colour === item.colour);
            if (setIndex !== -1) {
                allSets[setIndex].weight -= item.selected_weight;
            }
        });
    });

    // Filter out zero/negative weight sets
    const balancedSets = allSets.filter(s => s.weight > 0.01);
    res.json(balancedSets);
});

// @desc    Generate Inward Number (for UI display)
// @route   GET /api/inventory/inward/generate-no
// @access  Private
const generateInwardNumber = asyncHandler(async (req, res) => {
    const dateStr = new Date().toISOString().slice(0, 10).replace(/-/g, '');
    const count = await Inward.countDocuments({
        createdAt: {
            $gte: new Date(new Date().setHours(0, 0, 0, 0)),
            $lt: new Date(new Date().setHours(23, 59, 59, 999)),
        },
    });
    const inwardNo = `INW-${dateStr}-${(count + 1).toString().padStart(3, '0')}`;
    res.json({ inwardNo });
});

// --- OUTWARD HANDLERS ---

// @desc    Generate DC Number
// @route   GET /api/inventory/outward/generate-dc
const generateDcNumber = asyncHandler(async (req, res) => {
    const dateStr = new Date().toISOString().slice(0, 10).replace(/-/g, '');
    const count = await Outward.countDocuments({
        createdAt: {
            $gte: new Date(new Date().setHours(0, 0, 0, 0)),
            $lt: new Date(new Date().setHours(23, 59, 59, 999))
        }
    });
    const dcNo = `DC-${dateStr}-${(count + 1).toString().padStart(3, '0')}`;
    res.json({ dc_number: dcNo });
});

// @desc    Create a new outward entry (Outward Screen)
// @route   POST /api/inventory/outward
// @access  Private
const createOutward = asyncHandler(async (req, res) => {
    const {
        lotName,
        dateTime,
        dia,
        lotNo,
        partyName,
        process,
        address,
        vehicleNo,
        inTime,
        outTime,
        items,
        dc_number,
    } = req.body;

    const dcNo = dc_number || `DC-${Date.now()}`;

    const outward = await Outward.create({
        user: req.user._id,
        dcNo,
        lotName,
        dateTime,
        dia,
        lotNo,
        partyName,
        process,
        address,
        vehicleNo,
        inTime,
        outTime,
        items: items.map(item => ({
            ...item,
            roll_weight: item.roll_weight || 0,
            no_of_rolls: item.no_of_rolls || 0
        })),
    });

    res.status(201).json(outward);
});

// @desc    Get all outward entries
// @route   GET /api/inventory/outward
// @access  Private
const getOutwards = asyncHandler(async (req, res) => {
    const { startDate, endDate, lotName, lotNo, dia } = req.query;

    let query = {};
    if (startDate || endDate) {
        query.dateTime = {}; // Note: dateTime is the field name in Outward model
        if (startDate) query.dateTime.$gte = startDate;
        if (endDate) query.dateTime.$lte = endDate;
    }
    if (lotName) query.lotName = { $regex: new RegExp(lotName, 'i') };
    if (lotNo) query.lotNo = { $regex: new RegExp(lotNo, 'i') };
    if (dia) query.dia = { $regex: new RegExp(dia, 'i') };

    const outwards = await Outward.find(query).sort({ dateTime: -1 });
    res.json(outwards);
});

// @desc    Get Lot Aging Report
// @route   GET /api/inventory/reports/aging
// @access  Private
const getLotAgingReport = asyncHandler(async (req, res) => {
    const { lotNo, lotName, colour, dia } = req.query;

    let query = {};
    if (lotNo) query.lotNo = { $regex: new RegExp(lotNo, 'i') };
    if (lotName) query.lotName = { $regex: new RegExp(lotName, 'i') };
    // Note: Colour and Dia filters need to be applied after expanding diaEntries/storageDetails or by pre-filtering
    // For simplicity with this structure, we'll filter after expansion or build a complex query.
    // Let's filter after mapping for flexibility with the nested arrays.

    const inwards = await Inward.find(query).sort({ inwardDate: 1 });

    let report = [];

    inwards.forEach((inward) => {
        // We need to map diaEntries to storageDetails if possible to get colour
        // Or if storageDetails exist, use them.
        // The requirement is to show Colour. Colour is in storageDetails -> rows -> colour.

        // Strategy: Iterate over storageDetails if available, as they contain the broken-down rolls/weights per colour.
        // If storageDetails is empty (old data or not entered), fallback to diaEntries (colour will be "N/A").

        if (inward.storageDetails && inward.storageDetails.length > 0) {
            inward.storageDetails.forEach(sd => {
                sd.rows.forEach(row => {
                    // Each row has a colour and setWeights
                    // We need total weight/rolls for this colour/dia combination
                    // But wait, storageDetails tracks sets, not necessarily strict rolls count matching diaEntries one-to-one in a simple way 
                    // unless we sum them up.
                    // The user wants "Rolls" and "Wt". 
                    // In storageDetails, we have 'setWeights'. Number of weights = number of sets (which might be rolls if 1 roll = 1 set, but usually multiple rolls).
                    // Actually `diaEntries` has the authoritative `recRoll` and `recWt`.
                    // `storageDetails` is for sticker mapping.
                    // If we want accurate inventory "Stock" aging, we should use the remaining balance. 
                    // But the report seems to be "Aging Details" of *Inwards*, i.e. when it came in.
                    // The requirement says "filter option with lotno,lotname,colour,dia".

                    // Let's explicitly try to link them. 
                    // If we strictly want "Inward" aging, we list what came in.
                    // If we split by colour, we must know how many rolls/weight per colour.
                    // `storageDetails` has `setWeights` (list of weights). count(setWeights) approx rolls (or sets).
                    // Let's assume 1 set ~ 1 roll/bundle for this report or just count the entries.

                    const setWeights = row.setWeights.map(w => parseFloat(w) || 0);
                    const totalWt = setWeights.reduce((a, b) => a + b, 0);
                    const totalRolls = setWeights.length; // Approximate if sets=rolls

                    if (totalWt > 0) {
                        report.push({
                            lot_number: inward.lotNo,
                            lot_name: inward.lotName,
                            inward_date: inward.inwardDate,
                            dia: sd.dia,
                            colour: row.colour, // THE NEW FIELD
                            rolls: totalRolls,
                            weight: totalWt,
                            age: Math.ceil((new Date() - new Date(inward.inwardDate)) / (1000 * 60 * 60 * 24))
                        });
                    }
                });
            });
        } else {
            // Fallback for non-sticker entries
            inward.diaEntries.forEach(entry => {
                report.push({
                    lot_number: inward.lotNo,
                    lot_name: inward.lotName,
                    inward_date: inward.inwardDate,
                    dia: entry.dia,
                    colour: 'N/A',
                    rolls: entry.recRoll,
                    weight: entry.recWt,
                    age: Math.ceil((new Date() - new Date(inward.inwardDate)) / (1000 * 60 * 60 * 24))
                });
            });
        }
    });

    // Apply filters that couldn't be done in DB query easily
    if (colour) {
        report = report.filter(r => r.colour && r.colour.toLowerCase().includes(colour.toLowerCase()));
    }
    if (dia) {
        report = report.filter(r => r.dia && r.dia.toLowerCase().includes(dia.toLowerCase()));
    }

    res.json(report);
});

export {
    createInward,
    getInwards,
    getLotsFifo,
    getBalancedSets,
    generateInwardNumber,
    generateDcNumber,
    createOutward,
    getOutwards,
    getLotAgingReport
};
