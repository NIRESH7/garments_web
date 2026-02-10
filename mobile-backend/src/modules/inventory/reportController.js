import asyncHandler from 'express-async-handler';
import Inward from './inwardModel.js';
import Outward from './outwardModel.js';

// @desc    Get Overview Report (Stock Overview)
// @route   GET /api/inventory/reports/overview
const getOverviewReport = asyncHandler(async (req, res) => {
    const { startDate, endDate, lotNo, lotName, status } = req.query;

    const inwards = await Inward.find({}).sort({ inwardDate: 1 });
    const outwards = await Outward.find({});

    let stockMap = {};

    inwards.forEach(i => {
        // Filter by Inward Date if provided
        if (startDate && new Date(i.inwardDate) < new Date(startDate)) return;
        if (endDate && new Date(i.inwardDate) > new Date(endDate)) return;

        // Filter by Lot No/Name (Partial Match) during iteration or after
        // Doing it here saves processing
        if (lotNo && !new RegExp(lotNo, 'i').test(i.lotNo)) return;
        if (lotName && !new RegExp(lotName, 'i').test(i.lotName)) return;

        if (!stockMap[i.lotNo]) {
            stockMap[i.lotNo] = {
                lot_number: i.lotNo,
                lot_name: i.lotName,
                party_name: i.fromParty,
                rec_rolls: 0,
                rec_weight: 0,
                deliv_rolls: 0,
                deliv_weight: 0,
            };
        }
        stockMap[i.lotNo].rec_rolls += i.diaEntries.reduce((acc, curr) => acc + (curr.recRoll || curr.roll || 0), 0);
        stockMap[i.lotNo].rec_weight += i.diaEntries.reduce((acc, curr) => acc + (curr.recWt || 0), 0);
    });

    outwards.forEach(o => {
        // Only process outwards for lots that passed the inward filters
        if (stockMap[o.lotNo]) {
            stockMap[o.lotNo].deliv_rolls += o.items ? o.items.length : 0;
            stockMap[o.lotNo].deliv_weight += o.items ? o.items.reduce((acc, curr) => acc + (curr.selected_weight || 0), 0) : 0;
        } else {
            // Handle case where outward exists but inward doesn't (shouldn't happen ideally)
            // For now we ignore or create a negative entry if required, but usually strict reference implies inward exists
        }
    });

    // Calculate balances and status
    let report = Object.values(stockMap).map(s => {
        const bal_rolls = s.rec_rolls - s.deliv_rolls;
        const bal_weight = s.rec_weight - s.deliv_weight;
        const statusVal = bal_weight > 0.1 ? 'Pending' : 'Completed';
        return {
            ...s,
            balance_rolls: bal_rolls,
            balance_weight: bal_weight,
            status: statusVal
        };
    });

    // Filter by Status
    if (status && status !== 'All') {
        report = report.filter(r => r.status.toLowerCase() === status.toLowerCase());
    }

    res.json(report);
});

// @desc    Get Inward vs Outward Report
// @route   GET /api/inventory/reports/inward-outward
const getInwardOutwardReport = asyncHandler(async (req, res) => {
    const inwards = await Inward.find({});
    const outwards = await Outward.find({});

    const reportMap = {};

    inwards.forEach(i => {
        if (!reportMap[i.lotNo]) {
            reportMap[i.lotNo] = {
                lot_number: i.lotNo,
                party_name: i.fromParty,
                in_rolls: 0,
                in_weight: 0,
                out_rolls: 0,
                out_weight: 0,
            };
        }
        reportMap[i.lotNo].in_rolls += i.diaEntries.reduce((acc, curr) => acc + (curr.recRoll || curr.roll), 0);
        reportMap[i.lotNo].in_weight += i.diaEntries.reduce((acc, curr) => acc + curr.recWt, 0);
    });

    outwards.forEach(o => {
        if (reportMap[o.lotNo]) {
            reportMap[o.lotNo].out_rolls += o.items ? o.items.length : 0;
            reportMap[o.lotNo].out_weight += o.items ? o.items.reduce((acc, curr) => acc + curr.selected_weight, 0) : 0;
        }
    });

    res.json(Object.values(reportMap));
});

