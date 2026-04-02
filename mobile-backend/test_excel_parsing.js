import XLSX from 'xlsx';

// Mock data and helper functions to test buildInwardPayloadFromSummaryRows
const normalizeText = (value) => value?.toString().trim() ?? '';
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

const extractPrefixedValueFromRows = (rows, prefixes) => "LOT-123";
const extractValueByRegex = (rows, regex) => "LOT-123";
const extractDiaFromRows = (rows) => "30";
const parseDateToIso = (raw) => "2025-02-24";


const buildInwardPayloadFromSummaryRowsTest = (rows) => {
    if (!rows || rows.length === 0) return null;

    const lotNo = "2425/00074";
    const dateRaw = "24/02/2025";
    const fromParty = "TEST PARTY";
    const lotName = "TEST LOT";
    const dia = "30";

    if (!lotNo || !lotName || !fromParty || !dia) return null;

    let rackList = ["RACK-1"];
    let palletList = ["PALLET-1"];

    let headerIdx = 0;
    let colourCol = 0;
    let totalWeightCol = 1;
    let totalRollCol = 2;

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

    // --- PASTE NEW LOGIC HERE ---
    const totalSets = 1;
    const racks = rackList.length > 0 ? [rackList[0]] : [];
    const pallets = palletList.length > 0 ? [palletList[0]] : [];

    const rowsWithSets = storageRows.map((row) => {
        return {
            colour: row.colour,
            gsm: '',
            rollNo: row.totalRolls.toString(), // Preserve actual roll count from Excel
            setWeights: [formatWeight(row.totalWeight)], // Full weight as one set entry
            setLabels: ['Weight'],
        };
    });
    // --- END NEW LOGIC ---

    return {
        diaEntries: [{
            dia,
            roll: totalRollsAll,
            sets: totalSets,
            delivWt: Number(totalWeightAll.toFixed(3)),
            recRoll: totalRollsAll,
            recWt: Number(totalWeightAll.toFixed(3)),
        }],
        storageDetails: [{
            dia,
            racks,
            pallets,
            rows: rowsWithSets,
        }],
    };
};

const mockExcelRows = [
    ["COLOUR", "TOTAL WEIGHT", "TOTAL ROLL"],
    ["20403-ICE BLUE", 351.896, 16],
    ["20886-GREEN", 300.764, 14],
];

const result = buildInwardPayloadFromSummaryRowsTest(mockExcelRows);

console.log('--- TEST RESULTS ---');
console.log('Result:', JSON.stringify(result, null, 2));

const iceBlue = result.storageDetails[0].rows[0];
console.log('\nChecking ICE BLUE Row:');
console.log('Colour:', iceBlue.colour);
console.log('Roll No:', iceBlue.rollNo);
console.log('Set Weights:', iceBlue.setWeights);

if (iceBlue.rollNo === "16" && iceBlue.setWeights.length === 1 && iceBlue.setWeights[0] === "351.896") {
    console.log('\n✅ VERIFICATION SUCCESS: Data stored as is!');
} else {
    console.log('\n❌ VERIFICATION FAILED!');
}
