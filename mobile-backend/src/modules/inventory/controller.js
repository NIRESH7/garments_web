import asyncHandler from 'express-async-handler';
import XLSX from 'xlsx';
import Inward from './inwardModel.js';
import Outward from './outwardModel.js';
import Notification from '../notification/model.js';
import Category from '../master/categoryModel.js';
import { getFilePath } from '../../utils/fileUtils.js';

// --- INWARD HANDLERS ---

const COLOUR_CATEGORY_REGEX = /^(colou?r|colou?rs|color|colors)$/i;

const normalizeText = (value) => value?.toString().trim() ?? '';

// Ultra-robust key canonicalization for matching
// Removes "set" prefix, all spaces, and special characters. 
// E.g. "Set-1", "Set 1", "  1  ", "Set-01" all become "1"
const canonicalSet = (s) => {
    const normalized = normalizeText(s).toLowerCase().replace(/^set/i, '');
    const numericPart = normalized.replace(/[^0-9]/g, '');
    // If it's a number, return it without leading zeros
    if (numericPart && !isNaN(numericPart)) {
        return parseInt(numericPart, 10).toString();
    }
    // Otherwise return alphanumeric version
    return normalized.replace(/[^a-z0-9]/g, '');
};

// Removes all spaces and special characters from color name
const canonicalColour = (c) => {
    return normalizeText(c)
        .toLowerCase()
        .replace(/[^a-z0-9]/g, '');
};

const canonicalKey = (setNo, colour) => {
    return `${canonicalSet(setNo)}|${canonicalColour(colour)}`;
};

const escapeRegex = (value) => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

const extractColoursFromStorageDetails = (storageDetails) => {
    const colours = new Set();
    if (!storageDetails) return colours;

    const blocks = Array.isArray(storageDetails)
        ? storageDetails
        : Object.values(storageDetails);

    blocks.forEach((block) => {
        const rows = Array.isArray(block?.rows) ? block.rows : [];
        rows.forEach((row) => {
            const colour = normalizeText(row?.colour);
            if (colour) colours.add(colour);
        });
    });

    return colours;
};

const normalizeCategoryValues = (values) => {
    if (!Array.isArray(values)) return [];
    return values
        .map((value) => {
            if (typeof value === 'string') {
                const name = normalizeText(value);
                return name ? { name } : null;
            }
            if (value && typeof value === 'object') {
                const name = normalizeText(value.name);
                if (!name) return null;
                return {
                    name,
                    photo: value.photo ?? null,
                    gsm: value.gsm ?? null,
                };
            }
            return null;
        })
        .filter(Boolean);
};

const syncColoursCategory = async (storageDetails) => {
    try {
        const colours = Array.from(extractColoursFromStorageDetails(storageDetails));
        if (colours.length === 0) return;

        let category = await Category.findOne({ name: { $regex: COLOUR_CATEGORY_REGEX } });
        if (!category) {
            await Category.create({
                name: 'Colours',
                values: colours.map((name) => ({ name })),
            });
            return;
        }

        const normalizedValues = normalizeCategoryValues(category.values);
        const existing = new Set(
            normalizedValues.map((value) => normalizeText(value.name).toLowerCase()).filter(Boolean)
        );

        let changed = normalizedValues.length !== (category.values?.length ?? 0);
        for (const colour of colours) {
            const key = colour.toLowerCase();
            if (!existing.has(key)) {
                normalizedValues.push({ name: colour, photo: null, gsm: null });
                existing.add(key);
                changed = true;
            }
        }

        if (changed) {
            category.values = normalizedValues;
            await category.save();
        }
    } catch (error) {
        console.error('Failed to sync colours category:', error);
    }
};

const parseNumber = (value) => {
    if (value === null || value === undefined) return null;
    if (typeof value === 'number' && Number.isFinite(value)) return value;
    const text = normalizeText(value);
    if (!text || text === '-' || text === '--') return null;
    const parsed = Number(text.replace(/,/g, ''));
    return Number.isFinite(parsed) ? parsed : null;
};

const formatWeight = (value) => {
    const rounded = Number(value.toFixed(3));
    return rounded.toString();
};

const extractPrefixedValueFromRows = (rows, prefixes, maxScanRows = 60) => {
    const anchored = prefixes.map(
        (prefix) => new RegExp(`^${prefix.replace(/[.*+?^${}()|[\\]\\\\]/g, '\\\\$&')}\\s*[-:]\\s*(.+)$`, 'i')
    );
    const loose = prefixes.map(
        (prefix) => new RegExp(`${prefix.replace(/[.*+?^${}()|[\\]\\\\]/g, '\\\\$&')}\\s*[-:]\\s*(.+)$`, 'i')
    );

    const scan = (patterns) => {
        for (let r = 0; r < Math.min(rows.length, maxScanRows); r++) {
            const row = Array.isArray(rows[r]) ? rows[r] : [];
            for (const raw of row) {
                const text = normalizeText(raw);
                if (!text) continue;
                for (const pattern of patterns) {
                    const match = text.match(pattern);
                    if (match) return normalizeText(match[1]);
                }
            }
        }
        return '';
    };

    const strictValue = scan(anchored);
    if (strictValue) return strictValue;
    return scan(loose);
};

const extractValueByRegex = (rows, regex, maxScanRows = 80) => {
    for (let r = 0; r < Math.min(rows.length, maxScanRows); r++) {
        const row = Array.isArray(rows[r]) ? rows[r] : [];
        for (const raw of row) {
            const text = normalizeText(raw);
            if (!text) continue;
            const match = text.match(regex);
            if (match) return normalizeText(match[1] ?? match[0]);
        }
    }
    return '';
};

const parseDateToIso = (rawValue) => {
    const text = normalizeText(rawValue);
    if (!text) return new Date().toISOString().slice(0, 10);

    const match = text.match(/(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})/);
    if (!match) return new Date().toISOString().slice(0, 10);

    let day = Number(match[1]);
    let month = Number(match[2]);
    let year = Number(match[3]);
    if (year < 100) year += 2000;

    if (!Number.isFinite(day) || !Number.isFinite(month) || !Number.isFinite(year)) {
        return new Date().toISOString().slice(0, 10);
    }

    if (day < 1 || day > 31 || month < 1 || month > 12) {
        return new Date().toISOString().slice(0, 10);
    }

    const date = new Date(Date.UTC(year, month - 1, day));
    return date.toISOString().slice(0, 10);
};

const getSetIdentifierFromRow = (row, idx) => {
    const labels = Array.isArray(row?.setLabels) ? row.setLabels : [];
    const label = normalizeText(labels[idx]);
    return label || (idx + 1).toString();
};

const findSetIndexInRow = (row, setNo) => {
    const target = normalizeText(setNo).toLowerCase();
    if (!target) return -1;

    const labels = Array.isArray(row?.setLabels) ? row.setLabels : [];
    const byLabel = labels.findIndex((label) => normalizeText(label).toLowerCase() === target);
    if (byLabel >= 0) return byLabel;

    const parsed = Number.parseInt(target, 10);
    if (!Number.isNaN(parsed)) return parsed - 1;

    return -1;
};

const getLotBalanceByDia = async (lotNo, dia) => {
    if (!lotNo || !dia) return 0;

    const lotInwards = await Inward.find({ lotNo, 'diaEntries.dia': dia });
    let totalInwardWt = 0;
    lotInwards.forEach((inw) => {
        const entry = inw.diaEntries.find((e) => e.dia === dia);
        if (entry) totalInwardWt += (entry.recWt || 0);
    });

    const lotOutwards = await Outward.find({ lotNo, dia });
    let totalOutwardWt = 0;
    lotOutwards.forEach((out) => {
        out.items.forEach((item) => {
            totalOutwardWt += (item.total_weight || 0);
        });
    });

    return totalInwardWt - totalOutwardWt;
};

const getOldestAvailableLotNo = async (lotName, dia) => {
    if (!lotName || !dia) return null;

    const inwards = await Inward.find({
        lotName: { $regex: new RegExp(`^${escapeRegex(lotName)}$`, 'i') },
        'diaEntries.dia': dia,
    }).sort({ inwardDate: 1, createdAt: 1 });

    const orderedLotNos = [];
    const seen = new Set();
    for (const inw of inwards) {
        const lotNo = normalizeText(inw.lotNo);
        if (!lotNo || seen.has(lotNo)) continue;
        seen.add(lotNo);
        orderedLotNos.push(lotNo);
    }

    for (const lotNo of orderedLotNos) {
        const balance = await getLotBalanceByDia(lotNo, dia);
        if (balance > 0.1) return lotNo;
    }

    return null;
};

