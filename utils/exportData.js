/**
 * Export utility functions for converting data to various formats
 */

/**
 * Convert array of objects to CSV format
 */
export function toCSV(data, filename = 'export.csv') {
  if (!data || data.length === 0) {
    return { content: '', filename };
  }

  // Get headers from first object
  const headers = Object.keys(data[0]);
  
  // Create CSV rows
  const csvRows = [
    headers.join(','), // Header row
    ...data.map(row => 
      headers.map(header => {
        const value = row[header];
        // Handle values that contain commas, quotes, or newlines
        if (value === null || value === undefined) {
          return '';
        }
        const stringValue = String(value);
        if (stringValue.includes(',') || stringValue.includes('"') || stringValue.includes('\n')) {
          return `"${stringValue.replace(/"/g, '""')}"`;
        }
        return stringValue;
      }).join(',')
    )
  ];

  const csvContent = csvRows.join('\n');
  return { content: csvContent, filename };
}

/**
 * Convert array of objects to JSON format
 */
export function toJSON(data, filename = 'export.json') {
  const jsonContent = JSON.stringify(data, null, 2);
  return { content: jsonContent, filename };
}

/**
 * Convert array of objects to Excel format (CSV with .xlsx extension for compatibility)
 * Note: For true Excel format, you'd need a library like 'xlsx', but CSV works in Excel
 */
export function toExcel(data, filename = 'export.xlsx') {
  // Use CSV format but with .xlsx extension
  // Excel can open CSV files
  const csvResult = toCSV(data, filename.replace('.xlsx', '.csv'));
  return { content: csvResult.content, filename: csvResult.filename.replace('.csv', '.xlsx') };
}

/**
 * Download file in browser
 */
export function downloadFile(content, filename, mimeType = 'text/plain') {
  const blob = new Blob([content], { type: mimeType });
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  URL.revokeObjectURL(url);
}

/**
 * Format filename with timestamp
 */
export function formatFilename(baseName, extension, includeTimestamp = true) {
  const timestamp = includeTimestamp 
    ? `_${new Date().toISOString().replace(/[:.]/g, '-').slice(0, -5)}`
    : '';
  return `${baseName}${timestamp}.${extension}`;
}

