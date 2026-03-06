import asyncHandler from 'express-async-handler';
import Inward from './inwardModel.js';
import Outward from './outwardModel.js';
import StockLimit from '../master/stockLimitModel.js';
import Category from '../master/categoryModel.js';
import ItemGroup from '../master/itemGroupModel.js';

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
            o.items.forEach(item => {
                // Sum up rolls and weight for all colors in the set
                stockMap[o.lotNo].deliv_rolls += item.colours.reduce((acc, curr) => acc + (curr.no_of_rolls || 0), 0);
                stockMap[o.lotNo].deliv_weight += item.total_weight || 0;
            });
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
            o.items.forEach(item => {
                reportMap[o.lotNo].out_rolls += item.colours.reduce((acc, curr) => acc + (curr.no_of_rolls || 0), 0);
                reportMap[o.lotNo].out_weight += item.total_weight || 0;
            });
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
        ...outwards.map(o => {
            const totalRolls = o.items ? o.items.reduce((acc, set) => acc + set.colours.reduce((accIn, col) => accIn + (col.no_of_rolls || 0), 0), 0) : 0;
            const totalWeight = o.items ? o.items.reduce((acc, set) => acc + (set.total_weight || 0), 0) : 0;
            return { type: 'OUT', date: o.dateTime, rolls: totalRolls, weight: totalWeight };
        })
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

// @desc    Get Client Format Report (Professional Summary)
// @route   GET /api/inventory/reports/client-format
const getClientFormatReport = asyncHandler(async (req, res) => {
    const { fromParty } = req.query;

    let query = {};
    if (fromParty) {
        query.fromParty = { $regex: new RegExp(fromParty, 'i') };
    }

    const inwards = await Inward.find(query).sort({ inwardDate: -1 });
    const outwards = await Outward.find({});

    // Create a map of outward weights per lot
    const outwardMap = {};
    outwards.forEach(o => {
        if (!outwardMap[o.lotNo]) outwardMap[o.lotNo] = 0;
        o.items.forEach(item => {
            outwardMap[o.lotNo] += (item.total_weight || 0);
        });
    });

    const report = inwards.map(i => {
        const totalInWeight = i.diaEntries.reduce((acc, curr) => acc + (curr.recWt || 0), 0);
        const totalOutWeight = outwardMap[i.lotNo] || 0;
        const balanceWeight = Math.max(0, totalInWeight - totalOutWeight);
        const status = balanceWeight > 0.1 ? 'In Stock' : 'Dispatched';

        return {
            id: i._id,
            lotNo: i.lotNo,
            lotName: i.lotName,
            fromParty: i.fromParty,
            inwardDate: i.inwardDate,
            totalWeight: totalInWeight,
            balanceWeight: balanceWeight,
            status: status,
            qualityStatus: i.qualityStatus || 'N/A',
            vehicleNo: i.vehicleNo || 'N/A'
        };
    });

    res.json(report);
});

