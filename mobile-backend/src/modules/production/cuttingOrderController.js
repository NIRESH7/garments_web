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
async function runFifo({ dia, effDozenWeight, targetDozen, requiredWeight, excludedSets = [] }) {
    const inwards = await Inward.find({ 'diaEntries.dia': dia })
        .sort({ inwardDate: 1, createdAt: 1 });

    const setRows = [];
    let remainingWeight = requiredWeight;
    let globalRollsCounted = 0;

    // Normalize excludedSets to a Set of numbers
    const excludedSetNos = new Set((excludedSets || []).map(num => parseInt(num)));

    for (const inw of inwards) {
        if (remainingWeight <= 0.001) break;

        const entry = inw.diaEntries.find(e => e.dia === dia);
        if (!entry) continue;

        const totalInwardWt = entry.recWt || 0;

        // Calculate used weight from Outwards
        const outwards = await Outward.find({ lotNo: inw.lotNo, dia });
        let usedWt = 0;

        // Track which set numbers have already been outward-posted for this lot+dia
        const usedSetNos = new Set(excludedSetNos); // Start with externally excluded sets
        outwards.forEach(out => out.items.forEach(item => {
            usedWt += (item.total_weight || 0);
            if (item.set_no) usedSetNos.add(parseInt(item.set_no));
        }));

        // Also deduct allocations in CuttingOrders that are NOT yet posted to outward
        const existingAllocations = await CuttingOrder.find({
            'lotAllocations.lotNo': inw.lotNo,
            'lotAllocations.dia': dia
        });

        existingAllocations.forEach(plan => {
            plan.lotAllocations.forEach(alloc => {
                if (alloc.lotNo === inw.lotNo && alloc.dia === dia) {
                    if (!alloc.outwardPosted) {
                        usedWt += (alloc.setWeight || 0);
                    }
                    // Track used set numbers regardless of outwardPosted status
                    if (alloc.setNo) usedSetNos.add(parseInt(alloc.setNo));
                }
            });
        });

        const lotBalance = totalInwardWt - usedWt;
        if (lotBalance <= 0.001) continue;

        const allocatedWt = Math.min(lotBalance, remainingWeight);
        const wpr = calcWeightPerRoll(entry, effDozenWeight);
        const rollsAlloc = wpr > 0 ? allocatedWt / wpr : 0;

        // Storage Data
        const sd = inw.storageDetails && Array.isArray(inw.storageDetails)
            ? inw.storageDetails.find(s => s.dia === dia)
            : null;

        // Flatten all weights across all colors for this DIA to get a sequence of set weights
        const allInwardWeights = [];
        if (sd && sd.rows) {
            sd.rows.forEach(row => {
                if (row.setWeights && Array.isArray(row.setWeights)) {
                    row.setWeights.forEach(w => {
                        const val = parseFloat(w.toString().replace(/[^0-9.]/g, '')) || 0;
                        if (val > 0) allInwardWeights.push(val);
                    });
                }
            });
        }

        // Expand into individual set rows, skipping already-used set numbers
        let rollsNeeded = rollsAlloc;
        let setIndexInLot = 0; // index into storageDetail arrays
        let lotLevelRollsCounted = 0; // local counter to determine set number within this lot

        while (rollsNeeded > 0.001) {
            const rollsInSet = Math.min(rollsNeeded, ROLLS_PER_SET);
            // Use lot-level counter for set number to stay consistent with stickers
            const setNo = Math.floor(lotLevelRollsCounted / ROLLS_PER_SET) + 1;

            // 1. Get Actual Weight from inward if available, else use calculated
            let actualSetWeight = 0;
            const rollsInt = Math.round(rollsInSet);
            let hasStickerWeights = false;

            for (let i = 0; i < rollsInt; i++) {
                const w = allInwardWeights[setIndexInLot + i];
                if (w !== undefined) {
                    actualSetWeight += w;
                    hasStickerWeights = true;
                }
            }

            if (!hasStickerWeights) {
                actualSetWeight = parseFloat((rollsInSet * wpr).toFixed(2));
            } else {
                actualSetWeight = parseFloat(actualSetWeight.toFixed(2));
            }

            // 2. Get Specific Rack/Pallet for this specific set
            let rackName = 'N/A';
            let palletNumber = 'N/A';
            if (sd) {
                // We use the rack/pallet of the FIRST roll in this set
                if (sd.racks && sd.racks[setIndexInLot]) rackName = sd.racks[setIndexInLot];
                if (sd.pallets && sd.pallets[setIndexInLot]) palletNumber = sd.pallets[setIndexInLot];
            }

            // Skip sets that have already been used
            if (!usedSetNos.has(setNo)) {
                setRows.push({
                    lotName: inw.lotName,
                    lotNo: inw.lotNo,
                    dia,
                    setNo,
                    rolls: parseFloat(rollsInSet.toFixed(2)),
                    setWeight: actualSetWeight,
                    rackName,
                    palletNumber,
                    lotBalance: parseFloat((lotBalance - actualSetWeight).toFixed(2)),
                });
                rollsNeeded -= rollsInSet;
                globalRollsCounted += rollsInSet;
            }

            lotLevelRollsCounted += rollsInSet;
            setIndexInLot += rollsInt;

            // Safety break: if we've exhausted the sticker weights or rolls in lot, stop
            if (setIndexInLot >= (allInwardWeights.length > 0 ? allInwardWeights.length : totalInwardWt / wpr)) {
                break;
            }
        }

        remainingWeight -= allocatedWt;
    }

    const decimalSets = globalRollsCounted / ROLLS_PER_SET;
    const roundedSets = Math.round(decimalSets);

    // Filter granular setRows to include only rows up to roundedSets
    const filteredRows = setRows.filter(r => r.setNo <= roundedSets);

    return {
        setRows: filteredRows,
        totalRolls: parseFloat(globalRollsCounted.toFixed(2)),
        totalSets: roundedSets,
        remainingRolls: 0,
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
    const { itemName, size, dozen, dia: queryDia, dozenWeight: queryDozWt, excludedSets } = req.query;

    if (!itemName || !size || !dozen) {
        res.status(400);
        throw new Error('itemName, size and dozen are required');
    }

    const targetDozen = parseFloat(dozen);

    // Parse excludedSets if provided
    let excludedSetList = [];
    if (excludedSets) {
        if (Array.isArray(excludedSets)) {
            excludedSetList = excludedSets;
        } else {
            excludedSetList = excludedSets.split(',').filter(x => x).map(x => parseInt(x));
        }
    }

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
        await runFifo({ dia, effDozenWeight, targetDozen, requiredWeight, excludedSets: excludedSetList });

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

// @desc    Get previous planning entries by planName and dates
// @route   GET /api/production/cutting-orders/previous-entries
const getPreviousPlanning = asyncHandler(async (req, res) => {
    const { planName, startDate, endDate } = req.query;

    if (!planName) {
        res.status(400);
        throw new Error('planName is required');
    }

    const query = {
        planName: { $regex: new RegExp(`^${planName.trim()}$`, 'i') },
    };

    if (startDate && endDate) {
        query.startDate = { $gte: new Date(startDate) };
        query.endDate = { $lte: new Date(endDate) };
    }

    const orders = await CuttingOrder.find(query).sort({ createdAt: -1 });

    // Aggregate entries to show a unified view of what's already planned
    const aggregatedEntries = [];
    orders.forEach(order => {
        order.cuttingEntries.forEach(entry => {
            const existingIdx = aggregatedEntries.findIndex(e => e.itemName === entry.itemName);
            if (existingIdx > -1) {
                // Merge size quantities
                Object.keys(entry.sizeQuantities).forEach(size => {
                    aggregatedEntries[existingIdx].sizeQuantities[size] = (aggregatedEntries[existingIdx].sizeQuantities[size] || 0) + (entry.sizeQuantities[size] || 0);
                });
                aggregatedEntries[existingIdx].totalDozens += (entry.totalDozens || 0);
            } else {
                aggregatedEntries.push({
                    itemName: entry.itemName,
                    sizeQuantities: JSON.parse(JSON.stringify(entry.sizeQuantities)),
                    totalDozens: entry.totalDozens
                });
            }
        });
    });

    res.json(aggregatedEntries);
});

// @desc    Get Cut Order Plan Report with Pending Dozen calculation
// @route   GET /api/production/cutting-orders/report
const getCuttingPlanReport = asyncHandler(async (req, res) => {
    const { startDate, endDate, itemName, size } = req.query;

    const query = {};
    if (startDate || endDate) {
        query.date = {};
        if (startDate) query.date.$gte = new Date(startDate);
        if (endDate) query.date.$lte = new Date(endDate);
    }

    const orders = await CuttingOrder.find(query).sort({ date: -1 });

    const report = [];

    orders.forEach(order => {
        // First, handle the planned quantities from cuttingEntries
        order.cuttingEntries.forEach(entry => {
            if (itemName && entry.itemName.toLowerCase() !== itemName.toLowerCase()) return;

            Object.keys(entry.sizeQuantities).forEach(sz => {
                if (size && sz !== size) return;

                const planned = entry.sizeQuantities[sz] || 0;
                if (planned <= 0) return;

                // Find matching allocations for this plan, item, and size
                const allocated = order.lotAllocations
                    .filter(alloc => alloc.itemName === entry.itemName && alloc.size === sz)
                    .reduce((sum, alloc) => sum + (alloc.dozen || 0), 0);

                report.push({
                    planId: order.planId,
                    planName: order.planName,
                    planType: order.planType,
                    date: order.date,
                    itemName: entry.itemName,
                    size: sz,
                    planned,
                    issued: allocated,
                    pending: Math.max(0, planned - allocated)
                });
            });
        });
    });

    // If size filter is applied but planned was 0, maybe there are only allocations?
    // (Unlikely in this workflow but good for robustness)

    res.json(report);
});

// @desc    Update cutting order
// @route   PUT /api/production/cutting-orders/:id
// @access  Private
const updateCuttingOrder = asyncHandler(async (req, res) => {
    const cutOrder = await CuttingOrder.findById(req.params.id);

    if (cutOrder) {
        cutOrder.planName = req.body.planName || cutOrder.planName;
        cutOrder.planType = req.body.planType || cutOrder.planType;
        cutOrder.planPeriod = req.body.planPeriod || cutOrder.planPeriod;
        cutOrder.startDate = req.body.startDate || cutOrder.startDate;
        cutOrder.endDate = req.body.endDate || cutOrder.endDate;
        cutOrder.sizeType = req.body.sizeType || cutOrder.sizeType;
        cutOrder.cuttingEntries = req.body.cuttingEntries || cutOrder.cuttingEntries;
        cutOrder.status = req.body.status || cutOrder.status;

        const updatedOrder = await cutOrder.save();
        res.json(updatedOrder);
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
    getPreviousPlanning,
    getCuttingPlanReport,
    updateCuttingOrder,
};