const buildInwardPayloadFromRows = (rows) => {
    if (!rows || rows.length === 0) return null;

    const lotNo =
        extractPrefixedValueFromRows(rows, ['LOT NO', 'LOT NUMBER']) ||
        extractValueByRegex(rows, /(\d{4}\/\d{4,})/);
    const dateRaw =
        extractPrefixedValueFromRows(rows, ['DATE']) ||
        extractValueByRegex(rows, /(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})/);
    const fromParty =
        extractPrefixedValueFromRows(rows, ['PARTY NAME', 'PARTY']) ||
        extractValueByRegex(rows, /PARTY\\s*NAME\\s*[-:]\\s*(.+)$/i);
    const lotName =
        extractPrefixedValueFromRows(rows, ['LOT NAME']) ||
        extractValueByRegex(rows, /LOT\\s*NAME\\s*[-:]\\s*(.+)$/i);
    const dia =
        extractPrefixedValueFromRows(rows, ['DIA']) ||
        extractValueByRegex(rows, /(\d+(\.\d+)?)\s*DIA/i);

    if (!lotNo || !lotName || !fromParty || !dia) return null;

    const headerRow = Array.isArray(rows[6]) ? rows[6] : [];
    const setCols = [];
    let started = false;
    for (let c = 1; c < headerRow.length; c++) {
        const value = normalizeText(headerRow[c]).toUpperCase();
        if (!value) {
            if (started) break;
            continue;
        }
        if (value.startsWith('TOTAL')) break;
        if (value.startsWith('S-') || value.startsWith('SET')) {
            setCols.push(c);
            started = true;
        }
    }

    if (setCols.length === 0) return null;
    const setLabels = setCols.map((col, idx) => normalizeText(headerRow[col]) || `S-${idx + 1}`);

    const rackRow = Array.isArray(rows[4]) ? rows[4] : [];
    const palletRow = Array.isArray(rows[5]) ? rows[5] : [];
    const racks = setCols.map((col) => normalizeText(rackRow[col]));
    const pallets = setCols.map((col) => normalizeText(palletRow[col]));

    const storageRows = [];
    let recRoll = 0;
    let recWt = 0;
    let rowStartFound = false;

    for (let r = 7; r < rows.length; r++) {
        const row = Array.isArray(rows[r]) ? rows[r] : [];
        const colour = normalizeText(row[0]);
        if (!colour) {
            if (rowStartFound) break;
            continue;
        }
        rowStartFound = true;

        const setWeights = [];
        let totalWeight = 0;
        let rowRolls = 0;

        for (const col of setCols) {
            const num = parseNumber(row[col]);
            if (num === null) {
                setWeights.push('');
            } else {
                setWeights.push(formatWeight(num));
                totalWeight += num;
                rowRolls += 1;
            }
        }

        if (rowRolls === 0) continue;

        storageRows.push({
            colour,
            gsm: '',
            setWeights,
            setLabels,
            totalWeight: Number(totalWeight.toFixed(3)),
        });
        recRoll += rowRolls;
        recWt += totalWeight;
    }

    if (storageRows.length === 0) return null;

    return {
        inwardDate: parseDateToIso(dateRaw),
        inTime: '09:00 AM',
        outTime: '09:30 AM',
        lotName,
        lotNo,
        fromParty,
        process: fromParty.toUpperCase().includes('COMPACT') ? 'COMPACTING' : '',
        rate: 0,
        gsm: '',
        vehicleNo: '',
        partyDcNo: '',
        diaEntries: [{
            dia,
            roll: recRoll,
            sets: setCols.length,
            delivWt: Number(recWt.toFixed(3)),
            recRoll: recRoll,
            recWt: Number(recWt.toFixed(3)),
            rate: 0,
        }],
        storageDetails: [{
            dia,
            racks,
            pallets,
            rows: storageRows,
        }],
        qualityStatus: 'OK',
        gsmStatus: 'OK',
        shadeStatus: 'OK',
        washingStatus: 'OK',
        complaintText: '',
    };
};

const buildInwardPayloadFromSheet = (sheet) => {
    const rows = XLSX.utils.sheet_to_json(sheet, {
        header: 1,
        raw: true,
        defval: null,
        blankrows: false,
    });
    return buildInwardPayloadFromRows(rows);
};

const parsePdfTextToRows = (text) => {
    if (!text) return [];
    const lines = text
        .split(/\r?\n/)
        .map((line) => line.trim())
        .filter((line) => line.length > 0);

    return lines.map((line) =>
        line
            .split(/\s{2,}|\t+/)
            .map((cell) => cell.trim())
            .filter((cell) => cell.length > 0)
    );
};

const extractDiaFromRows = (rows) => {
    for (let r = 0; r < Math.min(rows.length, 15); r++) {
        const row = Array.isArray(rows[r]) ? rows[r] : [];
        for (const cell of row) {
            const text = normalizeText(cell).toUpperCase();
            if (!text) continue;
            let match = text.match(/DIA\\s*[-:]*\\s*(\\d+(\\.\\d+)?)/i);
            if (match) return match[1];
            match = text.match(/(\\d+(\\.\\d+)?)\\s*DIA/i);
            if (match) return match[1];
        }
    }
    return '';
};

const buildInwardPayloadFromSummaryRows = (rows) => {
    if (!rows || rows.length === 0) return null;

    const lotNo =
        extractPrefixedValueFromRows(rows, ['L.NO', 'LOT NO', 'LOT NUMBER']) ||
        extractValueByRegex(rows, /(\d{4}\/\d{4,})/);
    const dateRaw =
        extractPrefixedValueFromRows(rows, ['DATE']) ||
        extractValueByRegex(rows, /(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})/);
    const fromParty =
        extractPrefixedValueFromRows(rows, ['PARTY NAME', 'PARTY']) ||
        extractValueByRegex(rows, /PARTY\\s*NAME\\s*[-:]\\s*(.+)$/i);
    const lotName =
        extractPrefixedValueFromRows(rows, ['LOT NAME']) ||
        extractValueByRegex(rows, /LOT\\s*NAME\\s*[-:]\\s*(.+)$/i);
    const dia =
        extractDiaFromRows(rows) ||
        extractValueByRegex(rows, /(\d+(\.\d+)?)\s*DIA/i);

    if (!lotNo || !lotName || !fromParty || !dia) return null;

    let rackList = [];
    let palletList = [];
    for (let r = 0; r < Math.min(rows.length, 10); r++) {
        const row = Array.isArray(rows[r]) ? rows[r] : [];
        const label = normalizeText(row[0]).toUpperCase();
        if (label.includes('RACK')) {
            const value = normalizeText(row[1]);
            rackList = value ? value.split(',').map((v) => v.trim()).filter(Boolean) : [];
        }
        if (label.includes('PALLET')) {
            const value = normalizeText(row[1]);
            palletList = value ? value.split(',').map((v) => v.trim()).filter(Boolean) : [];
        }
    }

    let headerIdx = -1;
    let colourCol = -1;
    let totalWeightCol = -1;
    let totalRollCol = -1;
    for (let r = 0; r < rows.length; r++) {
        const row = Array.isArray(rows[r]) ? rows[r] : [];
        const normalized = row.map((c) => normalizeText(c).toUpperCase());
        const hasColour = normalized.includes('COLOUR') || normalized.includes('COLOR');
        const hasWt = normalized.includes('TOTAL WEIGHT') || normalized.includes('TOTAL WT');
        const hasRoll = normalized.includes('TOTAL ROLL') || normalized.includes('TOTAL ROLLS');
        if (hasColour && (hasWt || hasRoll)) {
            headerIdx = r;
            colourCol = normalized.indexOf('COLOUR');
            if (colourCol < 0) colourCol = normalized.indexOf('COLOR');
            totalWeightCol = normalized.indexOf('TOTAL WEIGHT');
            if (totalWeightCol < 0) totalWeightCol = normalized.indexOf('TOTAL WT');
            totalRollCol = normalized.indexOf('TOTAL ROLL');
            if (totalRollCol < 0) totalRollCol = normalized.indexOf('TOTAL ROLLS');
            break;
        }
    }

    if (headerIdx < 0 || colourCol < 0) return null;

    const storageRows = [];
    let totalRollsAll = 0;
    let totalWeightAll = 0;

    for (let r = headerIdx + 1; r < rows.length; r++) {
        const row = Array.isArray(rows[r]) ? rows[r] : [];
        const colour = normalizeText(row[colourCol]);
        if (!colour) break;

        const weight = totalWeightCol >= 0 ? parseNumber(row[totalWeightCol]) : null;
        const rolls = totalRollCol >= 0 ? parseNumber(row[totalRollCol]) : null;
        if (weight === null && rolls === null) continue;

        totalRollsAll += rolls || 0;
        totalWeightAll += weight || 0;

        storageRows.push({
            colour,
            gsm: '',
            totalWeight: Number((weight || 0).toFixed(3)),
            totalRolls: Number((rolls || 0).toFixed(0)),
        });
    }

    if (storageRows.length === 0) return null;

    const totalSets = 1;
    const racks = rackList.length > 0 ? [rackList[0]] : [];
    const pallets = palletList.length > 0 ? [palletList[0]] : [];

    const rowsWithSets = storageRows.map((row) => {
        return {
            colour: row.colour,
            gsm: '',
            rollNo: row.totalRolls.toString() || "1", // Use the total rolls for this colour directly
            setWeights: [formatWeight(row.totalWeight)], // Use the total weight as a single entry
            setLabels: ['Weight'], // Use 'Weight' to trigger No-Set mode in the app
            totalWeight: row.totalWeight // For consistency
        };
    });

    return {
        inwardDate: parseDateToIso(dateRaw),
        inTime: '09:00 AM',
        outTime: '09:30 AM',
        lotName,
        lotNo,
        fromParty,
        process: fromParty.toUpperCase().includes('COMPACT') ? 'COMPACTING' : '',
        rate: 0,
        gsm: '',
        vehicleNo: '',
        partyDcNo: '',
        diaEntries: [{
            dia,
            roll: totalRollsAll,
            sets: totalSets,
            delivWt: Number(totalWeightAll.toFixed(3)),
            recRoll: totalRollsAll,
            recWt: Number(totalWeightAll.toFixed(3)),
            rate: 0,
        }],
        storageDetails: [{
            dia,
            racks,
            pallets,
            rows: rowsWithSets,
        }],
        qualityStatus: 'OK',
        gsmStatus: 'OK',
        shadeStatus: 'OK',
        washingStatus: 'OK',
        complaintText: '',
    };
};

