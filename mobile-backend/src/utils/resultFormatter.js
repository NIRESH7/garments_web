// User-friendly column name mappings
const COLUMN_NAMES = {
    qualityStatus: 'Quality Status',
    complaintText: 'Complaint Details',
    lotNo: 'Lot No',
    lotName: 'Lot Name',
    fromParty: 'Supplier/Party',
    inwardDate: 'Inward Date',
    dcNo: 'DC No',
    dateTime: 'Date/Time',
    planId: 'Plan ID',
    planName: 'Plan Name'
};

const TECHNICAL_COLUMNS = ['_id', '__v', 'user', 'updatedAt', 'id', 'createdAt', 'password', 'tokens'];

function formatColumnName(key) {
    return COLUMN_NAMES[key] || key.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase());
}

export function formatResults(rows) {
    if (!rows || rows.length === 0) {
        return 'No matching records were found.';
    }

    // Filter out technical columns from all rows
    const cleanRows = rows.map(row => {
        const clean = { ...row };
        TECHNICAL_COLUMNS.forEach(col => delete clean[col]);
        return clean;
    });

    if (cleanRows.length === 1) {
        const row = cleanRows[0];

        // special handling for category-like objects with 'values'
        if (row.values && Array.isArray(row.values) && row.name) {
            return `**${row.name} list:**\n${row.values.join(', ')}`;
        }

        // Single row: show as key-value pairs with friendly names
        return Object.entries(row)
            .map(([key, value]) => {
                const friendlyKey = formatColumnName(key);
                const displayValue = value === null || value === undefined ? 'N/A' :
                    (Array.isArray(value) ? value.join(', ') :
                        (typeof value === 'object' ? JSON.stringify(value) : value));
                return `**${friendlyKey}**: ${displayValue}`;
            })
            .join('\n');
    }

    // Multiple rows: show as table with friendly headers
    const headers = Object.keys(cleanRows[0]);
    const friendlyHeaders = headers.map(h => formatColumnName(h));
    const table = cleanRows.map(row => headers.map(h => {
        const val = row[h];
        if (Array.isArray(val)) return val.join(', ');
        if (typeof val === 'object' && val !== null) return JSON.stringify(val);
        return (val ?? 'N/A');
    }));

    const headerLine = `| ${friendlyHeaders.join(' | ')} |`;
    const separator = `| ${friendlyHeaders.map(() => '---').join(' | ')} |`;
    const dataLines = table.map(cols => `| ${cols.join(' | ')} |`);

    return [headerLine, separator, ...dataLines].join('\n');
}
