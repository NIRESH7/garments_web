import asyncHandler from 'express-async-handler';
import CuttingOrder from './cuttingOrderModel.js';
import Inward from '../inventory/inwardModel.js';
import Outward from '../inventory/outwardModel.js';
import Assignment from './assignmentModel.js';

// ─── Constants ────────────────────────────────────────────────────────────────
const ROLLS_PER_SET = 11;

// ─── Helper: weight-per-roll from inward entry ────────────────────────────────
function calcWeightPerRoll(entry, effDozenWeight) {
    const recRolls = entry.recRoll || 0;
    const recWt = entry.recWt || 0;
    if (recRolls > 0 && recWt > 0) return recWt / recRolls;
    return effDozenWeight / ROLLS_PER_SET; // fallback
}

// ─── Helper: compute balance weight for a lot+dia ────────────────────────────
async function getLotBalance(inw, dia) {
    const entry = inw.diaEntries.find(e => e.dia === dia);
    if (!entry) return { balance: 0, entry: null, wpr: 0 };
    const totalInwardWt = entry.recWt || 0;
    const outwards = await Outward.find({ lotNo: inw.lotNo, dia });
    let used = 0;
    outwards.forEach(out => out.items.forEach(item => { used += (item.total_weight || 0); }));
    return { balance: totalInwardWt - used, entry, wpr: 0 }; // wpr filled below
}

// ─── FIFO Allocator (core logic, returns set rows) ───────────────────────────
async function runFifo({ dia, effDozenWeight, targetDozen, requiredWeight }) {
    const inwards = await Inward.find({ 'diaEntries.dia': dia })
        .sort({ inwardDate: 1, createdAt: 1 });

    const setRows = [];
    let remainingWeight = requiredWeight;
    let globalRollsCounted = 0;

    for (const inw of inwards) {
        if (remainingWeight <= 0.001) break;

        const entry = inw.diaEntries.find(e => e.dia === dia);
        if (!entry) continue;

        const totalInwardWt = entry.recWt || 0;

        // Calculate used weight from Outwards
        const outwards = await Outward.find({ lotNo: inw.lotNo, dia });
        let usedWt = 0;
        outwards.forEach(out => out.items.forEach(item => { usedWt += (item.total_weight || 0); }));

        // Also deduct allocations in CuttingOrders that are NOT yet posted to outward
        // (If posted, they are already in the Outward query above)
        const existingAllocations = await CuttingOrder.find({
            'lotAllocations.lotNo': inw.lotNo,
            'lotAllocations.dia': dia
        });

        existingAllocations.forEach(plan => {
            plan.lotAllocations.forEach(alloc => {
                if (alloc.lotNo === inw.lotNo && alloc.dia === dia && !alloc.outwardPosted) {
                    usedWt += (alloc.setWeight || 0);
                }
            });
        });

        const lotBalance = totalInwardWt - usedWt;
        if (lotBalance <= 0.001) continue;

        const allocatedWt = Math.min(lotBalance, remainingWeight);
        const wpr = calcWeightPerRoll(entry, effDozenWeight);
        const rollsAlloc = wpr > 0 ? allocatedWt / wpr : 0;

        // Storage
        const sd = inw.storageDetails && Array.isArray(inw.storageDetails)
            ? inw.storageDetails.find(s => s.dia === dia)
            : null;
        const rackName = sd?.racks?.length > 0 ? sd.racks.join(', ') : 'N/A';
        const palletNumber = sd?.pallets?.length > 0 ? sd.pallets.join(', ') : 'N/A';

        // Expand into individual set rows
        let rollsRemaining = rollsAlloc;
        while (rollsRemaining > 0.001) {
            const rollsInSet = Math.min(rollsRemaining, ROLLS_PER_SET);
            const setWeight = parseFloat((rollsInSet * wpr).toFixed(2));
            const setNo = Math.floor(globalRollsCounted / ROLLS_PER_SET) + 1;

            setRows.push({
                lotName: inw.lotName,
                lotNo: inw.lotNo,
                dia,
                setNo,
                rolls: parseFloat(rollsInSet.toFixed(2)),
                setWeight,
                rackName,
                palletNumber,
                lotBalance: parseFloat((lotBalance - allocatedWt).toFixed(2)), // Remaining weight in this specific lot
            });

            globalRollsCounted += rollsInSet;
            rollsRemaining -= rollsInSet;
        }

        remainingWeight -= allocatedWt;
    }

    const totalSets = Math.floor(globalRollsCounted / ROLLS_PER_SET);
    const remainingRolls = parseFloat((globalRollsCounted % ROLLS_PER_SET).toFixed(2));

    return {
        setRows,
        totalRolls: parseFloat(globalRollsCounted.toFixed(2)),
        totalSets,
        remainingRolls,
        shortfall: remainingWeight,
    };
}

