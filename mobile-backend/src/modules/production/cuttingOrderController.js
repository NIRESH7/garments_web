import asyncHandler from 'express-async-handler';
import CuttingOrder from './cuttingOrderModel.js';
import Inward from '../inventory/inwardModel.js';
import Outward from '../inventory/outwardModel.js';
import Assignment from './assignmentModel.js';

// @desc    Create new cutting plan (Planning Sheet)
// @route   POST /api/production/cutting-orders
// @access  Private
const createCuttingOrder = asyncHandler(async (req, res) => {
    const { planType, planPeriod, cuttingEntries, lotAllocations } = req.body;

    // Generate Unique Plan ID: PLN-YYYYMM-001 or PLN-YYYY-001
    const dateStr = new Date().toISOString().slice(0, 7).replace('-', '');
    const count = await CuttingOrder.countDocuments({
        createdAt: {
            $gte: new Date(new Date().setHours(0, 0, 0, 0)),
        },
    });
    const planId = `PLN-${dateStr}-${(count + 1).toString().padStart(3, '0')}`;

    const cuttingOrder = await CuttingOrder.create({
        user: req.user._id,
        planId,
        planType,
        planPeriod,
        cuttingEntries,
        lotAllocations,
    });

    res.status(201).json(cuttingOrder);
});

// @desc    Get FIFO Allocation for Item and Size
// @route   GET /api/production/cutting-orders/fifo-allocation
// @access  Private
const getFifoAllocation = asyncHandler(async (req, res) => {
    const { itemName, size, dozen } = req.query;

    if (!itemName || !size || !dozen) {
        res.status(400);
        throw new Error('Item Name, Size and Dozen are required');
    }

    const targetDozen = parseFloat(dozen);

    // 1. Find Dia from Assignment
    const assignment = await Assignment.findOne({
        fabricItem: { $regex: new RegExp(`^${itemName}$`, 'i') },
        size
    });

    if (!assignment) {
        res.status(404);
        throw new Error(`No assignment found for ${itemName} size ${size}`);
    }

    const { dia, dozenWeight, foldingWt } = assignment;
    const effDozenWeight = dozenWeight + (foldingWt || 0);
    const requiredWeight = targetDozen * effDozenWeight;

    // 2. Find Inward Lots for this Dia, sorted by FIFO
    const inwards = await Inward.find({ 'diaEntries.dia': dia }).sort({ inwardDate: 1, createdAt: 1 });

    let allocations = [];
    let remainingWeight = requiredWeight;
    let totalRollsUsed = 0;

    for (const inw of inwards) {
        if (remainingWeight <= 0) break;

        // Calculate balance for this lot
        const entry = inw.diaEntries.find(e => e.dia === dia);
        if (!entry) continue;

        const totalInwardWt = entry.recWt || 0;
        const lotOutwards = await Outward.find({ lotNo: inw.lotNo, dia });
        let totalOutwardWt = 0;
        lotOutwards.forEach(out => {
            out.items.forEach(item => {
                totalOutwardWt += (item.total_weight || 0);
            });
        });

        const lotBalance = totalInwardWt - totalOutwardWt;

        if (lotBalance > 0.001) {
            const allocatedWt = Math.min(lotBalance, remainingWeight);
            const allocatedDozen = allocatedWt / effDozenWeight;
            const rollsInThisLot = allocatedWt / 20;

            // Get storage details for this lot
            const sd = inw.storageDetails && Array.isArray(inw.storageDetails)
                ? inw.storageDetails.find(s => s.dia === dia)
                : null;

            // Calculate Set Number: 11 rolls = 1 set
            const startRoll = totalRollsUsed;
            const endRoll = totalRollsUsed + rollsInThisLot;
            const startSet = Math.floor(startRoll / 11) + 1;
            const endSet = Math.floor(endRoll / 11) + 1;
            const setNumDisplay = startSet === endSet ? `${startSet}` : `${startSet}-${endSet}`;

            allocations.push({
                lotName: inw.lotName,
                lotNo: inw.lotNo,
                dia: dia,
                dozen: parseFloat(allocatedDozen.toFixed(2)),
                weight: parseFloat(allocatedWt.toFixed(2)),
                rolls: parseFloat(rollsInThisLot.toFixed(2)),
                setNum: setNumDisplay,
                rackName: sd && sd.racks && sd.racks.length > 0 ? sd.racks.join(', ') : 'N/A',
                palletNumber: sd && sd.pallets && sd.pallets.length > 0 ? sd.pallets.join(', ') : 'N/A',
            });

            remainingWeight -= allocatedWt;
            totalRollsUsed += rollsInThisLot;
        }
    }

    if (remainingWeight > 0.1) {
        return res.json({
            success: false,
            message: `Insufficient stock. Short by ${(remainingWeight / effDozenWeight).toFixed(2)} dozens.`,
            allocations
        });
    }

    res.json({
        success: true,
        allocations,
        totalFabric: parseFloat(requiredWeight.toFixed(2)),
        totalRolls: parseFloat(totalRollsUsed.toFixed(2)),
        totalSets: parseFloat((totalRollsUsed / 11).toFixed(2))
    });
});

// @desc    Save Lot Allocation to Planning Sheet
// @route   POST /api/production/cutting-orders/:id/allocate
// @access  Private
const saveLotAllocation = asyncHandler(async (req, res) => {
    const { lotAllocations } = req.body;
    const plan = await CuttingOrder.findById(req.params.id);

    if (!plan) {
        res.status(404);
        throw new Error('Planning Sheet not found');
    }

    // Add new allocations to list
    plan.lotAllocations = [...plan.lotAllocations, ...lotAllocations];
    await plan.save();

    res.json(plan);
});

// @desc    Get all cutting order entries
// @route   GET /api/production/cutting-orders
// @access  Private
const getCuttingOrders = asyncHandler(async (req, res) => {
    const { startDate, endDate } = req.query;

    let query = { user: req.user._id };

    if (startDate || endDate) {
        query.date = {};
        if (startDate) query.date.$gte = new Date(startDate);
        if (endDate) query.date.$lte = new Date(endDate);
    }

    const cuttingOrders = await CuttingOrder.find(query).sort({ date: -1 });
    res.json(cuttingOrders);
});

// @desc    Get a single cutting order by ID
// @route   GET /api/production/cutting-orders/:id
// @access  Private
const getCuttingOrderById = asyncHandler(async (req, res) => {
    const cuttingOrder = await CuttingOrder.findById(req.params.id);

    if (cuttingOrder) {
        res.json(cuttingOrder);
    } else {
        res.status(404);
        throw new Error('Cutting Order not found');
    }
});

// @desc    Delete a cutting order
// @route   DELETE /api/production/cutting-orders/:id
// @access  Private
const deleteCuttingOrder = asyncHandler(async (req, res) => {
    const cuttingOrder = await CuttingOrder.findById(req.params.id);
    if (cuttingOrder) {
        await CuttingOrder.deleteOne({ _id: cuttingOrder._id });
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
};

