import asyncHandler from 'express-async-handler';
import Inward from '../inventory/inwardModel.js';
import Outward from '../inventory/outwardModel.js';
import Notification from '../notification/model.js';
import Lot from '../master/lotModel.js';
import ItemAssignment from '../production/assignmentModel.js';

// @desc    Get data for Home Dashboard (Inventory Overview)
// @route   GET /api/home
// @access  Private
// @desc    Get data for Home Dashboard (Inventory Overview)
// @route   GET /api/home
// @access  Private
const getHomeData = asyncHandler(async (req, res) => {
    try {
        const { startDate, endDate, lotName, dia } = req.query;

        const start = startDate ? new Date(startDate) : new Date(new Date().setHours(0, 0, 0, 0));
        const end = endDate ? new Date(endDate) : new Date(new Date().setHours(23, 59, 59, 999));

        console.log(`[Dashboard] Fetching stats for period: ${start.toISOString()} to ${end.toISOString()}, lotName: ${lotName}, dia: ${dia}`);

        // 1. User Info
        const userSummary = {
            name: req.user?.name || 'User',
            role: 'PRODUCTION',
            avatar: req.user?.avatar || '',
        };

        // 2. Notification Count
        const unreadNotificationsCount = await Notification.countDocuments({
            user: req.user?._id,
            isRead: false,
        }).catch(() => 0);

        // --- CALCULATION LOGIC ---

        // Helper to get weight/rolls from inward/outward
        const getInwardTotals = (list) => {
            let weight = 0;
            let rolls = 0;
            list.forEach(i => {
                if (lotName && i.lotName && !new RegExp('^' + lotName.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&') + '$', 'i').test(i.lotName)) return;
                if (!i.diaEntries) return;
                i.diaEntries.forEach(de => {
                    if (dia && de.dia !== dia) return;
                    weight += parseFloat(de.recWt || 0);
                    rolls += parseInt(de.recRoll || de.roll || 0);
                });
            });
            return { weight, rolls };
        };

        const getOutwardTotals = (list) => {
            let weight = 0;
            let rolls = 0;
            list.forEach(o => {
                if (lotName && o.lotName && !new RegExp('^' + lotName.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&') + '$', 'i').test(o.lotName)) return;
                if (dia && o.dia !== dia) return;
                if (!o.items) return;
                o.items.forEach(item => {
                    weight += parseFloat(item.total_weight || 0);
                    if (item.colours) {
                        item.colours.forEach(c => {
                            rolls += parseInt(c.no_of_rolls || 0);
                        });
                    }
                });
            });
            return { weight, rolls };
        };

        // Fetch all records for full balance calculation (Closing Stock = Opening + In - Out)
        const allInwards = await Inward.find({}).lean();
        const allOutwards = await Outward.find({}).lean();

        // 1. Opening Stock (Before start date)
        const openingInwards = allInwards.filter(i => i.inwardDate && new Date(i.inwardDate) < start);
        const openingOutwards = allOutwards.filter(o => o.dateTime && new Date(o.dateTime) < start);
        const openingInTotals = getInwardTotals(openingInwards);
        const openingOutTotals = getOutwardTotals(openingOutwards);

        const openingStock = {
            weight: (openingInTotals.weight - openingOutTotals.weight).toFixed(2),
            rolls: (openingInTotals.rolls - openingOutTotals.rolls)
        };

        // 2. Inward (In period)
        const periodInwards = allInwards.filter(i => i.inwardDate && new Date(i.inwardDate) >= start && new Date(i.inwardDate) <= end);
        const inwardTotals = getInwardTotals(periodInwards);

        // 3. Outward (In period)
        const periodOutwards = allOutwards.filter(o => o.dateTime && new Date(o.dateTime) >= start && new Date(o.dateTime) <= end);
        const outwardTotals = getOutwardTotals(periodOutwards);

        // 4. Closing Stock
        const closingWeight = parseFloat(openingStock.weight) + inwardTotals.weight - outwardTotals.weight;
        const closingRolls = openingStock.rolls + inwardTotals.rolls - outwardTotals.rolls;

        // 5. Recent Inwards (Global or filtered)
        const recentDisplayQuery = {};
        if (lotName) recentDisplayQuery.lotName = { $regex: new RegExp('^' + lotName.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&') + '$', 'i') };
        const recentInwardsRaw = await Inward.find(recentDisplayQuery)
            .sort({ inwardDate: -1 })
            .limit(3);

        res.json({
            user: userSummary,
            unreadNotificationsCount,
            summary: {
                opening: openingStock,
                inward: { weight: inwardTotals.weight.toFixed(2), rolls: inwardTotals.rolls },
                outward: { weight: outwardTotals.weight.toFixed(2), rolls: outwardTotals.rolls },
                closing: { weight: closingWeight.toFixed(2), rolls: closingRolls }
            },
            recentInwards: recentInwardsRaw.map(i => ({
                lot_number: i.lotNo,
                from_party: i.lotName,
                total_weight: (i.diaEntries?.reduce((a, c) => a + (parseFloat(c.recWt) || 0), 0) || 0).toFixed(2),
                created_at: i.inwardDate
            })),
            metrics: {
                total_lots: await Lot.countDocuments({}).catch(() => 0),
                total_inward_weight: allInwards.reduce((acc, curr) => acc + (curr.diaEntries?.reduce((a, c) => a + (c.recWt || 0), 0) || 0), 0).toFixed(2),
                total_outward_weight: allOutwards.reduce((acc, curr) => acc + (curr.items ? curr.items.reduce((a, c) => a + (c.total_weight || 0), 0) : 0), 0).toFixed(2),
                total_assignments: await ItemAssignment.countDocuments({}).catch(() => 0),
                countInwards: allInwards.length,
                countOutwards: allOutwards.length,
            },
        });
    } catch (error) {
        console.error('[Dashboard Error]', error);
        res.status(500).json({ message: 'Error loading dashboard data', error: error.message });
    }
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