// @desc    Get Godown Stock Report with Min/Max Indication
// @route   GET /api/inventory/reports/godown-stock
const getGodownStockReport = asyncHandler(async (req, res) => {
    const { lotName, dia } = req.query;

    const inwards = await Inward.find({});
    const outwards = await Outward.find({});
    const baseStockLimits = await StockLimit.find({});

    let stockMap = {};

    // 1. Process Inwards
    inwards.forEach(i => {
        i.diaEntries.forEach(entry => {
            const key = `${i.lotName}_${entry.dia}`;
            if (!stockMap[key]) {
                stockMap[key] = {
                    lotName: i.lotName,
                    dia: entry.dia,
                    currentWeight: 0,
                    currentRolls: 0
                };
            }
            stockMap[key].currentWeight += (entry.recWt || 0);
            stockMap[key].currentRolls += (entry.recRoll || entry.roll || 0);
        });
    });

    // 2. Process Outwards
    outwards.forEach(o => {
        const key = `${o.lotName}_${o.dia}`;
        if (stockMap[key]) {
            o.items.forEach(item => {
                stockMap[key].currentWeight -= (item.total_weight || 0);
                stockMap[key].currentRolls -= item.colours.reduce((acc, curr) => acc + (curr.no_of_rolls || 0), 0);
            });
        }
    });

    // 3. Integrate Stock Limits and Calculate Metrics
    const report = [];

    // We want to show all combinations that either have stock OR have a limit defined
    const allKeys = new Set([...Object.keys(stockMap), ...baseStockLimits.map(l => `${l.lotName}_${l.dia}`)]);

    allKeys.forEach(key => {
        const [lName, lDia] = key.split('_');
        const stockInfo = stockMap[key] || { currentWeight: 0, currentRolls: 0 };
        const limitInfo = baseStockLimits.find(l => l.lotName === lName && l.dia === lDia) || {
            minWeight: 0,
            maxWeight: 0,
            minRolls: 0,
            maxRolls: 0,
            manualAdjustment: 0
        };

        const totalCurrentWeight = stockInfo.currentWeight + (limitInfo.manualAdjustment || 0);

        let status = 'NORMAL';
        if (limitInfo.minWeight > 0 && totalCurrentWeight < limitInfo.minWeight) {
            status = 'LOW STOCK';
        } else if (limitInfo.maxWeight > 0 && totalCurrentWeight > limitInfo.maxWeight) {
            status = 'HIGH STOCK';
        }

        const needWeight = Math.max(0, (limitInfo.maxWeight || 0) - totalCurrentWeight);
        const needRolls = needWeight / 20;

        report.push({
            lotName: lName,
            dia: lDia,
            minWeight: limitInfo.minWeight,
            maxWeight: limitInfo.maxWeight,
            currentWeight: stockInfo.currentWeight,
            outsideInput: limitInfo.manualAdjustment,
            totalStock: totalCurrentWeight,
            needWeight: needWeight,
            needRolls: needRolls,
            status: status
        });
    });

    // Filter by query params if provided
    let filteredReport = report;
    if (lotName) {
        filteredReport = filteredReport.filter(r => r.lotName.toLowerCase().includes(lotName.toLowerCase()));
    }
    if (dia) {
        filteredReport = filteredReport.filter(r => r.dia === dia);
    }

    res.json(filteredReport);
});

// @desc    Get Shade Card Report (Grouped by Item Group)
// @route   GET /api/inventory/reports/shade-card
const getShadeCardReport = asyncHandler(async (req, res) => {
    const itemGroups = await ItemGroup.find({});
    const categories = await Category.find({});

    // Find the 'Colour' category
    const colourCategory = categories.find(c => c.name.toLowerCase().includes('colour'));
    const colorValues = colourCategory ? colourCategory.values : [];

    const report = itemGroups.map(group => {
        const enrichedColours = (group.colours || []).map(colourName => {
            const detail = colorValues.find(v => v.name.toLowerCase() === colourName.toLowerCase());
            return {
                name: colourName,
                gsm: (detail && detail.gsm) ? detail.gsm : group.gsm, // Priority to category detail gsm if exists
                photo: detail ? detail.photo : null
            };
        });

        return {
            groupName: group.groupName,
            items: group.itemNames,
            gsm: group.gsm,
            colours: enrichedColours
        };
    });

    res.json(report);
});

// @desc    Get Lot Aging Summary (Bucketed)
// @route   GET /api/inventory/reports/aging-summary
const getLotAgingSummaryReport = asyncHandler(async (req, res) => {
    const inwards = await Inward.find({}).sort({ inwardDate: 1 });

    const summary = {
        '0-15 Days': { rolls: 0, weight: 0 },
        '16-30 Days': { rolls: 0, weight: 0 },
        '31-45 Days': { rolls: 0, weight: 0 },
        '45+ Days': { rolls: 0, weight: 0 },
    };

    const now = new Date();

    inwards.forEach(inward => {
        const age = Math.ceil((now - new Date(inward.inwardDate)) / (1000 * 60 * 60 * 24));

        let bucket = '45+ Days';
        if (age <= 15) bucket = '0-15 Days';
        else if (age <= 30) bucket = '16-30 Days';
        else if (age <= 45) bucket = '31-45 Days';

        const totalRolls = inward.diaEntries.reduce((acc, curr) => acc + (curr.recRoll || curr.roll || 0), 0);
        const totalWt = inward.diaEntries.reduce((acc, curr) => acc + (curr.recWt || 0), 0);

        summary[bucket].rolls += totalRolls;
        summary[bucket].weight += totalWt;
    });

    // Format for frontend table
    const report = Object.keys(summary).map(key => ({
        range: key,
        rolls: summary[key].rolls,
        weight: summary[key].weight.toFixed(2)
    }));

    res.json(report);
});

