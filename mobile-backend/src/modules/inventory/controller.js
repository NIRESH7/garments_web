import asyncHandler from 'express-async-handler';
import Inward from './inwardModel.js';
import Outward from './outwardModel.js';

// --- INWARD HANDLERS ---

// @desc    Create a new inward entry (Lot Inward Entry)
// @route   POST /api/inventory/inward
// @access  Private
const createInward = asyncHandler(async (req, res) => {
    const {
        inwardDate,
        inTime,
        outTime,
        lotName,
        lotNo,
        fromParty,
        process,
        rate,
        vehicleNo,
        partyDcNo,
        diaEntries,
        storageDetails,
        qualityStatus,
        qualityImage,
        complaintText,
        complaintImage,
        balanceImage,
    } = req.body;

    const inward = await Inward.create({
        user: req.user._id,
        inwardDate,
        inTime,
        outTime,
        lotName,
        lotNo,
        fromParty,
        process,
        rate,
        vehicleNo,
        partyDcNo,
        diaEntries,
        storageDetails,
        qualityStatus,
        qualityImage,
        complaintText,
        complaintImage,
        balanceImage,
    });

    res.status(201).json(inward);
});

// @desc    Get all inward entries
// @route   GET /api/inventory/inward
// @access  Private
const getInwards = asyncHandler(async (req, res) => {
    const inwards = await Inward.find({}).sort({ createdAt: -1 });
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
        items,
    });

    res.status(201).json(outward);
});

// @desc    Get all outward entries
// @route   GET /api/inventory/outward
// @access  Private
const getOutwards = asyncHandler(async (req, res) => {
    const outwards = await Outward.find({}).sort({ createdAt: -1 });
    res.json(outwards);
});

// @desc    Get Lot Aging Report
// @route   GET /api/inventory/reports/aging
// @access  Private
const getLotAgingReport = asyncHandler(async (req, res) => {
    const inwards = await Inward.find({}).sort({ inwardDate: 1 });

    const report = inwards.flatMap((inward) => {
        return inward.diaEntries.map((diaEntry) => ({
            lot_number: inward.lotNo,
            lot_name: inward.lotName,
            inward_date: inward.inwardDate,
            dia: diaEntry.dia,
            rolls: diaEntry.roll,
            weight: diaEntry.recWt,
        }));
    });

    res.json(report);
});

export {
    createInward,
    getInwards,
    getLotsFifo,
    getBalancedSets,
    generateDcNumber,
    createOutward,
    getOutwards,
    getLotAgingReport
};
