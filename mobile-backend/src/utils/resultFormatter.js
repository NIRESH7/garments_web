const COLUMN_NAMES = {
    qualityStatus: 'Quality',
    complaintText: 'Message',
    lotNo: 'Lot #',
    lotName: 'Lot Name',
    fromParty: 'Party',
    partyName: 'Customer',
    inwardDate: 'Inward Date',
    dcNo: 'DC #',
    dateTime: 'Date',
    planId: 'Plan ID',
    planName: 'Plan',
    groupName: 'Group',
    itemNames: 'Items'
};

const TECHNICAL_COLUMNS = ['_id', '__v', 'user', 'updatedAt', 'id', 'createdAt', 'password', 'tokens', 'vehicleNo', 'inTime', 'outTime', 'partyDcNo'];

function formatColumnName(key) {
    return COLUMN_NAMES[key] || key.replace(/([A-Z])/g, ' $1').replace(/^./, str => str.toUpperCase());
}

export function formatResults(rows) {
    if (!rows || rows.length === 0) return '';

    // Filter out technical columns
    const cleanRows = rows.map(row => {
        const clean = { ...row };
        TECHNICAL_COLUMNS.forEach(col => delete clean[col]);
        return clean;
    });

    // Generate a bold, clean list for mobile readability
    return cleanRows.map((row, index) => {
        const entries = Object.entries(row)
            .filter(([_, v]) => v !== null && v !== undefined && v !== '')
            .map(([key, value]) => {
                const friendlyKey = formatColumnName(key);
                let displayValue = value;
                if (Array.isArray(value)) displayValue = value.join(', ');
                if (typeof value === 'object') displayValue = JSON.stringify(value);
                return `**${friendlyKey}**: ${displayValue}`;
            })
            .join('\n');
        
        return `Result ${index + 1}:\n${entries}\n\n--------------------\n`;
    }).join('\n');
}
