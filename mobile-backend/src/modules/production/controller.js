import asyncHandler from 'express-async-handler';
import Assignment from './assignmentModel.js';

// @desc    Create new item assignment
// @route   POST /api/production/assignments
// @access  Private
const createAssignment = asyncHandler(async (req, res) => {
    const { fabricItem, size, dia, efficiency, dozenWeight, layLength, layPcs, wastePercentage, foldingWt, lotName, gsm } = req.body;

    const assignment = await Assignment.create({
        user: req.user._id,
        fabricItem,
        size,
        dia,
        efficiency,
        dozenWeight,
        layLength,
        layPcs,
        wastePercentage,
        foldingWt,
        lotName,
        gsm,
    });

    res.status(201).json(assignment);
});

// @desc    Get all item assignments
// @route   GET /api/production/assignments
// @access  Private
const getAssignments = asyncHandler(async (req, res) => {
    const assignments = await Assignment.find({ user: req.user._id }).sort({
        createdAt: -1,
    });
    res.json(assignments);
});

// @desc    Delete an assignment
// @route   DELETE /api/production/assignments/:id
// @access  Private
const deleteAssignment = asyncHandler(async (req, res) => {
    const assignment = await Assignment.findById(req.params.id);

    if (assignment) {
        if (assignment.user.toString() !== req.user._id.toString()) {
            res.status(401);
            throw new Error('Not authorized');
        }
        await Assignment.deleteOne({ _id: assignment._id });
        res.json({ message: 'Assignment removed' });
    } else {
        res.status(404);
        throw new Error('Assignment not found');
    }
});

// @desc    Update an assignment
// @route   PUT /api/production/assignments/:id
// @access  Private
const updateAssignment = asyncHandler(async (req, res) => {
    const assignment = await Assignment.findById(req.params.id);

    if (!assignment) {
        res.status(404);
        throw new Error('Assignment not found');
    }

    if (assignment.user.toString() !== req.user._id.toString()) {
        res.status(401);
        throw new Error('Not authorized');
    }

    const { fabricItem, size, dia, efficiency, dozenWeight, layLength, layPcs, wastePercentage, foldingWt, lotName, gsm } = req.body;

    assignment.fabricItem      = fabricItem      ?? assignment.fabricItem;
    assignment.size            = size            ?? assignment.size;
    assignment.dia             = dia             ?? assignment.dia;
    assignment.efficiency      = efficiency      ?? assignment.efficiency;
    assignment.dozenWeight     = dozenWeight     ?? assignment.dozenWeight;
    assignment.layLength       = layLength       ?? assignment.layLength;
    assignment.layPcs          = layPcs          ?? assignment.layPcs;
    assignment.wastePercentage = wastePercentage ?? assignment.wastePercentage;
    assignment.foldingWt       = foldingWt       ?? assignment.foldingWt;
    assignment.lotName         = lotName         ?? assignment.lotName;
    assignment.gsm             = gsm             ?? assignment.gsm;

    const updated = await assignment.save();
    res.json(updated);
});

export { createAssignment, getAssignments, deleteAssignment, updateAssignment };
