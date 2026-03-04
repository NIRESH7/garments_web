import asyncHandler from 'express-async-handler';
import CuttingOrder from './cuttingOrderModel.js';
import Inward from '../inventory/inwardModel.js';
import Outward from '../inventory/outwardModel.js';
import Assignment from './assignmentModel.js';

// ─── Constants ────────────────────────────────────────────────────────────────
const ROLLS_PER_SET = 11;

function normalizeDia(value) {
    const raw = (value ?? '').toString().trim();
    if (!raw) return '';
    const numericPart = raw.replace(',', '.').match(/-?\d+(\.\d+)?/);
    const n = numericPart ? Number(numericPart[0]) : Number.NaN;
    if (Number.isNaN(n)) return raw.toLowerCase().replace(/\s+/g, '');
    return Number.isInteger(n) ? String(n) : String(n);
}

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
    const inwards = await Inward.find({})
        .sort({ inwardDate: 1, createdAt: 1 });
    const normalizedDia = normalizeDia(dia);

    const setRows = [];
    let remainingWeight = requiredWeight;
    let globalRollsCounted = 0;
    let totalWprUsed = 0;
    let wprCount = 0;

    // Normalize excludedSets to a Set of numbers
    const excludedSetNos = new Set((excludedSets || []).map(num => parseInt(num)));

    for (const inw of inwards) {
        if (remainingWeight <= 0.001) break;

        const entry = inw.diaEntries.find(e => normalizeDia(e.dia) === normalizedDia);
        if (!entry) continue;

        const totalInwardWt = entry.recWt || 0;

        // Calculate used weight from Outwards
        const outwards = await Outward.find({ lotNo: inw.lotNo });
        let usedWt = 0;

        // Track which set numbers have already been outward-posted for this lot+dia
        const usedSetNos = new Set(excludedSetNos); // Start with externally excluded sets
        outwards.forEach(out => {
            if (normalizeDia(out.dia) !== normalizedDia) return;
            out.items.forEach(item => {
                if (item.set_no) usedSetNos.add(parseInt(item.set_no));
            });
        });

        // Also deduct allocations in CuttingOrders
        const existingAllocations = await CuttingOrder.find({
            'lotAllocations.lotNo': inw.lotNo,
        });

        existingAllocations.forEach(plan => {
            plan.lotAllocations.forEach(alloc => {
                if (
                    alloc.lotNo === inw.lotNo &&
                    normalizeDia(alloc.dia) === normalizedDia
                ) {
                    if (alloc.setNo) usedSetNos.add(parseInt(alloc.setNo));
                }
            });
        });

        const wpr = calcWeightPerRoll(entry, effDozenWeight);

        // Storage Data
        let sd = null;
        let storageDetails = inw.storageDetails;
        if (typeof storageDetails === 'string') {
            try {
                storageDetails = JSON.parse(storageDetails);
            } catch (_) {
                storageDetails = null;
            }
        }
        if (storageDetails) {
            if (Array.isArray(storageDetails)) {
                sd = storageDetails.find(s => normalizeDia(s?.dia) === normalizedDia);
                if (!sd && storageDetails.length === 1) {
                    // Backward compatibility: older records may not carry dia inside storageDetails.
                    sd = storageDetails[0];
                }
            } else if (
                normalizeDia(storageDetails.dia) === normalizedDia ||
                !storageDetails.dia
            ) {
                sd = storageDetails;
            }
        }

        // Build set-wise weights by summing all color rows at the same set index.
        const setWeightMap = new Map();
        let maxSetIndexFromSticker = 0;
        if (sd && Array.isArray(sd.rows)) {
            sd.rows.forEach(row => {
                if (Array.isArray(row.setWeights)) {
                    row.setWeights.forEach((w, idx) => {
                        const val =
                            parseFloat(w.toString().replace(/[^0-9.]/g, '')) || 0;
                        if (val <= 0) return;
                        const setNo = idx + 1;
                        setWeightMap.set(setNo, (setWeightMap.get(setNo) || 0) + val);
                        if (setNo > maxSetIndexFromSticker) {
                            maxSetIndexFromSticker = setNo;
                        }
                    });
                }
            });
        }

        const setsFromDiaEntry = parseInt(entry.sets || 0) || 0;
        const setsFromRecRoll = Math.floor((entry.recRoll || 0) / ROLLS_PER_SET);
        let totalSetsInLot = Math.max(
            maxSetIndexFromSticker,
            setsFromDiaEntry,
            setsFromRecRoll
        );
        if (totalSetsInLot <= 0) {
            totalSetsInLot = Math.max(1, Math.floor(totalInwardWt / (ROLLS_PER_SET * wpr)));
        }

        // Expand into set rows, skipping already-used set numbers
        for (let setNo = 1; remainingWeight > 0.001 && setNo <= totalSetsInLot; setNo++) {
            const rollsInSet = ROLLS_PER_SET;
            const setWeightFromSticker = setWeightMap.get(setNo);
            let actualSetWeight = setWeightFromSticker != null
                ? parseFloat(setWeightFromSticker.toFixed(2))
                : parseFloat((rollsInSet * wpr).toFixed(2));

            // Skip sets that have already been used
            if (!usedSetNos.has(setNo)) {
                // 2. Get Specific Rack/Pallet for this specific set
                const setPositionIndex = setNo - 1;
                let rackName = 'N/A';
                let palletNumber = 'N/A';
                if (sd) {
                    if (Array.isArray(sd.racks) && setPositionIndex < sd.racks.length) {
                        const rackVal = (sd.racks[setPositionIndex] ?? '').toString().trim();
                        rackName = rackVal || 'N/A';
                    }
                    if (Array.isArray(sd.pallets) && setPositionIndex < sd.pallets.length) {
                        const palletVal = (sd.pallets[setPositionIndex] ?? '').toString().trim();
                        palletNumber = palletVal || 'N/A';
                    }
                }

                setRows.push({
                    lotName: inw.lotName,
                    lotNo: inw.lotNo,
                    dia,
                    setNo,
                    rolls: rollsInSet,
                    setWeight: actualSetWeight,
                    rackName,
                    palletNumber,
                    lotBalance: 0, // Not strictly used for math in current frontend
                });

                remainingWeight -= actualSetWeight;
                globalRollsCounted += rollsInSet;
                totalWprUsed += (actualSetWeight / rollsInSet);
                wprCount++;
            }
        }
    }

    const decimalSets = globalRollsCounted / ROLLS_PER_SET;
    const wholeSets = Math.floor(decimalSets);
    const fraction = decimalSets - wholeSets;

    // Custom rule: .5 ku mela iruntha next value, .5 ku Kela iruntha (or .5) whole number only
    let roundedSets = (fraction > 0.5) ? (wholeSets + 1) : wholeSets;

    if (globalRollsCounted > 0 && roundedSets < 1) roundedSets = 1;

    return {
        setRows: setRows,
        totalRolls: parseFloat(globalRollsCounted.toFixed(2)),
        totalSets: roundedSets,
        remainingRolls: 0,
        shortfall: remainingWeight,
        avgWpr: wprCount > 0 ? (totalWprUsed / wprCount) : (effDozenWeight / ROLLS_PER_SET)
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
    console.log('--- GET FIFO ALLOCATION ---');
    console.log(`Params: Item=${itemName}, Size=${size}, Dozen=${targetDozen}, Dia=${queryDia}, DozWt=${queryDozWt}`);

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
    let dia = queryDia || 'Standard';
    let effDozenWeight = queryDozWt ? parseFloat(queryDozWt) : 0;

    if (effDozenWeight > 0) {
        console.log(`Using explicit weight from app: ${effDozenWeight}kg`);
    } else {
        const assignment = await Assignment.findOne({
            fabricItem: { $regex: new RegExp(`^${itemName}$`, 'i') },
            size,
        });
        if (assignment) {
            dia = assignment.dia;
            effDozenWeight = assignment.dozenWeight + (assignment.foldingWt || 0);
            console.log(`Using assignment weight: ${effDozenWeight}kg`);
        } else {
            console.log(`No assignment/explicit weight. Using fallback 24.6kg`);
            effDozenWeight = 24.6;
        }
    }

    const requiredWeight = targetDozen * effDozenWeight;
    console.log(`Required Weight: ${requiredWeight.toFixed(2)}kg`);

    let { setRows, totalRolls, totalSets, remainingRolls, shortfall } =
        await runFifo({ dia, effDozenWeight, targetDozen, requiredWeight, excludedSets: excludedSetList });

    // Client Business Rule: If shortfall exists, add extra sets based on KG
    // - If shortfall > 5kg -> add 1 extra set (11 rolls)
    // - If shortfall > 10kg -> add 2 extra sets (22 rolls)
    if (shortfall > 5 && setRows.length > 0 && shortfall < (requiredWeight * 0.5)) {
        let setsToAdd = (shortfall > 10) ? 2 : 1;
        const weightPerSet = (ROLLS_PER_SET * avgWpr);
        const adjustedWeight = (setRows.reduce((sum, r) => sum + r.setWeight, 0)) + (setsToAdd * weightPerSet);

        console.log(`Weight threshold met: Shortfall ${shortfall.toFixed(2)}kg > 5kg. Retry with ${setsToAdd} extra set(s). New Target: ${adjustedWeight.toFixed(2)}kg`);

        const retry = await runFifo({
            dia,
            effDozenWeight,
            targetDozen,
            requiredWeight: adjustedWeight,
            excludedSets: excludedSetList
        });

        setRows = retry.setRows;
        totalRolls = retry.totalRolls;
        totalSets = retry.totalSets;
        shortfall = retry.shortfall;
    }

    if (shortfall > 5) {
        let msg = `Insufficient stock for Dia ${dia}. `;
        if (setRows.length === 0) {
            msg += `NO STOCK FOUND in warehouse for this dia.`;
        } else {
            msg += `Only ${((requiredWeight - shortfall) / effDozenWeight).toFixed(2)} dozens available. Short by ${(shortfall / effDozenWeight).toFixed(2)} dozens.`;
        }
        return res.json({
            success: false,
            message: msg,
            allocations: setRows,
            totalRolls,
            totalSets,
            remainingRolls,
        });
    }

    res.json({
        success: true,
        allocations: setRows,
        totalFabric: parseFloat((requiredWeight + (shortfall <= 0 ? 0 : shortfall)).toFixed(2)),
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
        postOutward = false,
    } = req.body;

    const plan = await CuttingOrder.findById(req.params.id);
    if (!plan) {
        res.status(404);
        throw new Error('Planning Sheet not found');
    }

    const today = new Date().toISOString().slice(0, 10);
    const enriched = [];

    if (postOutward) {
        for (let i = 0; i < lotAllocations.length; i++) {
            const s = lotAllocations[i];
            const outwardDoc = await Outward.create({
                user: req.user._id,
                dc_number: `AUTO-${Date.now()}-${i}`,
                date: today,
                lotNo: s.lotNo,
                dia: s.dia,
                items: [{
                    lotName: s.lotName,
                    lotNo: s.lotNo,
                    set_no: s.setNo,
                    rolls: s.rolls,
                    total_weight: s.setWeight,
                }],
                status: 'Completed',
            });

            enriched.push({
                ...s,
                day,
                date: date || today,
                itemName,
                size,
                // Only store dozen/weight for the first set in the group to avoid over-counting in balance reports
                dozen: i === 0 ? (dozen || 0) : 0,
                neededWeight: i === 0 ? (neededWeight || 0) : 0,
                outwardId: outwardDoc._id,
                outwardPosted: true,
            });
        }
    } else {
        for (let i = 0; i < lotAllocations.length; i++) {
            const s = lotAllocations[i];
            enriched.push({
                ...s,
                day,
                date: date || today,
                itemName,
                size,
                dozen: i === 0 ? (dozen || 0) : 0,
                neededWeight: i === 0 ? (neededWeight || 0) : 0,
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
// @desc    Delete a specific lot allocation from a plan
// @route   DELETE /api/production/cutting-orders/:id/allocation/:allocationId
const deleteLotAllocation = asyncHandler(async (req, res) => {
    const plan = await CuttingOrder.findById(req.params.id);
    if (!plan) {
        res.status(404);
        throw new Error('Planning Sheet not found');
    }

    const initialLength = plan.lotAllocations.length;
    plan.lotAllocations = plan.lotAllocations.filter(
        (a) => a._id.toString() !== req.params.allocationId
    );

    if (plan.lotAllocations.length === initialLength) {
        res.status(404);
        throw new Error('Allocation not found');
    }

    await plan.save();
    res.json({ success: true, message: 'Allocation removed' });
});

// @desc    Update a specific lot allocation
// @route   PUT /api/production/cutting-orders/:id/allocation/:allocationId
const updateLotAllocation = asyncHandler(async (req, res) => {
    const plan = await CuttingOrder.findById(req.params.id);
    if (!plan) {
        res.status(404);
        throw new Error('Planning Sheet not found');
    }

    const alloc = plan.lotAllocations.id(req.params.allocationId);
    if (!alloc) {
        res.status(404);
        throw new Error('Allocation not found');
    }

    // Only allow updating non-identifying fields to keep logic simple
    alloc.rackName = req.body.rackName ?? alloc.rackName;
    alloc.palletNumber = req.body.palletNumber ?? alloc.palletNumber;
    alloc.dozen = req.body.dozen ?? alloc.dozen;
    alloc.setWeight = req.body.setWeight ?? alloc.setWeight;

    await plan.save();
    res.json({ success: true, allocation: alloc });
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
    deleteLotAllocation,
    updateLotAllocation,
    runFifo
};