// ─────────────────────────────────────────────────────────────────────────────
// @desc    Create new cutting plan (Planning Sheet)
// @route   POST /api/production/cutting-orders
// @access  Private
// ─────────────────────────────────────────────────────────────────────────────
const createCuttingOrder = asyncHandler(async (req, res) => {
    const { planType, planPeriod, cuttingEntries, lotAllocations, planName, startDate, endDate } = req.body;

    const dateStr = new Date().toISOString().slice(0, 10).replace(/-/g, '');
    const prefix = `PLN-${dateStr}-`;
    const lastOrder = await CuttingOrder.findOne({ planId: new RegExp(`^${prefix}`) }).sort({ planId: -1 });
    let nextNum = 1;
    if (lastOrder && lastOrder.planId) {
        const lastNum = parseInt(lastOrder.planId.split('-').pop());
        if (!isNaN(lastNum)) nextNum = lastNum + 1;
    }
    const planId = `${prefix}${nextNum.toString().padStart(4, '0')}`;

    const cuttingOrder = await CuttingOrder.create({
        user: req.user._id,
        planId,
        planName,
        planType,
        planPeriod,
        startDate,
        endDate,
        cuttingEntries,
        lotAllocations: lotAllocations || [],
    });

    res.status(201).json(cuttingOrder);
});

// ─────────────────────────────────────────────────────────────────────────────
// @desc    GET FIFO Allocation — SET-LEVEL, 1 row per set, split across lots
// @route   GET /api/production/cutting-orders/fifo-allocation
// @access  Private
// ─────────────────────────────────────────────────────────────────────────────
const getFifoAllocation = asyncHandler(async (req, res) => {
    const { itemName, size, dozen, dia: queryDia, dozenWeight: queryDozWt } = req.query;

    if (!itemName || !size || !dozen) {
        res.status(400);
        throw new Error('itemName, size and dozen are required');
    }

    const targetDozen = parseFloat(dozen);

    // Resolve dia + dozenWeight ─ prefer explicit params from app
    let dia, effDozenWeight;
    if (queryDia && queryDozWt) {
        dia = queryDia;
        effDozenWeight = parseFloat(queryDozWt);
    } else {
        const assignment = await Assignment.findOne({
            fabricItem: { $regex: new RegExp(`^${itemName}$`, 'i') },
            size,
        });
        if (!assignment) {
            res.status(404);
            throw new Error(`No assignment for ${itemName} size ${size}`);
        }
        dia = assignment.dia;
        effDozenWeight = assignment.dozenWeight + (assignment.foldingWt || 0);
    }

    const requiredWeight = targetDozen * effDozenWeight;

    const { setRows, totalRolls, totalSets, remainingRolls, shortfall } =
        await runFifo({ dia, effDozenWeight, targetDozen, requiredWeight });

    if (shortfall > 0.1) {
        return res.json({
            success: false,
            message: `Insufficient stock. Short by ${(shortfall / effDozenWeight).toFixed(2)} dozens.`,
            allocations: setRows,
            totalRolls,
            totalSets,
            remainingRolls,
        });
    }

    res.json({
        success: true,
        allocations: setRows,
        totalFabric: parseFloat(requiredWeight.toFixed(2)),
        totalRolls,
        totalSets,
        remainingRolls,
    });
});

