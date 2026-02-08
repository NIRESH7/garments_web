import asyncHandler from 'express-async-handler';
import SupportTicket from './model.js';

// @desc    Create support ticket (Support Screen)
// @route   POST /api/support
// @access  Private
const createTicket = asyncHandler(async (req, res) => {
    const { subject, description } = req.body;

    const ticket = await SupportTicket.create({
        user: req.user._id,
        subject,
        description,
        messages: [
            {
                sender: 'user',
                message: description,
            },
        ],
    });

    res.status(201).json(ticket);
});

// @desc    Get user tickets
// @route   GET /api/support
// @access  Private
const getMyTickets = asyncHandler(async (req, res) => {
    const tickets = await SupportTicket.find({ user: req.user._id });
    res.json(tickets);
});

export { createTicket, getMyTickets };
