import asyncHandler from 'express-async-handler';
import Inward from '../inventory/inwardModel.js';
import Outward from '../inventory/outwardModel.js';
import Notification from '../notification/model.js';
import Lot from '../master/lotModel.js';
import ItemAssignment from '../production/assignmentModel.js';

// @desc    Get data for Home Dashboard (Inventory Overview)
// @route   GET /api/home
// @access  Private
const getHomeData = asyncHandler(async (req, res) => {
    // 1. User Info
    const userSummary = {
        name: req.user.name,
        role: 'PRODUCTION',
        avatar: req.user.avatar || '',
    };

    // 2. Notification Count
    const unreadNotificationsCount = await Notification.countDocuments({
        user: req.user._id,
        isRead: false,
    });

    // 3. Recent Inwards
    const recentInwards = await Inward.find({})
        .sort({ createdAt: -1 })
        .limit(3);

    // 4. Summary Metrics
    const totalLotsCount = await Lot.countDocuments({});
    const totalAssignmentsCount = await ItemAssignment.countDocuments({});

    const inwards = await Inward.find({});
    const outwards = await Outward.find({});

    const totalInwardWeight = inwards.reduce((acc, curr) =>
        acc + curr.diaEntries.reduce((a, c) => a + (c.recWt || 0), 0), 0);

    const totalOutwardWeight = outwards.reduce((acc, curr) =>
        acc + (curr.items ? curr.items.reduce((a, c) => a + (c.selected_weight || 0), 0) : 0), 0);

    res.json({
        user: userSummary,
        unreadNotificationsCount,
        recentInwards: recentInwards.map(i => ({
            lot_number: i.lotNo,
            from_party: i.lotName, // Mapping lotName to from_party for UI consistency
            total_weight: i.diaEntries.reduce((a, c) => a + (c.recWt || 0), 0),
            created_at: i.createdAt
        })),
        metrics: {
            total_lots: totalLotsCount,
            total_inward_weight: totalInwardWeight.toFixed(2),
            total_outward_weight: totalOutwardWeight.toFixed(2),
            total_assignments: totalAssignmentsCount,
        },
    });
});

// @desc    Get Splash Screen Config
// @route   GET /api/home/splash
// @access  Public
const getSplashConfig = asyncHandler(async (req, res) => {
    res.json({
        version: '1.0.0',
        minVersion: '1.0.0',
        forceUpdate: false,
        maintenanceMode: false,
        baseUrl: process.env.BASE_URL || 'http://localhost:5001',
    });
});

export { getHomeData, getSplashConfig };
