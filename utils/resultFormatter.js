// User-friendly column name mappings
const COLUMN_NAMES = {
  student_id: 'Student ID',
  student_name: 'Name',
  class: 'Class',
  section: 'Section',
  roll_no: 'Roll No',
  gender: 'Gender',
  total_days: 'Total Days',
  present_days: 'Present Days',
  absent_days: 'Absent Days',
  total_fee: 'Total Fee',
  paid_fee: 'Paid Fee',
  due_fee: 'Due Fee',
  leave_type: 'Leave Type',
  leave_days: 'Leave Days',
  exam_id: 'Exam ID',
  exam_name: 'Exam Name',
  total_marks: 'Total Marks',
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

    // Generate a bold, clean list for high readability
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
        
        return `${index + 1}. Details:\n${entries}\n\n--------------------\n`;
    }).join('\n');
}

export function summarizeHistory(rows) {
  if (!rows || rows.length === 0) {
    return 'No history recorded yet.';
  }
  return rows
    .map(row => `• ${row.question} → ${row.generated_sql}`)
    .join('\n');
}