const upsertInwardEntry = async ({ userId, body, files }) => {
    const {
        inwardNo,
        inwardDate,
        inTime,
        outTime,
        lotName,
        lotNo,
        fromParty,
        process,
        rate,
        gsm,
        vehicleNo,
        partyDcNo,
        diaEntries,
        storageDetails,
        qualityStatus,
        qualityImage,
        gsmStatus,
        gsmImage,
        shadeStatus,
        shadeImage,
        washingStatus,
        washingImage,
        complaintText,
        complaintImage,
        balanceImage,
    } = body;

    let finalLotInchargeSignature = body.lotInchargeSignature;
    let finalAuthorizedSignature = body.authorizedSignature;
    let finalMdSignature = body.mdSignature;

    if (files) {
        if (files.lotInchargeSignature) {
            finalLotInchargeSignature = getFilePath(files.lotInchargeSignature[0]);
        }
        if (files.authorizedSignature) {
            finalAuthorizedSignature = getFilePath(files.authorizedSignature[0]);
        }
        if (files.mdSignature) {
            finalMdSignature = getFilePath(files.mdSignature[0]);
        }
    }

    let processedDiaEntries = diaEntries;
    if (typeof diaEntries === 'string') {
        try {
            processedDiaEntries = JSON.parse(diaEntries);
        } catch (e) {
            console.error('Failed to parse diaEntries JSON:', e);
        }
    }

    let processedStorageDetails = storageDetails;
    if (typeof storageDetails === 'string') {
        try {
            processedStorageDetails = JSON.parse(storageDetails);
        } catch (e) {
            console.error('Failed to parse storageDetails JSON:', e);
        }
    }

    const cleanLotNo = lotNo?.toString().trim();
    const cleanLotName = lotName?.toString().trim().toUpperCase();
    if (!cleanLotNo || !cleanLotName) {
        throw new Error('Lot No and Lot Name are required');
    }

    /* 
    The user requested: "Inward Entry-la Merge aaga koodathu." 
    So we disable the auto-merge logic and always create a new record.
    */
    /*
    const escapedLotNo = cleanLotNo.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const escapedLotName = cleanLotName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

    console.log(`Checking merge for Lot No: [${cleanLotNo}], Lot Name: [${cleanLotName}]`);

    let inward = await Inward.findOne({
        lotNo: { $regex: new RegExp(`^\\s*${escapedLotNo}\\s*$`, 'i') },
        lotName: { $regex: new RegExp(`^\\s*${escapedLotName}\\s*$`, 'i') },
    });

    if (inward) {
        // ... update logic ...
    }
    */
    
    // Always treat as new entry for Inward List purposes
    let inward = null; 


    let finalInwardNo = inwardNo;
    if (!finalInwardNo) {
        const dateStr = new Date().toISOString().slice(0, 10).replace(/-/g, '');
        const count = await Inward.countDocuments({
            createdAt: {
                $gte: new Date(new Date().setHours(0, 0, 0, 0)),
                $lt: new Date(new Date().setHours(23, 59, 59, 999)),
            },
        });
        finalInwardNo = `INW-${dateStr}-${(count + 1).toString().padStart(3, '0')}`;
    }

    await syncColoursCategory(processedStorageDetails);
    inward = await Inward.create({
        user: userId,
        inwardNo: finalInwardNo,
        inwardDate,
        inTime,
        outTime,
        lotName: cleanLotName,
        lotNo: cleanLotNo,
        fromParty,
        process,
        rate: Number(rate) || 0,
        gsm,
        vehicleNo,
        partyDcNo,
        diaEntries: processedDiaEntries,
        storageDetails: processedStorageDetails,
        qualityStatus,
        qualityImage,
        gsmStatus,
        gsmImage,
        shadeStatus,
        shadeImage,
        washingStatus,
        washingImage,
        complaintText,
        complaintImage,
        balanceImage,
        lotInchargeSignature: finalLotInchargeSignature,
        authorizedSignature: finalAuthorizedSignature,
        mdSignature: finalMdSignature,
    });

    return { inward, mode: 'created', cleanLotNo, cleanLotName };
};

// @desc    Create a new inward entry (Lot Inward Entry)
// @route   POST /api/inventory/inward
// @access  Private
const createInward = asyncHandler(async (req, res) => {
    try {
        const result = await upsertInwardEntry({
            userId: req.user._id,
            body: req.body,
            files: req.files,
        });

        if (result.mode === 'updated') {
            await Notification.create({
                user: req.user._id,
                title: 'Inward Updated',
                body: `Inward Lot ${result.cleanLotNo} (${result.cleanLotName}) updated with new entries.`,
                type: 'info',
            }).catch((err) => console.error('Notification failed:', err));
        } else {
            await Notification.create({
                user: req.user._id,
                title: 'New Inward Created',
                body: `New Inward processed for Lot ${result.cleanLotNo} (${result.cleanLotName}).`,
                type: 'success',
            }).catch((err) => console.error('Notification failed:', err));
        }

        res.status(201).json(result.inward);
    } catch (error) {
        console.error('Error in createInward:', error);
        res.status(500);
        throw new Error(`Failed to process inward entry: ${error.message}`);
    }
});

// @desc    Import inward entries from Excel workbook
// @route   POST /api/inventory/inward/import
// @access  Private
const importInwardWorkbook = asyncHandler(async (req, res) => {
    if (!req.file || !req.file.buffer) {
        res.status(400);
        throw new Error('Excel or PDF file is required');
    }

    const originalName = (req.file.originalname || '').toLowerCase();
    const mime = (req.file.mimetype || '').toLowerCase();
    const isPdf = originalName.endsWith('.pdf') || mime.includes('pdf');

    if (isPdf) {
        let pdfText = '';
        try {
            const pdfParse = (await import('pdf-parse')).default;
            const parsed = await pdfParse(req.file.buffer);
            pdfText = parsed?.text || '';
        } catch (error) {
            res.status(400);
            throw new Error(`Invalid PDF file: ${error.message}`);
        }

        const rows = parsePdfTextToRows(pdfText);
        const payload =
            buildInwardPayloadFromRows(rows) ||
            buildInwardPayloadFromSummaryRows(rows);

        const results = [];
        let imported = 0;
        let failed = 0;
        let skipped = 0;

        if (!payload) {
            skipped += 1;
            results.push({
                sheet: 'PDF',
                status: 'skipped',
                message: 'Missing required format/values in PDF',
            });
        } else {
            try {
                const result = await upsertInwardEntry({
                    userId: req.user._id,
                    body: payload,
                    files: null,
                });
                imported += 1;
                results.push({
                    sheet: 'PDF',
                    status: 'imported',
                    mode: result.mode,
                    lotNo: payload.lotNo,
                    lotName: payload.lotName,
                    inwardId: result.inward?._id?.toString(),
                });
            } catch (error) {
                failed += 1;
                results.push({
                    sheet: 'PDF',
                    status: 'failed',
                    lotNo: payload.lotNo,
                    lotName: payload.lotName,
                    error: error.message,
                });
            }
        }

        res.json({
            fileName: req.file.originalname,
            totalSheets: 1,
            imported,
            failed,
            skipped,
            results,
        });
        return;
    }

    let workbook;
    try {
        workbook = XLSX.read(req.file.buffer, { type: 'buffer' });
    } catch (error) {
        res.status(400);
        throw new Error(`Invalid Excel file: ${error.message}`);
    }

    const sheetNames = workbook.SheetNames || [];
    const results = [];
    let imported = 0;
    let failed = 0;
    let skipped = 0;

    for (const sheetName of sheetNames) {
        const sheet = workbook.Sheets[sheetName];
        const payload =
            buildInwardPayloadFromSheet(sheet) ||
            buildInwardPayloadFromSummaryRows(
                XLSX.utils.sheet_to_json(sheet, {
                    header: 1,
                    raw: true,
                    defval: null,
                    blankrows: false,
                })
            );

        if (!payload) {
            skipped += 1;
            results.push({
                sheet: sheetName,
                status: 'skipped',
                message: 'Missing required format/values in sheet',
            });
            continue;
        }

        try {
            const result = await upsertInwardEntry({
                userId: req.user._id,
                body: payload,
                files: null,
            });
            imported += 1;
            results.push({
                sheet: sheetName,
                status: 'imported',
                mode: result.mode,
                lotNo: payload.lotNo,
                lotName: payload.lotName,
                inwardId: result.inward?._id?.toString(),
            });
        } catch (error) {
            failed += 1;
            results.push({
                sheet: sheetName,
                status: 'failed',
                lotNo: payload.lotNo,
                lotName: payload.lotName,
                error: error.message,
            });
        }
    }

    res.json({
        fileName: req.file.originalname,
        totalSheets: sheetNames.length,
        imported,
        failed,
        skipped,
        results,
    });
});

