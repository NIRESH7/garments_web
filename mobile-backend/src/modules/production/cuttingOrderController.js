import asyncHandler from 'express-async-handler';
import CuttingOrder from './cuttingOrderModel.js';

// @desc    Create new cutting order entry
// @route   POST /api/production/cutting-orders
// @access  Private
const createCuttingOrder = asyncHandler(async (req, res) => {
    const { date, cuttingEntries, lotRequirements } = req.body;

    const cuttingOrder = await CuttingOrder.create({
        user: req.user._id,
        date: date || new Date(),
        cuttingEntries,
        lotRequirements,
    });

    res.status(201).json(cuttingOrder);
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
        if (cuttingOrder.user.toString() !== req.user._id.toString()) {
            res.status(401);
            throw new Error('Not authorized');
        }
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
        if (cuttingOrder.user.toString() !== req.user._id.toString()) {
            res.status(401);
            throw new Error('Not authorized');
        }
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
};