// @desc    Get Rack and Pallet Wise Stock Report
// @route   GET /api/inventory/reports/rack-pallet
const getRackPalletStockReport = asyncHandler(async (req, res) => {
    const { rackName, palletNo, lotName } = req.query;

    console.log(`Getting Rack/Pallet Stock Report. Filters: lotName=${lotName}, rack=${rackName}, pallet=${palletNo}`);

    // Fetch all inwards to be safe, filter in memory
    const inwards = await Inward.find({}).sort({ inwardDate: -1 });
    const outwards = await Outward.find({});

    // 1. Create a map for used sets (Lot + Dia + SetNo)
    const usedSetsMap = new Set();
    outwards.forEach(o => {
        if (o.items) {
            o.items.forEach(item => {
                // Use a consistent key format
                const key = `${o.lotNo}_${o.dia}_${item.set_no}`.toLowerCase();
                usedSetsMap.add(key);
            });
        }
    });

    let stockReport = [];

    // 2. Flatten Inward storageDetails into individual sets
    inwards.forEach(inw => {
        // storageDetails can be an array OR just exists as an object
        const storageDetails = inw.storageDetails;
        if (storageDetails && Array.isArray(storageDetails) && storageDetails.length > 0) {
            storageDetails.forEach(sd => {
                const dia = sd.dia;
                if (sd.rows && Array.isArray(sd.rows)) {
                    sd.rows.forEach(row => {
                        const colour = row.colour;
                        if (row.setWeights && Array.isArray(row.setWeights)) {
                            row.setWeights.forEach((weight, index) => {
                                const labels = Array.isArray(row.setLabels) ? row.setLabels : [];
                                const setLabel = (labels[index] ?? '').toString().trim();
                                const setNo = setLabel || (index + 1).toString();
                                const rack = sd.racks && sd.racks[index] ? sd.racks[index] : 'N/A';
                                const pallet = sd.pallets && sd.pallets[index] ? sd.pallets[index] : 'N/A';

                                // Check if this set is already dispatched
                                const setKey = `${inw.lotNo}_${dia}_${setNo}`.toLowerCase();
                                if (!usedSetsMap.has(setKey)) {
                                    stockReport.push({
                                        rackName: rack,
                                        palletNo: pallet,
                                        lotName: inw.lotName,
                                        lotNo: inw.lotNo,
                                        dia: dia,
                                        colour: colour,
                                        weight: parseFloat(weight) || 0,
                                        setNo: setNo,
                                        inwardDate: inw.inwardDate,
                                        inwardNo: inw.inwardNo
                                    });
                                }
                            });
                        }
                    });
                }
            });
        }
    });

    console.log(`Initial stock count: ${stockReport.length}`);

    // 3. Apply filters
    if (rackName && rackName !== 'All') {
        const searchRack = rackName.toLowerCase();
        stockReport = stockReport.filter(s =>
            s.rackName && s.rackName.toString().toLowerCase().includes(searchRack)
        );
    }
    if (palletNo && palletNo !== 'All') {
        const searchPallet = palletNo.toLowerCase();
        stockReport = stockReport.filter(s =>
            s.palletNo && s.palletNo.toString().toLowerCase().includes(searchPallet)
        );
    }
    if (lotName && lotName !== 'All') {
        const searchLot = lotName.toLowerCase();
        stockReport = stockReport.filter(s =>
            (s.lotName && s.lotName.toString().toLowerCase().includes(searchLot)) ||
            (s.lotNo && s.lotNo.toString().toLowerCase().includes(searchLot))
        );
    }

    console.log(`Final filtered count: ${stockReport.length}`);

    // Sort by Rack and then Pallet
    stockReport.sort((a, b) => {
        const rackA = (a.rackName || '').toString().toLowerCase();
        const rackB = (b.rackName || '').toString().toLowerCase();
        if (rackA < rackB) return -1;
        if (rackA > rackB) return 1;

        const palA = (a.palletNo || '').toString().toLowerCase();
        const palB = (b.palletNo || '').toString().toLowerCase();
        if (palA < palB) return -1;
        if (palA > palB) return 1;

        return 0;
    });

    res.json(stockReport);
});

export {
    getOverviewReport,
    getInwardOutwardReport,
    getMonthlySummaryReport,
    getClientFormatReport,
    getGodownStockReport,
    getShadeCardReport,
    getLotAgingSummaryReport,
    getRackPalletStockReport
};
