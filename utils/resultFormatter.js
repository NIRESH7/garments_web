export function formatResults(rows) {
  if (!rows || rows.length === 0) {
    return 'No matching records were found.';
  }

  if (rows.length === 1) {
    return Object.entries(rows[0])
      .map(([key, value]) => `${key}: ${value ?? 'N/A'}`)
      .join('\n');
  }

  const headers = Object.keys(rows[0]);
  const table = rows.map(row => headers.map(h => row[h]));
  const headerLine = headers.join(' | ');
  const separator = headers.map(() => '---').join(' | ');
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