// ─────────────────────────────────────────────────────────────────────────────
// @desc    Save Lot Allocation + post outward entries per set
// @route   POST /api/production/cutting-orders/:id/allocate
// @access  Private
// ─────────────────────────────────────────────────────────────────────────────
const saveLotAllocation = asyncHandler(async (req, res) => {
    const {
        lotAllocations,   // array of set rows
        day,
        date,
        itemName,
        size,
        dozen,
        neededWeight,
        postOutward,      // boolean — client can control this
    } = req.body;

    const plan = await CuttingOrder.findById(req.params.id);
    if (!plan) {
        res.status(404);
        throw new Error('Planning Sheet not found');
    }

    const today = date || new Date().toISOString().slice(0, 10);

    // Group set-rows by lot to create outward per lot
    const lotGroups = {};
    for (const row of lotAllocations) {
        const key = `${row.lotNo}__${row.dia}`;
        if (!lotGroups[key]) lotGroups[key] = { row, sets: [] };
        lotGroups[key].sets.push(row);
    }

    const enriched = [];

    if (postOutward) {
        // Auto-generate a DC counter prefix
        const dcBase = `FIFO-${today.replace(/-/g, '')}`;
        let dcIndex = await Outward.countDocuments({ dcNo: { $regex: `^${dcBase}` } });

        for (const key of Object.keys(lotGroups)) {
            const { row: firstRow, sets } = lotGroups[key];
            dcIndex++;
            const dcNo = `${dcBase}-${dcIndex.toString().padStart(3, '0')}`;

            const outwardItems = sets.map(s => ({
                set_no: s.setNo.toString(),
                colours: [{ colour: 'N/A', weight: s.setWeight, no_of_rolls: Math.round(s.rolls), roll_weight: s.setWeight }],
                total_weight: s.setWeight,
                rack_name: s.rackName,
                pallet_number: s.palletNumber,
            }));

            const totalWt = sets.reduce((sum, s) => sum + s.setWeight, 0);

            const outwardDoc = await Outward.create({
                user: req.user._id,
                dcNo,
                lotName: firstRow.lotName,
                lotNo: firstRow.lotNo,
                dia: firstRow.dia,
                dateTime: new Date(today),
                partyName: 'FIFO Internal',
                process: `Plan Allocation - ${itemName} ${size} ${day || ''}`,
                items: outwardItems,
            });

            for (const s of sets) {
                enriched.push({
                    ...s, day, date: today, itemName, size, dozen: dozen || 0, neededWeight: neededWeight || 0,
                    outwardId: outwardDoc._id, outwardPosted: true,
                });
            }
        }
    } else {
        for (const s of lotAllocations) {
            enriched.push({
                ...s, day, date: today, itemName, size, dozen: dozen || 0, neededWeight: neededWeight || 0,
            });
        }
    }

    plan.lotAllocations = [...plan.lotAllocations, ...enriched];
    await plan.save();

    res.json({ success: true, plan });
});

// ─────────────────────────────────────────────────────────────────────────────
// @desc    Get Allocation Report (day-wise, set-level)
// @route   GET /api/production/cutting-orders/:id/allocation-report
// @access  Private
// ─────────────────────────────────────────────────────────────────────────────
const getAllocationReport = asyncHandler(async (req, res) => {
    const { day, date } = req.query;
    const plan = await CuttingOrder.findById(req.params.id);
    if (!plan) {
        res.status(404);
        throw new Error('Planning Sheet not found');
    }

    let rows = plan.lotAllocations || [];

    if (day) rows = rows.filter(r => r.day === day);
    if (date) rows = rows.filter(r => r.date === date);

    res.json({
        planId: plan.planId,
        planName: plan.planName,
        period: plan.planPeriod,
        rows,
    });
});

// ─────────────────────────────────────────────────────────────────────────────
// @desc    Get all cutting orders for this user
// @route   GET /api/production/cutting-orders
// @access  Private
// ─────────────────────────────────────────────────────────────────────────────
const getCuttingOrders = asyncHandler(async (req, res) => {
    const { startDate, endDate } = req.query;
    const query = { user: req.user._id };
    if (startDate || endDate) {
        query.date = {};
        if (startDate) query.date.$gte = new Date(startDate);
        if (endDate) query.date.$lte = new Date(endDate);
    }
    const orders = await CuttingOrder.find(query).sort({ date: -1 });
    res.json(orders);
});

// @desc  Get single cutting order
const getCuttingOrderById = asyncHandler(async (req, res) => {
    const order = await CuttingOrder.findById(req.params.id);
    if (order) res.json(order);
    else { res.status(404); throw new Error('Cutting Order not found'); }
});

// @desc  Delete cutting order
const deleteCuttingOrder = asyncHandler(async (req, res) => {
    const order = await CuttingOrder.findById(req.params.id);
    if (order) {
        await CuttingOrder.deleteOne({ _id: order._id });
        res.json({ message: 'Cutting Order removed' });
    } else {
        res.status(404);
        throw new Error('Cutting Order not found');
    }
});

export {
    createCuttingOrder,
    getCuttingOrders,
    getCuttingOrderById,
    deleteCuttingOrder,
    getFifoAllocation,
    saveLotAllocation,
    getAllocationReport,
};
