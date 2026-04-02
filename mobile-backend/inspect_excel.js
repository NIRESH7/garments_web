import XLSX from 'xlsx';
import path from 'path';

const filePath = 'c:/Users/Admin/Desktop/omvinayagagarments/L-74 (1).xlsx';

try {
    const workbook = XLSX.readFile(filePath);
    const firstSheetName = workbook.SheetNames[0];
    const worksheet = workbook.Sheets[firstSheetName];
    
    const rows = XLSX.utils.sheet_to_json(worksheet, { header: 1 });
    
    console.log('--- EXCEL PREVIEW (First 20 rows) ---');
    rows.slice(0, 20).forEach((row, i) => {
        console.log(`Row ${i}:`, JSON.stringify(row));
    });
} catch (err) {
    console.error('Error reading excel:', err);
}
