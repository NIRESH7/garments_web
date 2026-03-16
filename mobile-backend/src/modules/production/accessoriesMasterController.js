import asyncHandler from 'express-async-handler';
import AccessoriesMaster from './accessoriesMasterModel.js';

// @desc    Create an Accessories Master entry
// @route   POST /api/production/accessories-master
// @access  Private
const createAccessoriesMaster = asyncHandler(async (req, res) => {
    const { groupSetup, itemAssignment } = req.body;

    const entry = await AccessoriesMaster.create({
        createdBy: req.user._id,
        groupSetup: groupSetup || [],
        itemAssignment: itemAssignment || [],
    });

    res.status(201).json(entry);
});

// @desc    Get all Accessories Master entries
// @route   GET /api/production/accessories-master
// @access  Private
const getAccessoriesMasters = asyncHandler(async (req, res) => {
    const entries = await AccessoriesMaster.find({ createdBy: req.user._id }).sort({
        createdAt: -1,
    });
    res.json(entries);
});

// @desc    Get a single Accessories Master entry
// @route   GET /api/production/accessories-master/:id
// @access  Private
const getAccessoriesMasterById = asyncHandler(async (req, res) => {
    const entry = await AccessoriesMaster.findById(req.params.id);
    if (!entry) {
        res.status(404);
        throw new Error('Accessories master entry not found');
    }
    res.json(entry);
});

// @desc    Update an Accessories Master entry
// @route   PUT /api/production/accessories-master/:id
// @access  Private
const updateAccessoriesMaster = asyncHandler(async (req, res) => {
    const entry = await AccessoriesMaster.findById(req.params.id);

    if (!entry) {
        res.status(404);
        throw new Error('Accessories master entry not found');
    }

    const { groupSetup, itemAssignment } = req.body;

    entry.groupSetup = groupSetup || entry.groupSetup;
    entry.itemAssignment = itemAssignment || entry.itemAssignment;

    const updated = await entry.save();
    res.json(updated);
});

// @desc    Delete an Accessories Master entry
// @route   DELETE /api/production/accessories-master/:id
// @access  Private
const deleteAccessoriesMaster = asyncHandler(async (req, res) => {
    const entry = await AccessoriesMaster.findById(req.params.id);

    if (!entry) {
        res.status(404);
        throw new Error('Accessories master entry not found');
    }

    await AccessoriesMaster.deleteOne({ _id: entry._id });
    res.json({ message: 'Accessories master entry removed' });
});

export {
    createAccessoriesMaster,
    getAccessoriesMasters,
    getAccessoriesMasterById,
    updateAccessoriesMaster,
    deleteAccessoriesMaster,
};
