import asyncHandler from 'express-async-handler';
import Notification from './model.js';

// @desc    Get user notifications (Notifications Screen)
// @route   GET /api/notifications
// @access  Private
const getNotifications = asyncHandler(async (req, res) => {
    const notifications = await Notification.find({ user: req.user._id }).sort({
        createdAt: -1,
    });
    res.json(notifications);
});

// @desc    Mark notification as read
// @route   PUT /api/notifications/:id
// @access  Private
const markAsRead = asyncHandler(async (req, res) => {
    const notification = await Notification.findById(req.params.id);

    if (notification) {
        if (notification.user.toString() !== req.user._id.toString()) {
            res.status(401);
            throw new Error('Not authorized');
        }
        notification.isRead = true;
        await notification.save();
        res.json({ message: 'Notification marked as read' });
    } else {
        res.status(404);
        throw new Error('Notification not found');
    }
});

export { getNotifications, markAsRead };