// @desc    Get all inward entries
// @route   GET /api/inventory/inward
// @access  Private
const getInwards = asyncHandler(async (req, res) => {
    const { startDate, endDate, fromParty, lotName, lotNo } = req.query;

    let query = {};
    if (startDate || endDate) {
        query.inwardDate = {};
        if (startDate) query.inwardDate.$gte = startDate;
        if (endDate) query.inwardDate.$lte = endDate;
    }
    if (fromParty) query.fromParty = { $regex: new RegExp('^' + fromParty.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&') + '$', 'i') };
    if (lotName) query.lotName = { $regex: new RegExp('^' + lotName.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&') + '$', 'i') };
    if (lotNo) query.lotNo = { $regex: new RegExp('^' + lotNo.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&') + '$', 'i') };

    const inwards = await Inward.find(query).sort({ inwardDate: -1, createdAt: -1 });
    res.json(inwards);
});

// @desc    Get Lots by DIA for FIFO
// @route   GET /api/inventory/inward/fifo
const getLotsFifo = asyncHandler(async (req, res) => {
    const { dia, lotName } = req.query;
    const query = { 'diaEntries.dia': dia };
    if (lotName) {
        query.lotName = { $regex: new RegExp(`^${lotName.trim()}$`, 'i') };
    }
    const inwards = await Inward.find(query).sort({ inwardDate: 1 });
    const distinctLotNos = [...new Set(inwards.map(i => i.lotNo))];

    // Filter lots by remaining balance > 0
    const availableLotNos = [];
    for (const lotNo of distinctLotNos) {
        const balance = await getLotBalanceByDia(lotNo, dia);
        if (balance > 0.1) {
            availableLotNos.push(lotNo);
        }
    }

    res.json(availableLotNos);
});

// @desc    Get Balanced Sets for Lot and DIA
// @route   GET /api/inventory/inward/balanced-sets
const getBalancedSets = asyncHandler(async (req, res) => {
    const { lotNo, dia, excludeId } = req.query;
    
    // Normalize query params
    const normalizedLotNo = normalizeText(lotNo);
    const normalizedDia = normalizeText(dia);

    // Case-insensitive search for Lot and Dia with optional surrounding whitespace
    const lotRegex = new RegExp(`^\\s*${escapeRegex(normalizedLotNo)}\\s*$`, 'i');
    const diaRegex = new RegExp(`^\\s*${escapeRegex(normalizedDia)}\\s*$`, 'i');

    const inwards = await Inward.find({ 
        lotNo: lotRegex, 
        'diaEntries.dia': diaRegex
    });
    
    const queryOutwards = { 
        lotNo: lotRegex, 
        dia: diaRegex 
    };
    if (excludeId) {
        queryOutwards._id = { $ne: excludeId };
    }

    const outwards = await Outward.find(queryOutwards);

    console.log(`\n--- Balancing Logic [Lot: ${normalizedLotNo}, Dia: ${normalizedDia}] ---`);
    console.log(`[Diagnostic] Found ${inwards.length} Inward docs and ${outwards.length} Outward docs for lot matching: ${normalizedLotNo}`);

    // Map to track balance per canonicalKey
    const balanceMap = {};

    // 1. ROBUST METADATA SCAN: Build a map of best-known GSM and Cutting Dia per Color for THIS Lot
    const lotMetadataMap = {};
    let fallbackGsm = '';
    let fallbackDia = '';
    
    inwards.forEach(inw => {
        if (inw.gsm && !fallbackGsm) fallbackGsm = inw.gsm;
        
        if (inw.diaEntries && Array.isArray(inw.diaEntries)) {
            inw.diaEntries.forEach(de => {
                if (de.dia && !fallbackDia) fallbackDia = de.dia;
            });
        }

        if (inw.storageDetails && Array.isArray(inw.storageDetails)) {
            inw.storageDetails.forEach(sd => {
                const rows = Array.isArray(sd.rows) ? sd.rows : [sd];
                rows.forEach(row => {
                    const colour = normalizeText(row.colour);
                    if (!colour) return;
                    if (!lotMetadataMap[colour]) lotMetadataMap[colour] = { gsm: '', dia: '', cutting_dia: '' };

                    // GSM: Row > Inward Top Level > Previous Best
                    if (row.gsm) lotMetadataMap[colour].gsm = row.gsm;
                    else if (!lotMetadataMap[colour].gsm && inw.gsm) lotMetadataMap[colour].gsm = inw.gsm;
                    else if (!lotMetadataMap[colour].gsm && fallbackGsm) lotMetadataMap[colour].gsm = fallbackGsm;

                    // Dia: Block > Inward Top Level > Previous Best
                    if (sd.cuttingDia) lotMetadataMap[colour].cutting_dia = sd.cuttingDia;
                    if (sd.dia) lotMetadataMap[colour].dia = sd.dia;
                    
                    if (!lotMetadataMap[colour].cutting_dia && fallbackDia) lotMetadataMap[colour].cutting_dia = fallbackDia;
                    if (!lotMetadataMap[colour].dia && fallbackDia) lotMetadataMap[colour].dia = fallbackDia;
                });
            });
        }
    });

    inwards.forEach(inw => {
        if (inw.storageDetails && Array.isArray(inw.storageDetails)) {
            inw.storageDetails.forEach(sdOrRow => {
                const rows = Array.isArray(sdOrRow.rows) ? sdOrRow.rows : [sdOrRow];
                
                rows.forEach(row => {
                    const rowDia = normalizeText(row.dia || sdOrRow.dia);
                    const diaMismatch = rowDia && !new RegExp(`^\\s*${escapeRegex(normalizedDia)}\\s*$`, 'i').test(rowDia);
                    if (diaMismatch) return; 

                    const rawColour = normalizeText(row.colour);
                    const weightsArray = row.setWeights || row.stickerDetails;
                    if (weightsArray && Array.isArray(weightsArray)) {
                        weightsArray.forEach((weight, idx) => {
                            const inWeight = parseFloat(weight) || 0;
                            if (inWeight <= 0) return;

                            const rawSetNo = getSetIdentifierFromRow(row, idx);
                            const key = canonicalKey(rawSetNo, rawColour);

                            const rackName = normalizeText(row.rackName || (sdOrRow.racks ? sdOrRow.racks[idx] : ''));
                            const palletNumber = normalizeText(row.palletNumber || (sdOrRow.pallets ? sdOrRow.pallets[idx] : ''));

                            const inRolls = (weightsArray.length === 1 && row.rollNo) ? (parseInt(row.rollNo) || 1) : 1;

                             if (!balanceMap[key]) {
                                    const meta = lotMetadataMap[row.colour] || {};
                                    balanceMap[key] = {
                                        set_no: rawSetNo,
                                        colour: row.colour,
                                        weight: 0,
                                        rolls: 0,
                                        rack_name: rackName,
                                        pallet_number: palletNumber,
                                        gsm: row.gsm || meta.gsm || inw.gsm || '',
                                        dia: sdOrRow.dia || meta.dia || normalizedDia || '',
                                        cutting_dia: sdOrRow.cuttingDia || meta.cutting_dia || sdOrRow.dia || normalizedDia || '',
                                    };
                            } else {
                                    // If already exists, still try to populate missing GSM/Dia from meta
                                    const meta = lotMetadataMap[row.colour] || {};
                                    if (!balanceMap[key].gsm) balanceMap[key].gsm = row.gsm || meta.gsm || inw.gsm || '';
                                    if (!balanceMap[key].cutting_dia) balanceMap[key].cutting_dia = sdOrRow.cuttingDia || meta.cutting_dia || '';
                            }
                            balanceMap[key].weight += inWeight;
                            balanceMap[key].rolls += inRolls;
                        });
                    }
                });
            });
        }
    });

    // Subtraction logic
    outwards.forEach(out => {
        if (out.items && Array.isArray(out.items)) {
            out.items.forEach(item => {
                const rawSetNo = normalizeText(item.set_no);
                if (item.colours && Array.isArray(item.colours)) {
                    item.colours.forEach(c => {
                        const rawColour = normalizeText(c.colour);
                        const outWeight = parseFloat(c.weight) || 0;
                        const outRolls = parseInt(c.no_of_rolls) || 0;
                        if (outWeight <= 0 && outRolls <= 0) return;

                        const key = canonicalKey(rawSetNo, rawColour);
                        if (balanceMap[key]) {
                            balanceMap[key].weight = Math.max(0, balanceMap[key].weight - outWeight);
                            balanceMap[key].rolls = Math.max(0, balanceMap[key].rolls - outRolls);
                            console.log(`[Diagnostic] Subtraction: Key=${key}, DC=${out.dcNo}, -${outWeight}kg, -${outRolls} rolls (Result: ${balanceMap[key].weight}kg, ${balanceMap[key].rolls} rolls)`);
                        }
                    });
                }
            });
        }
    });

    // Extract results above practically zero
    const balancedSets = Object.values(balanceMap).filter(item => item.weight > 0.01);
    console.log(`[Diagnostic] Returning ${balancedSets.length} unique set-color pairs.`);
    
    res.json(balancedSets);
});

// @desc    Get All Colours for a Lot (from Inward)
// @route   GET /api/inventory/inward/colours
const getInwardColours = asyncHandler(async (req, res) => {
    const { lotNo } = req.query;
    const inwards = await Inward.find({ lotNo });

    const colours = new Set();
    inwards.forEach(inward => {
        if (inward.storageDetails && inward.storageDetails.length > 0) {
            inward.storageDetails.forEach(sd => {
                sd.rows.forEach(row => {
                    if (row.colour) colours.add(row.colour);
                });
            });
        }
        // Fallback to diaEntries if storageDetails is empty
        if (inward.diaEntries && inward.diaEntries.length > 0) {
            // diaEntries usually don't have colour explicitly unless matched with something else.
            // But let's check if we missed anything. 
            // In current schema, colours are in storageDetails.
        }
    });

    res.json(Array.from(colours));
});

// @desc    Generate Inward Number (for UI display)
// @route   GET /api/inventory/inward/generate-no
// @access  Private
const generateInwardNumber = asyncHandler(async (req, res) => {
    const dateStr = new Date().toISOString().slice(0, 10).replace(/-/g, '');
    const count = await Inward.countDocuments({
        createdAt: {
            $gte: new Date(new Date().setHours(0, 0, 0, 0)),
            $lt: new Date(new Date().setHours(23, 59, 59, 999)),
        },
    });
    const inwardNo = `INW-${dateStr}-${(count + 1).toString().padStart(3, '0')}`;
    res.json({ inwardNo });
});

// @desc    Get FIFO Recommendation for Lot Name and DIA
// @route   GET /api/inventory/inward/fifo-recommendation
const getFifoRecommendation = asyncHandler(async (req, res) => {
    const { lotName, dia } = req.query;

    if (!lotName || !dia) {
        res.status(400);
        throw new Error('Lot Name and DIA are required');
    }

    // 1. Find all inwards for this Lot Name and DIA, sorted by date (FIFO)
    const inwards = await Inward.find({
        lotName: { $regex: new RegExp(`^${lotName}$`, 'i') },
        'diaEntries.dia': dia
    }).sort({ inwardDate: 1, createdAt: 1 }); // Secondary sort by createdAt if dates are same

    const lotNos = [...new Set(inwards.map(i => i.lotNo))];

    for (const lotNo of lotNos) {
        console.log(`Checking FIFO for Lot No: ${lotNo}`);
        // 2. Check available stock for this specific lot + dia
        const lotInwards = await Inward.find({ lotNo, 'diaEntries.dia': dia });
        let totalInwardWt = 0;
        lotInwards.forEach(inw => {
            const entry = inw.diaEntries.find(e => e.dia === dia);
            if (entry) totalInwardWt += (entry.recWt || 0);
        });

        const lotOutwards = await Outward.find({ lotNo, dia });
        let totalOutwardWt = 0;
        lotOutwards.forEach(out => {
            out.items.forEach(item => {
                totalOutwardWt += (item.total_weight || 0);
            });
        });

        const balance = totalInwardWt - totalOutwardWt;
        console.log(`  Lot: ${lotNo}, Balance: ${balance}`);

        if (balance > 0.1) {
            // 3. Check if there are balanced sets (not yet dispatched)
            const usedSetNumbers = new Set();
            lotOutwards.forEach(out => {
                if (out.items) {
                    out.items.forEach(item => {
                        if (item.set_no) usedSetNumbers.add(item.set_no.toString());
                    });
                }
            });

            // Count total sets across all inwards for this lot
            let availableSet = null;
            let foundSet = false;

            for (const inw of lotInwards) {
                if (foundSet) break;
                if (inw.storageDetails && Array.isArray(inw.storageDetails)) {
                    for (const sd of inw.storageDetails) {
                        if (sd.dia === dia) {
                            // Assuming sets are listed in rows
                            for (const row of sd.rows) {
                                for (let i = 0; i < row.setWeights.length; i++) {
                                    const setNo = getSetIdentifierFromRow(row, i);
                                    if (!usedSetNumbers.has(setNo)) {
                                        availableSet = {
                                            lotNo,
                                            lotName: inw.lotName,
                                            rackName: sd.racks && sd.racks[i] ? sd.racks[i] : 'Not Assigned',
                                            palletNumber: sd.pallets && sd.pallets[i] ? sd.pallets[i] : 'Not Assigned',
                                            balanceWeight: balance
                                        };
                                        console.log(`  Found FIFO Lot: ${lotNo} with Set: ${setNo}`);
                                        foundSet = true;
                                        break;
                                    }
                                }
                                if (foundSet) break;
                            }
                        }
                        if (foundSet) break;
                    }
                } else {
                    // Fallback for lots without storage details but with balance
                    console.log(`  Lot ${lotNo} has balance but no storage details (sets)`);
                }
            }

            if (availableSet) {
                return res.json(availableSet);
            }
        }
    }

    console.log(`No FIFO recommendation found for ${lotName} / ${dia}`);
    res.json(null);
});

// --- OUTWARD HANDLERS ---

// @desc    Generate DC Number
// @route   GET /api/inventory/outward/generate-dc
const generateDcNumber = asyncHandler(async (req, res) => {
    const dateStr = new Date().toISOString().slice(0, 10).replace(/-/g, '');
    const count = await Outward.countDocuments({
        createdAt: {
            $gte: new Date(new Date().setHours(0, 0, 0, 0)),
            $lt: new Date(new Date().setHours(23, 59, 59, 999))
        }
    });
    const dcNo = `DC-${dateStr}-${(count + 1).toString().padStart(3, '0')}`;
    res.json({ dc_number: dcNo });
});

// @desc    Create a new outward entry (Outward Screen)
// @route   POST /api/inventory/outward
// @access  Private
const createOutward = asyncHandler(async (req, res) => {
    let {
        lotName,
        dateTime,
        dia,
        lotNo,
        partyName,
        process,
        address,
        vehicleNo,
        inTime,
        outTime,
        items,
        dc_number,
    } = req.body;

    // Parse items if it's a JSON string (common with multipart/form-data)
    console.log('[DEBUG] createOutward raw items type:', typeof items);

    if (typeof items === 'string') {
        try {
            console.log('[DEBUG] items is string, parsing...');
            items = JSON.parse(items);
            req.body.items = items;
            console.log('[DEBUG] Parsed items successfully. Is Array?', Array.isArray(items));
        } catch (e) {
            console.error('[DEBUG] Items parsing error:', e);
            res.status(400);
            throw new Error('Invalid items format');
        }
    } else if (!items) {
        console.log('[DEBUG] items is falsy, setting to empty array');
        items = [];
        req.body.items = items;
    }

    if (!Array.isArray(items)) {
        console.error('[DEBUG] Items is NOT an array. Type:', typeof items, 'Value:', items);
        res.status(400);
        throw new Error('Items must be an array of sets');
    }

    const dcNo = dc_number || `DC-${Date.now()}`;

    // FIFO PRIORITY CHECK (Lot Name + DIA)
    if (lotName && dia && lotNo) {
        const oldestAvailableLotNo = await getOldestAvailableLotNo(lotName, dia);
        if (oldestAvailableLotNo && oldestAvailableLotNo !== lotNo) {
            res.status(400);
            throw new Error(
                `FIFO Violation: Oldest available lot is ${oldestAvailableLotNo}. Please outward that lot first.`
            );
        }
    }

    // 1. Fetch Inwards and Outwards for balance check
    const normalizedLotNo = normalizeText(lotNo);
    const normalizedDia = normalizeText(dia);
    const lotRegex = new RegExp(`^\\s*${escapeRegex(normalizedLotNo)}\\s*$`, 'i');
    const diaRegex = new RegExp(`^\\s*${escapeRegex(normalizedDia)}\\s*$`, 'i');

    const [inwards, existingOutwards] = await Promise.all([
        Inward.find({ lotNo: lotRegex, 'diaEntries.dia': diaRegex }),
        Outward.find({ lotNo: lotRegex, dia: diaRegex })
    ]);

    const balanceMap = {};

    // Calculate Inward Totals per Set/Colour
    inwards.forEach(inw => {
        if (inw.storageDetails && Array.isArray(inw.storageDetails)) {
            inw.storageDetails.forEach(sdOrRow => {
                const rows = Array.isArray(sdOrRow.rows) ? sdOrRow.rows : [sdOrRow];
                rows.forEach(row => {
                    const rowDia = normalizeText(row.dia || sdOrRow.dia);
                    if (rowDia && !new RegExp(`^\\s*${escapeRegex(normalizedDia)}\\s*$`, 'i').test(rowDia)) return;

                    const rawColour = normalizeText(row.colour);
                    const weightsArray = row.setWeights || row.stickerDetails;
                    if (weightsArray && Array.isArray(weightsArray)) {
                        weightsArray.forEach((weight, idx) => {
                            const inWeight = parseFloat(weight) || 0;
                            if (inWeight <= 0) return;
                            const rawSetNo = getSetIdentifierFromRow(row, idx);
                            const key = canonicalKey(rawSetNo, rawColour);
                            if (!balanceMap[key]) balanceMap[key] = { weight: 0 };
                            balanceMap[key].weight += inWeight;
                        });
                    }
                });
            });
        }
    });

    // Subtract Existing Outward Totals per Set/Colour
    existingOutwards.forEach(out => {
        if (out.items && Array.isArray(out.items)) {
            out.items.forEach(item => {
                const rawSetNo = normalizeText(item.set_no);
                if (item.colours && Array.isArray(item.colours)) {
                    item.colours.forEach(c => {
                        const rawColour = normalizeText(c.colour);
                        const outWeight = parseFloat(c.weight) || 0;
                        const key = canonicalKey(rawSetNo, rawColour);
                        if (balanceMap[key]) {
                            balanceMap[key].weight -= outWeight;
                        }
                    });
                }
            });
        }
    });

    // Validate requested items against available balance
    for (const item of items) {
        if (item.colours) {
            for (const c of item.colours) {
                const key = canonicalKey(item.set_no, c.colour);
                const available = balanceMap[key] ? balanceMap[key].weight : 0;
                const requested = parseFloat(c.weight) || 0;
                
                // Allow a small tolerance for floating point precision (0.01 kg)
                if (requested > available + 0.01) {
                    res.status(400);
                    throw new Error(`Insufficient balance for Set ${item.set_no} with colour ${c.colour} for Lot ${lotNo}. Available: ${available.toFixed(3)}kg, Requested: ${requested.toFixed(3)}kg`);
                }
            }
        }
    }

    // Handle file uploads for signatures
    let finalLotInchargeSignature = req.body.lotInchargeSignature;
    let finalAuthorizedSignature = req.body.authorizedSignature;
    let lotInchargeSignTime = req.body.lotInchargeSignTime;
    let authorizedSignTime = req.body.authorizedSignTime;

    if (req.files) {
        if (req.files.lotInchargeSignature) {
            finalLotInchargeSignature = getFilePath(req.files.lotInchargeSignature[0]);
            lotInchargeSignTime = lotInchargeSignTime || new Date();
        }
        if (req.files.authorizedSignature) {
            finalAuthorizedSignature = getFilePath(req.files.authorizedSignature[0]);
            authorizedSignTime = authorizedSignTime || new Date();
        }
    }


    const outward = await Outward.create({
        user: req.user._id,
        dcNo,
        lotName,
        dateTime,
        dia,
        lotNo,
        partyName,
        process,
        address,
        vehicleNo,
        inTime,
        outTime,
        items: items.map(item => ({
            set_no: item.set_no,
            total_weight: item.total_weight || 0,
            rack_name: item.rack_name,
            pallet_number: item.pallet_number,
            colours: item.colours.map(c => ({
                colour: c.colour,
                weight: c.weight || 0,
                no_of_rolls: c.no_of_rolls || 0,
                roll_weight: c.roll_weight || 0
            }))
        })),
        lotInchargeSignature: finalLotInchargeSignature,
        authorizedSignature: finalAuthorizedSignature,
        lotInchargeSignTime: lotInchargeSignTime,
        authorizedSignTime: authorizedSignTime,
    });

    // Create notification
    await Notification.create({
        user: req.user._id,
        title: 'New Outward Created',
        body: `Outward entry processed for DC ${dcNo} (Lot: ${lotNo}).`,
        type: 'success'
    }).catch(err => console.error('Notification failed:', err));

    res.status(201).json(outward);
});

// @desc    Get all outward entries
// @route   GET /api/inventory/outward
// @access  Private
const getOutwards = asyncHandler(async (req, res) => {
    const { startDate, endDate, lotName, lotNo, dia } = req.query;

    let query = {};
    if (startDate || endDate) {
        query.dateTime = {}; // Note: dateTime is the field name in Outward model
        if (startDate) query.dateTime.$gte = startDate;
        if (endDate) query.dateTime.$lte = endDate;
    }
    if (lotName) query.lotName = { $regex: new RegExp('^' + lotName.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&') + '$', 'i') };
    if (lotNo) query.lotNo = { $regex: new RegExp('^' + lotNo.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&') + '$', 'i') };
    if (dia) query.dia = { $regex: new RegExp('^' + dia.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&') + '$', 'i') };

    const outwards = await Outward.find(query).sort({ dateTime: -1, createdAt: -1 }).lean();
    
    // Enrich with rate from Inward
    for (let out of outwards) {
        if (out.lotNo) {
            // Try partial match for lotNo too if needed, but usually strict is safer if data is clean
            const inward = await Inward.findOne({ 
                $or: [
                    { lotNo: out.lotNo },
                    { lotNo: { $regex: new RegExp(`^${out.lotNo.trim()}$`, 'i') } }
                ]
            }).select('rate diaEntries').lean();

            if (inward) {
                // Try to find rate for this specific dia if available
                const diaEntry = (inward.diaEntries || []).find(e => e.dia === out.dia);
                out.rate = diaEntry ? diaEntry.rate : (inward.rate || 0);
            } else {
                out.rate = 0;
            }
        } else {
            out.rate = 0;
        }
    }
    
    res.json(outwards);
});

// @desc    Delete an outward entry
// @route   DELETE /api/inventory/outward/:id
// @access  Private
const deleteOutward = asyncHandler(async (req, res) => {
    const outward = await Outward.findById(req.params.id);

    if (outward) {
        await outward.deleteOne();
        res.json({ message: 'Outward entry removed' });
    } else {
        res.status(404);
        throw new Error('Outward entry not found');
    }
});

// @desc    Update an outward entry
// @route   PUT /api/inventory/outward/:id
// @access  Private
const updateOutward = asyncHandler(async (req, res) => {
    const outward = await Outward.findById(req.params.id);

    if (outward) {
        let {
            lotName,
            dateTime,
            dia,
            lotNo,
            partyName,
            process,
            address,
            vehicleNo,
            inTime,
            outTime,
            items,
            dcNo
        } = req.body;

        if (typeof items === 'string') {
            items = JSON.parse(items);
        }

        outward.lotName = lotName || outward.lotName;
        outward.dateTime = dateTime || outward.dateTime;
        outward.dia = dia || outward.dia;
        outward.lotNo = lotNo || outward.lotNo;
        outward.partyName = partyName || outward.partyName;
        outward.process = process || outward.process;
        outward.address = address || outward.address;
        outward.vehicleNo = vehicleNo || outward.vehicleNo;
        outward.inTime = inTime || outward.inTime;
        outward.outTime = outTime || outward.outTime;
        outward.dcNo = dcNo || outward.dcNo;

        if (items) {
            outward.items = items.map(item => ({
                set_no: item.set_no,
                total_weight: item.total_weight || 0,
                rack_name: item.rack_name,
                pallet_number: item.pallet_number,
                colours: item.colours.map(c => ({
                    colour: c.colour,
                    weight: c.weight || 0,
                    no_of_rolls: c.no_of_rolls || 0,
                    roll_weight: c.roll_weight || 0
                }))
            }));
        }

        if (req.files) {
            if (req.files.lotInchargeSignature) {
                outward.lotInchargeSignature = getFilePath(req.files.lotInchargeSignature[0]);
                outward.lotInchargeSignTime = new Date();
            }
            if (req.files.authorizedSignature) {
                outward.authorizedSignature = getFilePath(req.files.authorizedSignature[0]);
                outward.authorizedSignTime = new Date();
            }
        }

        const updatedOutward = await outward.save();
        res.json(updatedOutward);
    } else {
        res.status(404);
        throw new Error('Outward entry not found');
    }
});


// @desc    Get Lot Aging Report
// @route   GET /api/inventory/reports/aging
// @access  Private
const getLotAgingReport = asyncHandler(async (req, res) => {
    const { lotNo, lotName, colour, dia, startDate, endDate } = req.query;

    let query = {};
    if (lotNo) query.lotNo = { $regex: new RegExp(lotNo, 'i') };
    if (lotName) query.lotName = { $regex: new RegExp(lotName, 'i') };

    if (startDate || endDate) {
        query.inwardDate = {};
        if (startDate) query.inwardDate.$gte = startDate;
        if (endDate) query.inwardDate.$lte = endDate;
    }

    const inwards = await Inward.find(query).sort({ inwardDate: 1 }).lean();
    const allOutwards = await Outward.find({}).lean();

    // Map outward quantities: Key = lotNo|dia|colour
    const outwardCredit = {};
    allOutwards.forEach(o => {
        o.items.forEach(item => {
            if (item.colours) {
                item.colours.forEach(c => {
                    const k = `${o.lotNo}|${o.dia}|${c.colour}`.toLowerCase();
                    if (!outwardCredit[k]) outwardCredit[k] = { weight: 0, rolls: 0 };
                    outwardCredit[k].weight += (c.weight || 0);
                    outwardCredit[k].rolls += (c.no_of_rolls || 0);
                });
            }
        });
    });

    let report = [];
    const now = new Date();

    inwards.forEach((inward) => {
        if (inward.storageDetails && inward.storageDetails.length > 0) {
            inward.storageDetails.forEach(sd => {
                sd.rows.forEach(row => {
                    // Correctly aggregate only active sets (those with non-empty weights)
                    const activeSetWeights = (row.setWeights || [])
                        .map(w => parseFloat(w))
                        .filter(w => !isNaN(w) && w > 0);
                    
                    let inwardWt = activeSetWeights.reduce((a, b) => a + b, 0);
                    let inwardRolls = activeSetWeights.length;

                    // Apply Outward Credit (FIFO)
                    const k = `${inward.lotNo}|${sd.dia}|${row.colour}`.toLowerCase();
                    if (outwardCredit[k]) {
                        const usedWt = Math.min(inwardWt, outwardCredit[k].weight);
                        const usedRolls = Math.min(inwardRolls, outwardCredit[k].rolls);
                        
                        inwardWt -= usedWt;
                        inwardRolls -= usedRolls;
                        
                        outwardCredit[k].weight -= usedWt;
                        outwardCredit[k].rolls -= usedRolls;
                    }

                    // Only show if there's stock remaining
                    if (inwardWt > 0.05) {
                        const diaRate = (inward.diaEntries.find(e => e.dia === sd.dia)?.rate) || inward.rate || 0;
                        report.push({
                            lot_number: inward.lotNo,
                            lot_name: inward.lotName,
                            inward_date: inward.inwardDate,
                            dia: sd.dia,
                            colour: row.colour,
                            rolls: inwardRolls,
                            weight: Number(inwardWt.toFixed(2)),
                            rate: diaRate,
                            age: Math.ceil((now - new Date(inward.inwardDate)) / (1000 * 60 * 60 * 24))
                        });
                    }
                });
            });
        } else {
            // Fallback for non-sticker entries (Legacy/Summary data)
            inward.diaEntries.forEach(entry => {
                let inwardWt = entry.recWt || 0;
                let inwardRolls = entry.recRoll || 0;

                const k = `${inward.lotNo}|${entry.dia}|n/a`.toLowerCase();
                if (outwardCredit[k]) {
                    const usedWt = Math.min(inwardWt, outwardCredit[k].weight);
                    const usedRolls = Math.min(inwardRolls, outwardCredit[k].rolls);
                    inwardWt -= usedWt;
                    inwardRolls -= usedRolls;
                    outwardCredit[k].weight -= usedWt;
                    outwardCredit[k].rolls -= usedRolls;
                }

                if (inwardWt > 0.05) {
                    report.push({
                        lot_number: inward.lotNo,
                        lot_name: inward.lotName,
                        inward_date: inward.inwardDate,
                        dia: entry.dia,
                        colour: 'N/A',
                        rolls: inwardRolls,
                        weight: Number(inwardWt.toFixed(2)),
                        rate: entry.rate || inward.rate || 0,
                        age: Math.ceil((now - new Date(inward.inwardDate)) / (1000 * 60 * 60 * 24))
                    });
                }
            });
        }
    });

    // Apply filters that couldn't be done in DB query easily
    if (colour) {
        report = report.filter(r => r.colour && r.colour.toLowerCase().includes(colour.toLowerCase()));
    }
    if (dia) {
        report = report.filter(r => r.dia && r.dia.toLowerCase().includes(dia.toLowerCase()));
    }

    res.json(report);
});

// @desc    Update complaint solution for Inward
// @route   PUT /api/inventory/inward/:id/complaint-solution
const updateInwardComplaint = asyncHandler(async (req, res) => {
    const inward = await Inward.findById(req.params.id);

    if (inward) {
        inward.complaintReply = req.body.complaintReply || inward.complaintReply;
        inward.complaintResolution = req.body.complaintResolution || inward.complaintResolution;
        inward.complaintFindDate = req.body.complaintFindDate || inward.complaintFindDate;
        inward.complaintCompletionDate = req.body.complaintCompletionDate || inward.complaintCompletionDate;
        inward.complaintArrestLotNo = req.body.complaintArrestLotNo || inward.complaintArrestLotNo;
        inward.isComplaintCleared = req.body.isComplaintCleared !== undefined ? req.body.isComplaintCleared : inward.isComplaintCleared;

        const updatedInward = await inward.save();
        res.json(updatedInward);
    } else {
        res.status(404);
        throw new Error('Inward not found');
    }
});

// @desc    Get Quality & Complaint Audit Report
// @route   GET /api/inventory/reports/quality-audit
const getQualityAuditReport = asyncHandler(async (req, res) => {
    const { lotNo, isCleared } = req.query;

    let query = {
        $or: [
            { qualityStatus: 'Not OK' },
            { gsmStatus: 'Not OK' },
            { shadeStatus: 'Not OK' },
            { washingStatus: 'Not OK' },
            { complaintText: { $exists: true, $ne: '' } },
            { complaintResolution: { $exists: true, $ne: '' } },
            { complaintReply: { $exists: true, $ne: '' } }
        ]
    };

    if (lotNo) query.lotNo = { $regex: new RegExp(lotNo, 'i') };
    if (isCleared !== undefined) query.isComplaintCleared = isCleared === 'true';

    const report = await Inward.find(query).sort({ inwardDate: -1 });
    res.json(report);
});

// @desc    Get Lot Details for Auto-population
// @route   GET /api/inventory/inward/lot-details
// @access  Private
const getLotDetails = asyncHandler(async (req, res) => {
    const { lotName, lotNo } = req.query;

    if (!lotName || !lotNo) {
        return res.status(400).json({ message: 'Lot Name and Lot No are required' });
    }

    const cleanLotNo = lotNo.toString().trim();
    const cleanLotName = lotName.toString().trim();

    // Escape regex special characters just in case
    const escapedLotNo = cleanLotNo.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const escapedLotName = cleanLotName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

    const inward = await Inward.findOne({
        lotNo: { $regex: new RegExp(`^\\s*${escapedLotNo}\\s*$`, 'i') },
        lotName: { $regex: new RegExp(`^\\s*${escapedLotName}\\s*$`, 'i') }
    });

    if (inward) {
        // Calculate existing totals per DIA
        const diaDetails = inward.diaEntries.map(entry => {
            // Find latest GSM for this DIA from storageDetails if available
            let latestGsm = inward.gsm || ''; // Default to main inward GSM
            if (inward.storageDetails && Array.isArray(inward.storageDetails)) {
                const sd = inward.storageDetails.find(s => s.dia === entry.dia);
                if (sd && sd.rows && sd.rows.length > 0) {
                    // Look for GSM in the first row of this DIA's storage details
                    latestGsm = sd.rows[0].gsm || latestGsm;
                }
            }

            return {
                dia: entry.dia,
                rollNo: entry.rollNo || '',
                existingRecRolls: entry.recRoll || entry.roll || 0,
                existingRecWt: entry.recWt || 0,
                gsm: latestGsm
            };
        });

        res.json(diaDetails);
    } else {
        res.json([]);
    }
});

// @desc    Get Distinct Lot Numbers from Inward
// @route   GET /api/inventory/inward/distinct-lots
const getDistinctLots = asyncHandler(async (req, res) => {
    const lots = await Inward.distinct('lotNo');
    // Map to object structure expected by frontend [{ lotNumber: '...' }]
    const result = lots.filter(l => l).map(l => ({ lotNumber: l }));
    res.json(result);
    res.json(result);
});

// @desc    Check for FIFO Violation (Set availability in previous lots)
// @route   GET /api/inventory/outward/check-fifo
const checkFifoViolation = asyncHandler(async (req, res) => {
    const { dia, setNo, rack, pallet } = req.query;

    if (!dia || !setNo) {
        res.status(400);
        throw new Error('Dia and Set Number are required');
    }


    // 1. Find all Inwards with this Dia, sorted by Date (Oldest first)
    // We need to look for ANY lot that has this combination available.
    // Logic: 
    // - Iterate through all lots (oldest to newest).
    // - If we find a lot that contains this specific Set No (mapped to Rack/Pallet if provided, or just Set No uniqueness within Dia)
    // - AND that set is NOT yet outwarded (balance > 0).
    // - Then that is the "Current FIFO Lot" for this Set.

    // However, the requirement is slightly more specific: 
    // "if I previously skipped an earlier lot and try to process a later lot... trigger notification... This Dia, Set Number... already available in a previous lot."

    // This implies we aren't just looking for "Is this set available ANYWHERE?".
    // We are looking for "Is this set available in an OLDER lot than the one I am currently working on?".
    // BUT, the current screen `_toggleSetSelection` doesn't pass the "Current Lot Date" or "Current Lot ID" easily to compare "Older".
    // AND the user selects "Lot Number" at the top of the screen.
    // SO, we know the "Current Selected Lot".

    // Revised Logic:
    // 1. Get the "Current Lot" (from query params - I need to add `currentLotNo` to request).
    // 2. Find the Inward Date of the Current Lot.
    // 3. Find all Lots OLDER than Current Lot (same Dia).
    // 4. Check if the requested Set (Set No) exists and is available in any of those OLDER lots.

    const { currentLotNo } = req.query;
    if (!currentLotNo) {
        // If no current lot is specified (rare), we can't compare "older". 
        // But maybe we just check ALL lots? 
        // Let's assume user ALWAYS selects a Lot No first.
        res.status(400);
        throw new Error('Current Lot Number is required');
    }

    const currentInward = await Inward.findOne({ lotNo: currentLotNo });
    if (!currentInward) {
        // Current lot not found? Can't do FIFO check against non-existent ref.
        return res.json({ violation: false });
    }

    // Find all lots with SAME Lot Name and Dia that are OLDER than current lot
    const olderInwards = await Inward.find({
        lotName: currentInward.lotName,
        'diaEntries.dia': dia,
        $or: [
            { inwardDate: { $lt: currentInward.inwardDate } },
            {
                inwardDate: currentInward.inwardDate,
                createdAt: { $lt: currentInward.createdAt },
                lotNo: { $ne: currentLotNo }
            }
        ]
    }).sort({ inwardDate: 1, createdAt: 1 });

    for (const oldLot of olderInwards) {
        // Check if Set exists in this Old Lot
        // We need to check if it was INWARDED
        let setInOldLot = false;

        if (oldLot.storageDetails && oldLot.storageDetails.length > 0) {
            oldLot.storageDetails.forEach(sd => {
                if (sd.dia === dia) {
                    sd.rows.forEach(row => {
                        const setIdx = findSetIndexInRow(row, setNo);
                        if (setIdx >= 0 && setIdx < row.setWeights.length) {
                            // This old lot HAS this set number.
                            // Check if Rack/Pallet matches? 
                            // User requirement: "This Dia, Set Number, Rack, and Pallet Number are already available..."
                            // This implies the Exact Same Physical Item (if Set No is unique globally or per Dia).
                            // If Set 1 is in Lot A (Rack A) and Set 1 is in Lot B (Rack B)... are they the same?
                            // Usually Set No resets per Lot? Or is it unique per Dia?
                            // "Select Set No (Unique)" in UI suggests unique per Lot.
                            // If Set 1 in Lot A and Set 1 in Lot B are different physical bundles, why block?
                            // "skipped an earlier lot... try to process a later lot"
                            // This means I should consume Lot A's Set 1 before Lot B's Set 1?
                            // YES. Standard FIFO. Consume Oldest Lot first.
                            // So if Lot A has a "Set 1" available, I shouldn't take "Set 1" from Lot B?
                            // Or simply, if Lot A has ANY stock, I should exhaust it?
                            // The prompt specifically says: "This Dia, Set Number, Rack, and Pallet Number are already available"
                            // This phrasing is tricky. It sounds like specific item duplication.
                            // BUT "skipped earlier lot" implies general FIFO.
                            // I will assume: If "Set <N>" exists in Older Lot and is NOT Outwarded, BLOCK.
                            // It doesn't matter if Rack matches. If Old Lot has a Set <N>, use it.

                            // WAIT, usually Set 1 in Lot A is totally different fabric from Set 1 in Lot B.
                            // Unless it's "Same Dia" logic where sets are interchangeable?
                            // Let's stick to the prompt's implied logic: 
                            // Check if Older Lot has this Set Number available.

                            setInOldLot = true;
                        }
                    });
                }
            });
        }

        if (setInOldLot) {
            // Check if it's already used (Outwarded)
            const oldLotOutward = await Outward.find({ lotNo: oldLot.lotNo, dia });
            let isUsed = false;
            oldLotOutward.forEach(out => {
                if (out.items) {
                    out.items.forEach(item => {
                        if (item.set_no && item.set_no.toString() === setNo.toString()) {
                            isUsed = true;
                        }
                    });
                }
            });

            if (!isUsed) {
                // VIOLATION FOUND!
                // Old Lot has this Set, and it's not used.
                return res.json({
                    violation: true,
                    lotNo: oldLot.lotNo,
                    lotName: oldLot.lotName,
                    inwardDate: oldLot.inwardDate,
                    message: `FIFO Violation: Set ${setNo} is available in older Lot ${oldLot.lotNo}. Please use that first.`
                });
            }
        }
    }

    res.json({ violation: false });
});

// @desc    Delete an inward entry
// @route   DELETE /api/inventory/inward/:id
// @access  Private
const deleteInward = asyncHandler(async (req, res) => {
    const inward = await Inward.findById(req.params.id);

    if (inward) {
        await inward.deleteOne();
        res.json({ message: 'Inward entry removed' });
    } else {
        res.status(404);
        throw new Error('Inward entry not found');
    }
});

// @desc    Update an inward entry
// @route   PUT /api/inventory/inward/:id
// @access  Private
const updateInward = asyncHandler(async (req, res) => {
    const inward = await Inward.findById(req.params.id);

    if (inward) {
        const {
            inwardDate,
            inTime,
            outTime,
            lotName,
            lotNo,
            fromParty,
            process,
            rate,
            gsm,
            vehicleNo,
            partyDcNo,
            diaEntries,
            storageDetails,
            qualityStatus,
            qualityImage,
            gsmStatus,
            gsmImage,
            shadeStatus,
            shadeImage,
            washingStatus,
            washingImage,
            complaintText,
            complaintImage,
            balanceImage,
        } = req.body;

        inward.inwardDate = inwardDate || inward.inwardDate;
        inward.inTime = inTime || inward.inTime;
        inward.outTime = outTime || inward.outTime;
        inward.lotName = lotName || inward.lotName;
        inward.lotNo = lotNo || inward.lotNo;
        inward.fromParty = fromParty || inward.fromParty;
        inward.process = process || inward.process;
        inward.rate = rate !== undefined ? Number(rate) : inward.rate;
        inward.gsm = gsm || inward.gsm;
        inward.vehicleNo = vehicleNo || inward.vehicleNo;
        inward.partyDcNo = partyDcNo || inward.partyDcNo;

        inward.qualityStatus = qualityStatus || inward.qualityStatus;
        inward.qualityImage = qualityImage || inward.qualityImage;
        inward.gsmStatus = gsmStatus || inward.gsmStatus;
        inward.gsmImage = gsmImage || inward.gsmImage;
        inward.shadeStatus = shadeStatus || inward.shadeStatus;
        inward.shadeImage = shadeImage || inward.shadeImage;
        inward.washingStatus = washingStatus || inward.washingStatus;
        inward.washingImage = washingImage || inward.washingImage;
        inward.complaintText = complaintText || inward.complaintText;
        inward.complaintImage = complaintImage || inward.complaintImage;
        inward.balanceImage = balanceImage || inward.balanceImage;

        if (diaEntries) {
            inward.diaEntries = typeof diaEntries === 'string' ? JSON.parse(diaEntries) : diaEntries;
        }
        if (storageDetails) {
            inward.storageDetails = typeof storageDetails === 'string' ? JSON.parse(storageDetails) : storageDetails;
            await syncColoursCategory(inward.storageDetails);
        }

        if (req.files) {
            if (req.files.lotInchargeSignature) {
                inward.lotInchargeSignature = getFilePath(req.files.lotInchargeSignature[0]);
            }
            if (req.files.authorizedSignature) {
                inward.authorizedSignature = getFilePath(req.files.authorizedSignature[0]);
            }
            if (req.files.mdSignature) {
                inward.mdSignature = getFilePath(req.files.mdSignature[0]);
            }
        }

        const updatedInward = await inward.save();
        res.json(updatedInward);
    } else {
        res.status(404);
        throw new Error('Inward entry not found');
    }
});

// @desc    Update stock in a specific rack/pallet slot from 3D interface
// @route   PUT /api/inventory/update-rack-stock
// @access  Private
const updateRackPalletStock = asyncHandler(async (req, res) => {
    const { lotNo, dia, setNo, colour, weightAction, weightValue } = req.body;
    
    const inward = await Inward.findOne({ 
        lotNo: { $regex: new RegExp(`^${lotNo.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, 'i') } 
    });

    if (!inward) {
        res.status(404);
        throw new Error('Inward not found');
    }

    let storage = inward.storageDetails;
    if (!Array.isArray(storage)) {
        res.status(400);
        throw new Error('Invalid storage structure in inward record');
    }

    let updated = false;
    let newWeight = 0;

    storage.forEach(block => {
        if (block.dia === dia) {
            block.rows.forEach(row => {
                if (row.colour.toLowerCase() === colour.toLowerCase()) {
                    const setIndex = findSetIndexInRow(row, setNo);
                    if (setIndex >= 0) {
                        let currentWeight = parseFloat(row.setWeights[setIndex]) || 0;
                        const val = parseFloat(weightValue) || 0;

                        if (weightAction === 'add') {
                            currentWeight += val;
                        } else if (weightAction === 'minus') {
                            currentWeight = Math.max(0, currentWeight - val);
                        } else if (weightAction === 'remove') {
                            currentWeight = 0;
                        }
                        
                        newWeight = currentWeight;
                        row.setWeights[setIndex] = currentWeight > 0.001 ? currentWeight.toFixed(2) : "";
                        updated = true;
                    }
                }
            });
        }
    });

    if (!updated) {
        res.status(404);
        throw new Error('Specific set/colour not found in storage details');
    }

    inward.markModified('storageDetails');
    await inward.save();

    res.json({ message: 'Stock updated successfully', currentWeight: newWeight });
});

export {
    createInward,
    importInwardWorkbook,
    getInwards,
    deleteInward,
    updateInward,
    getLotsFifo,
    getBalancedSets,
    generateInwardNumber,
    generateDcNumber,
    createOutward,
    getOutwards,
    deleteOutward,
    updateOutward,
    getLotAgingReport,
    getInwardColours,
    getFifoRecommendation,
    updateInwardComplaint,
    getQualityAuditReport,
    getLotDetails,
    getDistinctLots,
    updateRackPalletStock,
    checkFifoViolation,
};
