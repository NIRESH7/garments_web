import asyncHandler from 'express-async-handler';
import Assignment from './assignmentModel.js';

// @desc    Create new item assignment
// @route   POST /api/production/assignments
// @access  Private
const createAssignment = asyncHandler(async (req, res) => {
    const { fabricItem, size, dia, efficiency, dozenWeight } = req.body;

    const assignment = await Assignment.create({
        user: req.user._id,
        fabricItem,
        size,
        dia,
        efficiency,
        dozenWeight,
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

export { createAssignment, getAssignments, deleteAssignment };
