import asyncHandler from 'express-async-handler';
import Task from './taskModel.js';

// @desc    Create a new task
// @route   POST /api/tasks
// @access  Private/Admin
const createTask = asyncHandler(async (req, res) => {
    const { title, description, voiceDescriptionUrl, assignedTo, priority, deadline, attachmentUrl } = req.body;

    const task = await Task.create({
        admin: req.user._id,
        title,
        description,
        voiceDescriptionUrl,
        assignedTo,
        priority,
        deadline,
        attachmentUrl,
    });

    res.status(201).json(task);
});

// @desc    Get all tasks
// @route   GET /api/tasks
// @access  Private
const getTasks = asyncHandler(async (req, res) => {
    const tasks = await Task.find({}).sort({ createdAt: -1 });
    res.json(tasks);
});

// @desc    Get task by ID
// @route   GET /api/tasks/:id
// @access  Private
const getTaskById = asyncHandler(async (req, res) => {
    const task = await Task.findById(req.params.id);
    if (task) {
        res.json(task);
    } else {
        res.status(404);
        throw new Error('Task not found');
    }
});

// @desc    Add a reply to a task
// @route   POST /api/tasks/:id/reply
// @access  Private
const addTaskReply = asyncHandler(async (req, res) => {
    const { workerName, replyText, voiceReplyUrl, status } = req.body;
    const task = await Task.findById(req.params.id);

    if (task) {
        const reply = {
            workerName,
            replyText,
            voiceReplyUrl,
            type: req.body.type || 'Progress',
        };

        if (status === 'Completed') {
            reply.type = 'Completion';
        }

        task.replies.push(reply);
        if (status) {
            task.status = status;
        }
        await task.save();
        res.status(201).json(task);
    } else {
        res.status(404);
        throw new Error('Task not found');
    }
});

// @desc    Update task status
// @route   PUT /api/tasks/:id/status
// @access  Private
const updateTaskStatus = asyncHandler(async (req, res) => {
    const { status } = req.body;
    const task = await Task.findById(req.params.id);

    if (task) {
        task.status = status;
        const updatedTask = await task.save();
        res.json(updatedTask);
    } else {
        res.status(404);
        throw new Error('Task not found');
    }
});

// @desc    Delete a task
// @route   DELETE /api/tasks/:id
// @access  Private/Admin
const deleteTask = asyncHandler(async (req, res) => {
    const task = await Task.findById(req.params.id);

    if (task) {
        await task.deleteOne();
        res.json({ message: 'Task removed' });
    } else {
        res.status(404);
        throw new Error('Task not found');
    }
});

export { deleteTask, createTask, getTasks, getTaskById, addTaskReply, updateTaskStatus };