// @desc    Get Monthly Summary Report
// @route   GET /api/inventory/reports/monthly
const getMonthlySummaryReport = asyncHandler(async (req, res) => {
    const { startDate, endDate } = req.query;

    let inwardQuery = {};
    let outwardQuery = {};

    // For monthly report, we typically want the full history to calculate opening balance correctly.
    // If startDate is provided, we still need previous data to calc opening balance.
    // However, the report is "Closing Stock" which usually shows a snapshot or trend.
    // The previous implementation calculates month-by-month from the beginning.
    // To support "Filter by Date", we should still calculate everything but only RETURN the months within the range.

    const inwards = await Inward.find({}).sort({ inwardDate: 1 });
    const outwards = await Outward.find({}).sort({ dateTime: 1 });

    const monthSummaries = {};

    // Helper to get month key YYYY-MM
    const getMonthKey = (date) => new Date(date).toISOString().substring(0, 7);

    // Initial stock (everything before earliest record)
    let runningRolls = 0;
    let runningWeight = 0;

    // We'll iterate through all months from first record to current
    const allRecords = [
        ...inwards.map(i => ({ type: 'IN', date: i.inwardDate, rolls: i.diaEntries.reduce((acc, curr) => acc + curr.recRoll, 0), weight: i.diaEntries.reduce((acc, curr) => acc + curr.recWt, 0) })),
        ...outwards.map(o => ({ type: 'OUT', date: o.dateTime, rolls: o.items ? o.items.length : 0, weight: o.items ? o.items.reduce((acc, curr) => acc + curr.selected_weight, 0) : 0 }))
    ].sort((a, b) => new Date(a.date) - new Date(b.date));

    if (allRecords.length === 0) return res.json([]);

    const calculationStartDate = new Date(allRecords[0].date);
    const calculationEndDate = new Date();

    let curr = new Date(calculationStartDate.getFullYear(), calculationStartDate.getMonth(), 1);
    while (curr <= calculationEndDate) {
        const monthKey = getMonthKey(curr);
        monthSummaries[monthKey] = {
            month: monthKey,
            opening_balance_rolls: runningRolls,
            opening_balance: runningWeight,
            inward_rolls: 0,
            inward_weight: 0,
            outward_rolls: 0,
            outward_weight: 0,
        };

        const monthRecords = allRecords.filter(r => getMonthKey(r.date) === monthKey);
        monthRecords.forEach(r => {
            if (r.type === 'IN') {
                monthSummaries[monthKey].inward_rolls += r.rolls;
                monthSummaries[monthKey].inward_weight += r.weight;
                runningRolls += r.rolls;
                runningWeight += r.weight;
            } else {
                monthSummaries[monthKey].outward_rolls += r.rolls;
                monthSummaries[monthKey].outward_weight += r.weight;
                runningRolls -= r.rolls;
                runningWeight -= r.weight;
            }
        });

        monthSummaries[monthKey].closing_balance_rolls = runningRolls;
        monthSummaries[monthKey].closing_balance = runningWeight;

        curr.setMonth(curr.getMonth() + 1);
    }

    const result = Object.values(monthSummaries).reverse();

    if (startDate || endDate) {
        const start = startDate ? new Date(startDate) : new Date('1970-01-01');
        const end = endDate ? new Date(endDate) : new Date();

        const filtered = result.filter(r => {
            const mDate = new Date(r.month + '-01'); // YYYY-MM -> Date
            // Check if month matches range (simple check)
            return mDate >= start && mDate <= end;
        });
        res.json(filtered);
    } else {
        res.json(result);
    }
});

export {
    getOverviewReport,
    getInwardOutwardReport,
    getMonthlySummaryReport
};
