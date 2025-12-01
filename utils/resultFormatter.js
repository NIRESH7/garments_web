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
  obtained_marks: 'Obtained Marks',
  class_rank: 'Class Rank',
  teacher_id: 'Teacher ID',
  teacher_name: 'Teacher Name',
  subject_id: 'Subject ID',
  subject_name: 'Subject',
  attendance_id: 'Attendance ID',
  fee_id: 'Fee ID',
  mark_id: 'Mark ID',
  rank_id: 'Rank ID',
  leave_id: 'Leave ID',
  summary_id: 'Summary ID',
  total_students: 'Total Students'
};

function formatColumnName(key) {
  return COLUMN_NAMES[key] || key.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase());
}

export function formatResults(rows) {
  if (!rows || rows.length === 0) {
    return 'No matching records were found.';
  }

  if (rows.length === 1) {
    // Single row: show as key-value pairs with friendly names
    return Object.entries(rows[0])
      .map(([key, value]) => {
        const friendlyKey = formatColumnName(key);
        const displayValue = value === null || value === undefined ? 'N/A' : value;
        return `${friendlyKey}: ${displayValue}`;
      })
      .join('\n');
  }

  // Multiple rows: show as table with friendly headers
  const headers = Object.keys(rows[0]);
  const friendlyHeaders = headers.map(h => formatColumnName(h));
  const table = rows.map(row => headers.map(h => row[h] ?? 'N/A'));
  
  const headerLine = friendlyHeaders.join(' | ');
  const separator = friendlyHeaders.map(() => '---').join(' | ');
  const dataLines = table.map(cols => cols.join(' | '));
  
  return [headerLine, separator, ...dataLines].join('\n');
}

export function summarizeHistory(rows) {
  if (!rows || rows.length === 0) {
    return 'No history recorded yet.';
  }
  return rows
    .map(row => `• ${row.question} → ${row.generated_sql}`)
    .join('\n');
}

