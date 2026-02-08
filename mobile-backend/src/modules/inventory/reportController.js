import asyncHandler from 'express-async-handler';
import Inward from './inwardModel.js';
import Outward from './outwardModel.js';

// @desc    Get Overview Report (Stock Overview)
// @route   GET /api/inventory/reports/overview
const getOverviewReport = asyncHandler(async (req, res) => {
    const inwards = await Inward.find({});
    const outwards = await Outward.find({});

    const stockMap = {};

    inwards.forEach(i => {
        if (!stockMap[i.lotNo]) {
            stockMap[i.lotNo] = {
                lot_number: i.lotNo,
                lot_name: i.lotName,
                party_name: i.fromParty,
                rolls: 0,
                weight: 0,
            };
        }
        stockMap[i.lotNo].rolls += i.diaEntries.reduce((acc, curr) => acc + curr.recRoll, 0);
        stockMap[i.lotNo].weight += i.diaEntries.reduce((acc, curr) => acc + curr.recWt, 0);
    });

    outwards.forEach(o => {
        if (stockMap[o.lotNo]) {
            stockMap[o.lotNo].rolls -= o.items ? o.items.length : 0;
            stockMap[o.lotNo].weight -= o.items ? o.items.reduce((acc, curr) => acc + curr.selected_weight, 0) : 0;
        }
    });

    // Convert to array and filter out zero stock if needed
    const report = Object.values(stockMap).filter(s => s.weight > 0);
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

    const startDate = new Date(allRecords[0].date);
    const endDate = new Date();

    let curr = new Date(startDate.getFullYear(), startDate.getMonth(), 1);
    while (curr <= endDate) {
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

    res.json(Object.values(monthSummaries).reverse());
});

export {
    getOverviewReport,
    getInwardOutwardReport,
    getMonthlySummaryReport
};
